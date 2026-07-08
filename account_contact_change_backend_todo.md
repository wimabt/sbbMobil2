# Backend TODO — E-posta Doğrulama + E-posta/Telefon Değiştirme

> Hedef servis: **sbbMobilBackend** — **Express + raw `pg` + Redis (ioredis) + JWT**, JavaScript.
> (NestJS DEĞİL.) Mobil `authApiClientProvider`'ın gittiği auth backend'i — CMS değil.
> ⚠️ Prod: asla `docker compose down` yapma; servisleri tek tek restart et.

## ✅ DURUM: UYGULANDI (2026-06-10)
- `src/db/migrations/038_email_verification.sql` — `users.email_verified BOOLEAN DEFAULT false`.
- `src/services/mail.service.js` — sağlayıcıdan bağımsız mail; **varsayılan `log` provider** (gönderim yok),
  SMTP (nodemailer) iskeleti. 🔌 **Bağlama kullanıcıya bırakıldı** (`.env`: `MAIL_PROVIDER`, `SMTP_*`).
- `src/services/contact-change.service.js` — Redis tabanlı kod, sensitive-action token, tek-pending
  (`cc:active:<userId>`), cooldown, maskeleme, `audit_logs`'a denetim izi.
- `src/routes/account-contact.routes.js` — 10 endpoint; `app.js` → `/api/v1/user` altına mount edildi.
- `src/routes/auth.routes.js` — `/auth/me` yanıtına `email_verified` eklendi.
- Pending/token/cooldown **Redis'te** (yeni tablo yok); denetim izi mevcut **`audit_logs`** tablosunda.

> ⚠️ **SMS boşluğu:** Telefona giden kodlar (e-posta değişimi step-up'ı + yeni numara OTP'si) için
> gerçek SMS sağlayıcısı yok — login OTP ile aynı durum. Bu kodlar yalnızca **production dışında**
> yanıtta `dev_code` olarak döner; prod'da SMS bağlanana kadar teslim edilemez.

> ▶️ **Çalıştırma:** `npm run migrate` (038'i uygular), sonra servis restart.

---

## 0. Tehdit modeli & çekirdek mantık (kullanıcı onaylı kararlar)

- Telefon numarası = **giriş kimlik bilgisi** (şifre yok, OTP login). Telefon değiştirmek
  = kimlik bilgisi devri = potansiyel account-takeover.
- **Çapraz kilit:** Telefon işlemlerinin step-up'ı **e-postaya**, e-posta işlemlerinin
  step-up'ı **telefona** gider. Tek bir kanalı ele geçiren (sadece SIM veya sadece e-posta)
  hesabı çalamaz.
- Mevcut durum: e-posta kayıtta **zorunlu toplanıyor ama hiç doğrulanmıyor**;
  `email_verified` alanı yok; login'de e-posta kullanılmıyor.

### Kararlar
- **K1 — Doğrulama zamanı:** Kayıt akışı değişmez. Profil, e-posta doğrulanmamışsa
  "doğrulanmamış" ibaresi gösterir (soft). Telefon değişimi için doğrulanmış e-posta **zorunlu kapı**.
- **K2 — E-posta kaldırma:** **Yok.** E-posta silinemez, yalnızca değiştirilebilir.
- **K3 — Telefon değişiminde:** mevcut cihaz hariç **tüm refresh token'lar iptal edilir.**

---

## FAZ 0 — Ortak altyapı (diğer her şeyin temeli)

- [ ] `users` tablosuna **`email_verified BOOLEAN DEFAULT false`** ekle (mevcut e-postalar `false`).
- [ ] `GET /api/v1/auth/me` yanıtına `email` + **`email_verified`** ekle.
- [ ] OTP/kod tablosuna **`purpose`** kolonu:
      `login | register | verify_email | change_email_stepup | change_email_new |
       change_phone_stepup | change_phone_new`.
- [ ] **`pending_contact_changes`**: `id, user_id, type(email|phone), new_value,
      status(pending|verified|expired|cancelled), stepup_verified_at, created_at, expires_at`.
      Kullanıcı başına **tek** aktif kayıt.
- [ ] **`account_change_audit`**: `user_id, action, old_masked, new_masked, ip, device, result, created_at`.
      Tam değer LOG'lanmaz (maskeli).
- [ ] **Sensitive-action token** mekanizması: step-up doğrulandıktan sonra üretilen,
      tek amaçlı, **kısa ömürlü (5–10 dk), tek kullanımlık** token; sadece ilgili değişiklik endpoint'inde geçerli.
      - `verify-stepup` yanıtında `{ success: true, token: "<...>" }` (veya `data.token`) döner.
      - Sonraki `set-new` / `confirm` çağrıları bu token'ı **`X-Sensitive-Action: <token>`** header'ında taşır
        (access-token'ın `Authorization: Bearer` header'ından AYRI; mobil böyle gönderiyor).
      - Token başka endpoint/işlemde reddedilir; ilgili pending kayda bağlıdır.

---

## FAZ 1 — E-posta doğrulama (TEMEL — önce bu)

Step-up kanalı: **telefon OTP** (kullanıcı telefonla girişli, telefonu çalışıyor).

- [ ] `POST /api/v1/user/email/verify/start`
      → Doğrulanmamış mevcut e-postaya 6 haneli kod (`purpose: verify_email`).
- [ ] `POST /api/v1/user/email/verify/confirm` `{ code }`
      → Doğruysa `email_verified=true`, audit log.
- [ ] `POST /api/v1/user/email/add` `{ new_email }` (e-postası olmayan/legacy kullanıcı)
      → Step-up: telefona OTP → sensitive token → yeni e-postaya kod → confirm ile doğrula.
      (E-posta zaten varsa "değiştirme" akışına yönlendir — bu add değil.)

---

## FAZ 2 — E-posta değiştirme / ekleme (4 adım, simetrik)

> E-postası olmayan (legacy) kullanıcı için de aynı akış kullanılır — backend
> "mevcut e-posta yok" durumunu ekleme gibi ele alır; ayrı `add` endpoint'i yok.

- [ ] `POST /api/v1/user/account/change-email/start`
      → Step-up: **mevcut telefona** OTP (`purpose: change_email_stepup`).
- [ ] `POST /api/v1/user/account/change-email/verify-stepup` `{ otp }`
      → OTP doğruysa **sensitive-action token** döner (`token`).
- [ ] `POST /api/v1/user/account/change-email/set-new` `{ new_email }` — header `X-Sensitive-Action`
      → RFC validate; başka hesapta kayıtlıysa **jenerik** hata; yeni adrese kod (`change_email_new`); pending kayıt.
- [ ] `POST /api/v1/user/account/change-email/confirm` `{ code }` — header `X-Sensitive-Action`
      → Güncelle, `email_verified=true`, **eski adrese** "e-postanız değişti + itiraz linki", audit log.

---

## FAZ 3 — Telefon değiştirme (FAZ 1'e bağımlı)

**Ön koşul:** doğrulanmış e-posta. Yoksa tüm `change-phone/*` çağrılarında **`409 EMAIL_REQUIRED_FIRST`**.

- [ ] `POST /api/v1/user/account/change-phone/start`
      → Doğrulanmış e-posta yoksa `409 EMAIL_REQUIRED_FIRST`.
      → **Mevcut e-postaya** 6 haneli kod (`purpose: change_phone_stepup`).
- [ ] `POST /api/v1/user/account/change-phone/verify-stepup` `{ code }` → **sensitive-action token** (`token`).
- [ ] `POST /api/v1/user/account/change-phone/set-new` `{ new_phone }` — header `X-Sensitive-Action`
      → E.164 validate; başka hesapta kayıtlıysa jenerik hata; yeni numaraya OTP (`change_phone_new`); pending kayıt.
- [ ] `POST /api/v1/user/account/change-phone/confirm` `{ otp }` — header `X-Sensitive-Action`
      → **Atomik** güncelle → **mevcut cihaz hariç tüm refresh token'ları iptal (K3)**
        → eski e-postaya "numaranız değişti + itiraz linki" → audit log.

---

## Güvenlik kontrolleri (tüm fazlarda zorunlu)

- [ ] **Rate limit:** kullanıcı + IP + hedef bazlı (mevcut send-otp 429 mantığını genişlet).
- [ ] **OTP/kod:** 6 hane, 5 dk TTL, **tek kullanımlık**, maks. 3–5 deneme → kilit, sabit-zamanlı karşılaştırma.
- [ ] **Anti-enumeration:** "zaten kayıtlı" sızdırma yok; jenerik mesaj.
- [ ] **Cooldown:** başarılı değişiklikten sonra 24s tekrar değiştirilemez.
- [ ] **Pending expiry:** kullanılmayan pending TTL sonunda otomatik iptal.
- [ ] **İtiraz/iptal:** her başarılı değişiklikte eski kanala bildirim + tek tıkla itiraz/geri al linki.
- [ ] **Audit:** her başarı/başarısızlık maskeli loglanır.

---

## E-posta gönderim servisi (bağlantılar hazırlanır, BAĞLAMA kullanıcıya bırakılır)

Bu özellik e-posta gönderimi gerektirir (doğrulama kodu, değişiklik bildirimi, itiraz linki).
Tüm **iskelet hazırlanır**, gerçek sağlayıcıya **bağlama** (kimlik bilgisi/secret) kullanıcıya bırakılır.

- [ ] **`MailService` arayüzü** (`sendVerificationCode`, `sendContactChangedNotice`).
- [ ] **Sağlayıcıdan bağımsız** soyutlama; başlangıçta `LogMailProvider` (kodu sadece loglar — dev'de akış test edilebilir).
- [ ] Prod sağlayıcı adapter iskeleti (SMTP **veya** SendGrid/Postmark/SES — biri seçilecek), gönderim
      mantığı yazılır ama **kimlik bilgileri boş** bırakılır.
- [ ] `.env.example`'a **placeholder** anahtarlar (örnek):
      `MAIL_PROVIDER=`, `MAIL_FROM=`, `SMTP_HOST=`, `SMTP_PORT=`, `SMTP_USER=`, `SMTP_PASS=`
      (veya `SENDGRID_API_KEY=`). `.env`'e gerçek değerleri **kullanıcı** girecek.
- [ ] E-posta şablonları (TR + EN): doğrulama kodu, "e-postanız/numaranız değişti" + itiraz linki.
- [ ] Sağlayıcı yapılandırılmamışsa: dev'de `LogMailProvider`'a düş, prod'da net hata logla (sessiz başarısızlık yok).

> 🔌 **BAĞLAMA NOKTASI:** Sağlayıcı seçimi + `.env` secret girişi + DNS (SPF/DKIM) ayarı kullanıcıya ait.
> Kod tarafı bu değerler dolar dolmaz çalışacak şekilde hazır bırakılır.

## Senaryo matrisi (atlanmayacak)

| # | Senaryo | Backend davranışı |
|---|---|---|
| S1 | E-postası yok, telefon değiştirmek istiyor | `409 EMAIL_REQUIRED_FIRST` → FAZ 1 (add+verify) |
| S2 | E-postası var ama doğrulanmamış, telefon değiştirmek istiyor | `409 EMAIL_REQUIRED_FIRST` → verify |
| S3 | Doğrulanmış e-posta var | Telefon değişimi serbest |
| S4 | Yeni telefon = eski / yeni e-posta = eski | `400` no-op |
| S5 | Yeni değer başka hesapta kayıtlı | Jenerik hata (anti-enumeration) |
| S6 | Kod expired / max deneme / rate limit | `CODE_EXPIRED` / `TOO_MANY_ATTEMPTS` / `RATE_LIMITED` |
| S7 | Akış ortası terk / sensitive-token expired | Pending sunucuda expire; client baştan başlar |
| S8 | İkinci eşzamanlı değişiklik | `409 CHANGE_ALREADY_PENDING` |
| S9 | Başarıdan hemen sonra tekrar | Cooldown reddi |
| S10 | E-posta erişimi kayıp + telefon değiştirmek istiyor | İçeride çözülemez → **manuel destek** (uygulama dışı; belgele) |
| S11 | SIM kayıp + e-posta değiştirmek istiyor | step-up SMS gelmez → destek yolu |
| S12 | Başarılı değişiklikte eski kanala itiraz bildirimi | Bildirim + iptal linki |

## Hata kodu sözleşmesi (mobil lokalize eder)
`EMAIL_REQUIRED_FIRST`, `CHANGE_ALREADY_PENDING`, `INVALID_CODE`, `CODE_EXPIRED`,
`TOO_MANY_ATTEMPTS`, `RATE_LIMITED`, `VALUE_ALREADY_IN_USE` (jenerikleştirilir), `SAME_VALUE`.

## Yanıt sözleşmesi
Başarı: `{ success: true, user: {...güncel profil, email_verified...} }` → mobil direkt state'e yazar.
