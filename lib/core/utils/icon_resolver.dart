import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Icon resolver - Veritabanından gelen icon string'lerini parse eder
/// Format: "maki:museum", "fa-medkit", "restaurant" gibi
/// 
/// Desteklenen formatlar:
/// - maki:xxx - Mapbox Maki icon seti
/// - fa-xxx veya fa:xxx - FontAwesome icon seti  
/// - xxx - Direkt Maki icon adı (varsayılan)
class IconResolver {
  /// Icon string'i parse eder ve gerekli bilgileri döner
  static IconInfo parseIconString(String? iconString) {
    if (iconString == null || iconString.isEmpty) {
      return const IconInfo(type: IconType.material, name: 'place');
    }

    final lower = iconString.toLowerCase().trim();
    
    // FontAwesome prefix (fa-xxx)
    if (lower.startsWith('fa-')) {
      final iconName = lower.substring(3); // "fa-medkit" -> "medkit"
      return IconInfo(type: IconType.fontawesome, name: iconName);
    }
    
    // Explicit prefix kontrolü (maki:xxx, fa:xxx, fontawesome:xxx)
    if (iconString.contains(':')) {
      final parts = iconString.split(':');
      if (parts.length == 2) {
        final prefix = parts[0].toLowerCase().trim();
        final name = parts[1].trim();
        
        switch (prefix) {
          case 'maki':
            return IconInfo(type: IconType.maki, name: name);
          case 'fa':
          case 'fontawesome':
            return IconInfo(type: IconType.fontawesome, name: name);
          case 'material':
            return IconInfo(type: IconType.material, name: name);
        }
      }
    }
    
    // Prefix yoksa direkt Maki icon adı olarak kabul et
    return IconInfo(type: IconType.maki, name: lower);
  }
  
  /// SVG asset yolunu döner
  static String getSvgAssetPath(IconInfo info) {
    switch (info.type) {
      case IconType.maki:
        return 'assets/icons/maki/${info.name}.svg';
      case IconType.fontawesome:
        return 'assets/icons/fontawesome/${info.name}.svg';
      case IconType.material:
        return '';
    }
  }
  
  /// Material IconData döner - API icon isimlerini Material Icons'a map eder
  static IconData? getMaterialIcon(String name) {
    final iconMap = <String, IconData>{
      // Genel
      'place': Icons.place,
      'apps': Icons.apps,
      'all': Icons.apps,
      
      // API'den gelen icon isimleri
      'information': Icons.info_outline,
      'landmark': Icons.account_balance,
      'restaurant': Icons.restaurant,
      'museum': Icons.museum,
      'natural': Icons.nature,
      'swimming': Icons.pool,
      'medkit': Icons.local_hospital,
      
      // Diğer yaygın isimler
      'park': Icons.park,
      'hotel': Icons.hotel,
      'home': Icons.home,
      'star': Icons.star,
      'explore': Icons.explore,
      'beach': Icons.beach_access,
      'nature': Icons.nature,
      'forest': Icons.forest,
      'water': Icons.water,
      'hospital': Icons.local_hospital,
      'health': Icons.local_hospital,
      'shop': Icons.shopping_bag,
      'shopping': Icons.shopping_bag,
      'school': Icons.school,
      'stadium': Icons.stadium,
      'cinema': Icons.movie,
      'theater': Icons.theater_comedy,
      'lodging': Icons.hotel,
      'cafe': Icons.local_cafe,
      'bar': Icons.local_bar,
      'bus': Icons.directions_bus,
      'train': Icons.train,
      'car': Icons.directions_car,
    };
    
    return iconMap[name.toLowerCase()];
  }
  
  /// Icon widget'ı oluşturur
  /// Öncelik: SVG (Maki/FontAwesome) > Maki fallback (FontAwesome için) > Material
  static Widget buildIcon({
    required String? iconString,
    double size = 18,
    Color? color,
    Color? fallbackColor,
  }) {
    final info = parseIconString(iconString);
    
    // SVG icon dene (Maki veya FontAwesome)
    if (info.type != IconType.material) {
      final assetPath = getSvgAssetPath(info);
      
      return SvgPicture.asset(
        assetPath,
        width: size,
        height: size,
        colorFilter: color != null 
            ? ColorFilter.mode(color, BlendMode.srcIn) 
            : null,
        placeholderBuilder: (context) {
          // FontAwesome başarısız olursa, Maki fallback dene
          if (info.type == IconType.fontawesome) {
            final makiFallback = _getFontAwesomeToMakiFallback(info.name);
            if (makiFallback != null) {
              return SvgPicture.asset(
                'assets/icons/maki/$makiFallback.svg',
                width: size,
                height: size,
                colorFilter: color != null 
                    ? ColorFilter.mode(color, BlendMode.srcIn) 
                    : null,
                placeholderBuilder: (_) => _buildMaterialFallback(
                  info.name, size, color ?? fallbackColor ?? Colors.grey,
                ),
              );
            }
          }
          // SVG yoksa Material fallback
          return _buildMaterialFallback(
            info.name, size, color ?? fallbackColor ?? Colors.grey,
          );
        },
      );
    }
    
    // Material icon dene
    return _buildMaterialFallback(
      info.name, size, color ?? fallbackColor ?? Colors.grey,
    );
  }
  
  /// Material icon widget oluşturur
  static Widget _buildMaterialFallback(String name, double size, Color color) {
    final materialIcon = getMaterialIcon(name);
    return Icon(
      materialIcon ?? Icons.place,
      size: size,
      color: color,
    );
  }
  
  /// FontAwesome icon adından Maki fallback döner
  static String? _getFontAwesomeToMakiFallback(String faName) {
    final normalizedName = faName.toLowerCase().replaceAll('-', '_');
    
    const faToMakiMap = <String, String>{
      // Health & Medical
      'medkit': 'hospital',
      'hospital': 'hospital',
      'hospital_o': 'hospital',
      'hospital_alt': 'hospital',
      'clinic_medical': 'hospital',
      'first_aid': 'hospital',
      'spa': 'hospital',
      'stethoscope': 'doctor',
      'user_md': 'doctor',
      'user_doctor': 'doctor',
      'pills': 'pharmacy',
      'capsules': 'pharmacy',
      'prescription_bottle': 'pharmacy',
      'tooth': 'dentist',
      
      // Food & Dining
      'cutlery': 'restaurant',
      'utensils': 'restaurant',
      'hamburger': 'fast-food',
      'pizza_slice': 'fast-food',
      'ice_cream': 'ice-cream',
      'coffee': 'cafe',
      'mug_hot': 'cafe',
      'beer': 'bar',
      'wine_glass': 'bar',
      'cocktail': 'bar',
      'bread_slice': 'bakery',
      
      // Shopping
      'shopping_cart': 'shop',
      'shopping_bag': 'shop',
      'store': 'shop',
      'gem': 'jewelry-store',
      'tshirt': 'clothing-store',
      
      // Education
      'graduation_cap': 'college',
      'university': 'college',
      'school': 'school',
      'book': 'library',
      'book_open': 'library',
      
      // Sports
      'futbol': 'soccer',
      'futbol_o': 'soccer',
      'soccer_ball_o': 'soccer',
      'basketball_ball': 'basketball',
      'swimming_pool': 'swimming',
      'swimmer': 'swimming',
      'dumbbell': 'fitness-centre',
      
      // Accommodation
      'bed': 'lodging',
      'hotel': 'lodging',
      'campground': 'campsite',
      
      // Transportation
      'bus': 'bus',
      'train': 'rail',
      'subway': 'rail-metro',
      'car': 'car',
      'bicycle': 'bicycle',
      'plane': 'airport',
      'ship': 'ferry',
      'anchor': 'harbor',
      'gas_pump': 'fuel',
      'parking': 'parking',
      
      // Culture & Entertainment
      'museum': 'museum',
      'landmark': 'landmark',
      'monument': 'monument',
      'theater_masks': 'theatre',
      'film': 'cinema',
      'music': 'music',
      'gamepad': 'gaming',
      'dice': 'casino',
      
      // Nature
      'tree': 'park',
      'leaf': 'garden',
      'mountain': 'mountain',
      'umbrella_beach': 'beach',
      'paw': 'zoo',
      
      // Places & Landmarks
      'map_marker': 'marker',
      'map_marker_alt': 'marker',
      'location_pin': 'marker',
      'home': 'home',
      'building': 'building',
      'city': 'city',
      'church': 'place-of-worship',
      'mosque': 'religious-muslim',
      
      // Services
      'phone': 'telephone',
      'envelope': 'post',
      'atm': 'bank',
      'money_bill': 'bank',
      'police': 'police',
      'toilet': 'toilet',
      'recycle': 'recycling',
      'wheelchair': 'wheelchair',
      'wifi': 'communications-tower',
      
      // Attractions
      'star': 'attraction',
      'award': 'attraction',
      'trophy': 'attraction',
      'gift': 'gift',
      'binoculars': 'viewpoint',
      'info': 'information',
      'info_circle': 'information',
    };
    
    return faToMakiMap[normalizedName];
  }
}

/// Icon tipi enum
enum IconType {
  maki,
  fontawesome,
  material,
}

/// Parse edilmiş icon bilgisi
class IconInfo {
  const IconInfo({
    required this.type,
    required this.name,
  });
  
  final IconType type;
  final String name;
  
  @override
  String toString() => 'IconInfo($type, $name)';
}
