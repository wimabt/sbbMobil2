# Tersine Mühendislik & İstemci Güvenliği Sertleştirmesi

> Şartname §5.5.3 (tersine mühendislik tedbirleri), §10.4.1 (mobil uygulama
> güvenliği), §10.4.2 (veri sızıntısı) karşılığı. Son güncelleme: 7 Temmuz 2026.

Bu belge, mobil uygulamanın tersine mühendisliğe ve kötü amaçlı müdahaleye karşı
aldığı teknik tedbirleri ve **release build'in nasıl alınması gerektiğini** açıklar.

## 1. Kod Obfuscation (KRİTİK — build adımı)

Flutter'da iki ayrı katman obfuscate edilir:

| Katman | Araç | Durum |
|--------|------|-------|
| Java/Kotlin sarmalayıcı + plugin kodu | **R8 / ProGuard** | ✅ `android/app/build.gradle.kts` → `isMinifyEnabled = true`, `isShrinkResources = true`, `proguard-android-optimize.txt` + `proguard-rules.pro` |
| **Asıl Dart kodu** (`libapp.so`) | **`flutter build --obfuscate`** | ✅ `scripts/build_release.*` üzerinden zorunlu |

> ⚠️ R8 tek başına **yeterli değildir** — Dart kodu native `.so` içine gömülür ve
> `--obfuscate` olmadan sembol isimleri okunabilir kalır. **Release her zaman
> aşağıdaki scriptlerle alınmalıdır.**

### Release build alma

```powershell
# Windows
./scripts/build_release.ps1 -Target appbundle          # Play Store
./scripts/build_release.ps1 -Target ipa                # App Store
```
```bash
# macOS / Linux
./scripts/build_release.sh appbundle
./scripts/build_release.sh ipa
```

Scriptler şunu çalıştırır:
```
flutter build <target> --release --obfuscate --split-debug-info=symbols/<...>
```

- `--obfuscate` → Dart sınıf/metot isimleri karıştırılır.
- `--split-debug-info` → de-obfuscation için gerekli sembol haritası **uygulamadan
  ayrılır**, `symbols/` altına yazılır (`.gitignore`'da; repoya girmez).

### Sembol dosyaları (ÖNEMLİ)

`symbols/` klasörü **uygulamayla DAĞITILMAZ** ama her sürüm için **arşivlenmelidir**.
Üretimden gelen obfuscate'li crash stack-trace'leri yalnız ilgili sürümün sembol
dosyalarıyla okunabilir:

```
flutter symbolize -i <stack_trace.txt> -d symbols/<target-stamp>/app.android-arm64.symbols
```

## 2. İç Log Sızıntısının Engellenmesi

`lib/main.dart` — release/profile build'lerde tüm `debugPrint` çağrıları no-op'a
çevrilir:

```dart
if (!kDebugMode) {
  debugPrint = (String? message, {int? wrapWidth}) {};
}
```

Böylece endpoint isimleri, auth/state geçişleri, ID'ler vb. logcat/Console
üzerinden okunamaz. Debug build'lerde loglar korunur. Dosyaya loglama
(`LogService.enableFileLogging`) zaten yalnızca `kDebugMode`'da açılır.

## 3. Root / Jailbreak Tespiti + Runtime Koruması (RASP)

### 3.1 Temel root/jailbreak (jailbreak_detection)

`lib/core/security/device_integrity_service.dart` (`flutter_jailbreak_detection`):

- `main.dart` startup'ında `DeviceIntegrityService.checkAndWarn` çağrılır.
- Tehlikeli cihazda kapatılamaz güvenlik uyarısı gösterilir; QR ödeme / puan
  işlemleri kısıtlı moda alınır (`deviceIntegrityProvider`).
- Debug modda devre dışı (geliştirme bloke olmasın).

### 3.2 freeRASP / Talsec (7 Temmuz 2026 eklendi)

`lib/core/security/threat_monitor_service.dart` — native seviyede sürekli izleme.
Basit root kontrolünün ötesinde şunları tespit eder:

| Tehdit | Açıklama |
|--------|----------|
| `hooks` | Frida / Xposed / Shadow gibi hooking framework'leri |
| `debug` | Bağlı debugger (dinamik analiz) |
| `simulator` | Emülatör / simülatör |
| `appIntegrity` | **Repack / yeniden imzalama** (imza hash uyuşmazlığı) |
| `privilegedAccess` | Root / jailbreak (Magisk, unc0ver, Dopamine…) |
| `unofficialStore` | Resmî olmayan yükleme kaynağı |
| + | deviceBinding, adbEnabled, devMode, screen recording, VPN… |

- **Başlatma:** `main.dart` paralel görevlerinde `ThreatMonitorService.start()`.
- **Politika:** `killOnBypass: false` — native sert-kapatma YOK (yanlış-pozitif
  çökmesini önlemek için). Tehditler Dart tarafında toplanır; yalnız KRİTİK olanlar
  (`hooks`/`privilegedAccess`/`appIntegrity`/`debug`/`simulator`/`unofficialStore`/
  `deviceBinding`) `criticalThreatProvider` üzerinden UX kısıtına bağlanabilir.
- **`isProd: !kDebugMode`** — debug'da dev modu (alarm gürültüsü olmadan geliştirme).
- **Konfigürasyon** `--dart-define` ile (release değerleri `scripts/build_release.*`):
  - `ANDROID_SIGNING_HASHES` — release imza sertifikası SHA-256 (base64). **Release
    keystore oluşunca doldurulmalı**; boşsa debug hash gömülüdür ve her release'de
    `appIntegrity` alarmı üretir.
  - `IOS_TEAM_ID` / `IOS_BUNDLE_IDS` — iOS repack tespiti (Apple hesabı gerektirir).
  - `SECURITY_WATCHER_MAIL` — Talsec haftalık güvenlik raporu adresi.

### 3.3 App switcher gizlilik örtüsü (iOS)

`ios/Runner/AppDelegate.swift` — uygulama arka plana alınırken (`resignActive`)
ekranın üstüne opak örtü konur, aktifleşince kaldırılır. iOS FLAG_SECURE'u
desteklemediğinden, app-switcher önizlemesinde/arka plan snapshot'ında OTP/QR
gibi hassas içeriğin görünmesini engeller (Android'de bu işi FLAG_SECURE yapıyor).

## 4. Hassas Veri Saklama

- Token / kimlik bilgileri `flutter_secure_storage` (Keychain / Keystore) ile
  saklanır — `api_service.dart`, `api_client.dart`, `staff_api_service.dart`.
- Tüm API trafiği HTTPS/TLS üzerinden taşınır (§10.3.2). OSRM rota sorguları
  (kullanıcı konumu içerir) HTTPS'e taşındı (`distance_helper.dart`,
  `osrm_service.dart`).

## 5. Ağ Katmanı Sertleştirmesi (7 Temmuz 2026)

- **Network security config** (`android/app/src/main/res/xml/`):
  release'te yalnız **sistem CA'larına** güvenilir — kullanıcı CA'ları
  (Burp/mitmproxy) reddedilir. Cleartext istisnası yok. Geliştirme
  kolaylıkları (user CA, emülatör/LAN HTTP) `src/debug/res/xml/` altındaki
  debug kopyasında; release paketine girmez.
- **SSL (SPKI) pinning AKTİF**: `lib/core/network/ssl_pinning.dart` public key
  (SubjectPublicKeyInfo) SHA-256 pinler; doğrulama Dio
  `IOHttpClientAdapter.validateCertificate` üzerinden **her** bağlantıda
  çalışır. Pin'ler `scripts/build_release.*` içinden `--dart-define` ile
  gömülür, `SSL_PINNING_STRICT=true` ile fail-closed.
  **Sunucu tarafı gereksinimi (reuse_key) ve işletme rehberi:**
  `docs/SSL_PINNING_SERVER_SETUP.md`.
- **Release imza guard'ı**: `android/app/build.gradle.kts` — `key.properties`
  yokken release paketi build'i FAIL eder (sessiz debug-imzalı release önlenir;
  bilinçli kaçış: `-PallowDebugSigning=true`).

## 6. Yapılacaklar / İyileştirme Adayları

- [ ] iOS için Xcode "Strip Swift Symbols" + dSYM yükleme akışının CI'da
      doğrulanması.
- [ ] CI pipeline'ında release build'in **yalnızca** `build_release.*` üzerinden
      alınmasının zorunlu kılınması (manuel `flutter build` engellenmeli).
- [x] ~~SSL pinning değerlendirmesi~~ → SPKI pinning aktif (bkz. §5 +
      `docs/SSL_PINNING_SERVER_SETUP.md`). Kalan: yedek pin üretimi (rehber §4)
      ve sunucuda `reuse_key` doğrulaması.
- [x] ~~`applicationId` hâlâ `com.example.sbb_mobile`~~ → 7 Temmuz 2026:
      Android applicationId/namespace + iOS bundle id `com.smartsamsun.mobil`
      yapıldı (Kotlin paketi, method channel isimleri dahil). Konsol tarafı
      bekliyor: Firebase'e yeni paket adıyla uygulama ekleme + gerçek
      `google-services.json` + Maps API key kısıtı — bkz. `cila.md` #3.
- [ ] Bütünlük imzası / anti-tamper (Play Integrity API) ileri aşama değerlendirme.
- [x] ~~Runtime koruması genişletmesi (freeRASP)~~ → 7 Temmuz 2026: freeRASP
      entegre edildi (§3.2) + iOS app switcher örtüsü (§3.3). Kalan: release
      keystore oluşunca `ANDROID_SIGNING_HASHES`, Apple hesabı oluşunca
      `IOS_TEAM_ID` doldurulmalı; kritik tehditlerin QR gate'ine bağlanması
      (`criticalThreatProvider` hazır, henüz UI'da tüketilmiyor).
