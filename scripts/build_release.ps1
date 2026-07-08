<#
.SYNOPSIS
  SBB Mobile — obfuscate'li (tersine mühendisliğe karşı sertleştirilmiş) release build.

.DESCRIPTION
  Dart kodunu obfuscate eder ve debug sembollerini `symbols/` altına AYIRIR.
  Bu sembol dosyaları uygulamayla SHIP EDİLMEZ; yalnızca crash stack-trace'lerini
  okunur hale getirmek (de-obfuscation) için her sürümde arşivlenmelidir.

  R8/ProGuard (Android Java/Kotlin sarmalayıcı) zaten `build.gradle.kts` içinde
  `isMinifyEnabled = true` ile açıktır. `--obfuscate` ise asıl Dart kodunu
  (libapp.so) karıştırır — bu ikisi birlikte tam kapsama sağlar. (§5.5.3, §10.4.1)

.PARAMETER Target
  appbundle (Play Store, varsayılan) | apk | ipa (App Store / iOS).

.PARAMETER PointsEnabled
  Gamification feature flag (varsayılan false).

.PARAMETER PinnedSha256
  SSL pinning: SPKI (public key) SHA-256 pin(ler)i, virgülle ayrılmış.
  Varsayılan: mobil.smartsamsun.com canlı sunucusunun SPKI pin'i.
  Sunucu private key'i DEĞİŞİRSE uygulama API'ye bağlanamaz —
  bkz. docs/SSL_PINNING_SERVER_SETUP.md (reuse_key ZORUNLU + yedek pin).
  Yeniden üretmek için:
    openssl s_client -connect mobil.smartsamsun.com:443 -servername mobil.smartsamsun.com </dev/null |
      openssl x509 -pubkey -noout | openssl pkey -pubin -outform der |
      openssl dgst -sha256 -binary | openssl enc -base64

.EXAMPLE
  ./scripts/build_release.ps1 -Target appbundle
  ./scripts/build_release.ps1 -Target ipa -PointsEnabled true
#>
param(
  [ValidateSet('appbundle', 'apk', 'ipa')]
  [string]$Target = 'appbundle',
  [string]$PointsEnabled = 'false',
  # SPKI pin (2026-07-07'de canlı sunucudan alındı). Yedek anahtar pin'i
  # üretilince virgülle buraya eklenmeli (docs/SSL_PINNING_SERVER_SETUP.md §4).
  [string]$PinnedSha256 = 'BcKsW3xTBEvdNXN2hJyQmHuX3ZJVrs+5EIFvuL+E7yo=',
  # Pin yalnızca bu host(lar)a uygulanır; CDN/OSRM gibi diğer host'lar
  # sistem TLS doğrulamasıyla devam eder.
  [string]$PinnedHosts = 'mobil.smartsamsun.com',
  # freeRASP (RASP) — repack/appIntegrity tespiti RELEASE imza sertifikasının
  # SHA-256'sını (base64) ister. key.properties'teki keystore'dan üret:
  #   keytool -list -v -alias <alias> -keystore <store> -storepass <pass> |
  #     grep 'SHA256:' → hex'i base64'e çevir (xxd -r -p | base64)
  # BOŞ bırakılırsa debug hash gömülür ve HER release'de appIntegrity alarmı çıkar.
  [string]$AndroidSigningHashes = '',
  # freeRASP iOS repack tespiti: Apple Developer Team ID + izinli bundle id(ler).
  [string]$IosTeamId = '',
  [string]$IosBundleIds = 'com.smartsamsun.mobil',
  # Talsec haftalık güvenlik raporu e-postası.
  [string]$SecurityWatcherMail = 'guvenlik@smartsamsun.com'
)

if (-not $AndroidSigningHashes) {
  Write-Warning "ANDROID_SIGNING_HASHES verilmedi — freeRASP debug imza hash'iyle çalışır ve release'de appIntegrity alarmı üretir. Release keystore hash'ini -AndroidSigningHashes ile geçin."
}

$ErrorActionPreference = 'Stop'

# Sembol çıktısı sürüme göre ayrılır; arşivlenmeli, ship edilmemeli.
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$symbols = "symbols/$Target-$stamp"
New-Item -ItemType Directory -Force -Path $symbols | Out-Null

Write-Host "▶ Obfuscate'li $Target build başlıyor (semboller: $symbols)" -ForegroundColor Cyan

# dart-define listesi. Boş olabilen değerler (imza hash'i) verilmezse hiç
# geçilmez → Dart tarafındaki güvenli varsayılan devreye girer.
$defines = @(
  "--dart-define=POINTS_ENABLED=$PointsEnabled",
  "--dart-define=SSL_PINNED_SHA256=$PinnedSha256",
  "--dart-define=SSL_PINNED_HOSTS=$PinnedHosts",
  "--dart-define=SSL_PINNING_STRICT=true",
  "--dart-define=SECURITY_WATCHER_MAIL=$SecurityWatcherMail",
  "--dart-define=IOS_BUNDLE_IDS=$IosBundleIds"
)
if ($AndroidSigningHashes) { $defines += "--dart-define=ANDROID_SIGNING_HASHES=$AndroidSigningHashes" }
if ($IosTeamId)            { $defines += "--dart-define=IOS_TEAM_ID=$IosTeamId" }

# SSL_PINNING_STRICT=true: pin konfigürasyonu eksik/bozuksa release paketi
# sessizce pinning'siz çıkmak yerine açılışta hata verir (fail-closed).
flutter build $Target --release --obfuscate --split-debug-info=$symbols @defines

if ($LASTEXITCODE -ne 0) { throw "flutter build başarısız (exit $LASTEXITCODE)" }

Write-Host "✓ Build tamam." -ForegroundColor Green
Write-Host "⚠ Sembol dosyalarını arşivleyin (de-obfuscation için): $symbols" -ForegroundColor Yellow
Write-Host "  Bu klasörü uygulama paketiyle DAĞITMAYIN." -ForegroundColor Yellow
