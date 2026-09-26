# Yol Yoldaşı — API spesifikasiyası (v1)

Bu sənəd Flutter klientinin qurulması üçün tam istinaddır. Bütün endpoint-lər
Laravel 12 + Sanctum üzərində qurulub, autentifikasiya telefon nömrəsinə
göndərilən OTP ilə başlayır və Sanctum token ilə davam edir.

---

## 1. Əsas qaydalar

**Base URL**

```
https://<domen>/api/v1
```

> Domeni serverdən təsdiqlə — layihədə `yolyoldasi.az` və `yolyodasi.az`
> yazılışlarının hər ikisi işlənib. Flutter tərəfdə bunu `--dart-define` ilə
> konfiqurasiya et, koda sabit yazma.

**Hər sorğuda göndərilməli başlıqlar**

```
Accept: application/json
Content-Type: application/json          # fayl yükləmələrdə multipart/form-data
Authorization: Bearer <sanctum_token>   # qorunan endpoint-lərdə
```

`Accept: application/json` **məcburidir**. Onsuz Laravel validasiya xətalarında
JSON yerinə HTML redirect qaytarır.

**Tək obyekt cavabı**

```json
{ "data": { "id": 1, "...": "..." } }
```

**Səhifələnmiş cavab**

```json
{
  "data": [ { "...": "..." } ],
  "links": { "first": "...", "last": "...", "prev": null, "next": "..." },
  "meta": { "current_page": 1, "last_page": 4, "per_page": 20, "total": 74 }
}
```

**Xəta formatları**

| Kod | Nə vaxt | Gövdə |
|---|---|---|
| 401 | token yoxdur / etibarsızdır | `{"message":"..."}` |
| 403 | resurs başqasınındır, hesab bloklanıb | `{"message":"..."}` |
| 404 | tapılmadı (silinmiş istifadəçi daxil) | `{"message":"..."}` |
| 409 | təkrar əməliyyat (ikinci dəfə rezervasiya/rəy) | `{"message":"..."}` |
| 422 | validasiya və ya biznes qaydası | `{"message":"...","errors":{"field":["..."]}}` |
| 429 | limit aşıldı | `{"message":"Too Many Attempts."}` |

> 422 cavabında `errors` açarı **yalnız validasiya xətalarında** olur.
> Biznes qaydası pozulanda (`abort(422, '...')`) yalnız `message` gəlir.
> Klient hər iki halı idarə etməlidir.

**Tarixlər** — bütün tarix sahələri ISO 8601 (`2026-09-15T14:30:00+04:00`).
Yalnız `searched_date` `YYYY-MM-DD` formatındadır.

---

## 2. Enum dəyərləri

Bunları Flutter tərəfdə `enum` kimi təyin et — server məhz bu sətirləri gözləyir.

```
gender:              male | female | unspecified
active_mode:         passenger | driver
platform:            android | ios
language_code:       az | en | ru

ride.status:         active | inactive | completed | cancelled
booking.status:      pending | confirmed | rejected
                     | cancelled_by_passenger | cancelled_by_driver | completed

driver_profile.status: not_uploaded | pending | approved | rejected
document.type:         id_card | driver_license | vehicle_registration | insurance
document.status:       not_uploaded | pending | approved | rejected

report.reason:       no_show | unsafe_driving | rude_behaviour
                     | wrong_vehicle | price_dispute | spam | other

notification.type:   bookingRequested | bookingInstant | bookingConfirmed
                     | bookingRejected | bookingCancelled
                     | rideReminder | rideCancelled
                     | newMessage | reviewRequest
                     | documentsApproved | documentsRejected
```

---

## 3. Autentifikasiya axını

```
1. POST /auth/phone/request  { phone: "0505550001" }      → kod yaranır
2. POST /auth/phone/verify   { phone, code, device: "app" } → token
3. Cavabdakı token-i təhlükəsiz saxla (flutter_secure_storage)
4. Bundan sonra hər sorğuda Authorization: Bearer <token>
```

Hər iki addım **açıqdır** — token tələb etmir. Axın **həm qeydiyyat, həm giriş**
üçündür: nömrə bazada yoxdursa yeni hesab yaranır, varsa mövcud hesab qaytarılır.

`device: "app"` göndərəndə token **müddətsiz** olur. Göndərilməsə `web` sayılır
və token 1 saata bitir.

### POST `/auth/phone/request` — açıq, 10 sorğu/dəqiqə (IP)

| Sahə | Tip | Qayda |
|---|---|---|
| `phone` | string | **məcburi** — tam E.164, `+` ilə |

**Ölkə məhdudiyyəti yoxdur.** Nömrə `+` ilə başlayırsa, server onu olduğu kimi
qəbul edir — `+905551234567`, `+995555123456`, `+994505550001` hamısı işləyir.
Tətbiqdə ölkə seçimi var (defolt Azərbaycan) və o, tam nömrəni göndərir.

`+`-sız gələn nömrə Azərbaycan sayılır: `0505550001`, `050 555 00 01`, `994…`
hamısı `+994505550001` olur. Bu, ölkə seçimi olmayan köhnə tətbiq versiyaları
üçün saxlanılıb — **yeni klient həmişə `+` göndərməlidir**, əks halda doqquz
rəqəmli gürcü nömrəsi `+994…`, trunk sıfırı ilə yazılmış türk nömrəsi isə
`+0555…` olur.

Cavabdakı `phone`-u saxla — 2-ci addımda **məhz o** göndərilməlidir.

```json
{
  "message": "Təsdiq kodu yaradıldı.",
  "phone": "+994505550002",
  "expires_in": 300,
  "resend_after": 60,
  "code": "752082"
}
```

> `code` yalnız SMS provayderi qoşulana qədər qaytarılır. **Onu produksiyada
> saxlamaq hesab ələ keçirməyə bərabərdir** — nömrəni bilən hər kəs kodu
> cavabdan oxuyub o hesaba girə bilər.

| Hal | Kod | Gövdə |
|---|---|---|
| format səhvdir | `422` | `{"message":"Telefon nömrəsi düzgün deyil.","errors":{"phone":[…]}}` |
| 60 saniyə keçməyib | `429` | `{"message":"Yeni kod üçün 44 saniyə gözlə.","retry_after":44}` |
| IP limiti | `429` | `{"message":"Too Many Attempts."}` — gözləmə `Retry-After` başlığında |

İki fərqli 429 var və gözləmə müddətini fərqli yerdə verirlər: bizim throttle
gövdədə `retry_after`, Laravel-in `throttle` middleware-i isə yalnız
`Retry-After` başlığında. Klient hər ikisini oxumalıdır.

### POST `/auth/phone/verify` — açıq, 20 sorğu/dəqiqə (IP)

| Sahə | Tip | Qayda |
|---|---|---|
| `phone` | string | **məcburi** — 1-ci cavabdakı nömrə |
| `code` | string | **məcburi**, tam 6 rəqəm — string göndər |
| `device` | enum | ixtiyari, `web`\|`app` — tətbiqdə həmişə `app` |
| `full_name` | string | ixtiyari, 3–255 |
| `role` | enum | ixtiyari, `passenger`\|`driver` |
| `city_id` | int | ixtiyari, mövcud şəhər |

`full_name` / `role` / `city_id` göndərmə: hər girişdə mövcud profilin üzərinə
yazılacaq. Profil sonradan `PATCH /me` ilə doldurulur.

```json
{
  "token": "9|ZD7nhf...",
  "user": {
    "id": 6,
    "full_name": "Test Sərnişin",
    "phone": "+994505550002",
    "active_mode": "passenger",
    "has_driver_profile": false
  },
  "is_new_user": false
}
```

Buradakı `user` qısa formadır — şəhər, statistika və bildiriş seçimləri yoxdur.
Tam profil üçün dərhal sonra `GET /me` çağır.

| Hal | Kod | Gövdə |
|---|---|---|
| kod yanlışdır | `422` | `{"message":"Kod yanlışdır.","attempts_left":4}` |
| kod yoxdur / vaxtı keçib / işlənib | `422` | `{"message":"Kod tapılmadı və ya vaxtı keçib. Yeni kod istə."}` |
| 5 yanlış cəhd | `429` | `{"message":"Çox sayda yanlış cəhd. Yeni kod istə."}` — kod ləğv olunur |
| hesab bloklanıb | `403` | `{"message":"Hesabın bloklanıb. Dəstək ilə əlaqə saxla."}` |
| IP limiti | `429` | `{"message":"Too Many Attempts."}` |

Server qaydaları: kod 5 dəqiqə yaşayır · yeni kod istəyəndə köhnəsi dərhal ölür,
yəni istifadəçi iki dəfə «yenidən göndər» basıbsa yalnız sonuncu kod işləyir ·
uğurlu təsdiqdən sonra kod bir daha işləmir.

### POST `/auth/logout`
Cari tokeni silir. Digər cihazlardakı sessiyalara toxunmur.

### DELETE `/auth/account`
Hesabı silir (soft delete), nömrəni anonimləşdirir, bütün tokenləri və cihaz
tokenlərini silir. **Geri qaytarılmır.** Silmədən əvvəl istifadəçidən təsdiq al.

---

## 4. Profil

### GET `/me`

```json
{
  "data": {
    "id": 42,
    "phone": "+994501234567",
    "phone_verified_at": "2026-09-15T12:00:00+04:00",
    "full_name": "Rəşad Məmmədov",
    "photo_url": "https://.../storage/avatars/x.jpg",
    "about": "Həftə sonu Bakı–Qəbələ gedirəm.",
    "gender": "male",
    "birth_year": 1994,
    "city": { "id": 1, "name": "Bakı" },
    "active_mode": "passenger",
    "has_driver_profile": true,
    "language_code": "az",
    "is_admin": false,
    "stats": {
      "driver_rating": 4.8,  "driver_review_count": 12, "driver_trip_count": 15,
      "passenger_rating": 5.0, "passenger_review_count": 3, "passenger_trip_count": 4
    },
    "notification_preferences": { "...": "..." }
  }
}
```

### PATCH `/me`
Yalnız göndərdiyin sahələr dəyişir.

| Sahə | Qayda |
|---|---|
| `full_name` | 3–255 |
| `about` | nullable, ≤300 |
| `gender` | `male`\|`female`\|`unspecified` |
| `birth_year` | nullable, 1930 – (cari il − 16) |
| `city_id` | nullable, mövcud şəhər |
| `language_code` | `az`\|`en`\|`ru` |

### PUT `/me/mode`
`{ "active_mode": "driver" }` → `422` əgər `has_driver_profile` false-dursa.

### POST `/me/photo` — `multipart/form-data`
`photo`: jpg/jpeg/png/webp, ≤4 MB. Köhnə şəkil avtomatik silinir.

### GET / PUT `/me/notification-preferences`

```json
{ "data": {
  "user_id": 42, "push_enabled": true, "bookings": true,
  "messages": true, "reminders": true, "marketing": false
}}
```

PUT-da istənilən alt çoxluğu göndər. **`push_enabled` qalan dördünün üstündədir** —
klient "hamısını söndür" düyməsini ona bağlamalıdır.

---

## 5. Cihaz tokenləri (OneSignal)

### POST `/me/device-tokens` → 201
```json
{
  "token": "a1b2c3d4-...",
  "platform": "android",
  "provider": "onesignal",
  "external_id": "42"
}
```

| Sahə | Qayda |
|---|---|
| `token` | **məcburi** — OneSignal **subscription id** (köhnə klientlərdə FCM tokeni) |
| `platform` | **məcburi**, `android`\|`ios` |
| `provider` | ixtiyari, `onesignal`\|`fcm` — göndərilməsə `fcm` sayılır |
| `external_id` | ixtiyari — hesabın id-si, sətir kimi |

`token` artıq FCM registration tokeni deyil, OneSignal subscription id-sidir.
Formasına baxıb ayırd etmək mümkün olmadığına görə `provider` hansı olduğunu
deyir; ikisi fərqli API ilə ünvanlanır. Köhnə tətbiq versiyaları bu sahəni
göndərmir və `fcm` sayılır.

`external_id` hesabın öz id-sidir — tətbiq girişdən sonra
`OneSignal.login(user_id)` çağırır və həmin dəyəri buraya ötürür. Server onu
`users.onesignal_external_id`-yə yazır və bundan sonra bildirişi **cihaz
siyahısına yox, birbaşa hesaba** ünvanlayır. Fərq boşluqlardadır: token
dəyişəndə, bu sorğu alınmayanda və ya tətbiq yenidən quraşdırılanda cihaz
siyahıdan sakitcə düşür, alias isə qalır. Başqasının id-si göndərilsə
gözardı edilir.

Token cihazla birlikdə hesablar arasında köçdüyü üçün server `updateOrCreate`
işlədir — eyni tokeni təkrar göndərmək təhlükəsizdir.

**Nə vaxt çağırmalı:** girişdən dərhal sonra, subscription dəyişəndə və
tətbiq hər dəfə açılanda.

### DELETE `/me/device-tokens`
`{ "token": "<subscription_id>" }` — çıxışdan **əvvəl** çağır, yoxsa cihaz
köhnə hesabın bildirişlərini almağa davam edər.

`users.onesignal_external_id` qəsdən silinmir: tətbiq `OneSignal.logout()`
çağırdığı üçün bu cihaz artıq həmin hesabın adı altında görünmür, alias-ı
silmək isə eyni hesabın *digər* cihazlarını da kəsərdi.

---

## 6. Şəhərlər

### GET `/cities` — açıq
`{"data":[{"id":1,"name":"Bakı"}, ...]}` — 54 şəhər, ada görə sıralı.
Nadir dəyişir, klientdə keşlə.

---

## 7. Sürücü profili və sənədlər

### GET `/driver/profile`

```json
{ "data": {
  "status": "pending",
  "submitted_at": "2026-09-15T10:00:00+04:00",
  "reviewed_at": null,
  "rejection_reason": null,
  "instant_booking_default": false,
  "vehicle": { "id": 3, "brand": "Toyota", "model": "Prius",
               "color": "Ağ", "year": 2018, "seats": 4, "plate": "10-AB-123" },
  "documents": [
    { "type": "id_card", "status": "pending",
      "uploaded_at": "...", "rejection_reason": null, "needs_back_side": true },
    { "type": "driver_license", "status": "not_uploaded",
      "uploaded_at": null, "rejection_reason": null, "needs_back_side": true },
    { "type": "vehicle_registration", "status": "not_uploaded", "...": "..." },
    { "type": "insurance", "status": "not_uploaded", "...": "..." }
  ]
}}
```

`documents` **həmişə dörd element** qaytarır — yüklənməyənlər `not_uploaded`.
Klient siyahını olduğu kimi göstərə bilər.

Profilin ümumi `status`-u sənədlərdən törəyir:
hamısı `approved` → `approved` · biri `rejected` → `rejected` ·
hamısı yüklənib → `pending` · əks halda `not_uploaded`.

### PUT `/driver/profile`
`{ "instant_booking_default": true }` — yeni elanlarda ilkin dəyər.
Keçmiş elanlara təsir etmir.

### POST `/driver/documents` — `multipart/form-data` → 201

| Sahə | Qayda |
|---|---|
| `type` | **məcburi**, dörd növdən biri |
| `file` | **məcburi**, jpg/jpeg/png/pdf, ≤8 MB |
| `back_file` | ixtiyari, yalnız `id_card` və `driver_license` üçün |

Təkrar yükləmə mövcud sənədi əvəz edir və statusu `pending`-ə qaytarır —
rədd edilmiş sənədi yenidən göndərmək üçün eyni endpoint işlədilir.
`back_file`-ı yanlış növə göndərsən `422`.

---

## 8. Avtomobillər

| Metod | Yol |
|---|---|
| GET | `/vehicles` |
| POST | `/vehicles` → 201 |
| PUT | `/vehicles/{id}` |
| DELETE | `/vehicles/{id}` |

| Sahə | POST | Qayda |
|---|---|---|
| `brand` | məcburi | ≤255 |
| `model` | məcburi | ≤255 |
| `color` | ixtiyari | ≤20 |
| `plate` | ixtiyari | ≤15, məs. `10-AB-123` |
| `year` | ixtiyari | 1950 – (cari il + 1) |
| `seats` | ixtiyari | 1–4, default **4** |

İlk avtomobil avtomatik sürücü profilinə bağlanır və `has_driver_profile`
`true` olur. Aktiv səfərə bağlı avtomobil silinmir → `422`.

> `seats` sürücü daxil **ümumi yer sayıdır**, sərnişin yeri deyil.

---

## 9. Səfərlər

### GET `/rides` — axtarış

| Parametr | Qayda |
|---|---|
| `from_city_id` | **məcburi** |
| `to_city_id` | **məcburi**, `from_city_id`-dən fərqli |
| `date` | ixtiyari, `YYYY-MM-DD` |
| `seats` | ixtiyari, 1–4, default 1 |
| `sort` | ixtiyari, `departure_at` (default) \| `price_per_seat` |

Yalnız `active`, gələcək tarixli və **istənilən qədər boş yeri olan** səfərlər
qaytarılır. Səhifədə 20 nəticə. Hər axtarış avtomatik `recent-searches`-ə yazılır.

**Səfər obyekti**

```json
{
  "id": 7,
  "driver": { "id": 42, "full_name": "Rəşad M.", "photo_url": null,
              "gender": "male", "birth_year": 1994,
              "has_driver_profile": true, "stats": { "...": "..." } },
  "vehicle": { "id": 3, "brand": "Toyota", "model": "Prius",
               "color": "Ağ", "year": 2018, "seats": 4 },
  "from_city": { "id": 1, "name": "Bakı" },
  "to_city":   { "id": 9, "name": "Qəbələ" },
  "departure_at": "2026-09-20T08:00:00+04:00",
  "total_seats": 4, "booked_seats": 2, "seats_left": 2,
  "price_per_seat": 15.0,
  "status": "active",
  "note": "Siqaret çəkilmir.",
  "pickup_point": "20 Yanvar metrosu",
  "dropoff_point": "Qəbələ mərkəz",
  "instant_booking": false,
  "is_mine": false,
  "created_at": "2026-09-15T09:00:00+04:00"
}
```

> `vehicle.plate` **yalnız sürücünün özünə** qaytarılır. Başqası üçün açar
> cavabda ümumiyyətlə olmur — Dart modelində `plate` nullable olmalıdır.

### POST `/rides` → 201

| Sahə | Qayda |
|---|---|
| `vehicle_id` | **məcburi**, öz avtomobilin |
| `from_city_id` / `to_city_id` | **məcburi**, bir-birindən fərqli |
| `departure_at` | **məcburi**, gələcək tarix |
| `total_seats` | **məcburi**, 1–4 |
| `price_per_seat` | **məcburi**, 1–500 |
| `note` | ixtiyari, ≤400 |
| `pickup_point` / `dropoff_point` | ixtiyari, ≤255 |
| `instant_booking` | ixtiyari; göndərilməsə profilin defaultu |

`422` — sürücü profili yoxdursa, avtomobil başqasınındırsa və ya sürücünün
sənədləri (`driver_profile.status`) `approved` deyilsə. Sonuncu qayda
`POST /rides/{id}/repeat`-ə də aiddir; qaydadan əvvəl verilmiş elanlara
toxunulmur.

### GET `/rides/mine?status=active`
Sürücünün öz elanları, `departure_at` üzrə azalan.

### GET `/rides/{id}` · PUT `/rides/{id}`
PUT-da dəyişdirilə bilənlər: `departure_at`, `total_seats`, `price_per_seat`,
`note`, `pickup_point`, `dropoff_point`, `instant_booking`, `status`
(`active`\|`inactive`). Yalnız `active` səfər redaktə olunur.

> `total_seats`-i `booked_seats`-dən aşağı salmaq olmaz → `422`.

### DELETE `/rides/{id}` — ləğv
Sətir silinmir, `status` → `cancelled`. **Bütün `pending` və `confirmed`
rezervasiyalar avtomatik ləğv olunur** və sərnişinlərə bildiriş gedir.

### POST `/rides/{id}/complete`
Səfəri tamamlanmış elan edir: təsdiqlənmiş rezervasiyalar `completed` olur,
səfər sayğacları artır, hər iki tərəfə rəy tələbi göndərilir.
`422` — səfər hələ başlamayıbsa (`departure_at` gələcəkdədirsə).

---

## 10. Rezervasiyalar

### Vəziyyət diaqramı

```
                  instant_booking = false
  POST /rides/{id}/bookings ──────────────► pending
                                             │
                        confirm ─────────────┼───────────► confirmed ──► completed
                        reject  ─────────────┘                 │         (ride complete)
                                                               │
        cancel (sərnişin) ────► cancelled_by_passenger ◄───────┤
        cancel (sürücü)   ────► cancelled_by_driver   ◄────────┘

                  instant_booking = true
  POST /rides/{id}/bookings ──────────────► confirmed   (yer dərhal tutulur)
```

### POST `/rides/{id}/bookings` → 201

| Sahə | Qayda |
|---|---|
| `seats` | **məcburi**, 1–4 |
| `message` | ixtiyari, ≤400 |

Cavabda `conversation_id` gəlir — **söhbət rezervasiya ilə birlikdə açılır**,
tərəflər təsdiqdən əvvəl də yazışa bilir.

Elanı paylaşan sürücüyə bildiriş gedir: adi rejimdə `bookingRequested`, ani
bronda `bookingInstant` (§13).

Xətalar:
`422` öz səfərin · `422` səfər aktiv deyil · `422` vaxtı keçib ·
`422` boş yer yoxdur (yalnız `instant_booking`-də) ·
**`409` bu səfərə artıq müraciət etmisən**.

> `409` qalıcıdır: ləğv etsən belə eyni səfərə ikinci dəfə müraciət edə
> bilməzsən. Klient bunu istifadəçiyə aydın izah etməlidir.

### GET `/bookings?status=pending` — sərnişin kimi
### GET `/bookings/incoming?status=pending` — sürücü kimi
### GET `/bookings/{id}`

**Rezervasiya obyekti**

```json
{
  "id": 88,
  "ride": { "...": "səfər obyekti" },
  "passenger": { "...": "qısa profil" },
  "driver": { "...": "qısa profil" },
  "seats": 2,
  "total_price": 30.0,
  "status": "confirmed",
  "message": "İki nəfərik.",
  "decided_at": "2026-09-16T11:00:00+04:00",
  "cancelled_at": null,
  "cancellation_reason": null,
  "passenger_reviewed": false,
  "driver_reviewed": false,
  "conversation_id": 14,
  "contact_phone": "+994501234567",
  "created_at": "2026-09-16T10:30:00+04:00"
}
```

> `contact_phone` **yalnız `confirmed` və `completed` statusunda** gəlir və
> qarşı tərəfin nömrəsidir. Digər hallarda açar cavabda olmur — nullable et.

### POST `/bookings/{id}/confirm` — yalnız sürücü
`422` — artıq cavablandırılıbsa və ya boş yer qalmayıbsa.

### POST `/bookings/{id}/reject` — yalnız sürücü
Söhbəti bağlayır (`is_locked: true`).

### POST `/bookings/{id}/cancel` — hər iki tərəf
`{ "reason": "Planım dəyişdi" }` (ixtiyari, ≤255).
Təsdiqlənmiş rezervasiya ləğv olunanda yer səfərə geri qaytarılır.

---

## 11. Mesajlaşma

### GET `/conversations`

```json
{ "data": [{
  "id": 14, "booking_id": 88, "ride_id": 7,
  "last_message": "Saat 8-də görüşürük.",
  "last_message_at": "2026-09-16T12:00:00+04:00",
  "last_sender_id": 42,
  "is_locked": false,
  "other_user": { "...": "qısa profil" },
  "unread_count": 2
}]}
```

### GET `/conversations/{id}/messages`
Səhifədə 50, **ən yenidən köhnəyə** sıralı. Çat ekranında siyahını tərsinə çevir.

```json
{ "data": [{
  "id": 301, "sender_id": 42, "is_mine": true,
  "text": "Saat 8-də görüşürük.",
  "read_at": null,
  "created_at": "2026-09-16T12:00:00+04:00"
}]}
```

### POST `/conversations/{id}/messages` → 201
`{ "text": "..." }` — ≤1000 simvol. `422` əgər söhbət bağlanıbsa.

### POST `/conversations/{id}/read`
Oxunmamış sayğacı sıfırlayır və qarşı tərəfin mesajlarına `read_at` qoyur.
Çat ekranı açılanda çağır.

Eyni tranzaksiyada oxuyanın **bu söhbətə aid oxunmamış `newMessage`
bildirişlərini** də oxunmuş edir (`read_at = now()`). Başqa növlərə
(`bookingConfirmed`, `bookingCancelled` və s.) toxunmur — onlar söhbəti
oxumaqla bağlı deyil. Yəni uğurlu cavabdan sonra **hər iki** sayğac dəyişə
bilər: `/conversations/unread-count` və `/notifications/unread-count` (§13).
Klient ikisini də yenidən oxumalıdır, həmin bildirişlər üçün ayrıca
`POST /notifications/{id}/read` göndərməyə ehtiyac yoxdur.

> Əvvəllər bu çağırış bildirişlərə toxunmurdu: mesajlar oxunmuş olurdu, amma
> zəngdəki rəqəm düşmürdü, çünki hər mesaj alıcıya bir `newMessage` sətri də
> yaradır.

### GET `/conversations/unread-count`
`{ "unread_total": 5 }` — naviqasiyadakı nişan üçün.

> Söhbət rezervasiya `rejected` və ya `cancelled_*` olanda bağlanır
> (`is_locked: true`). Klient bu halda mesaj sahəsini deaktiv etməlidir.

---

## 12. Rəylər

### POST `/bookings/{id}/reviews` → 201

| Sahə | Qayda |
|---|---|
| `rating` | **məcburi**, 1–5 |
| `comment` | ixtiyari, ≤500 |

Yalnız `completed` rezervasiyaya yazıla bilər. Kim yazdığını server özü
müəyyən edir — `target` və rol avtomatik təyin olunur.
`409` — bu səfərə artıq rəy yazmısansa.

### GET `/users/{id}` — ictimai profil
### GET `/users/{id}/reviews?role=driver`

`role=driver` → həmin şəxsin **sürücü kimi** aldığı rəylər.
`role=passenger` → **sərnişin kimi** aldıqları. Parametrsiz → hamısı.

```json
{ "data": [{
  "id": 55,
  "author": { "...": "qısa profil" },
  "rating": 5,
  "author_was_driver": false,
  "comment": "Vaxtında gəldi.",
  "created_at": "..."
}]}
```

> `author_was_driver` **rəyi yazanın** rolunu bildirir, hədəfin yox.
> `false` = sərnişin yazıb = bu, sürücü haqqında rəydir.

---

## 13. Bildirişlər

| Metod | Yol | Nə edir |
|---|---|---|
| GET | `/notifications?unread=1` | siyahı, səhifədə 30 |
| GET | `/notifications/unread-count` | `{"unread_total": 3}` |
| POST | `/notifications/{id}/read` | biri oxundu |
| POST | `/notifications/read-all` | hamısı oxundu |

`unread-count` bütün oxunmamış sətirləri sayır, `newMessage` də daxil: hər
çat mesajı alıcıya bir `newMessage` bildirişi yaradır. Söhbət açılanda
(`POST /conversations/{id}/read`, §11) həmin söhbətin `newMessage` sətirləri
server tərəfində özü oxunmuş olur, ona görə bu sayğac da azalır — klient onu
həmin çağırışdan **sonra** yenidən oxumalıdır, eyni anda yox, yoxsa köhnə
rəqəmi ala bilər. Eyni qayda `/{id}/read` və `read-all` üçün də keçərlidir.

```json
{ "data": [{
  "id": 120,
  "type": "bookingRequested",
  "ride_id": 7, "booking_id": 88, "conversation_id": null,
  "actor": { "...": "qısa profil" },
  "payload": { "seats": 2 },
  "read_at": null,
  "created_at": "..."
}]}
```

**Deep-link:** `ride_id` / `booking_id` / `conversation_id` sahələri hansı
ekrana keçəcəyini göstərir. **Hər üçü `null` ola bilər** — əlaqəli obyekt
silinibsə keçid ölür. Klient bu halda siyahıda qalan bildirişə toxunanda
boş ekran yox, "artıq mövcud deyil" mesajı göstərməlidir.

### Yeni bron: kimə hansı növ gedir

`POST /rides/{id}/bookings` sürücüyə səfərin rejiminə görə **iki fərqli**
bildiriş göndərir:

| `type` | Kimə | Nə vaxt |
|---|---|---|
| `bookingRequested` | sürücüyə | sərnişin yer istədi, `instant_booking = false` — bron `pending`-dir, sürücü təsdiqləməli və ya rədd etməlidir |
| `bookingInstant` | sürücüyə | sərnişin yer bron etdi, `instant_booking = true` — bron artıq `confirmed`-dir, sürücüdən qərar gözlənilmir |
| `bookingConfirmed` | sərnişinə | sürücü sorğunu təsdiqlədi (`POST /bookings/{id}/confirm`) |

`bookingRequested` və `bookingInstant` eyni sahələri daşıyır: `ride_id`,
`booking_id`, `actor` — bron edən sərnişin, `payload.seats` — tutulan yer sayı.
`conversation_id` **null**-dur. Hər ikisi `bookings` kanalında gedir və
`notification_preferences.bookings` açarına tabedir. Toxunanda `booking_id`
üzrə rezervasiya ekranı açılır.

`bookingInstant`-in mətni: az `Səfərinizə yer bron edildi` ·
ru `Место в вашей поездке забронировано` · en `A seat on your ride was booked`.
Push-da bu mətn gövdədir, başlıq isə sərnişinin adıdır; tətbiqin siyahısında
həmin mətn başlıq olur.

> Əvvəllər ani bronda sürücüyə `bookingConfirmed` gedirdi. O, sərnişinin
> mətnidir — "Bronunuz təsdiqləndi" — və həm push, həm də tətbiqdəki başlıq
> yalnız `type`-a görə seçildiyi üçün sürücüyə öz bronunun təsdiqləndiyi
> deyilirdi. İndi `bookingConfirmed` yalnız sərnişinə gedir. Bu növü tanımayan
> köhnə tətbiq versiyası da toxunuşu `booking_id`-yə görə rezervasiyaya
> aparır; yalnız siyahıdakı başlıq bu növə aid olmur.

### Push payload

Hər bildiriş sətri yaradılanda OneSignal-a da göndərilir (`OneSignalService`).
`data` bloku **düz** və **tamamilə sətirlərdən** ibarətdir — FCM `data` bloku
yalnız `Map<String, String>` saxlaya bilir və klientdəki `PushMessage.fromData`
da buna görə yazılıb. İç-içə `actor` obyekti göndərilsə klientdə səssizcə
itərdi, ona görə yalnız ad düz açar kimi gedir:

```json
{
  "type": "newMessage",
  "notification_id": "120",
  "ride_id": "7",
  "booking_id": "88",
  "conversation_id": "14",
  "actor_name": "Rəşad Məmmədov",
  "created_at": "..."
}
```

Boş sahələr ümumiyyətlə göndərilmir. Başlıq və mətn `az`/`ru`/`en` üçün birlikdə
gedir; cihaz hansını göstərəcəyini tətbiqdə `OneSignal.User.setLanguage()` ilə
qoyulan hesab dilinə görə seçir.

**Göndərilməmə halları** — sətir hər halda yazılır, sadəcə push getmir:
`notification_preferences.push_enabled` söndürülüb · növün öz açarı
(`messages` / `bookings` / `reminders`) söndürülüb · hesab nə alias, nə də
cihaz qeyd etdirib · `ONESIGNAL_REST_API_KEY` boşdur.

### Admin panelindən gələn bildirişlər

Panel əl ilə də bildiriş göndərə bilir (hamıya və ya bir hesaba). Bunlar
**adi bildiriş sətri kimi yazılır** — yəni `GET /notifications` siyahısında,
`unread-count` sayğacında və `read` əməliyyatlarında digər növlərdən heç nə ilə
fərqlənmirlər. Ayrıca endpoint yoxdur.

```json
{
  "id": 310,
  "type": "adminMessage",
  "ride_id": null, "booking_id": null, "conversation_id": null,
  "actor": null,
  "payload": { "heading": "Texniki fasilə", "content": "Sabah 02:00–04:00 arası tətbiq işləməyəcək." },
  "read_at": null,
  "created_at": "2026-09-21T12:00:00+04:00"
}
```

| `type` | Kanal | Kimə getmir |
|---|---|---|
| `adminMessage` | `yolyoldasi_default` | `push_enabled: false` |
| `adminMarketing` | `yolyoldasi_marketing` | `push_enabled: false` və ya `marketing: false` |

**Klient tərəfdə nəzərə al:**

1. `actor` **null**, keçid sahələri (`ride_id` / `booking_id` /
   `conversation_id`) **null** — siyahıda bu iki növ üçün deep-link yox, sadəcə
   mətn göstərilməlidir.
2. Başlıq və mətn `payload.heading` / `payload.content`-dədir; digər növlərdə
   olduğu kimi `type`-a görə hazır mətn qurma.
3. Push `data` bloku qısadır — `{"type": "adminMessage", "created_at": "..."}`.
   İçində `notification_id` **yoxdur**: push bütün alıcılara bir sorğu ilə gedir,
   sətir id-si isə hər kəsdə fərqlidir. Belə push gələndə siyahını yenilə.
4. Tənzimləməni söndürən istifadəçi bu bildirişi **ümumiyyətlə almır** — nə push,
   nə də siyahıda sətir.

---

## 14. Axtarış tarixçəsi

`GET /me/recent-searches` → son 10 marşrut (hər marşrut üçün bir sətir).
`DELETE /me/recent-searches` → hamısını silir.

> **Klient bu endpoint-i çağırmır.** "Son axtarışlar" bölməsi ana ekrandan
> çıxarıldı, ona görə Flutter tərəfdə nə bloc, nə model, nə də `Api` sabiti
> qalıb. Cədvəlin özü **qalmalıdır**: `GET /rides` hər axtarışı ora yazır və
> §20-dəki tələb statistikası (`GET /demand`) bütünlüklə həmin sətirlərdən
> hesablanır. Yəni endpoint istifadəsizdir, data isə yox.

```json
{ "data": [{
  "from_city": { "id": 1, "name": "Bakı" },
  "to_city": { "id": 9, "name": "Qəbələ" },
  "searched_date": "2026-09-20",
  "seats": 2,
  "searched_at": "..."
}]}
```

---

## 15. Şikayətlər

### POST `/reports` → 201

| Sahə | Qayda |
|---|---|
| `target_user_id` | **məcburi**, özün ola bilməz |
| `reason` | **məcburi**, yeddi dəyərdən biri |
| `details` | `reason=other` olduqda **məcburi**, ≤2000 |
| `ride_id` / `booking_id` | ixtiyari, kontekst üçün |

---

## 16. Klient tərəfində nəzərə alınmalılar

1. **Token saxlanması** — `flutter_secure_storage`, `SharedPreferences` yox.
2. **401 tutucusu** — Dio interceptor qoy: 401 gələndə tokeni sil və istifadəçini
   giriş ekranına qaytar. Token serverdə ləğv edilmiş ola bilər. `/auth/phone/*`
   istisnadır — orada hələ sessiya yoxdur, 401-i sessiya bitməsi kimi oxuma.
3. **`seats_left` serverdən gəlir**, özün hesablama — `total_seats - booked_seats`
   klientdə köhnəlmiş ola bilər.
4. **Rezervasiya yaradılanda 409-u ayrıca tut** — bu, "təkrar müraciət" deməkdir
   və istifadəçiyə fərqli mesaj göstərilməlidir.
5. **Nullable sahələr:** `vehicle.plate`, `booking.contact_phone`,
   `notification.ride_id/booking_id/conversation_id`, `user.city`, `user.photo_url`,
   `about`, `birth_year`. Dart modellərində hamısını nullable elan et.
6. **Fayl yükləmələri** `multipart/form-data` — `Content-Type` başlığını əl ilə
   qoyma, Dio özü boundary ilə birlikdə təyin edir.
7. **Səhifələmə** — `meta.current_page < meta.last_page` olduqca `?page=N` ilə davam et.

---

## 17. Tətbiq versiyası (məcburi yeniləmə)

### GET `/app-version` — açıq

Tətbiq hər açılışda və fondan qayıdanda soruşur. **Açıqdır**: yeniləmə divarı
giriş ekranından da əvvəl qalxmalıdır, ona görə token tələb etmir.

| Parametr | Qayda |
|---|---|
| `platform` | `android` \| `ios` |
| `build` | tam ədəd — Android `versionCode`, iOS `CFBundleVersion` |
| `version` | ixtiyari, yalnız jurnal üçün (`1.0.0`) |
| `lang` | `az` \| `ru` \| `en`, standart `az` |

Qərarı **server verir**. Klient `status` sahəsinə baxır və müqayisə etmir —
beləliklə qaydanı dəyişmək üçün mağazaya yeni buraxılış göndərmək lazım gəlmir.

```json
{ "data": {
  "status": "required",
  "min_build": 8,
  "min_version": "1.1.0",
  "latest_build": 12,
  "latest_version": "1.2.0",
  "store_url": "https://play.google.com/store/apps/details?id=yolyoldasi.az",
  "message": "Köhnə versiya artıq dəstəklənmir."
}}
```

| `status` | Şərt | Tətbiqin davranışı |
|---|---|---|
| `required` | `build < min_build` | Ekran tam bloklanır, yalnız mağazaya keçid |
| `optional` | `min_build ≤ build < latest_build` | Keçiləbilən vərəq — “Yenilə” / “Sonra” |
| `ok` | `build ≥ latest_build` | Heç nə göstərilmir |

`ok` cavabı yalnız `status` daşıyır — göstəriləsi ekran olmadığı üçün qalan
sahələr qaytarılmır.

Dəyərlər `app_versions` cədvəlindədir (platforma başına bir sətir) və admin
panelinin **Tətbiq versiyası** səhifəsindən dəyişdirilir.

### Şübhə olanda yol ver

Endpoint aşağıdakı hallarda **`ok`** qaytarır — səhv bir cavabın nəticəsi
istifadəçinin tətbiqə ümumiyyətlə girə bilməməsidir:

- naməlum və ya boş `platform`;
- cədvəldə həmin platforma üçün sətir yoxdur;
- sətir var, amma `is_enabled = false`;
- `build` oxunmur və ya 1-dən kiçikdir.

Klient tərəfində eyni prinsip: sorğu alınmasa, cavab parse olunmasa, yaxud
`status` tanınmayan bir söz olsa — tətbiq açıq qalır. Serverin əlçatmaz olması
tətbiqin köhnə olduğuna dəlil deyil.

---

## 18. Girişsiz baxış

Bu endpoint-lər **token tələb etmir**. Token göndərilsə tanınır (`is_mine`,
`vehicle.plate`, axtarış tarixçəsi ona görə işləyir), göndərilməsə sorğu yenə
işləyir.

| Metod | Yol |
|---|---|
| GET | `/rides` |
| GET | `/rides/{id}` |
| GET | `/users/{id}` |
| GET | `/users/{id}/reviews` |
| POST | `/events` |

Səbəb funnel-dir: əvvəl bunlar `auth:sanctum` altında idi və tətbiqi ilk dəfə
açan adam **bir dənə də səfər görmədən** nömrəsini verməli olurdu. Giriş yalnız
bron etmək, yazışmaq və elan vermək üçün tələb olunur.

> Qonaq sorğusunda `recent_searches` **yazılmır** (sətrin sahibi olmazdı) və
> `is_mine` həmişə `false` olur.

Limit: dəqiqədə 120 sorğu (IP).

---

## 19. Tələb elanları (sərnişin tərəfi)

Bazarın ikinci yarısı. `rides` təklifi saxlayır, `ride_requests` tələbi:
"bu marşrutda, bu tarixdə yer axtarıram".

İki iş görür — sürücüyə real tələb göstərir və uyğun elan yaranan kimi
sərnişini geri çağırır.

### POST `/ride-requests` → 201

| Sahə | Qayda |
|---|---|
| `from_city_id` | **məcburi** |
| `to_city_id` | **məcburi**, `from_city_id`-dən fərqli |
| `wanted_date` | **məcburi**, `YYYY-MM-DD`, bu gün və ya sonra |
| `flexible_days` | ixtiyari, 0–3 (±gün) |
| `seats` | ixtiyari, 1–4, default 1 |
| `note` | ixtiyari, ≤300 |

Eyni marşrut + tarix üçün ikinci sətir yaranmır — mövcud sətir **yenilənir**
(409 qaytarılmır).

Cavabda `data` ilə yanaşı `matches` gəlir: həmin an uyğun gələn səfərlər
(səfər obyektlərinin massivi). Sərnişin "yazdım, gözləyirəm" ekranında
qalmamalıdır.

```json
{
  "data": {
    "id": 12,
    "passenger": { "...": "qısa profil" },
    "from_city": { "id": 1, "name": "Bakı" },
    "to_city":   { "id": 9, "name": "Qəbələ" },
    "wanted_date": "2026-09-25",
    "flexible_days": 1,
    "seats": 2,
    "note": "Axşam saatları uyğundur.",
    "status": "open",
    "is_mine": true,
    "matched_ride_id": null,
    "created_at": "..."
  },
  "matches": [ { "...": "səfər obyekti" } ]
}
```

### GET `/ride-requests?status=open`
Sərnişinin öz elanları. Filtrsiz sorğuda `open` və `fulfilled` qayıdır.

### GET `/ride-requests/{id}`
Sahibi və ya — elan `open` olduqda — istənilən daxil olmuş istifadəçi görə
bilir. Cavabda `matches` var.

### DELETE `/ride-requests/{id}`
Sətir silinmir, `status` → `cancelled`.

### GET `/ride-requests/incoming` — sürücü kimi

Marşrut verilməyəndə sürücünün **əvvəllər sürdüyü** marşrutlar götürülür; heç
elanı yoxdursa, profilindəki şəhərdən keçən tələblər. `from_city_id` +
`to_city_id` verilsə yalnız o marşrut.

### Statuslar

```
open       → sürücülərə görünür, matç axtarılır
fulfilled  → sərnişin uyğun səfəri bron etdi (avtomatik)
cancelled  → sərnişin özü bağladı
expired    → tarix keçdi (`demand:tidy` əmri bağlayır)
```

### Bildirişlər

İki yeni `notification.type`:

| `type` | Kimə | Nə vaxt |
|---|---|---|
| `rideRequestMatched` | sərnişinə | marşrutunda uyğun səfər yarandı |
| `rideRequestPosted` | sürücüyə | marşrutunda kimsə yer axtarır |

`rideRequestMatched` deep-link üçün `ride_id` daşıyır; `rideRequestPosted`-də
`ride_id` **null**-dur, keçid `payload.request_id`-yə görə qurulur.

> Sərnişinə eyni tələb üçün **gündə bir dəfədən çox** push getmir: bir
> marşrutda beş elan verən sürücü telefonu beş dəfə oyadardı.

---

## 20. Tələb statistikası və qiymət təklifi

### GET `/demand?from_city_id=1&to_city_id=9`

```json
{ "data": {
  "searches": 43, "requests": 6, "requested_seats": 9,
  "active_rides": 2, "seats_available": 3, "window_days": 7
}}
```

`searches` — son 7 gündə həmin marşrutu axtaran **fərqli istifadəçi** sayı
(`recent_searches`-də `(user, from, to)` unikaldır).

### GET `/demand/top`
Sürücünün ana ekranı üçün ən çox tələb olunan 5 marşrut. Şəhər sorğudan yox,
sürücünün profilindən götürülür. Sıralama xam axtarış sayına görə deyil,
**qarşılanmamış tələbə** görədir — elanı bol olan marşrut siyahıya düşmür.

Hər sətirdə `/demand` sahələri + `from_city`, `to_city`, `score`.

### GET `/price-suggestion?from_city_id=1&to_city_id=9`

```json
{ "data": {
  "suggested": 15.0, "min": 12.0, "max": 18.0,
  "source": "history", "sample_size": 24,
  "distance_km": 225.4, "fuel_estimate": 21.6
}}
```

`source`: `history` (marşrutdakı elanların medianı, ≥3 nümunə) ·
`distance` (koordinatlara görə) · `none` (heç biri — `suggested` **null**).

> `null` gələndə klient heç nə göstərməməlidir. Uydurma rəqəm susmaqdan pisdir.

---

## 21. Böyümə funksiyaları

### Səfər obyektinə əlavə sahələr

| Sahə | Məna |
|---|---|
| `women_only` | yalnız qadın sərnişin qəbul edən səfər |
| `is_boosted` | dəvət mükafatı ilə axtarışın başındadır |
| `share_url` | `https://<domen>/r/{id}` — ictimai səhifə |

`POST /rides` və `PUT /rides/{id}` `women_only` qəbul edir. **Yalnız
`gender=female` olan sürücü** onu `true` edə bilər → əks halda `422`.

Bron cəhdi: `women_only` səfərə `gender != female` sərnişin müraciət etsə
`422`.

### Axtarış filtrləri (`GET /rides`)

| Parametr | Dəyər |
|---|---|
| `driver_gender` | `male` \| `female` |
| `women_only` | `1` |
| `instant_only` | `1` |
| `verified_only` | `1` |

### Təkrar elan

`POST /rides/{id}/repeat` → 201

| Sahə | Qayda |
|---|---|
| `departure_at` | **məcburi**, gələcək tarix |
| `repeat_weeks` | ixtiyari, 1–8 — həftəlik təkrar |

`POST /rides` də `repeat_weeks` qəbul edir. Hər iki cavabda `created_count`
gəlir; `data` birinci yaradılmış səfərdir.

### Sürücü statistikası

`stats` blokuna üç sahə əlavə olundu (həm `/me`, həm qısa profil):

| Sahə | Məna |
|---|---|
| `driver_response_rate` | gələn sorğuların neçə %-inə cavab verib (0–100) |
| `driver_response_minutes` | orta cavab vaxtı (dəqiqə) |
| `driver_tier` | `new` \| `rising` \| `trusted` |

> İlk ikisi **3 sorğudan az olanda `null`** qayıdır: bir sorğuya cavab vermiş
> sürücünün "100%" görünməsi yalan siqnaldır.

`is_verified` qısa profildə gəlir — sənədləri təsdiqlənmiş sürücü. Əlaqə
yüklənməyibsə **açar ümumiyyətlə olmur** (§16.5): "bilinmir" ilə
"təsdiqlənməyib" fərqli şeylərdir.

### Təkrar bron (409 qaydası dəyişdi)

Əvvəl qayda qalıcı idi. İndi:

- sərnişin **özü ləğv edibsə** → bir dəfə yenidən müraciət edə bilər;
- sürücü rədd edibsə və ya ləğv edibsə → `409`, dəyişməz;
- limit keçiləndə → `409` «təkrar müraciət limitini keçmisən».

### Dəvət sistemi

`GET /me/referral`

```json
{ "data": {
  "code": "K7MQ2P", "invited_count": 4, "active_count": 2,
  "reward_days": 7, "boost_until": "2026-10-05T12:00:00+04:00"
}}
```

Kod `/me` cavabında da var (`referral_code`). `POST /auth/phone/verify`
ixtiyari `referral_code` qəbul edir — **yalnız yeni hesabda** işləyir.

Mükafat pul deyil: dəvət olunan ilk səfərini edəndə dəvət edənin elanları
7 gün axtarışın başında çıxır (maksimum 60 gün yığılır).

---

## 22. Telemetriya

### POST `/events` → 202 — açıq

```json
{
  "anonymous_id": "b3f1...",
  "platform": "android",
  "app_version": "1.1.0+7",
  "events": [
    { "name": "search_empty", "params": { "from_city_id": 1, "to_city_id": 9 },
      "occurred_at": "2026-09-22T10:00:00+04:00" }
  ]
}
```

Bir sorğuda ≤50 hadisə. Cavab: `{ "accepted": 1 }`.

- Ağ siyahıdan kənar `name` **sakitcə atılır** (xəta qaytarılmır) — tətbiqin
  yeni versiyasındakı bir hadisə bütün dəstəni itirməməlidir.
- `params`-dan şəxsi sahələr (`phone`, `name`, `message`, `token`, …) server
  tərəfdə **kəsilir**; yalnız sadə dəyərlər, ≤12 açar saxlanılır.
- `anonymous_id` girişdən əvvəlki addımları bağlayır.

Qəbul edilən adlar: `app_open`, `onboarding_done`, `signin_started`,
`signin_completed`, `profile_completed`, `search_performed`, `search_empty`,
`ride_viewed`, `ride_request_created`, `ride_request_opened`,
`booking_requested`, `booking_confirmed`, `booking_cancelled`,
`publish_started`, `publish_completed`, `ride_repeated`, `vehicle_added`,
`documents_uploaded`, `ride_shared`, `mode_switched`, `referral_shared`,
`review_submitted`.

---

## 23. SMS və OTP

`POST /auth/phone/request` artıq kodu **SMS ilə göndərir**
(`config/sms.php`). Cavabda:

| Sahə | Nə vaxt |
|---|---|
| `code` | yalnız `OTP_EXPOSE_CODE=true` **və** `APP_ENV != production` |
| `delivery_failed` | provayder qoşulub, amma sorğu alınmayıb |

`delivery_failed` gələndə kod bazada **hələ də etibarlıdır** — klient
"SMS gecikə bilər" deməli, axını dayandırmamalıdır.

---

## 24. Rejim keçidi

`PUT /me/mode` artıq **tam profil** qaytarır (`GET /me` ilə eyni gövdə) ki,
klient sessiyanı ikinci sorğu etmədən yeniləsin.

Rejim tətbiqdə profil ekranından da dəyişdirilir — əvvəl yalnız giriş
ekranında seçilirdi və dəyişmək üçün çıxıb yenidən OTP ilə girmək lazım idi.
