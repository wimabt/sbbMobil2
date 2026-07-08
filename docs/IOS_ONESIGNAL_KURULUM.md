# iOS OneSignal Push Kurulumu — Adım Adım (Mac)

> Bu doküman **SBB Mobile** projesine özeldir. Android'de OneSignal push zaten çalışıyor.
> Burada iOS tarafını sıfırdan kuruyoruz. Tüm adımlar **Mac + Xcode** üzerinde yapılır.

---

## 0. Önce bilmen gerekenler (çok önemli)

### iOS'ta Firebase YOK
Android'de gördüğün `google-services.json` / Firebase, sadece **FCM** içindir — Android'in
push taşıyıcısı budur. **iOS'ta push taşıyıcısı APNs'tir (Apple Push Notification service).**
OneSignal iOS'ta doğrudan APNs'e bağlanır.

➡️ **iOS için Firebase / GoogleService-Info.plist eklemene GEREK YOK.** Eklemeye çalışma.
Bu dokümanda "Firebase" ile ilgili tek bir adım bile yok — çünkü gerekli değil.

### Kod tarafı zaten hazır
Flutter/Dart kısmı (`onesignal_flutter` paketi, `notification_service.dart`) hazır.
**Hiç Dart kodu yazmayacaksın.** Tüm iş: Apple portal + Xcode + OneSignal dashboard.

### Ücretli Apple Developer hesabı ZORUNLU
iOS push için ücretsiz Apple ID **yetmez**. Şunlar sadece ücretli hesapla ($99/yıl) yapılır:
- APNs Auth Key (.p8) üretmek
- "Push Notifications" capability'yi aktif etmek

Hesap yoksa bu dokümandaki hiçbir adım tamamlanamaz. **Önce hesabı al.**

### Push sadece GERÇEK cihazda test edilir
iOS **simülatör push ALAMAZ.** Test için ücretli hesap + fiziksel iPhone gerekir.

---

## Projemize özel sabitler (bunları elinin altında tut)

| Bilgi | Değer |
|---|---|
| **OneSignal App ID** | `b457f34f-c0a4-4378-90ea-c0fc1c175ad8` |
| **Mevcut Bundle ID** | `com.example.sbbMobile` ⚠️ (aşağıdaki Adım 1'e bak) |
| **Uygulama adı** | Sbb Mobile |
| **Min iOS sürümü** | 14.0 |
| **Xcode workspace** | `ios/Runner.xcworkspace` (`.xcodeproj` DEĞİL) |
| **OneSignalXCFramework hedef sürüm** | 5.5.x (`< 6.0.0`) |

---

## ⚠️ Adım 1 — Bundle ID'yi düzelt (ilk iş, her şeyin temeli)

Mevcut bundle ID **`com.example.sbbMobile`** — bu Flutter'ın varsayılan placeholder'ı.
**Apple `com.example.*` ile başlayan uygulamaları App Store'a kabul etmez.** Ayrıca APNs,
provisioning ve OneSignal'ın hepsi bundle ID'ye kilitlenir; sonradan değiştirmek her yeri
bozar. O yüzden **en başta** gerçek bir ID belirle.

**Örnek:** `com.smartsamsun.sbbmobile` (kendi ters-domain'ine göre seç)

Değiştirilecek yerler (Xcode'da):
1. `Runner.xcworkspace` aç → sol panelde **Runner** projesine tıkla
2. **Runner target → General → Identity → Bundle Identifier** alanını değiştir
3. Android tarafındaki `applicationId` ile aynı olması ŞART DEĞİL (platformlar bağımsız),
   ama karışıklığı önlemek için tutarlı isim seç.

> Bu yeni bundle ID'yi aşağıdaki **tüm** adımlarda kullanacaksın. Bu dokümanda
> `com.smartsamsun.sbbmobile` yazan yerlere **kendi seçtiğin ID'yi** koy.

---

## Adım 2 — Apple Developer Portal: App ID + APNs Key

### 2a. App ID'yi (Identifier) hazırla
1. [developer.apple.com](https://developer.apple.com) → **Certificates, Identifiers & Profiles**
2. **Identifiers** → `+` → **App IDs** → **App**
3. **Bundle ID**: Adım 1'de seçtiğin ID'yi gir (örn. `com.smartsamsun.sbbmobile`)
4. **Capabilities** listesinden **Push Notifications**'ı işaretle → Kaydet
   - (Zaten bir App ID varsa, onu düzenleyip Push Notifications'ı aç)

### 2b. APNs Auth Key (.p8) üret
1. Aynı yerde **Keys** sekmesi → `+`
2. İsim ver (örn. "SBB Mobile APNs")
3. **Apple Push Notifications service (APNs)** kutusunu işaretle → Continue → Register
4. **`.p8` dosyasını indir** — ⚠️ **SADECE BİR KEZ inebilir, kaybedersen yenisini üretirsin**
5. Şu üç bilgiyi bir yere kaydet:
   - **Key ID** (bu ekranda yazar, örn. `ABC123DEFG`)
   - **Team ID** (sağ üstte üyelik bilgilerinde, örn. `1A2B3C4D5E`)
   - İndirdiğin **`.p8` dosyası**

---

## Adım 3 — OneSignal Dashboard: iOS platformu ekle

Android push için kullandığın **aynı** OneSignal uygulamasına iOS'u ekliyorsun.

1. [OneSignal Dashboard](https://dashboard.onesignal.com) → App ID'si `b457f34f...` olan uygulamayı aç
2. **Settings → Push & In-App → Apple iOS (APNs)**
3. Kurulum tipi: **"Authentication Token" (.p8)** seç (sertifika değil, key ile)
4. Şunları gir:
   - **`.p8` dosyasını** yükle
   - **Key ID** (Adım 2b)
   - **Team ID** (Adım 2b)
   - **Bundle ID** (Adım 1'de seçtiğin, örn. `com.smartsamsun.sbbmobile`)
5. Kaydet. Android platformuna dokunma — o çalışmaya devam eder.

---

## Adım 4 — Xcode: Capabilities ekle

1. `ios/Runner.xcworkspace` aç (workspace, xcodeproj değil!)
2. Sol panelde **Runner** projesi → **Runner** target → **Signing & Capabilities**
3. **Signing:**
   - **Team**: ücretli developer hesabını seç
   - **Bundle Identifier**: Adım 1'deki ID ile aynı olduğunu doğrula
   - "Automatically manage signing" işaretli olsun
4. **`+ Capability`** butonu → **Push Notifications** ekle
   - Bu, projede **`Runner.entitlements`** dosyasını otomatik oluşturur (şu an projede yok)
5. Tekrar **`+ Capability`** → **Background Modes** ekle
   - Açılan listede **"Remote notifications"** kutusunu işaretle

---

## Adım 5 — Notification Service Extension (önerilen)

Bu extension; zengin bildirim (resim), teslim onayı (confirmed delivery) ve rozet (badge)
için gerekir. Push'un temel çalışması için şart değil ama **kesinlikle önerilir**.

### 5a. Extension target'ı oluştur
1. Xcode → **File → New → Target…**
2. **Notification Service Extension** seç → Next
3. **Product Name**: `OneSignalNotificationServiceExtension` (birebir bu isim)
4. Language: **Swift** → Finish
5. Xcode "Activate scheme?" diye sorarsa → **Cancel** (Aktifleştirme!)

### 5b. Extension'ın min iOS sürümünü ayarla
- Yeni target → **General → Minimum Deployments → iOS**: ana app ile uyumlu tut.
- Ana app 14.0; extension'ı da **14.0** yap (daha düşük gerekirse OneSignal dokümanına bak).

### 5c. App Groups ekle (hem Runner hem extension'a)
Confirmed delivery ve badge senkronu için gerekir.
1. **Runner** target → Signing & Capabilities → `+ Capability` → **App Groups** → `+`
   - Grup adı: `group.com.smartsamsun.sbbmobile.onesignal`
     *(kendi bundle ID'ne göre `group.{BUNDLE_ID}.onesignal`)*
2. **OneSignalNotificationServiceExtension** target → aynı **App Groups** capability'yi ekle
   - **Aynı grup adını** işaretle (ikisi aynı grupta olmalı)

### 5d. NotificationService.swift içeriğini değiştir
Xcode'un ürettiği `NotificationService.swift` dosyasının **tüm içeriğini sil**, yerine bunu koy:

```swift
import UserNotifications
import OneSignalExtension

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var receivedRequest: UNNotificationRequest!
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.receivedRequest = request
        self.contentHandler = contentHandler
        self.bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        if let bestAttemptContent = bestAttemptContent {
            OneSignalExtension.didReceiveNotificationExtensionRequest(
                self.receivedRequest,
                with: bestAttemptContent,
                withContentHandler: self.contentHandler
            )
        }
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler,
           let bestAttemptContent = bestAttemptContent {
            OneSignalExtension.serviceExtensionTimeWillExpire(
                self.receivedRequest,
                with: bestAttemptContent
            )
            contentHandler(bestAttemptContent)
        }
    }
}
```

---

## Adım 6 — Podfile: extension target'ı ekle

`ios/Podfile` dosyasını aç. Dosyanın **sonuna** (en alttaki `post_install` bloğundan
ÖNCE veya SONRA, ama `target 'Runner'` bloğunun DIŞINA) şunu ekle:

```ruby
target 'OneSignalNotificationServiceExtension' do
  use_frameworks!
  pod 'OneSignalXCFramework', '>= 5.0.0', '< 6.0.0'
end
```

Sonra terminalde:

```bash
cd ios

# Önce mevcut OneSignal sürüm kilidini güncelle (5.4.1 ↔ 5.5.x çakışması için)
pod update OneSignalXCFramework

# Extension target'ın pod'unu kur
pod install

cd ..
```

> **Not:** Daha önce yaşadığın `OneSignalXCFramework 5.4.1 vs 5.5.1` Podfile.lock çakışması
> tam da burada çözülüyor. Ana app ve extension **aynı** OneSignalXCFramework sürümünü
> kullanmalı; `pod update` bunu senkronlar. Yetmezse: `rm Podfile.lock && pod install`.

---

## Adım 7 — Tutarlılık kontrolü

Şu **üç yerde bundle ID birebir aynı** olmalı — en sık yapılan hata budur:

- [ ] Apple Developer App ID (Adım 2a)
- [ ] OneSignal dashboard iOS platformu (Adım 3)
- [ ] Xcode Runner → Bundle Identifier (Adım 1 & 4)

Ayrıca:
- [ ] `.p8` dosyası, Key ID, Team ID OneSignal'a doğru girildi mi?
- [ ] Runner + extension **aynı App Group**'ta mı? (Adım 5c)
- [ ] Push Notifications + Background Modes (Remote notifications) capability'leri ekli mi?

---

## Adım 8 — Gerçek cihazda test

> Simülatör push ALAMAZ. Fiziksel iPhone + ücretli hesap şart.

1. iPhone'u Mac'e bağla
2. Proje kökünden: `flutter run` (veya Xcode'dan Run)
3. Uygulama açılınca **bildirim izni** iste → izin ver
4. **OneSignal Dashboard → Audience → Subscriptions** altında cihazın **"Subscribed"**
   olarak göründüğünü doğrula
   - Görünmüyorsa: Sorun Giderme bölümüne bak
5. **Messages → New Push** → test bildirimi gönder → cihaza düşmeli
6. Uygulama **arka planda/kapalıyken** de test et (T902–T904 senaryoları)
7. Bildirime dokununca doğru ekranın açıldığını doğrula (deep link)

---

## Sorun Giderme

| Belirti | Olası neden / çözüm |
|---|---|
| Cihaz OneSignal'da "Subscribed" görünmüyor | Push Notifications capability eksik, yanlış Team, veya `.p8` yanlış girilmiş |
| `No profiles for 'com.…' were found` | Signing & Capabilities'te Team seçili değil veya App ID portalda yok |
| `CocoaPods … OneSignalXCFramework` sürüm hatası | `cd ios && pod update OneSignalXCFramework` → gerekirse `rm Podfile.lock && pod install` |
| App Store "com.example.*" reddi | Adım 1 — bundle ID hâlâ placeholder |
| Bildirim geliyor ama resim yok | Notification Service Extension eksik/yanlış (Adım 5) |
| Simülatörde push gelmiyor | Normal — iOS simülatör push almaz, gerçek cihaz kullan |

---

## Özet akış

```
1. Bundle ID'yi gerçek yap (com.example → com.smartsamsun.sbbmobile)
2. Apple portal: App ID + Push capability + APNs .p8 key
3. OneSignal dashboard: iOS platformu (.p8 + Key ID + Team ID + Bundle ID)
4. Xcode: Push Notifications + Background Modes capability
5. Xcode: Notification Service Extension + App Groups
6. Podfile: extension target + pod update/install
7. Bundle ID'yi 3 yerde eşitle
8. Gerçek cihazda test
```

Kod değişikliği yok — hepsi konfigürasyon. En kritik ön koşul: **ücretli Apple Developer hesabı.**
