# SSL (SPKI) Pinning — Sunucu Tarafı Kurulum Rehberi

> Uygulama tarafı: `lib/core/network/ssl_pinning.dart` + `scripts/build_release.*`
> Son güncelleme: 7 Temmuz 2026. Pin alınan sertifika: `mobil.smartsamsun.com`
> (Let's Encrypt E7, ECC, geçerlilik: 26 May 2026 → 24 Ağu 2026).

## 0. TL;DR — Yapman gerekenler

1. Sunucuda **`reuse_key` ayarını aç** (aşağıda §2) — **bunu yapmazsan 24
   Ağustos 2026'daki otomatik yenilemede uygulamanın API bağlantısı KİLİTLENİR.**
2. Yenileme sonrası pin'in değişmediğini doğrula (§3).
3. Yedek anahtar + yedek pin üret, güvenli yerde sakla (§4).
4. (İsteğe bağlı ama önerilir) Takvime not: her sertifika yenilemesinden sonra §3 doğrulaması.

---

## 1. Sistem nasıl çalışıyor?

### Uygulama tarafı zinciri

```
scripts/build_release.ps1 / .sh
  └─ --dart-define=SSL_PINNED_SHA256=<SPKI pin(ler)i>     ← pin buradan gömülür
     --dart-define=SSL_PINNED_HOSTS=mobil.smartsamsun.com  ← yalnız bu host'a uygulanır
     --dart-define=SSL_PINNING_STRICT=true                 ← pin eksikse açılışta hata
        └─ lib/core/network/ssl_pinning.dart
             └─ Her TLS bağlantısında sunucu sertifikasının PUBLIC KEY'inin
                (SPKI DER) SHA-256'sını pin listesiyle karşılaştırır.
                Uymuyorsa bağlantı REDDEDİLİR.
```

### Neden sertifika değil de public key (SPKI) pinleniyor?

| | Sertifika hash pin | **SPKI (public key) pin** |
|---|---|---|
| Let's Encrypt yenilemesi (~60 günde bir) | ❌ Her yenilemede pin kırılır → uygulama kilitlenir | ✅ **Private key aynı kaldığı sürece** pin sabit |
| Şart | Her yenilemede yeni uygulama sürümü | Sunucuda `reuse_key` açık olmalı |

**Kritik sonuç:** Let's Encrypt varsayılan olarak her yenilemede **yeni bir
private key** üretir. `reuse_key` açılmazsa SPKI pin de kırılır. Bu yüzden §2
zorunludur.

### Şu anki pin

```
SPKI SHA-256 (base64): BcKsW3xTBEvdNXN2hJyQmHuX3ZJVrs+5EIFvuL+E7yo=
Alındığı tarih       : 2026-07-07 (canlı sunucudan)
```

---

## 2. `reuse_key` açma (ZORUNLU)

Önce sunucuda sertifikayı neyin yönettiğini tespit et:

```bash
# certbot kurulu mu ve bu domain'i yönetiyor mu?
sudo certbot certificates 2>/dev/null | grep -A4 mobil.smartsamsun.com

# acme.sh kurulu mu?
ls ~/.acme.sh/ 2>/dev/null | grep smartsamsun

# Docker'da TLS sonlandıran bir proxy var mı? (Traefik / Caddy / nginx-proxy)
docker ps --format '{{.Names}}\t{{.Image}}' | grep -Ei 'traefik|caddy|nginx|proxy|acme|certbot'
```

> ⚠️ Backend kurallarımız gereği `docker compose down` YAPMA — aşağıdaki
> adımların hiçbiri container durdurmayı gerektirmez.

### Senaryo A — certbot (host üzerinde, en yaygın)

```bash
# 1. Yenileme yapılandırmasını aç:
sudo nano /etc/letsencrypt/renewal/mobil.smartsamsun.com.conf

# 2. [renewalparams] bölümüne şu satırı ekle (yoksa):
reuse_key = True

# 3. Kaydet ve doğrula — dry-run gerçek sertifikaya dokunmaz:
sudo certbot renew --cert-name mobil.smartsamsun.com --dry-run
```

Alternatif (conf dosyasını elle düzenlemeden — certbot bu bayrağı kalıcı olarak
renewal conf'a yazar):

```bash
sudo certbot certonly --cert-name mobil.smartsamsun.com --reuse-key --keep-until-expiring
```

### Senaryo B — acme.sh

acme.sh **varsayılan olarak anahtarı yeniden kullanır** — yine de kontrol et:

```bash
# Bu dosyada Le_ForceNewDomainKey satırı YA HİÇ OLMAMALI ya da '' olmalı:
grep -i key ~/.acme.sh/mobil.smartsamsun.com*/mobil.smartsamsun.com.conf
```

`--always-force-new-domain-key` ile kurulmuşsa kaldır:

```bash
acme.sh --issue -d mobil.smartsamsun.com --always-force-new-domain-key 0 --force
```

### Senaryo C — Docker içinde certbot container'ı

Container'ı durdurmadan, host'a mount edilen `/etc/letsencrypt` üzerinde
Senaryo A'daki conf düzenlemesini yap (volume path'ini `docker inspect
<certbot-container> | grep letsencrypt` ile bul). Sonra:

```bash
docker exec <certbot-container> certbot renew --dry-run
```

### Senaryo D — Traefik / Caddy

- **Caddy:** anahtarı varsayılan olarak yeniden kullanır → ek işlem gerekmez,
  ama §3 doğrulamasını yenileme sonrası mutlaka yap.
- **Traefik:** anahtar yeniden kullanımı sürüme göre değişir ve garanti
  **değildir**. Traefik kullanılıyorsa iki seçenek:
  1. Sertifika yönetimini certbot'a taşı (Senaryo A), Traefik'e dosyadan ver; veya
  2. SPKI pinning yerine uygulamayı `SSL_PINNING_STRICT=false` ile derle
     (koruma seviyesi düşer — önerilmez).

---

## 3. Doğrulama (her yenileme sonrası)

### Pin'i canlı sunucudan oku

```bash
openssl s_client -connect mobil.smartsamsun.com:443 -servername mobil.smartsamsun.com </dev/null 2>/dev/null \
  | openssl x509 -pubkey -noout \
  | openssl pkey -pubin -outform der \
  | openssl dgst -sha256 -binary | openssl enc -base64
```

Çıktı **`BcKsW3xTBEvdNXN2hJyQmHuX3ZJVrs+5EIFvuL+E7yo=`** olmalı.
Farklıysa → private key değişmiş → **uygulama o sunucuya bağlanamıyor
demektir** → §5 acil durum adımlarına git.

### Sunucudaki key dosyasından da teyit edebilirsin

```bash
# certbot yerleşimi:
sudo openssl pkey -in /etc/letsencrypt/live/mobil.smartsamsun.com/privkey.pem \
  -pubout -outform der | openssl dgst -sha256 -binary | openssl enc -base64
```

### reuse_key'in gerçekten çalıştığını test et (isteğe bağlı, güvenli)

```bash
# Yenilemeyi zorla (rate limit'e dikkat: ayda ~5 hakkın var, 1 kez yeterli):
sudo certbot renew --cert-name mobil.smartsamsun.com --force-renewal
# Ardından yukarıdaki pin komutunu tekrar çalıştır — AYNI çıktıyı vermeli.
# Nginx/proxy sertifikayı yeniden yüklesin:
sudo nginx -s reload   # veya: docker exec <nginx-container> nginx -s reload
```

---

## 4. Yedek anahtar + yedek pin (önerilir)

Amaç: sunucu private key'i tehlikeye girerse (sızıntı vb.) **uygulama
güncellemesi beklemeden** yeni anahtara geçebilmek. Yedek anahtarın pin'i
uygulamada şimdiden gömülü olur; gerektiğinde sunucuda o anahtara geçersin.

```bash
# 1. Yedek EC anahtarı üret (sunucuda DEĞİL, güvenli bir makinede):
openssl ecparam -name prime256v1 -genkey -noout -out sbb_backup_key.pem

# 2. Pin'ini hesapla:
openssl pkey -in sbb_backup_key.pem -pubout -outform der \
  | openssl dgst -sha256 -binary | openssl enc -base64

# 3. sbb_backup_key.pem dosyasını OFFLINE ve ŞİFRELİ sakla
#    (parola kasası / şifreli USB — sunucuya KOYMA).
```

Çıkan pin'i build script'lerine virgülle ekle:

- `scripts/build_release.ps1` → `-PinnedSha256 'BcKsW3...u4=,<YEDEK_PIN>'`
  (veya param varsayılanını güncelle)
- `scripts/build_release.sh` → `SSL_PINNED_SHA256` varsayılanına ekle

**Yedek anahtara geçiş günü gelirse:**

```bash
sudo certbot certonly --cert-name mobil.smartsamsun.com \
  --key-path /path/to/sbb_backup_key.pem ...   # certbot sürümüne göre:
# certbot >= 2.x: --key-path yoksa, CSR ile: openssl req -new -key sbb_backup_key.pem ...
# ardından reuse_key'in yeni anahtar için de açık kaldığını doğrula (§2).
```

---

## 5. Acil durum: "uygulama API'ye bağlanamıyor, pin mismatch"

Belirti: Uygulamada tüm API istekleri TLS hatasıyla düşer; sunucu loglarında
istek görünmez (handshake istemci tarafında kesilir).

1. **Teşhis:** §3'teki pin komutunu çalıştır → pin değişmişse sebep bu.
2. **Hızlı çözüm (sunucu tarafı, dakikalar):** Eski private key hâlâ
   duruyorsa (`/etc/letsencrypt/archive/mobil.smartsamsun.com/privkeyN.pem`
   önceki sürümler), eski key ile sertifikayı yeniden düzenle:
   ```bash
   sudo ls /etc/letsencrypt/archive/mobil.smartsamsun.com/
   # privkey1.pem, privkey2.pem ... → pin'i tutan sürümü §3 komutuyla bul,
   # o key için CSR üretip certbot'la yeniden sertifika al, reuse_key'i aç.
   ```
3. **Kalıcı çözüm (uygulama tarafı):** Yeni pin'le build alıp store'lara
   güncelleme gönder (`build_release.ps1 -PinnedSha256 '<yeni>,<eski>'` —
   geçiş süresince iki pin birden tut).
4. **Son çare:** `-PinnedSha256 ''` + strict kapalı build → pinning devre dışı
   (yalnızca geçici; koruma kaybolur).

---

## 6. İlgili dosyalar

| Dosya | Rol |
|---|---|
| `lib/core/network/ssl_pinning.dart` | Pin doğrulama (SPKI çıkarımı + `validateCertificate`) |
| `scripts/build_release.ps1` / `.sh` | Pin'lerin release build'e gömülmesi |
| `android/app/src/main/res/xml/network_security_config.xml` | Release'te user CA reddi (pinning'in yan savunması) |
| `docs/SECURITY_HARDENING.md` | Genel sertleştirme envanteri |
