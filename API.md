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

notification.type:   bookingRequested | bookingConfirmed | bookingRejected
                     | bookingCancelled | rideReminder | rideCancelled
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
| `phone` | string | **məcburi** — istifadəçinin yazdığı kimi göndər |

Nömrəni normallaşdırmağa çalışma: server `0505550001`, `050 555 00 01`, `994…`
və `+994…` formalarının hamısını `+994505550001`-ə gətirir. Cavabdakı `phone`-u
saxla — 2-ci addımda **məhz o** göndərilməlidir.

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

## 5. Cihaz tokenləri (FCM)

### POST `/me/device-tokens` → 201
`{ "token": "<fcm_token>", "platform": "android" }`

Token cihazla birlikdə hesablar arasında köçdüyü üçün server `updateOrCreate`
işlədir — eyni tokeni təkrar göndərmək təhlükəsizdir.

**Nə vaxt çağırmalı:** girişdən dərhal sonra, `onTokenRefresh` hadisəsində və
tətbiq hər dəfə açılanda.

### DELETE `/me/device-tokens`
`{ "token": "<fcm_token>" }` — çıxışdan **əvvəl** çağır, yoxsa cihaz köhnə
hesabın bildirişlərini almağa davam edər.

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

`422` — sürücü profili yoxdursa və ya avtomobil başqasınındırsa.

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

```json
{ "data": [{
  "id": 120,
  "type": "bookingConfirmed",
  "ride_id": 7, "booking_id": 88, "conversation_id": 14,
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

> Push bildirişləri hələ **göndərilmir** — bu endpoint-lər yalnız tətbiqdaxili
> siyahını doldurur. FCM qoşulanda payload strukturu eyni qalacaq.

---

## 14. Axtarış tarixçəsi

`GET /me/recent-searches` → son 10 marşrut (hər marşrut üçün bir sətir).
`DELETE /me/recent-searches` → hamısını silir.

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
