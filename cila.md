# Cila / Yapılacaklar Listesi

Bu dosya, test sürecinde tespit edilen ama **hemen düzeltilmeyip sonraya bırakılan** kod/konfigürasyon sorunlarını takip etmek için.

---

## 1. [ÇÖZÜLDÜ — Mac'te doğrulama bekliyor] iOS izin pencereleri açılmıyordu (kamera + "her zaman" konum)

**Kök sebep & çözüm (7 Temmuz 2026):** `permission_handler`, iOS'ta kullanılan her
izin türü için [ios/Podfile](ios/Podfile) `post_install`'da ayrı bir preprocessor
makrosu ister; makrosu olmayan iznin native kodu hiç derlenmez → `request()` sistem
penceresini hiç açmadan `denied` döner. Eksik olan `PERMISSION_LOCATION_ALWAYS`
(geofence'in arka plan konum izni) makrosu **Podfile'a eklendi**; kod tabanının
kullandığı tüm izinler (kamera + konum + her-zaman-konum + bildirim) tarandı ve
eksiksiz listelendi — **Podfile'da yapılacak başka iş yok.**

**Doğrulama (Mac'te, ilk iOS build'inde — zaten standart kurulum adımları):**
- [ ] `cd ios && pod install` (sorun sürerse: `rm -rf Pods Podfile.lock && pod install`)
- [ ] Cihazdan uygulamayı silip temiz kur (eski "denied" durumu cache'li olabilir)
- [ ] AR Kamera + QR-AR ekranlarında kamera izin penceresinin çıktığını doğrula
- [ ] Geofence toggle'ı açılınca "Her Zaman" konum akışının yürüdüğünü doğrula

---

## 2. [AÇIK] Prod TLS/certbot yapılandırması backend repo'sunda yok + `reuse_key` açılmalı

**⏰ SON TARİH: 24 Ağustos 2026** (sertifika yenileme günü). Uygulama SSL pinning'li
şekilde yayına çıkmadan önce mutlaka çözülmeli; yayın 24 Ağustos'tan sonraysa bile
`reuse_key` açılmadan yayınlanan pinning'li uygulama ilk sertifika yenilemesinde
**API'ye bağlanamaz hale gelir**.

**Durum tespiti (7 Temmuz 2026):**
- Canlı sunucu (`mobil.smartsamsun.com`) 443'te Let's Encrypt sertifikasıyla cevap
  veriyor ve 80→301 redirect yapıyor.
- Ama backend repo'daki `nginx/nginx.conf` **sadece port 80 dinliyor** — TLS bloğu,
  sertifika mount'u, certbot servisi repo'da YOK (compose'daki certbot mount'u yorum
  satırında). Yerel makinede gitignore'lu dosyalar dahil hiçbir yerde TLS config'i yok.
- Yani 443/TLS terminasyonu sunucuda repo DIŞI bir katmanda yaşıyor (host nginx? ayrı
  container? bilinmiyor). Mobil uygulamanın SPKI pin'i bu bilinmeyen kuruluma bağımlı.

**Yapılacak:**
- [ ] Sunucu erişimi olan kişiden şu salt-okunur komutların çıktısını al:
      `sudo ss -tlnp | grep ':443'` (443'ü kim dinliyor), `docker ps`,
      `sudo ls /etc/letsencrypt/live/`, `cat /etc/letsencrypt/renewal/mobil.smartsamsun.com.conf`
- [ ] Certbot yenileme conf'una `reuse_key = True` ekletilsin — adım adım rehber:
      `docs/SSL_PINNING_SERVER_SETUP.md` §2 (mobil repo)
- [ ] Yenileme sonrası pin doğrulaması: rehber §3 (beklenen pin:
      `BcKsW3xTBEvdNXN2hJyQmHuX3ZJVrs+5EIFvuL+E7yo=`)
- [ ] Yedek anahtar + yedek pin üret (rehber §4), build script'lerine ikinci pin ekle
- [ ] Orta vade: prod TLS config'ini repoya al (nginx.prod.conf + certbot sidecar +
      `/.well-known/acme-challenge/` location'ı — mevcut `location ~ /\.` kuralı ACME
      challenge'ı 404'lüyor, webroot yenilemesi bu config'le çalışamaz)

---

## 3. [KISMEN DÜZELTİLDİ] Firebase + Maps API key + OneSignal, yeni applicationId'ye geçirilmeli

7 Temmuz 2026'da applicationId/bundle id `com.example.sbb_mobile` →
`com.smartsamsun.mobil` yapıldı.

**Tamamlanan:**
- [x] Firebase Console'da yeni proje (`sbbmobile-d40ef`, paket `com.smartsamsun.mobil`)
      oluşturuldu; gerçek `google-services.json` indirilip
      `android/app/google-services.json`'a kondu (kullanıcı tarafından, 7 Temmuz).

**Yapılacak — OneSignal FCM (KRİTİK, Android push'u etkiler):**
- [ ] OneSignal, Android push'u FCM üzerinden **eski** Firebase projesinin
      (`sbbmobile-1684b`) service-account kimlik bilgileriyle gönderiyor olabilir.
      Yeni proje (`sbbmobile-d40ef`) için:
      1. Firebase Console (yeni proje) → **Project Settings → Service Accounts** →
         **Generate new private key** → JSON iner.
      2. [OneSignal Dashboard](https://dashboard.onesignal.com) → App `b457f34f...`
         → **Settings → Push & In-App → Google Android (FCM)** → bu JSON'u
         yükle/değiştir → Kaydet.
      3. iOS platformuna DOKUNMA — APNs ayrı, aşağıdaki #4'te ele alınıyor.
- [ ] Test: yeni paket+google-services.json ile build al → cihaza kur →
      OneSignal Dashboard → Audience → Subscriptions'ta cihaz "Subscribed"
      görünmeli → test push gönder.
- [ ] `ONESIGNAL_APP_ID` **değişmiyor** (`b457f34f...` kalıyor) — kod/backend'de
      hiçbir yerde güncelleme gerekmiyor, sadece dashboard'daki FCM credential'ı.

**Yapılacak — diğer konsol adımları:**
- [ ] Google Cloud Console → Maps API key kısıtlaması `com.example.sbb_mobile` paketine
      bağlıysa `com.smartsamsun.mobil` + yeni SHA-1 ile güncelle.
- [ ] iOS: Apple Developer'da `com.smartsamsun.mobil` bundle id'sini kaydet
      (bu, aşağıdaki #4'ün Adım 2a'sıyla aynı iş — birlikte yapılabilir).

---

## 4. [KISMEN DÜZELTİLDİ] iOS'a OneSignal push bildirimi gitmiyor (Android çalışıyor)

**Kök sebep (7 Temmuz 2026 tespit):** `ios/Runner.xcodeproj`'da Push Notifications
capability **hiç eklenmemiş**ti — `Runner.entitlements` dosyası yoktu,
`CODE_SIGN_ENTITLEMENTS` hiçbir build config'te tanımlı değildi,
`SystemCapabilities` boştu. `aps-environment` girişi olmadan cihaz APNs'ten
geçerli bir push token alamaz; bu yüzden Android (FCM üzerinden, bu adıma hiç
ihtiyaç duymuyor) çalışırken iOS sessizce başarısız oluyordu.
[docs/IOS_ONESIGNAL_KURULUM.md](docs/IOS_ONESIGNAL_KURULUM.md) Adım 4 hiç
uygulanmamış demek.

**Kod tarafında düzeltilen:**
- [x] `ios/Runner/Runner.entitlements` oluşturuldu (`aps-environment: development`)
- [x] `project.pbxproj`: Debug/Profile/Release üç build config'e de
      `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;` bağlandı + dosya
      Xcode "Runner" grubuna eklendi (Info.plist'in yanında görünür)

**Xcode/Apple Developer/OneSignal dashboard tarafında YAPILMASI GEREKENLER**
(kod değişikliği değil, GUI/portal işleri — Mac + ücretli Apple Developer
hesabı şart, rehber: `docs/IOS_ONESIGNAL_KURULUM.md`):
- [ ] Apple Developer Portal: App ID'de (`com.smartsamsun.mobil`) Push
      Notifications capability açık mı doğrula (Adım 2a)
- [ ] APNs Auth Key (.p8) üret — yoksa (Adım 2b)
- [ ] OneSignal Dashboard → App `b457f34f...` → Settings → Push & In-App →
      Apple iOS (APNs) → `.p8` + Key ID + Team ID + Bundle ID gir (Adım 3)
- [ ] Xcode'da Runner target → Signing & Capabilities'te Push Notifications
      capability'nin (artık entitlements dosyası sayesinde) doğru
      göründüğünü, Team'in seçili olduğunu doğrula (Adım 4)
- [ ] (Önerilir, zorunlu değil) Notification Service Extension ekle — zengin
      bildirim/rozet için (Adım 5-6); bu bir Xcode target'ı oluşturmayı
      gerektirir, dosya düzenlemesiyle güvenle yapılamaz
- [ ] Gerçek iPhone'da test: OneSignal Dashboard → Audience → Subscriptions'ta
      cihaz "Subscribed" görünmeli, ardından test push gönder (Adım 8 —
      simülatör push ALAMAZ)

---

## 5. [AÇIK] freeRASP release konfigürasyonu eksik (release keystore + Apple hesabı bekliyor)

7 Temmuz 2026'da entegre edilen RASP (freeRASP/Talsec —
[SECURITY_HARDENING.md](docs/SECURITY_HARDENING.md) §3.2) şu an **debug/geçici
değerlerle** çalışıyor. Release'e çıkmadan doldurulmalı, yoksa yanlış-pozitif
"repack" alarmı üretir:

- [ ] **Release keystore oluşunca:** `android/key.properties`'teki keystore'dan
      release imza sertifikasının SHA-256'sını (base64) üret:
      ```
      keytool -list -v -alias <alias> -keystore <store> -storepass <pass> \
        | awk '/SHA256:/{print $2}' | tr -d ':' | xxd -r -p | base64
      ```
      Sonucu `scripts/build_release.ps1`/`--AndroidSigningHashes` veya
      `.sh`/`ANDROID_SIGNING_HASHES` env'ine gir. **Doldurulmazsa her release
      build'de `appIntegrity` (repack) yanlış-pozitif alarmı üretir.**
- [ ] **Apple Developer hesabı bağlanınca:** Team ID'yi
      `scripts/build_release.ps1 -IosTeamId` / `.sh` `IOS_TEAM_ID` env'ine gir
      (iOS bundle id zaten `com.smartsamsun.mobil` olarak varsayılı doğru).
- [ ] (Ürün kararı, opsiyonel) `criticalThreatProvider`
      ([threat_monitor_service.dart](lib/core/security/threat_monitor_service.dart))
      şu an tespit edilen tehditleri topluyor ama hiçbir UI'a bağlı değil — QR
      ödeme ekranını `deviceIntegrityProvider` gibi buna da gate etmek istenirse
      karar verilmeli.

---

*(Yeni tespit edilen sorunlar bu listeye eklenecek.)*
