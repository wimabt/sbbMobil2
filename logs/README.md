# Uygulama logları

## Neden proje klasöründe otomatik yok?

Telefonda veya emülatörde çalışan uygulama, geliştirme makinenizdeki bu klasöre **doğrudan yazamaz** (Android/iOS koruması). Log dosyası uygulamanın kendi alanında oluşur.

## Seçenekler

### 1) Masaüstü hedefi (log doğrudan repoda)

Projeyi masaüstünde çalıştırın; loglar **`logs/flutter_*.log`** olarak bu repoda oluşur:

```bash
flutter run -d windows
# veya
flutter run -d macos
```

Çalışma dizini genelde proje kökü olduğu için dosya `sbbMobil/logs/` altında görünür.

### 2) Android telefon / emülatör

Uygulama logu cihazda şuna benzer bir yolda:

`.../app_flutter/logs/flutter_<tarih>.log`

Bilgisayara almak için proje kökünde:

```powershell
.\scripts\pull_device_logs.ps1
```

Çıktı: `logs/device/flutter_latest_from_device.log`

**Manuel (adb):** USB hata ayıklama açık, cihaz bağlı:

```powershell
adb shell "run-as com.example.sbb_mobile ls app_flutter/logs"
adb shell "run-as com.example.sbb_mobile cat app_flutter/logs/flutter_2026-03-21T13-39-10.log" > logs/device/manual.log
```

`applicationId` değiştiyse `LogService.androidApplicationId` ve script içindeki `$package` ile aynı olmalı.

### 3) Terminalde gördüğünüz her şeyi dosyaya (önerilen)

`flutter run` çıktısı zaten terminalde; bunu **aynı anda** dosyaya da yazmak için PowerShell’de `Tee-Object` kullanılır — ekranda da görürsünüz, `logs/` altına da düşer.

**Hazır script (proje kökünden):**

```powershell
.\scripts\flutter_run_log.ps1
```

Çıktı: `logs/terminal_<tarih-saat>.log`

Belirli cihaz:

```powershell
.\scripts\flutter_run_log.ps1 run -d windows
.\scripts\flutter_run_log.ps1 run -d <cihaz_id>
```

**Tek satır (manuel):**

```powershell
flutter run 2>&1 | Tee-Object -FilePath logs/terminal_manual.log
```

> Not: Sadece `flutter run > log.txt` kullanırsanız çıktı **ekranda görünmez**; `Tee-Object` hem ekran hem dosya verir.

---

## Git

`*.log` dosyaları `.gitignore` ile genelde commit edilmez; ihtiyaç halinde paylaşmak için dosyayı yeniden adlandırın veya `git add -f` kullanın.
