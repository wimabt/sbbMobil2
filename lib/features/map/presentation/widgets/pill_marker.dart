import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/design/design_tokens.dart';

/// Pixel-perfect pill marker widget for map locations.
/// 
/// **Design Specifications:**
/// - FIXED height: 40dp (logical pixels)
/// - Min width: 80dp, Max width: 180dp
/// - Perfect stadium shape (borderRadius = height/2)
/// - Icon circle (28x28) on the left
/// - Text with ellipsis for overflow
/// - Pointer triangle at bottom center
/// 
/// **Pixel-Perfect Rules:**
/// - All dimensions are even numbers
/// - Border radius is exactly half of height
/// - No fractional pixels
class PillMarker extends StatelessWidget {
  const PillMarker({
    super.key,
    required this.title,
    this.categoryIcon,
    this.isDark = false,
  });

  final String title;
  final Widget? categoryIcon;
  final bool isDark;

  // ===== FIXED LAYOUT CONSTANTS (EVEN NUMBERS) =====
  /// Main pill height - FIXED, never changes
  static const double pillHeight = 40.0;
  
  /// Maximum width constraint
  static const double maxWidth = 180.0;
  
  /// Minimum width constraint
  static const double minWidth = 80.0;
  
  /// Icon circle diameter
  static const double iconSize = 28.0;
  
  /// Pointer triangle height
  static const double pointerHeight = 8.0;
  
  /// Pointer triangle width
  static const double pointerWidth = 14.0;
  
  /// Horizontal padding inside pill
  static const double horizontalPadding = 6.0;
  
  /// Gap between icon and text
  static const double iconTextGap = 6.0;
  
  /// Right padding after text
  static const double rightPadding = 10.0;
  
  // ===== BITMAP CAPTURE SIZE =====
  /// Width for bitmap capture (includes shadow overflow)
  static const double bitmapWidth = maxWidth + 24.0;  // 204
  
  /// Height for bitmap capture (pill + pointer + shadow)
  static const double bitmapHeight = pillHeight + pointerHeight + 16.0; // 64

  @override
  Widget build(BuildContext context) {
    // Theme colors with high contrast
    final backgroundColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final shadowOpacity = isDark ? 0.5 : 0.25;
    
    // Icon background and color — marka yeşili tonları (eskiden mavi idi).
    final iconBgColor = isDark
        ? AppColors.brandGreenBright.withAlpha(40)
        : AppColors.brandGreen.withAlpha(30);
    final iconColor = isDark
        ? AppColors.brandGreenBright
        : AppColors.brandGreen;

    return SizedBox(
      // Fixed capture area - prevents any resizing
      width: bitmapWidth,
      height: bitmapHeight,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Main pill positioned with room for shadow
          Positioned(
            top: 8.0, // Shadow offset from top
            child: _buildPill(
              backgroundColor: backgroundColor,
              textColor: textColor,
              iconBgColor: iconBgColor,
              iconColor: iconColor,
              shadowOpacity: shadowOpacity,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the main pill container with icon and text
  Widget _buildPill({
    required Color backgroundColor,
    required Color textColor,
    required Color iconBgColor,
    required Color iconColor,
    required double shadowOpacity,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The pill itself
        Container(
          height: pillHeight,
          constraints: const BoxConstraints(
            minWidth: minWidth,
            maxWidth: maxWidth,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            // Perfect stadium shape: radius = exactly half of height
            borderRadius: BorderRadius.circular(pillHeight / 2),
            boxShadow: [
              // Main shadow
              BoxShadow(
                color: Colors.black.withAlpha((shadowOpacity * 255).round()),
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
              // Subtle ambient shadow
              BoxShadow(
                color: Colors.black.withAlpha((shadowOpacity * 0.3 * 255).round()),
                blurRadius: 4,
                spreadRadius: 0,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          padding: const EdgeInsets.only(
            left: horizontalPadding,
            right: rightPadding,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon circle - FIXED 28x28
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: categoryIcon ?? Icon(
                    Icons.place_rounded,
                    color: iconColor,
                    size: 16,
                  ),
                ),
              ),
              
              // Fixed gap
              const SizedBox(width: iconTextGap),
              
              // Text - Flexible with ellipsis
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13.0,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
            ],
          ),
        ),
        
        // Pointer triangle - centered below pill
        CustomPaint(
          size: const Size(pointerWidth, pointerHeight),
          painter: _PointerPainter(
            color: backgroundColor,
            shadowColor: Colors.black.withAlpha((shadowOpacity * 0.8 * 255).round()),
          ),
        ),
      ],
    );
  }
}

/// Triangle pointer painter with shadow
class _PointerPainter extends CustomPainter {
  const _PointerPainter({
    required this.color,
    required this.shadowColor,
  });

  final Color color;
  final Color shadowColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Shadow first (drawn below)
    final shadowPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height + 1)
      ..lineTo(size.width, 0)
      ..close();
    
    canvas.drawPath(
      shadowPath,
      Paint()
        ..color = shadowColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Main triangle (sharp edges)
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PointerPainter old) =>
      color != old.color || shadowColor != old.shadowColor;
}

/// Category icon widget for marker and category chips
/// Displays SVG icons from Maki or FontAwesome sets based on iconString
class CategoryIcon extends StatelessWidget {
  const CategoryIcon({
    super.key,
    this.categorySlug,
    this.iconString,
    this.size = 16.0,
    this.isSelected = false,
    this.isDark = false,
  });

  final String? categorySlug;
  final String? iconString;
  final double size;
  final bool isSelected;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? (isDark ? const Color(0xFF0A0A0A) : Colors.white)
        : _getColorForSlug(categorySlug, isDark);

    // Determine the asset path based on iconString
    final assetPath = _resolveIconAssetPath();
    
    if (assetPath != null) {
      return SvgPicture.asset(
        assetPath,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        placeholderBuilder: (_) => _buildFallbackIcon(color),
      );
    }

    return _buildFallbackIcon(color);
  }

  /// Resolves the icon string/slug to an actual asset path
  String? _resolveIconAssetPath() {
    // Priority 1: iconString from API
    if (iconString != null && iconString!.isNotEmpty) {
      final iconStr = iconString!.toLowerCase().trim();

      // Handle "fa-xxx" format (FontAwesome)
      // Map screen'de kullanılan ikonların, liste ekranındaki
      // `IconResolver` ile aynı görünmesi için burada da önce
      // doğrudan FontAwesome asset'ini kullanıyoruz.
      if (iconStr.startsWith('fa-')) {
        final faIconName = iconStr.substring(3); // "fa-medkit" -> "medkit"
        return 'assets/icons/fontawesome/$faIconName.svg';
      }
      
      // Handle "maki:xxx" or "fontawesome:xxx" format
      if (iconStr.contains(':')) {
        final parts = iconStr.split(':');
        if (parts.length == 2) {
          final iconSet = parts[0].trim();
          final iconName = parts[1].trim();
          if (iconSet == 'maki') {
            return 'assets/icons/maki/$iconName.svg';
          } else if (iconSet == 'fontawesome' || iconSet == 'fa') {
            final makiFallback = _getFontAwesomeToMaki(iconName);
            if (makiFallback != null) {
              return 'assets/icons/maki/$makiFallback.svg';
            }
            return 'assets/icons/fontawesome/$iconName.svg';
          }
        }
      }
      
      // Plain icon name - assume Maki (e.g. "restaurant", "museum", "information")
      return 'assets/icons/maki/$iconStr.svg';
    }
    
    // Priority 2: categorySlug (e.g. "onemli-noktalar", "gastronomi")
    if (categorySlug != null && categorySlug!.isNotEmpty) {
      final slug = categorySlug!.toLowerCase().trim();
      
      // First try the slug directly as a Maki icon name
      // Then try mapping the slug to a known Maki icon
      final mappedIcon = _getSlugToMakiIcon(slug);
      if (mappedIcon != null) {
        return 'assets/icons/maki/$mappedIcon.svg';
      }
      
      // Try slug directly (might match some icons)
      return 'assets/icons/maki/$slug.svg';
    }
    
    // Default marker icon
    return 'assets/icons/maki/marker.svg';
  }

  /// Maps FontAwesome icon names to Maki equivalents
  String? _getFontAwesomeToMaki(String faIconName) {
    final fa = faIconName.toLowerCase().replaceAll('-', '_');
    
    const mapping = <String, String>{
      // Health
      'medkit': 'hospital',
      'hospital': 'hospital',
      'hospital_o': 'hospital',
      'hospital_alt': 'hospital',
      'spa': 'hospital',
      'stethoscope': 'doctor',
      'user_md': 'doctor',
      'pills': 'pharmacy',
      'tooth': 'dentist',
      
      // Food
      'cutlery': 'restaurant',
      'utensils': 'restaurant',
      'coffee': 'cafe',
      'mug_hot': 'cafe',
      'beer': 'bar',
      'wine_glass': 'bar',
      'hamburger': 'fast-food',
      'pizza_slice': 'fast-food',
      'ice_cream': 'ice-cream',
      
      // Shopping
      'shopping_cart': 'shop',
      'shopping_bag': 'shop',
      'store': 'shop',
      
      // Transport
      'bus': 'bus',
      'train': 'rail',
      'subway': 'rail-metro',
      'car': 'car',
      'bicycle': 'bicycle',
      'plane': 'airport',
      'ship': 'ferry',
      
      // Education
      'graduation_cap': 'college',
      'school': 'school',
      'book': 'library',
      'university': 'college',
      
      // Culture
      'museum': 'museum',
      'landmark': 'landmark',
      'monument': 'monument',
      'theater_masks': 'theatre',
      'film': 'cinema',
      
      // Nature
      'tree': 'park',
      'mountain': 'mountain',
      'umbrella_beach': 'beach',
      'swimming_pool': 'swimming',
      'paw': 'zoo',
      
      // Places
      'map_marker': 'marker',
      'location_pin': 'marker',
      'home': 'home',
      'building': 'building',
      'church': 'place-of-worship',
      
      // Sports
      'futbol': 'soccer',
      'futbol_o': 'soccer',
      'dumbbell': 'fitness-centre',
      
      // Accommodation
      'bed': 'lodging',
      'hotel': 'lodging',
      'campground': 'campsite',
      
      // Info
      'info': 'information',
      'info_circle': 'information',
    };
    
    return mapping[fa];
  }

  /// Maps Turkish category slugs to Maki icon names
  String? _getSlugToMakiIcon(String slug) {
    const mapping = <String, String>{
      // Turkish category slugs from your API
      'onemli-noktalar': 'information',
      'saglik-turizmi': 'hospital',
      'samsunu-kesfet': 'landmark',
      'gastronomi': 'restaurant',
      'tarihi-yer-muzeler': 'museum',
      'doga-parklar': 'park',
      'plajlar': 'swimming',
      
      // Generic mappings
      'tarihi': 'monument',
      'historic': 'monument',
      'heritage': 'monument',
      'parklar': 'park',
      'park': 'park',
      'parks': 'park',
      'nature': 'park',
      'kultur': 'museum',
      'culture': 'museum',
      'museum': 'museum',
      'restaurant': 'restaurant',
      'food': 'restaurant',
      'dining': 'restaurant',
      'cafe': 'cafe',
      'yeme-icme': 'restaurant',
      'health': 'hospital',
      'saglik': 'hospital',
      'medical': 'hospital',
      'hospital': 'hospital',
      'shopping': 'shop',
      'alisveris': 'shop',
      'education': 'school',
      'egitim': 'school',
      'sport': 'stadium',
      'spor': 'stadium',
      'transport': 'bus',
      'ulasim': 'bus',
      'hotel': 'lodging',
      'konaklama': 'lodging',
      'entertainment': 'cinema',
      'eglence': 'cinema',
      'beach': 'beach',
      'plaj': 'beach',
    };
    
    return mapping[slug.replaceAll('-', '_').toLowerCase()];
  }

  Widget _buildFallbackIcon(Color color) {
    return Icon(_getIconForSlug(categorySlug), size: size, color: color);
  }

  IconData _getIconForSlug(String? slug) {
    if (slug == null || slug.isEmpty) return Icons.place_rounded;
    
    return switch (slug.toLowerCase()) {
      'restaurant' || 'cafe' || 'fast-food' => Icons.restaurant_rounded,
      'park' => Icons.park_rounded,
      'museum' || 'art-gallery' => Icons.museum_rounded,
      'monument' || 'historic' || 'landmark' => Icons.account_balance_rounded,
      'hospital' || 'doctor' || 'pharmacy' => Icons.local_hospital_rounded,
      'shop' || 'grocery' || 'clothing-store' => Icons.shopping_bag_rounded,
      'school' || 'college' || 'university' => Icons.school_rounded,
      'stadium' || 'soccer' || 'fitness-centre' => Icons.sports_soccer_rounded,
      'theatre' || 'cinema' => Icons.theater_comedy_rounded,
      'lodging' || 'hotel' => Icons.hotel_rounded,
      'bus' || 'rail' => Icons.directions_transit_rounded,
      _ => Icons.place_rounded,
    };
  }

  Color _getColorForSlug(String? slug, bool isDark) {
    // Bilinmeyen kategoriler için marka yeşili — eskiden mavi idi.
    final defaultColor =
        isDark ? AppColors.brandGreenBright : AppColors.brandGreen;
    if (slug == null || slug.isEmpty) return defaultColor;

    // Kategori-spesifik renkler korunuyor (yiyecek=turuncu, sağlık=kırmızı vb.)
    // çünkü kullanıcı haritada hangi POI tipinde olduğunu hızlı tanısın.
    return switch (slug.toLowerCase()) {
      'monument' || 'historic' || 'landmark' =>
          isDark ? const Color(0xFFBCAAA4) : const Color(0xFF8D6E63),
      'park' =>
          isDark ? AppColors.brandGreenBright : AppColors.accentRoutes,
      'museum' || 'art-gallery' || 'theatre' =>
          isDark ? AppColors.neonPurple : AppColors.accentCulture,
      'restaurant' || 'cafe' || 'fast-food' =>
          isDark ? const Color(0xFFFFAB40) : AppColors.accentFood,
      'hospital' || 'doctor' || 'pharmacy' =>
          isDark ? const Color(0xFFEF5350) : AppColors.error,
      'shop' || 'grocery' =>
          isDark ? const Color(0xFF7986CB) : AppColors.accentMap,
      'school' || 'college' => defaultColor,
      'stadium' || 'soccer' || 'fitness-centre' =>
          isDark ? const Color(0xFF66BB6A) : AppColors.success,
      _ => defaultColor,
    };
  }
}
