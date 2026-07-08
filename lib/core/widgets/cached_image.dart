import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../design/design_tokens.dart';
import 'skeleton_loader.dart';

/// Merkezi cached network image widget'ı
/// Tüm network görseller için kullanılmalı - disk cache ile performans artışı sağlar
/// 
/// Özellikler:
/// - Otomatik disk caching
/// - Memory cache optimizasyonu (memCacheWidth/Height)
/// - Skeleton loader placeholder
/// - Error state handling
/// - Fade-in animasyonu
/// - Asset fallback desteği
/// 
/// Performance Notes:
/// - memCacheWidth/Height: Görseli bellekte küçük boyutta tutar (RAM tasarrufu)
/// - Disk cache: Görseli orijinal boyutta saklar (kalite kaybı yok)
/// - fadeOutDuration: 0 ile anlık geçiş (daha hızlı algı)
class CachedImage extends StatelessWidget {
  const CachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.assetFallback,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  /// Network URL veya asset path
  final String imageUrl;
  
  /// Görsel boyutları
  final double? width;
  final double? height;
  
  /// Görsel fit modu
  final BoxFit fit;
  
  /// Border radius (opsiyonel)
  final BorderRadius? borderRadius;
  
  /// Custom placeholder widget
  final Widget? placeholder;
  
  /// Custom error widget
  final Widget? errorWidget;
  
  /// Fade-in animasyon süresi
  final Duration fadeInDuration;
  
  /// Asset fallback (network yüklenemezse)
  final String? assetFallback;
  
  /// Memory cache genişliği (piksel)
  /// Belirtilmezse width * devicePixelRatio kullanılır
  final int? memCacheWidth;
  
  /// Memory cache yüksekliği (piksel)
  /// Belirtilmezse height * devicePixelRatio kullanılır
  final int? memCacheHeight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Defensive: bazı backend modelleri `photoUrls`/`item.url` alanında boş
    // string döndürebiliyor. `Image.asset('')` "Unable to load asset" hatası
    // atıp ekranı bozar (resource service exception loop, kırmızı ekrana
    // kadar gidebilir). Boş/whitespace path'i baştan error widget'a düşür.
    if (imageUrl.trim().isEmpty) {
      return errorWidget ?? _buildErrorWidget(isDark);
    }

    // Eğer asset path ise (http ile başlamıyorsa), direkt Image.asset kullan
    if (!imageUrl.startsWith('http')) {
      return _buildAssetImage(isDark);
    }

    // Network image - cached
    return _buildCachedImage(isDark);
  }

  Widget _buildAssetImage(bool isDark) {
    Widget image = Image.asset(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return _buildErrorWidget(isDark);
      },
    );
    
    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }
    
    return image;
  }

  /// width/height değerinin memCache için güvenli olup olmadığını kontrol et
  /// double.infinity, NaN veya null değerleri filtrelenir
  static int? _safeMemCacheSize(double? size, double devicePixelRatio) {
    if (size == null || size.isInfinite || size.isNaN || size <= 0) {
      return null;
    }
    return (size * devicePixelRatio).toInt();
  }

  Widget _buildCachedImage(bool isDark) {
    // ✅ PERFORMANCE: Memory cache boyutunu hesapla
    // Widget boyutu * devicePixelRatio = gerçek piksel boyutu
    // Bu sayede bellekte gereksiz büyük görseller tutulmaz
    final devicePixelRatio = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    
    // Explicit memCache değeri varsa onu kullan, yoksa widget boyutundan güvenli hesapla
    // double.infinity, NaN gibi geçersiz değerler otomatik filtrelenir
    final effectiveMemCacheWidth = memCacheWidth ?? _safeMemCacheSize(width, devicePixelRatio);
    final effectiveMemCacheHeight = memCacheHeight ?? _safeMemCacheSize(height, devicePixelRatio);
    
    Widget image = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      // ✅ PERFORMANCE: Memory cache optimizasyonu
      // Görseli bellekte widget boyutunda tut (RAM tasarrufu)
      memCacheWidth: effectiveMemCacheWidth,
      memCacheHeight: effectiveMemCacheHeight,
      // ✅ PERFORMANCE: Hızlı geçiş animasyonu
      fadeInDuration: fadeInDuration,
      fadeOutDuration: Duration.zero, // Anlık fade-out (daha hızlı algı)
      placeholder: (context, url) => placeholder ?? _buildPlaceholder(isDark),
      errorWidget: (context, url, error) {
        // Önce asset fallback'i dene
        if (assetFallback != null) {
          return Image.asset(
            assetFallback!,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) {
              return _buildErrorWidget(isDark);
            },
          );
        }
        return errorWidget ?? _buildErrorWidget(isDark);
      },
    );
    
    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }
    
    return image;
  }

  Widget _buildPlaceholder(bool isDark) {
    return SkeletonLoader(
      width: width ?? double.infinity,
      height: height ?? 200,
      borderRadius: borderRadius ?? BorderRadius.circular(AppRadius.md),
    );
  }

  Widget _buildErrorWidget(bool isDark) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark 
            ? AppColors.darkSurfaceElevated 
            : AppColors.lightBackground,
        borderRadius: borderRadius ?? BorderRadius.circular(AppRadius.md),
      ),
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 32,
          color: isDark 
              ? Colors.white.withAlpha(60) 
              : Colors.black.withAlpha(60),
        ),
      ),
    );
  }
}

/// Card içindeki görseller için özel widget
/// Daha küçük placeholder ve error icon
class CachedCardImage extends StatelessWidget {
  const CachedCardImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.assetFallback,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final String? assetFallback;

  @override
  Widget build(BuildContext context) {
    return CachedImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
      assetFallback: assetFallback,
      fadeInDuration: const Duration(milliseconds: 200),
    );
  }
}

/// Hero/Banner görselleri için
/// Daha uzun fade-in süresi
class CachedHeroImage extends StatelessWidget {
  const CachedHeroImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.assetFallback,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String? assetFallback;

  @override
  Widget build(BuildContext context) {
    return CachedImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      assetFallback: assetFallback,
      fadeInDuration: const Duration(milliseconds: 500),
    );
  }
}
