# 📢 Admin Panel - Duyurular Modülü Tasarım Raporu

**Tarih:** 15 Ocak 2026  
**Proje:** SBB Mobil - Samsun Şehir Rehberi  
**Hazırlayan:** Geliştirme Ekibi

---

## 📋 İçindekiler

1. [Genel Bakış](#1-genel-bakış)
2. [Mevcut Mobil Uygulama Yapısı](#2-mevcut-mobil-uygulama-yapısı)
3. [Veritabanı Tasarımı](#3-veritabanı-tasarımı)
4. [API Endpoint Tasarımı](#4-api-endpoint-tasarımı)
5. [Admin Panel Arayüz Tasarımı](#5-admin-panel-arayüz-tasarımı)
6. [Uygulama Adımları](#6-uygulama-adımları)

---

## 1. Genel Bakış

### 1.1 Amaç
Samsun Büyükşehir Belediyesi mobil uygulaması için duyuru yönetim sistemi oluşturmak. Admin panel üzerinden duyuru ekleme, düzenleme, silme ve yayınlama işlemleri yapılabilecek.

### 1.2 Mobil Uygulamada Kullanılan Alanlar

Mevcut `Announcement` modelinde kullanılan alanlar:

| Alan | Tip | Zorunlu | Açıklama |
|------|-----|---------|----------|
| `id` | String | ✅ | Benzersiz kimlik |
| `title` | String | ✅ | Duyuru başlığı |
| `excerpt` | String | ❌ | Kısa özet (liste görünümü için) |
| `content` | String | ❌ | Tam içerik (detay sayfası için) |
| `category` | String | ✅ | Kategori adı |
| `imageUrl` | String | ❌ | Görsel URL'i |
| `createdAt` | DateTime | ❌ | Oluşturulma tarihi |
| `publishedAt` | DateTime | ❌ | Yayınlanma tarihi |
| `isNew` | Boolean | ❌ | Yeni rozeti göster |
| `isImportant` | Boolean | ❌ | Önemli/acil duyuru |
| `tags` | List<String> | ❌ | Etiketler |
| `author` | String | ❌ | Yazar adı |

### 1.3 Kategoriler (Sabit)

Mobil uygulamada tanımlı kategoriler:
- `Ulaşım`
- `Etkinlik`
- `Belediye`
- `Çevre`
- `Sosyal`

---

## 2. Mevcut Mobil Uygulama Yapısı

### 2.1 Model Dosyası
**Konum:** `lib/data/models/announcement.dart`

```dart
class Announcement {
  final String id;
  final String title;
  final String? excerpt;
  final String? content;
  final String category;
  final String? imageUrl;
  final DateTime? createdAt;
  final DateTime? publishedAt;
  final bool isNew;
  final bool isImportant;
  final List<String> tags;
  final String? author;
}
```

### 2.2 JSON Mapping

```dart
factory Announcement.fromJson(Map<String, dynamic> json) {
  return Announcement(
    id: json['id'].toString(),
    title: json['title'] as String? ?? '',
    excerpt: json['excerpt'] as String?,
    content: json['content'] as String?,
    category: json['category'] as String? ?? '',
    imageUrl: json['image_url'] as String?,
    createdAt: json['created_at'] != null
        ? DateTime.tryParse(json['created_at'] as String)
        : null,
    publishedAt: json['published_at'] != null
        ? DateTime.tryParse(json['published_at'] as String)
        : null,
    isNew: json['is_new'] == true,
    isImportant: json['is_important'] == true,
    tags: List<String>.from(json['tags'] ?? []),
    author: json['author'] as String?,
  );
}
```

### 2.3 Ekranlar ve Kullanım

| Ekran | Dosya | Kullanılan Alanlar |
|-------|-------|-------------------|
| Ana Sayfa Preview | `home_screen.dart` | id, title, excerpt, date, category, isNew |
| Duyuru Listesi | `announcements_screen.dart` | Tüm liste alanları + filtreleme |
| Duyuru Detay | `announcement_detail_screen.dart` | Tüm alanlar |

---

## 3. Veritabanı Tasarımı

### 3.1 Ana Tablo: `announcements`

```sql
CREATE TABLE announcements (
    id INT AUTO_INCREMENT PRIMARY KEY,
    
    -- Çok Dilli İçerik
    title_tr VARCHAR(255) NOT NULL COMMENT 'Türkçe başlık',
    title_en VARCHAR(255) NULL COMMENT 'İngilizce başlık',
    
    excerpt_tr TEXT NULL COMMENT 'Türkçe kısa özet',
    excerpt_en TEXT NULL COMMENT 'İngilizce kısa özet',
    
    content_tr LONGTEXT NULL COMMENT 'Türkçe tam içerik (HTML destekli)',
    content_en LONGTEXT NULL COMMENT 'İngilizce tam içerik (HTML destekli)',
    
    -- Kategori ve Etiketler
    category_id INT UNSIGNED NULL COMMENT 'Kategori ID (FK)',
    tags JSON NULL COMMENT 'Etiketler dizisi ["tag1", "tag2"]',
    
    -- Görsel
    image_url VARCHAR(500) NULL COMMENT 'Ana görsel URL',
    thumbnail_url VARCHAR(500) NULL COMMENT 'Küçük resim URL (liste için)',
    
    -- Durum ve Önem
    status ENUM('draft', 'published', 'archived') DEFAULT 'draft' COMMENT 'Yayın durumu',
    is_important TINYINT(1) DEFAULT 0 COMMENT 'Önemli duyuru flag',
    priority INT DEFAULT 0 COMMENT 'Sıralama önceliği (yüksek = üstte)',
    
    -- Push Bildirim
    send_push TINYINT(1) DEFAULT 0 COMMENT 'Push bildirim gönderildi mi?',
    push_sent_at DATETIME NULL COMMENT 'Push gönderim tarihi',
    
    -- Meta Bilgiler
    author_id INT UNSIGNED NULL COMMENT 'Yazar kullanıcı ID',
    author_name VARCHAR(100) NULL COMMENT 'Yazar adı (görüntüleme için)',
    
    -- Tarihler
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    published_at DATETIME NULL COMMENT 'Yayınlanma tarihi',
    expires_at DATETIME NULL COMMENT 'Son geçerlilik tarihi (opsiyonel)',
    
    -- İndeksler
    INDEX idx_status (status),
    INDEX idx_category (category_id),
    INDEX idx_published_at (published_at),
    INDEX idx_is_important (is_important),
    
    -- Foreign Keys
    FOREIGN KEY (category_id) REFERENCES announcement_categories(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 3.2 Kategori Tablosu: `announcement_categories`

```sql
CREATE TABLE announcement_categories (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    
    -- Çok Dilli İsimler
    name_tr VARCHAR(100) NOT NULL COMMENT 'Türkçe kategori adı',
    name_en VARCHAR(100) NULL COMMENT 'İngilizce kategori adı',
    
    -- Görsel ve Simge
    icon VARCHAR(50) NULL COMMENT 'Icon adı (material icons)',
    color VARCHAR(7) NULL COMMENT 'Kategori rengi (#RRGGBB)',
    
    -- Sıralama
    sort_order INT DEFAULT 0 COMMENT 'Listeleme sırası',
    
    -- Durum
    is_active TINYINT(1) DEFAULT 1 COMMENT 'Aktif mi?',
    
    -- Tarihler
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 3.3 Varsayılan Kategoriler

```sql
INSERT INTO announcement_categories (name_tr, name_en, icon, color, sort_order) VALUES
    ('Ulaşım', 'Transportation', 'directions_bus', '#2196F3', 1),
    ('Etkinlik', 'Events', 'event', '#9C27B0', 2),
    ('Belediye', 'Municipality', 'account_balance', '#4CAF50', 3),
    ('Çevre', 'Environment', 'eco', '#8BC34A', 4),
    ('Sosyal', 'Social', 'people', '#FF9800', 5);
```

### 3.4 Görüntülenme/İstatistik Tablosu (Opsiyonel)

```sql
CREATE TABLE announcement_views (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    announcement_id INT NOT NULL,
    user_id INT UNSIGNED NULL COMMENT 'Giriş yapmış kullanıcı',
    device_id VARCHAR(100) NULL COMMENT 'Anonim cihaz ID',
    viewed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_announcement (announcement_id),
    INDEX idx_viewed_at (viewed_at),
    
    FOREIGN KEY (announcement_id) REFERENCES announcements(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

---

## 4. API Endpoint Tasarımı

### 4.1 Mobil Uygulama (Public) Endpoint'leri

| Method | Endpoint | Açıklama |
|--------|----------|----------|
| GET | `/api/v1/announcements` | Duyuru listesi |
| GET | `/api/v1/announcements/{id}` | Tek duyuru detayı |
| GET | `/api/v1/announcements/categories` | Kategori listesi |
| GET | `/api/v1/announcements/latest` | Son duyurular (home için) |
| POST | `/api/v1/announcements/{id}/view` | Görüntülenme kaydet |

### 4.2 Admin Panel Endpoint'leri

| Method | Endpoint | Açıklama |
|--------|----------|----------|
| GET | `/api/admin/announcements` | Tüm duyurular (taslak dahil) |
| POST | `/api/admin/announcements` | Yeni duyuru oluştur |
| GET | `/api/admin/announcements/{id}` | Duyuru detayı (edit için) |
| PUT | `/api/admin/announcements/{id}` | Duyuru güncelle |
| DELETE | `/api/admin/announcements/{id}` | Duyuru sil |
| POST | `/api/admin/announcements/{id}/publish` | Yayınla |
| POST | `/api/admin/announcements/{id}/unpublish` | Yayından kaldır |
| POST | `/api/admin/announcements/{id}/send-push` | Push bildirim gönder |
| GET | `/api/admin/announcements/stats` | İstatistikler |

### 4.3 Örnek API Response

#### GET `/api/v1/announcements`

```json
{
  "status": true,
  "message": "Success",
  "data": [
    {
      "id": 1,
      "title": "Yeni Bisiklet Yolları Açıldı",
      "excerpt": "Şehrimizin doğu yakasında 15 km'lik yeni bisiklet yolu hizmete girdi.",
      "content": "<p>Detaylı içerik...</p>",
      "category": "Ulaşım",
      "category_id": 1,
      "image_url": "https://cdn.samsun.bel.tr/announcements/2026/01/bisiklet-yolu.jpg",
      "author": "Basın Bürosu",
      "is_new": true,
      "is_important": false,
      "tags": ["ulaşım", "bisiklet", "yeşil"],
      "created_at": "2026-01-15T10:30:00Z",
      "published_at": "2026-01-15T12:00:00Z"
    }
  ],
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 45,
    "total_pages": 3,
    "has_next": true,
    "has_prev": false
  }
}
```

#### POST `/api/admin/announcements` (Request Body)

```json
{
  "title_tr": "Yeni Bisiklet Yolları Açıldı",
  "title_en": "New Bike Lanes Opened",
  "excerpt_tr": "Şehrimizin doğu yakasında 15 km'lik yeni bisiklet yolu.",
  "excerpt_en": "15 km new bike lane on the east side of our city.",
  "content_tr": "<p>Detaylı Türkçe içerik...</p>",
  "content_en": "<p>Detailed English content...</p>",
  "category_id": 1,
  "tags": ["ulaşım", "bisiklet", "yeşil"],
  "image_url": "https://cdn.samsun.bel.tr/announcements/2026/01/bisiklet-yolu.jpg",
  "is_important": false,
  "priority": 10,
  "status": "published",
  "published_at": "2026-01-15T12:00:00Z",
  "send_push": true
}
```

---

## 5. Admin Panel Arayüz Tasarımı

### 5.1 Duyurular Listesi Sayfası

```
┌─────────────────────────────────────────────────────────────────────────┐
│ 📢 Duyurular                                           [+ Yeni Duyuru] │
├─────────────────────────────────────────────────────────────────────────┤
│ [🔍 Ara...              ] [Kategori ▼] [Durum ▼] [Tarih Aralığı ▼]     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│ ┌─────┬────────────────────────────┬──────────┬──────────┬───────────┐ │
│ │     │ Başlık                     │ Kategori │ Durum    │ Tarih     │ │
│ ├─────┼────────────────────────────┼──────────┼──────────┼───────────┤ │
│ │ [✓] │ 🔴 Yeni Bisiklet Yolları   │ Ulaşım   │ ✅ Yayında│ 15.01.26 │ │
│ │     │ Açıldı                     │          │          │           │ │
│ ├─────┼────────────────────────────┼──────────┼──────────┼───────────┤ │
│ │ [✓] │ Hafta Sonu Etkinlikleri    │ Etkinlik │ ✅ Yayında│ 14.01.26 │ │
│ ├─────┼────────────────────────────┼──────────┼──────────┼───────────┤ │
│ │ [✓] │ Su Kesintisi Duyurusu      │ Belediye │ 📝 Taslak│ 13.01.26 │ │
│ └─────┴────────────────────────────┴──────────┴──────────┴───────────┘ │
│                                                                         │
│ Seçili: 0  │  [Toplu Yayınla] [Toplu Sil] [Toplu Arşivle]             │
│                                                                         │
│ [< Önceki]  Sayfa 1 / 5  [Sonraki >]                                   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Duyuru Ekleme/Düzenleme Formu

```
┌─────────────────────────────────────────────────────────────────────────┐
│ 📝 Yeni Duyuru Ekle                          [Önizle] [Taslak Kaydet] │
│                                                        [🚀 Yayınla]    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│ ┌─── Temel Bilgiler ──────────────────────────────────────────────────┐ │
│ │                                                                     │ │
│ │ Başlık (TR) *                                                       │ │
│ │ ┌───────────────────────────────────────────────────────────────┐  │ │
│ │ │ Yeni Bisiklet Yolları Açıldı                                  │  │ │
│ │ └───────────────────────────────────────────────────────────────┘  │ │
│ │                                                                     │ │
│ │ Başlık (EN)                                                         │ │
│ │ ┌───────────────────────────────────────────────────────────────┐  │ │
│ │ │ New Bike Lanes Opened                                         │  │ │
│ │ └───────────────────────────────────────────────────────────────┘  │ │
│ │                                                                     │ │
│ │ Kategori *                     Önem Durumu                         │ │
│ │ ┌─────────────────────┐       ┌─────────────────────┐             │ │
│ │ │ Ulaşım         ▼   │       │ [✓] Önemli Duyuru   │             │ │
│ │ └─────────────────────┘       └─────────────────────┘             │ │
│ │                                                                     │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
│                                                                         │
│ ┌─── Kısa Özet ───────────────────────────────────────────────────────┐ │
│ │                                                                     │ │
│ │ Özet (TR) - Liste görünümünde gösterilir                           │ │
│ │ ┌───────────────────────────────────────────────────────────────┐  │ │
│ │ │ Şehrimizin doğu yakasında 15 km'lik yeni bisiklet yolu       │  │ │
│ │ │ hizmete girdi.                                                │  │ │
│ │ └───────────────────────────────────────────────────────────────┘  │ │
│ │ 85/200 karakter                                                    │ │
│ │                                                                     │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
│                                                                         │
│ ┌─── Detaylı İçerik ──────────────────────────────────────────────────┐ │
│ │                                                                     │ │
│ │ İçerik (TR) *                                                       │ │
│ │ ┌───────────────────────────────────────────────────────────────┐  │ │
│ │ │ [B] [I] [U] [Link] [Görsel] [Liste] [Alıntı]                 │  │ │
│ │ ├───────────────────────────────────────────────────────────────┤  │ │
│ │ │                                                               │  │ │
│ │ │ <Rich Text Editor>                                            │  │ │
│ │ │                                                               │  │ │
│ │ │ Samsun Büyükşehir Belediyesi'nin "Yeşil Ulaşım" projesi       │  │ │
│ │ │ kapsamında hayata geçirilen bisiklet yolları, şehrin doğu     │  │ │
│ │ │ yakasını kapsamaktadır...                                     │  │ │
│ │ │                                                               │  │ │
│ │ └───────────────────────────────────────────────────────────────┘  │ │
│ │                                                                     │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
│                                                                         │
│ ┌─── Görsel ──────────────────────────────────────────────────────────┐ │
│ │                                                                     │ │
│ │  ┌─────────────┐                                                    │ │
│ │  │             │  [📤 Görsel Yükle]                                 │ │
│ │  │   🖼️ Önizle │                                                    │ │
│ │  │             │  Önerilen: 1200x630px, max 2MB                     │ │
│ │  └─────────────┘                                                    │ │
│ │                                                                     │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
│                                                                         │
│ ┌─── Etiketler ───────────────────────────────────────────────────────┐ │
│ │                                                                     │ │
│ │ [ulaşım] [bisiklet] [yeşil] [+ Ekle]                               │ │
│ │                                                                     │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
│                                                                         │
│ ┌─── Yayın Ayarları ──────────────────────────────────────────────────┐ │
│ │                                                                     │ │
│ │ Yayın Tarihi                   Son Geçerlilik (opsiyonel)          │ │
│ │ ┌─────────────────────┐       ┌─────────────────────┐             │ │
│ │ │ 📅 15.01.2026 12:00 │       │ 📅 Seçilmedi        │             │ │
│ │ └─────────────────────┘       └─────────────────────┘             │ │
│ │                                                                     │ │
│ │ [✓] Push bildirim gönder                                           │ │
│ │                                                                     │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
│                                                                         │
│ ┌───────────────────────────────────────────────────────────────────┐   │
│ │  [İptal]                              [Taslak Kaydet] [🚀 Yayınla] │   │
│ └───────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 5.3 İstatistikler Dashboard

```
┌─────────────────────────────────────────────────────────────────────────┐
│ 📊 Duyuru İstatistikleri                                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │   📄 45     │  │   ✅ 38     │  │   📝 5      │  │   📦 2      │    │
│  │   Toplam    │  │   Yayında   │  │   Taslak    │  │   Arşiv     │    │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘    │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ 📈 Son 30 Gün - Görüntülenme                                    │   │
│  │ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓            │   │
│  │ Toplam: 12,450 görüntülenme                                     │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─── En Çok Görüntülenen ─────┐  ┌─── Kategori Dağılımı ──────────┐  │
│  │                             │  │                                 │  │
│  │ 1. Bisiklet Yolları  2,340  │  │  Ulaşım    ████████████  35%   │  │
│  │ 2. Su Kesintisi      1,890  │  │  Etkinlik  ████████     25%   │  │
│  │ 3. Festival Duyurusu 1,567  │  │  Belediye  ██████       20%   │  │
│  │ 4. Park Açılışı      1,234  │  │  Çevre     ████         12%   │  │
│  │ 5. Yol Çalışması     1,100  │  │  Sosyal    ███           8%   │  │
│  │                             │  │                                 │  │
│  └─────────────────────────────┘  └─────────────────────────────────┘  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 6. Uygulama Adımları

### 6.1 Backend (PHP/Laravel) Dosyaları

#### Oluşturulması Gereken Dosyalar:

```
app/
├── Http/
│   └── Controllers/
│       ├── Api/
│       │   └── AnnouncementController.php      # Public API
│       └── Admin/
│           └── AnnouncementController.php      # Admin API
├── Models/
│   ├── Announcement.php                         # Eloquent Model
│   └── AnnouncementCategory.php                 # Kategori Model
├── Repositories/
│   └── AnnouncementRepository.php               # Data Access Layer
├── Services/
│   └── AnnouncementService.php                  # Business Logic
└── Requests/
    ├── StoreAnnouncementRequest.php             # Validation
    └── UpdateAnnouncementRequest.php            # Validation

routes/
├── api.php                                       # Public routes
└── admin.php                                     # Admin routes
```

### 6.2 Veritabanı Migration Sırası

1. `announcement_categories` tablosunu oluştur
2. Varsayılan kategorileri ekle (seeder)
3. `announcements` tablosunu oluştur
4. `announcement_views` tablosunu oluştur (opsiyonel)

### 6.3 Admin Panel Frontend (Önerilen)

- **Framework:** React + TypeScript veya Next.js
- **UI Library:** Ant Design veya Material-UI
- **Rich Text Editor:** TinyMCE veya Quill
- **Tablo:** AG Grid veya React Table
- **Form Yönetimi:** React Hook Form + Yup validation

### 6.4 Test Checklist

- [ ] Duyuru CRUD işlemleri (Create, Read, Update, Delete)
- [ ] Çok dilli içerik desteği (TR/EN)
- [ ] Görsel yükleme ve boyutlandırma
- [ ] Kategori filtreleme
- [ ] Arama fonksiyonu
- [ ] Yayınlama/yayından kaldırma
- [ ] Push bildirim entegrasyonu
- [ ] Tarih bazlı otomatik yayın
- [ ] Görüntülenme istatistikleri

---

## 📌 Notlar

1. **isNew Hesaplama:** Mobil uygulamada `isNew`, yayınlanma tarihinden itibaren 24-48 saat içinde `true` olarak hesaplanır. Backend'de bunu dinamik olarak hesapla veya `is_new` flag'ini cron job ile güncelle.

2. **Push Bildirim:** Firebase Cloud Messaging (FCM) entegrasyonu gerekli. Duyuru yayınlandığında veya admin "Push Gönder" butonuna bastığında bildirim gönderilecek.

3. **Görsel CDN:** Görseller için CDN kullanılması önerilir (örn: Cloudflare R2, AWS S3).

4. **Cache:** Duyuru listesi ve detayları için Redis cache kullanarak performans artırılabilir.

5. **SEO:** Web sitesi varsa, duyurular için meta description ve Open Graph tag'leri eklenmelidir.

---

## 📞 İletişim

Sorularınız için geliştirme ekibiyle iletişime geçin.

---

*Son Güncelleme: 15 Ocak 2026*
