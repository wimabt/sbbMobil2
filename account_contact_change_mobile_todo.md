# Mobil TODO — E-posta Doğrulama + E-posta/Telefon Değiştirme (Flutter)

> Backend sözleşmesi: `account_contact_change_backend_todo.md`.
> Tüm yeni metin **TR + EN** (ARB + `context.l10n`). i18n taraması özel
> karaktersiz Türkçe metni kaçırabilir — elle gözden geçir.

---

## 0. Çekirdek mantık & kararlar
- **Çapraz kilit:** telefon işlemleri step-up'ı **e-postaya**, e-posta işlemleri step-up'ı **telefona**.
- **K1:** Profilde e-posta doğrulanmamışsa **"doğrulanmamış" rozeti**; telefon değişiminde zorunlu kapı.
- **K2:** E-posta **kaldırılamaz**, yalnızca değiştirilebilir.
- **K3:** Telefon değişince diğer cihazlar otomatik logout (backend revoke eder; mobil bilgilendirir).

---

## FAZ 0 — Model & altyapı  ✅ TAMAM
- [x] `AuthUser`'a **`emailVerified`** alanı (`auth_provider.dart`); `fromJson`/`copyWith`.
- [x] Sensitive-action token'ı bellekte tutan yardımcı (`account_contact_provider.dart`;
      secure storage'a yazılmaz, akış bitince/iptalde `resetSensitive()` ile temizlenir).

## FAZ 1 — E-posta doğrulama  ✅ TAMAM (uçtan uca)
- [x] `ApiService`: `startEmailVerification()`, `confirmEmailVerification(code)`.
      (Ayrı `addEmail` yok — e-postasız kullanıcı FAZ 2 change-email akışını kullanır.)
- [x] State akışı (`accountContactProvider`: start → confirm; başarıda `loadProfile(force:true)`).
- [x] **Hesap ekranı** (`/account`) + ayarlara giriş + e-posta **"doğrulanmamış" rozeti** + **"Doğrula" CTA** (K1).
- [x] Kod giriş sheet'i + "kodu tekrar gönder" + hata kodu → l10n eşlemesi (`contactErrorMessage`).

## FAZ 2 — E-posta değiştirme / ekleme  ✅ TAMAM (uçtan uca)
- [x] `ApiService`: `startEmailChange()`, `verifyEmailChangeStepup(otp)`, `setNewEmail(email)`, `confirmEmailChange(code)`.
- [x] State akışı (`accountContactProvider`, sensitive token yönetimi dahil).
- [x] 4 adımlı sihirbaz (`change_contact_flows.dart` → `ChangeEmailScreen`): telefon OTP → token → yeni e-posta → yeni e-postaya kod.
- [x] Hesap ekranında "E-postayı Değiştir" / e-postasızsa "E-posta Ekle" (`isAdd`) butonu + başarı snackbar'ı.

## FAZ 3 — Telefon değiştirme (FAZ 1'e bağımlı)  ✅ TAMAM (uçtan uca)
- [x] `ApiService`: `startPhoneChange()`, `verifyPhoneChangeStepup(code)`, `setNewPhone(phone)`, `confirmPhoneChange(otp)`.
- [x] State akışı (`accountContactProvider`).
- [x] 3 işlemli + step-up sihirbazı (`ChangePhoneScreen`): **e-postaya gelen kod** → yeni numara → yeni numara OTP.
- [x] **`EMAIL_REQUIRED_FIRST`** kapısı: doğrulanmış e-posta yoksa "önce e-postanı doğrula" ekranı (Hesap'a yönlendirir).
- [x] Başarıda diğer cihazların logout olacağı bilgisi gösterilir (`changePhoneOtherDevicesNote`).

---

## UI yerleşimi
- [ ] **Hesap Bilgileri ekranı** `/account` (router'a route + `_SettingsCard`'a satır:
      `lib/features/profile/presentation/widgets/settings_section.dart`).
      Ad, maskeli telefon, e-posta (+ doğrulanmamışsa rozet) ve "Değiştir" aksiyonları.
- [ ] OTP/kod girişinde mevcut `otp_screen` deseni yeniden kullanılabilir.
      ⚠️ **Yayından önce OTP'yi ekranda gösteren geçici kod kaldırılmalı** (`otp_screen.dart`).
- [ ] Tüm akışlarda her başarıda dönen `user`'ı state'e yaz **veya** `loadProfile(force: true)`.
- [ ] Backend hata kodlarını lokalize mesaja çevir; `_isSafeForUser` filtresini koru.

## State / hata
- [ ] Hata kodu → l10n eşlemesi: `EMAIL_REQUIRED_FIRST`, `CHANGE_ALREADY_PENDING`, `INVALID_CODE`,
      `CODE_EXPIRED`, `TOO_MANY_ATTEMPTS`, `RATE_LIMITED`, `VALUE_ALREADY_IN_USE`, `SAME_VALUE`.
- [ ] Geri/iptal her adımda sensitive token'ı temizliyor mu?

## l10n (TR+EN)
- [ ] Ekran/adım başlıkları, buton metinleri, "kod e-postanıza gönderildi" / "yeni numaranıza SMS",
      "doğrulanmamış" rozeti, hata mesajları.

## Senaryolar (mobil tarafı — atlanmayacak)
- [ ] S1 e-postasız → telefon değişiminde "önce e-posta ekle" kapısı.
- [ ] S2 doğrulanmamış → telefon değişiminde "önce doğrula" kapısı + profilde rozet.
- [ ] S4 same-value, S5 jenerik "kullanımda" hatası, S6 expired/limit, S7 akış terk → baştan,
      S8 pending çakışması, S9 cooldown, S12 itiraz bildirimi bilgilendirmesi.
- [ ] S10/S11 (kanal kaybı) → uygulama içinde "destek ile iletişim" yönlendirmesi.

## Test
- [ ] Mutlu yollar (3 faz), hatalı/expired kod, 429, pending çakışması, e-postasız/doğrulanmamış kullanıcı,
      telefon değişiminde diğer cihazların logout olması.
