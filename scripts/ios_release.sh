#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# SBB Mobil — deterministik iOS release build + yükleme-öncesi doğrulama
#
# Kullanım (Mac'te, proje kök klasöründe):
#   chmod +x scripts/ios_release.sh          # (ilk seferde)
#   ./scripts/ios_release.sh <build-number>  # örn: ./scripts/ios_release.sh 42
#
# Ne garanti eder:
#   1. Build, HER ZAMAN bu klasördeki güncel Podfile ile sıfırdan alınır
#      (eski Pods / DerivedData / Xcode cache kullanılamaz).
#   2. IPA üretildikten sonra binary'nin İÇİ kontrol edilir: kamera izin
#      kodu (AudioVideoPermissionStrategy) derlenmemişse script HATA verir
#      ve o IPA'yı yüklememeniz gerektiğini söyler.
#   3. Build numarası parametreyle sabitlenir → TestFlight'ta hangi build'in
#      kurulduğunu şüpheye yer bırakmadan doğrularsınız.
# ============================================================================

BUILD_NUMBER="${1:?Kullanım: ./scripts/ios_release.sh <build-number>}"

echo "==> [1/6] Temiz başlangıç (flutter clean + Pods + DerivedData)"
flutter clean
rm -rf ios/Pods ios/Podfile.lock
rm -rf ~/Library/Developer/Xcode/DerivedData

echo "==> [2/6] Bağımlılıklar (pub get + pod install)"
flutter pub get
(cd ios && pod install --repo-update)

echo "==> [3/6] Ön kontrol: PERMISSION_CAMERA makrosu Pods projesine yazıldı mı?"
if ! grep -q "PERMISSION_CAMERA=1" ios/Pods/Pods.xcodeproj/project.pbxproj; then
  echo "HATA: PERMISSION_CAMERA=1 Pods projesinde yok."
  echo "      ios/Podfile post_install bloğu çalışmamış — Podfile'ı kontrol edin."
  exit 1
fi
echo "    OK."

echo "==> [4/6] IPA derleniyor (build numarası: $BUILD_NUMBER)"
flutter build ipa --release --build-number="$BUILD_NUMBER"

IPA=$(ls build/ios/ipa/*.ipa | head -1)
echo "    Üretilen IPA: $IPA"

echo "==> [5/6] Son kontrol: derlenmiş binary'de kamera izin kodu var mı?"
TMP=$(mktemp -d)
unzip -q "$IPA" -d "$TMP"

FOUND=0
# use_frameworks! → permission_handler_apple dinamik framework olarak gelir:
FRAMEWORK="$TMP"/Payload/Runner.app/Frameworks/permission_handler_apple.framework/permission_handler_apple
if [ -f "$FRAMEWORK" ] && strings "$FRAMEWORK" | grep -q "AudioVideoPermissionStrategy"; then
  FOUND=1
fi
# Statik linklenmiş kurulum ihtimaline karşı ana binary'ye de bak:
if [ "$FOUND" -eq 0 ] && strings "$TMP"/Payload/Runner.app/Runner | grep -q "AudioVideoPermissionStrategy"; then
  FOUND=1
fi
rm -rf "$TMP"

if [ "$FOUND" -eq 1 ]; then
  echo "    OK: kamera izin stratejisi binary'de MEVCUT — IPA yüklenebilir."
else
  echo "HATA: kamera izin kodu binary'de YOK."
  echo "      Bu IPA'yı TestFlight'a YÜKLEMEYİN. (PERMISSION_CAMERA makrosu"
  echo "      derlemeye girmemiş — yukarıdaki adımların çıktısını inceleyin.)"
  exit 1
fi

echo "==> [6/6] Tamamlandı."
echo ""
echo "Sıradaki adımlar:"
echo "  1. $IPA dosyasını Transporter uygulamasıyla App Store Connect'e yükleyin."
echo "  2. TestFlight'ta işlenen build'in numarasının $BUILD_NUMBER olduğunu doğrulayın."
echo "  3. Telefonda TestFlight'tan kurarken sürüm detayında build $BUILD_NUMBER yazdığını kontrol edin."
