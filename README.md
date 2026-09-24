# Yol Yoldaşı

Azərbaycan üçün şəhərlərarası **carpooling** (yol yoldaşı) tətbiqi. Sürücülər
boş yerlərini elan edir, sərnişinlər marşrut üzrə axtarıb yer bron edir.

Flutter · BLoC · go_router · Laravel REST API · Clean Architecture · Az/Ru/En ·
işıqlı və qaranlıq rejim.

---

## Tez başlanğıc

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=https://yolyoldasi.az/api/v1
```

Tətbiq bütün datanı [`API.md`](API.md)-də təsvir olunan REST API-dən alır.
`API_BASE_URL` verilməsə default `https://yolyoldasi.az/api/v1` istifadə olunur
— domeni serverdən təsdiqləyin, API.md-də iki yazılış qeyd olunub.

```bash
# Başqa mühit
flutter run --dart-define=API_BASE_URL=https://staging.yolyoldasi.az/api/v1

# Bütün sorğu/cavabları konsola yaz (bodylərdə nömrə və token olur — diqqətli olun)
flutter run --dart-define=LOG_HTTP=true
```

---

## Giriş

Telefon nömrəsi → 6 rəqəmli OTP → Sanctum token (API.md §3). Firebase çıxarılıb
və geri qayıtmır: iOS-da `PhoneAuthProvider.swift` crash verirdi, kodu indi
backend özü yaradır.

Axın [`PhoneSignInBloc`](lib/features/auth/presentation/bloc/phone_sign_in/phone_sign_in_bloc.dart)-dadır,
hər iki addım bir ekranda — [`login_page.dart`](lib/features/auth/presentation/pages/login_page.dart).

```
POST /auth/phone/request  { phone }                → kod + expires_in + resend_after
POST /auth/phone/verify   { phone, code, device }  → token + user
```

Nömrə serverə istifadəçinin yazdığı kimi gedir; normallaşdırmanı server edir və
2-ci addım **onun qaytardığı** `phone`-u göndərir.

### SMS

Kod artıq SMS ilə gedir — backend-də `config/sms.php`. Provayder şablonla
konfiqurasiya olunur, kod dəyişmir:

```
SMS_DRIVER=http
SMS_URL=https://.../send
SMS_PARAM_PHONE=to
SMS_PARAM_TEXT=text
SMS_AUTH_HEADER="Bearer ..."
```

`OTP_EXPOSE_CODE` defolt **false**-dur və `APP_ENV=production` olanda dəyəri nə
olursa-olsun söndürülür. Klient tərəfdə heç nə silmək lazım deyil: `code` sahəsi
gəlməyəndə banner öz-özünə yox olur.

> ⚠️ Qalan tək iş — provayderin açarlarını serverin `.env`-inə yazmaq.

### Development

```bash
# SMS addımını tamam atlamaq üçün hazır token
flutter run \
  --dart-define=API_BASE_URL=https://yolyoldasi.az/api/v1 \
  --dart-define=DEV_API_TOKEN='12|abcdef...'
```

Token-i backend-dən alın (Laravel: `$user->createToken('app')->plainTextToken`).
Köhnəlibsə problem deyil — `GET /me` 401 qaytarır və tətbiq giriş ekranına düşür.

### Hələ gözləyən

| Funksiya | Vəziyyət |
|---|---|
| SMS provayderi | ⏸ kod hazır, provayderin açarları `.env`-ə yazılmalıdır |
| iOS Notification Service Extension | ⏸ şəkil və çatdırılma təsdiqi üçün; push onsuz da gedir |
| Bildiriş mərkəzi (in-app) | ✅ işləyir — `GET /notifications` |

---

## Sessiya axını

```
1. POST /auth/phone/verify token qaytarır                (AuthRepositoryImpl)
2. flutter_secure_storage-a yazılır                      (SecureTokenStorage)
3. GET /me tam profili gətirir                           (SessionBloc)
4. Hər sorğuda Authorization: Bearer <token>             (AuthInterceptor)
```

401 gələndə `AuthInterceptor` siqnal verir, `SessionBloc` tokeni silir və
istifadəçini giriş ekranına qaytarır (§16.2). `/auth/phone/*` istisnadır — orada
hələ sessiya yoxdur, ona görə interceptor-un `_publicPaths` siyahısındadır.

### Yeniləmə divarı

Bu axının **qarşısında** dayanır. Tətbiq açılanda və fondan qayıdanda
`GET /app-version` soruşur (§17); cavab `required` olanda `AppGuard` bütün
ünvanları `/update`-ə yönəldir — giriş ekranını da. `optional` olanda tab
qabığının üstündə keçiləbilən vərəq açılır və cavab buraxılış başına bir dəfə
soruşulur.

Qərarı server verir, klient müqayisə etmir: minimum versiyanı qaldırmaq üçün
admin panelindəki **Tətbiq versiyası** səhifəsi kifayətdir, yeni buraxılış
lazım deyil.

Bir prinsip hər yerdə keçərlidir — **şübhə olanda yol ver**. Sorğu alınmasa,
cavab tanınmasa, yaxud cədvəldə sətir olmasa, tətbiq açıq qalır. Cari build
`pubspec.yaml`-dan yox, `package_info_plus` ilə binar fayldan oxunur
(`core/services/app_version_info.dart`) — çünki əl ilə saxlanan sabit sürüşən
kimi tətbiq öz istifadəçilərini bayırda qoyardı.

---

## Arxitektura

Feature-first **Clean Architecture**. Hər feature üç qatdan ibarətdir:

```
lib/features/<feature>/
├── domain/
│   ├── entities/         # saf Dart — nə Flutter, nə HTTP tanıyır
│   └── repositories/     # interfeys
├── data/
│   ├── models/           # fromJson / toJson — API.md-dəki payload-lar
│   ├── services/         # REST çağırışları (ApiClient üzərində)
│   └── repositories/     # interfeysin implementasiyası
└── presentation/
    ├── bloc/<ad>/        # <ad>_bloc.dart + _event.dart + _state.dart
    ├── pages/
    └── widgets/
```

Asılılıq istiqaməti həmişə içəriyə doğrudur: `presentation → domain ← data`.

### Şəbəkə qatı

```
core/network/
├── api_client.dart        # Dio wrapper — bütün HTTP bir yerdə
├── api_endpoints.dart     # API.md-dəki bütün yollar
├── api_envelope.dart      # { "data": ... } və səhifələnmə (meta/links)
├── api_error_mapper.dart  # §1-dəki status cədvəli → Failure
├── auth_interceptor.dart  # Bearer token + 401 siqnalı
├── json_reader.dart       # müdafiəli oxucular (absent açarlar üçün)
└── upload_file.dart       # multipart yükləmələr
```

`ApiClient` heç vaxt exception atmır — hər metod `Result<T>` qaytarır, beləliklə
çağıran tərəf xəta yolunu nəzərə almağa məcburdur.

### Xəta ötürülməsi

Hər `Failure` maşın oxunan `FailureCode` daşıyır. Amma API.md §1 qeyd edir ki,
biznes qaydası pozulanda (`abort(422, '...')`) yalnız **mətn** gəlir və onu
uyğunlaşdıracaq kod yoxdur. Ona görə `Failure.serverMessage` var:
`failure_message.dart` əvvəl onu, sonra lokal tərcüməni göstərir.

409 ayrıca tutulur (`ConflictFailure`): "bu səfərə artıq müraciət etmisiniz"
təkrar cəhdlə həll olunmur, ona görə istifadəçiyə "yenidən cəhd edin" demək
səhv olardı.

Qayda §21-də yumşaldılıb: **sərnişin özü ləğv edibsə** bir dəfə yenidən müraciət
edə bilir. Sürücü rədd və ya ləğv edibsə 409 dəyişmir — cavab artıq verilib.

### State management

`flutter_bloc`, hər ekran üçün Bloc + Event + State. Uzunömürlü bloc-lar
router-in üstündə (`app/app.dart`):

| Bloc | Rol |
|---|---|
| `SessionBloc` | kim daxil olub — router redirect-inin yeganə girişi |
| `PhoneSignInBloc` | telefon + OTP → sessiya, resend geri sayımı ilə |
| `SettingsBloc` | tema və dil |
| `CitiesBloc` | `GET /cities` (keşlənir) |
| `DriverProfileBloc` | sürücü profili, avtomobil, sənəd statusu |
| `RideSearchBloc` | axtarış sorğusu və nəticələri |
| `BadgesBloc` | oxunmamış mesaj/bildiriş sayğacları |

Blok olmayan, amma eyni qatda duran bir servis də var: `Analytics`
(`core/services/analytics.dart`). Hadisələr yaddaşda yığılır, 20 hadisədə və ya
30 saniyədə bir `POST /events`-ə gedir, tətbiq fona keçəndə boşaldılır. Heç vaxt
istisna atmır və heç vaxt gözlətmir — uğursuz göndəriş hadisələri növbənin
başına qaytarır, yalnız 200 hadisə həddini keçəndə atır.

Qalanları ekranla birlikdə yaranıb ölür (`RideDetailBloc`, `ChatBloc`, …).
`bloc_concurrency` transformerləri: axtarışda `restartable`, "daha çox yüklə"
üçün `droppable`.

### API ilə uyğunlaşdırılan yerlər

Bir neçə UI xüsusiyyəti API-də birbaşa qarşılığı olmadığı üçün klientdə
həll olunub — hər biri kodda şərhlə qeyd edilib:

| Nə | Necə |
|---|---|
| Qiymət və vaxt filtrləri | `GET /rides`-də parametr yoxdur → yüklənmiş nəticələrə tətbiq olunur, sheet-də bu yazılır |
| Bir elanın bronları | `GET /rides/{id}/bookings` yoxdur → `/bookings/incoming` filtrlənir |
| Çatda realtime | transport yoxdur → ekran açıq ikən 8 saniyəlik polling |
| Söhbətin başlığı | `GET /conversations/{id}` yoxdur → siyahıdan tapılır |
| Şəhər koordinatları | API yalnız `{id, name}` verir → `az_cities.dart` adla uyğunlaşdırılır |
| Vaxtı keçmiş elanlar | siyahı ekranda açıq qalarkən yola düşmə vaxtı keçə bilər → `Ride.upcomingOnly` hər siyahıdan çıxarır |
| Vaxtı keçmiş tələb elanları | serverin gecə süpürgəsi (`demand:tidy`) səhərə qədər işləmir → `RideRequest.hasExpired` klientdə də yoxlanır |

### Girişsiz baxış

`AppGuard` imzasız ziyarətçini **axtarış, nəticələr, səfər detalı və ictimai
profilə** buraxır (API.md §18). Yazan hər şey — bron, yazışma, elan, tələb —
həmin düyməyə toxunan anda giriş ekranına aparır.

Səbəb funnel-dir: əvvəl onboarding-dən sonrakı ilk ekran telefon nömrəsi
istəyirdi və adam bir dənə də səfər görmədən nömrəsini verməli olurdu.

Praktiki nəticə: qonaq ekranlarında `/me`-yə gedən heç bir sorğu işə düşməməlidir
— 401 `AuthInterceptor`-da "sessiya bitdi" kimi oxunur və heç vaxt daxil olmamış
adam üçün bu izaholunmazdır. `SearchHomePage` və `AppShell` bunu açıq yoxlayır.

---

## Funksionallıq

| Modul | Endpoint | Vəziyyət |
|---|---|---|
| Telefon OTP ilə giriş | `POST /auth/phone/request`, `/verify` | ✅ |
| Sürücü / sərnişin rejimi | `PUT /me/mode` | ✅ |
| Girişdə rejim seçimi | `PUT /me/mode` (`/me`-dən sonra) | ✅ |
| Profil, avatar, şəhər, doğum ili | `PATCH /me`, `POST /me/photo` | ✅ |
| Avtomobil | `/vehicles` | ✅ |
| 4 sənədin yüklənməsi | `POST /driver/documents` | ✅ |
| Elan vermə şərti | avtomobil + 4 sənədin admin təsdiqi (§9) | ✅ |
| Marşrut elanı (3 addım) | `POST /rides` | ✅ |
| Elan redaktəsi, aktiv/deaktiv, ləğv, tamamlama | `PUT`/`DELETE /rides/{id}`, `/complete` | ✅ |
| Axtarış + səhifələmə | `GET /rides` | ✅ |
| Bütün aktiv elanlar (filtrsiz) | `GET /rides` (şəhərsiz) | ✅ |
| **Girişsiz baxış** | `GET /rides`, `/users/{id}` açıqdır | ✅ API.md §18 |
| **Tələb elanları** | `/ride-requests/*` | ✅ API.md §19 |
| **Tələb statistikası** | `GET /demand`, `/demand/top` | ✅ API.md §20 |
| **Qiymət təklifi** | `GET /price-suggestion` | ✅ API.md §20 |
| **Qadın sürücü / qadın sərnişin** | `driver_gender`, `women_only` | ✅ API.md §21 |
| **Təkrar və həftəlik elan** | `POST /rides/{id}/repeat`, `repeat_weeks` | ✅ API.md §21 |
| **Paylaşma linki** | `share_url` → `/r/{id}` | ✅ API.md §21 |
| **Cavab statistikası, etibar pilləsi** | `stats.driver_*` | ✅ API.md §21 |
| **Dəvət sistemi** | `GET /me/referral` | ✅ API.md §21 |
| **Telemetriya** | `POST /events` | ✅ API.md §22 |
| **Rejim keçidi (profil ekranından)** | `PUT /me/mode` | ✅ API.md §24 |
| Son axtarışlar | `GET /me/recent-searches` | ❌ klientdən çıxarılıb |
| Bron və qərarlar | `/bookings/*` | ✅ |
| Ani bron | `instant_booking` | ✅ |
| Nömrənin təsdiqdən sonra açılması | `contact_phone` | ✅ |
| Daxili çat | `/conversations/*` | ✅ |
| Bildiriş mərkəzi | `/notifications` | ✅ |
| Rəylər | `/bookings/{id}/reviews`, `/users/{id}/reviews` | ✅ |
| Şikayət | `POST /reports` | ✅ |
| Dil Az/Ru/En | `language_code` | ✅ |
| Hesabın silinməsi | `DELETE /auth/account` | ✅ |
| Push **göndərilməsi** | OneSignal | ✅ backend `NotificationService` → `OneSignalService` |
| Admin panelindən elan | `adminMessage` / `adminMarketing` | ✅ API.md §13 |
| Məcburi / könüllü yeniləmə | `GET /app-version` | ✅ API.md §17 |
| Admin panel | — | ❌ API-də admin endpoint-i yoxdur (panel Laravel tərəfdədir) |

### Biznes qaydaları

`core/constants/app_constants.dart` — API.md-dəki validasiya cədvəllərinin
klient tərəfdəki güzgüsü. Server həmişə son sözü deyir; buradakılar yalnız
istifadəçinin 422 alacağı formanı göndərməsinin qarşısını alır.

---

## Dizayn sistemi

`core/theme/` — heç bir widget rəngi, radiusu və ya kölgəni birbaşa yazmır.

- `app_colors.dart` — brend palitrası + `AppPalette` (`ThemeExtension`)
- `app_dimens.dart` — 4pt aralıq şkalası, radiuslar, motion token-ləri
- `app_typography.dart` — Inter (ə, ğ, ı, İ, ö, ü, ç, ş üçün tam dəstək)
- `app_theme.dart` — hər iki rejim üçün tam `ThemeData`

Hazır komponentlər `core/widgets/` altındadır.

---

## Lokalizasiya

Kod generasiyası yoxdur. `core/localization/strings_az.dart` açar dəstinin
mənbəyidir; `strings_ru.dart` və `strings_en.dart` eyni açarları saxlamalıdır.
Uyğunluğu test qoruyur.

---

## Testlər

```bash
flutter test
```

- `test/api_models_test.dart` — API.md-dəki payload-ların birbaşa parse
  edilməsi: absent açarlar (§16.5), `seats_left`-in serverdən götürülməsi
  (§16.3), `plate`-in gizlədilməsi (§9), `contact_phone`-un yalnız təsdiqdən
  sonra görünməsi (§10), `author_was_driver`-in mənası (§12)
- `test/api_client_test.dart` — §1-dəki status cədvəli, 401 siqnalı,
  `PATCH`-də explicit null-un qorunması
- `test/localization_test.dart` — üç dilin açar uyğunluğu, cəm formaları
- `test/brand_mark_test.dart` — logonun kvadrat qalması
- `test/app_update_gate_test.dart` — §17-nin cavablarının oxunması və
  **əlçatmaz serverin tətbiqi bağlamaması**; könüllü xəbərdarlığın buraxılış
  başına bir dəfə soruşulması
- `test/app_update_router_test.dart` — `AppGuard`: məcburi yeniləmə zamanı
  bütün digər ünvanların `/update`-ə yönəlməsi, blokun olmadığı halda isə
  heç birinin yönəlməməsi; **girişsiz baxışın** açıq, yazma ekranlarının isə
  bağlı qalması
- `test/growth_models_test.dart` — §19–§22-nin payload-ları: tələb elanının
  tarix pəncərəsi, `is_verified`-in absent ↔ false fərqi, cavab statistikasının
  3 sorğudan az olanda `null` qalması, `women_only` bron qaydası

---

## Növbəti addımlar

1. **iOS Notification Service Extension** — şəkilli bildiriş və çatdırılma
   statistikası üçün. Xcode-da target yaratmaq tələb edir; push onsuz da gedir.
2. **Admin panel** — API-də admin endpoint-i yoxdur. `/me`-dəki `is_admin`
   bayrağı oxunur, amma istifadə olunacaq ekran yoxdur.
3. **Xəritə inteqrasiyası** — `pickup_point` / `dropoff_point` hazırda sərbəst
   mətndir.
4. **`demand:tidy` cron** — serverdə gündəlik işə salınmalıdır: vaxtı keçmiş
   tələb elanlarını bağlayır və sabahkı səfərlər üçün `rideReminder` göndərir.

   ```
   0 9 * * *  cd /var/www/... && php artisan demand:tidy
   ```
