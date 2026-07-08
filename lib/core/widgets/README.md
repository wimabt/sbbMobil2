# Reusable Widgets

Bu klasör, uygulama genelinde kullanılan yeniden kullanılabilir widget'ları içerir.

## Kullanım

```dart
import 'package:sbb_mobile/core/widgets/widgets.dart';
```

## Mevcut Widget'lar

### AppSearchBar
Arama çubuğu component'i. Tüm ekranlarda tutarlı arama deneyimi sağlar.

```dart
AppSearchBar(
  hintText: 'Mekan ara...',
  showFilterButton: true,
  onChanged: (value) {
    // Arama işlemi
  },
  onFilterTap: () {
    // Filtre açma
  },
)
```

### CategoryPill
Kategori seçimi için pill component'i. Aktif/pasif durumları destekler.

```dart
CategoryPill(
  label: 'Tümü',
  icon: Icons.all_inclusive,
  isActive: _selectedCategory == 'all',
  onTap: () {
    setState(() => _selectedCategory = 'all');
  },
)
```

### BadgeChip
Etiket ve durum göstergeleri için badge component'i.

```dart
// Basit kullanım
BadgeChip(label: 'Yeni', color: AppColors.error)

// Önceden tanımlı varyantlar
BadgeChipVariants.success(context, 'Tamamlandı')
BadgeChipVariants.warning(context, 'Beklemede')
BadgeChipVariants.error(context, 'Hata')
BadgeChipVariants.info(context, 'Bilgi')
BadgeChipVariants.newBadge(context) // "Yeni" badge'i
```

### SectionHeader
Bölüm başlıkları için header component'i. İsteğe bağlı aksiyon butonu içerir.

```dart
SectionHeader(
  title: 'Öne Çıkan Mekanlar',
  actionText: 'Tümünü Gör',
  onAction: () => context.push('/places'),
)
```

### StatCard
Metrik gösterimi için stat card component'i.

```dart
StatCard(
  icon: Icons.emoji_events_outlined,
  iconColor: Colors.green,
  value: '2,450',
  label: 'Puan',
)
```

### AppCard
Tutarlı stil ile base card component'i.

```dart
AppCard(
  onTap: () => print('Tıklandı'),
  child: Text('İçerik'),
)
```

## Design Tokens

Tüm widget'lar `lib/core/design/design_tokens.dart` dosyasındaki token'ları kullanır:

- `AppSpacing`: xs, sm, md, lg, xl, xxl, xxxl
- `AppRadius`: sm, md, lg, xl, pill
- `AppElevation`: level1, level2, level3, level4
- `AppTouchTarget`: minimum (48dp), comfortable (56dp)
- `AppColors`: success, warning, error, info
- `AppTextStyles`: Typography helper'ları

## Migrasyon Rehberi

Mevcut ekranlardaki kod tekrarlarını bu widget'larla değiştirin:

1. **Search Bar**: 5 ekranda tekrarlanan ~50 satır kod → `AppSearchBar`
2. **Category Pills**: 6 ekranda tekrarlanan ~40 satır kod → `CategoryPill`
3. **Badges**: 8 yerde tekrarlanan ~20 satır kod → `BadgeChip`
4. **Section Headers**: 10 yerde tekrarlanan ~15 satır kod → `SectionHeader`
5. **Stat Cards**: 3 yerde tekrarlanan kod → `StatCard`
6. **Cards**: Tüm card'lar → `AppCard` wrapper kullanın

**Tahmini kod azaltması:** ~960 satır → ~100 satır (yaklaşık %90 azalma)

