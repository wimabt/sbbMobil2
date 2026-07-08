/// Image URL helper utilities
/// Handles both full URLs and relative paths from API
library;

import '../network/api_service.dart';

/// Rewrites internal Docker/MinIO URLs to the public backend base URL.
///
/// Backend bazen mobil cihazdan erişilemeyen iç ağ URL'leri (Docker hostname'i
/// veya geliştirme makinesindeki LAN IP'si, ICS gateway gibi) döndürebilir.
/// Bu fonksiyon, böyle URL'leri otomatik olarak `ApiService.baseUrl`'in
/// host'una çevirir, port'u ve path'i korur. Sayede mobil cihaz her durumda
/// kendi backend'i üzerinden dosyaya ulaşır.
///
/// Algılanan iç host paternleri:
///   • `minio` (Docker hostname)
///   • RFC1918 private IP range'leri: `10.x`, `172.16-31.x`, `192.168.x`
///   • Loopback: `127.x`, `localhost`
///
/// `ApiService.baseUrl` host'u zaten private IP olabilir (Android emülatör
/// senaryosu — `10.0.2.2` veya geliştirici makinesi LAN IP'si). Bu durumda
/// rewrite yapılmaz çünkü mobil zaten o subnet'e erişebiliyor.
String rewriteStorageUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return url;

  final baseUri = Uri.tryParse(ApiService.baseUrl);
  if (baseUri == null) return url;

  // Host zaten public domain ise (kesfetpanel.smartsamsun.com gibi) veya
  // ApiService.baseUrl ile aynı host'taysa rewrite gereksiz.
  if (uri.host == baseUri.host) return url;
  if (!_isInternalHost(uri.host)) return url;

  // Port seçimi:
  //   • baseUri explicit port veriyor → onu kullan (reverse proxy senaryosu)
  //   • baseUri public domain (smartsamsun.com gibi) → source port'u
  //     **KORUMA**. Production'da MinIO/storage genelde 443 arkasında
  //     reverse-proxy ile yayınlanır; :9000 gibi custom port'lar internete
  //     açılmaz. Source port'unu körü körüne taşımak `connection refused`
  //     ile sonuçlanır (gerçek bug bu şekilde tespit edildi).
  //   • baseUri de internal (dev senaryosu) → source port'u KORU
  //     (MinIO doğrudan :9000'de erişiliyor olabilir)
  final targetPort = baseUri.hasPort
      ? baseUri.port
      : _isInternalHost(baseUri.host)
          ? (uri.hasPort ? uri.port : (baseUri.scheme == 'https' ? 443 : 80))
          : (baseUri.scheme == 'https' ? 443 : 80);
  final rewritten = uri.replace(
    scheme: baseUri.scheme,
    host: baseUri.host,
    port: targetPort,
  );
  return rewritten.toString();
}

/// `host` cihazın doğrudan ulaşamayacağı bir iç ağ adresi mi?
bool _isInternalHost(String host) {
  if (host == 'localhost' || host == 'minio') return true;

  // IPv4 parse
  final parts = host.split('.');
  if (parts.length != 4) return false;
  final octets = parts.map(int.tryParse).toList();
  if (octets.any((o) => o == null || o < 0 || o > 255)) return false;
  final a = octets[0]!;
  final b = octets[1]!;

  // RFC1918 + loopback
  if (a == 10) return true;
  if (a == 127) return true;
  if (a == 172 && b >= 16 && b <= 31) return true;
  if (a == 192 && b == 168) return true;
  return false;
}

/// Builds a full image URL from API response
/// 
/// If the URL is already a full URL (starts with http:// or https://), returns it as-is.
/// If it's a relative path, combines it with the base URL.
/// For video URLs, removes /api/v1 from base URL since videos are in /uploads/ folder.
/// Returns null if the input is null or empty.
String? buildImageUrl(String? imageUrl, {String? baseUrl, bool isVideo = false}) {
  if (imageUrl == null || imageUrl.isEmpty) {
    return null;
  }

  // If it's already a full URL, return as-is
  if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
    return imageUrl;
  }

  // If baseUrl is provided and imageUrl is relative, combine them
  if (baseUrl != null && baseUrl.isNotEmpty) {
    // For video URLs, remove /api/v1 from base URL
    String cleanBaseUrl = baseUrl.endsWith('/') 
        ? baseUrl.substring(0, baseUrl.length - 1) 
        : baseUrl;
    
    if (isVideo && cleanBaseUrl.contains('/api/v1')) {
      cleanBaseUrl = cleanBaseUrl.replaceAll('/api/v1', '');
    }
    
    final cleanImageUrl = imageUrl.startsWith('/') ? imageUrl : '/$imageUrl';
    return '$cleanBaseUrl$cleanImageUrl';
  }

  // If no baseUrl provided, return the imageUrl as-is (might be relative)
  return imageUrl;
}

/// Builds image URLs for a list of photo URLs
List<String> buildImageUrls(List<String> photoUrls, {String? baseUrl, bool isVideo = false}) {
  return photoUrls
      .map((url) => buildImageUrl(url, baseUrl: baseUrl, isVideo: isVideo))
      .whereType<String>()
      .toList();
}
