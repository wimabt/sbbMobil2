#!/usr/bin/env bash
# SBB Mobile — obfuscate'li (tersine mühendisliğe karşı sertleştirilmiş) release build.
#
# Dart kodunu obfuscate eder ve debug sembollerini symbols/ altına AYIRIR.
# Bu sembol dosyaları uygulamayla SHIP EDİLMEZ; crash stack-trace de-obfuscation'ı
# için her sürümde arşivlenmelidir.
#
# R8/ProGuard (Android Java/Kotlin) zaten build.gradle.kts'de açık; --obfuscate
# asıl Dart kodunu (libapp.so) karıştırır — ikisi birlikte tam kapsama. (§5.5.3, §10.4.1)
#
# Kullanım:
#   ./scripts/build_release.sh [appbundle|apk|ipa] [points_enabled]
#   ./scripts/build_release.sh appbundle false
#   ./scripts/build_release.sh ipa true
set -euo pipefail

TARGET="${1:-appbundle}"
POINTS_ENABLED="${2:-false}"

# SSL pinning: SPKI (public key) SHA-256 pin(ler)i, virgülle ayrılmış.
# 2026-07-07'de mobil.smartsamsun.com canlı sunucusundan alındı.
# Sunucu private key'i DEĞİŞİRSE uygulama API'ye bağlanamaz —
# bkz. docs/SSL_PINNING_SERVER_SETUP.md (reuse_key ZORUNLU + yedek pin).
# Yeniden üretmek için:
#   openssl s_client -connect mobil.smartsamsun.com:443 -servername mobil.smartsamsun.com </dev/null \
#     | openssl x509 -pubkey -noout | openssl pkey -pubin -outform der \
#     | openssl dgst -sha256 -binary | openssl enc -base64
SSL_PINNED_SHA256="${SSL_PINNED_SHA256:-BcKsW3xTBEvdNXN2hJyQmHuX3ZJVrs+5EIFvuL+E7yo=}"
SSL_PINNED_HOSTS="${SSL_PINNED_HOSTS:-mobil.smartsamsun.com}"

# freeRASP (RASP) yapılandırması — env ile geçilebilir.
# ANDROID_SIGNING_HASHES: RELEASE imza sertifikası SHA-256 (base64). BOŞ ise
#   Dart tarafı debug hash'e düşer → her release'de appIntegrity alarmı. Üret:
#     keytool -list -v -alias <alias> -keystore <store> -storepass <pass> \
#       | awk '/SHA256:/{print $2}' | tr -d ':' | xxd -r -p | base64
# IOS_TEAM_ID: Apple Developer Team ID (iOS repack tespiti için).
SECURITY_WATCHER_MAIL="${SECURITY_WATCHER_MAIL:-guvenlik@smartsamsun.com}"
IOS_BUNDLE_IDS="${IOS_BUNDLE_IDS:-com.smartsamsun.mobil}"
ANDROID_SIGNING_HASHES="${ANDROID_SIGNING_HASHES:-}"
IOS_TEAM_ID="${IOS_TEAM_ID:-}"

case "$TARGET" in
  appbundle|apk|ipa) ;;
  *) echo "Geçersiz target: $TARGET (appbundle|apk|ipa)" >&2; exit 1 ;;
esac

STAMP="$(date +%Y%m%d-%H%M%S)"
SYMBOLS="symbols/${TARGET}-${STAMP}"
mkdir -p "$SYMBOLS"

echo "▶ Obfuscate'li $TARGET build başlıyor (semboller: $SYMBOLS)"

# dart-define listesi. Boş olabilen değerler verilmezse hiç geçilmez → Dart
# tarafındaki güvenli varsayılan devreye girer.
DEFINES=(
  --dart-define=POINTS_ENABLED="$POINTS_ENABLED"
  --dart-define=SSL_PINNED_SHA256="$SSL_PINNED_SHA256"
  --dart-define=SSL_PINNED_HOSTS="$SSL_PINNED_HOSTS"
  --dart-define=SSL_PINNING_STRICT=true
  --dart-define=SECURITY_WATCHER_MAIL="$SECURITY_WATCHER_MAIL"
  --dart-define=IOS_BUNDLE_IDS="$IOS_BUNDLE_IDS"
)
[ -n "$ANDROID_SIGNING_HASHES" ] && DEFINES+=(--dart-define=ANDROID_SIGNING_HASHES="$ANDROID_SIGNING_HASHES")
[ -n "$IOS_TEAM_ID" ] && DEFINES+=(--dart-define=IOS_TEAM_ID="$IOS_TEAM_ID")
[ -z "$ANDROID_SIGNING_HASHES" ] && echo "⚠ ANDROID_SIGNING_HASHES boş — freeRASP debug hash kullanır, release'de appIntegrity alarmı üretir."

# SSL_PINNING_STRICT=true: pin konfigürasyonu eksik/bozuksa release paketi
# sessizce pinning'siz çıkmak yerine açılışta hata verir (fail-closed).
flutter build "$TARGET" \
  --release \
  --obfuscate \
  --split-debug-info="$SYMBOLS" \
  "${DEFINES[@]}"

echo "✓ Build tamam."
echo "⚠ Sembol dosyalarını arşivleyin (de-obfuscation için): $SYMBOLS"
echo "  Bu klasörü uygulama paketiyle DAĞITMAYIN."
