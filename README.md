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

### SMS hələ qoşulmayıb

`request` cavabı kodu `code` sahəsində geri qaytarır və giriş ekranı onu banner-də
göstərir — cihaza SMS gəlmədiyi üçün başqa yolla girmək mümkün deyil.

> ⚠️ Provayder qoşulan kimi `code` sahəsi cavabdan **çıxarılmalıdır**. Qalsa,
> nömrəni bilən hər kəs kodu cavabdan oxuyub o hesaba girə bilər. Klient tərəfdə
> heç nə silmək lazım deyil: sahə gəlməyəndə banner öz-özünə yox olur.

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
| SMS provayderi | ⏸ kod hazırda cavabda qaytarılır |
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

409 ayrıca tutulur (`ConflictFailure`): §16.4-ə görə "bu səfərə artıq müraciət
etmisiniz" qalıcıdır, ləğv etsən belə təkrar müraciət olmur — istifadəçiyə
"yenidən cəhd edin" demək səhv olardı.

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
| Elan vermə şərti | avtomobil (sənəd təsdiqi **şərt deyil** — §9) | ✅ |
| Marşrut elanı (3 addım) | `POST /rides` | ✅ |
| Elan redaktəsi, aktiv/deaktiv, ləğv, tamamlama | `PUT`/`DELETE /rides/{id}`, `/complete` | ✅ |
| Axtarış + səhifələmə | `GET /rides` | ✅ |
| Bütün aktiv elanlar (filtrsiz) | `GET /rides` (şəhərsiz) | ⏳ backend `from_city_id`/`to_city_id`-ni ixtiyari etməlidir |
| Son axtarışlar | `GET /me/recent-searches` | ✅ |
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
| Admin panel | — | ❌ API-də admin endpoint-i yoxdur |

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

---

## Növbəti addımlar

1. **iOS Notification Service Extension** — şəkilli bildiriş və çatdırılma
   statistikası üçün. Xcode-da target yaratmaq tələb edir; push onsuz da gedir.
2. **Admin panel** — API-də admin endpoint-i yoxdur. `/me`-dəki `is_admin`
   bayrağı oxunur, amma istifadə olunacaq ekran yoxdur.
3. **Xəritə inteqrasiyası** — `pickup_point` / `dropoff_point` hazırda sərbəst
   mətndir.
