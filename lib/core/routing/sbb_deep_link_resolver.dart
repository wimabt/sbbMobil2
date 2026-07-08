import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/log_service.dart';
import 'deep_link_validator.dart';

/// `mobile_pending_changes.md` B8 — QR resolve sonrası dönen `deep_link`
/// alanını uygulamanın router yapısına çevirir.
///
/// Desteklenen şemalar:
///   * `sbb://place/<id>`   → `/places/<id>`
///   * `sbb://route/<id>`   → `/routes/<id>`
///   * `sbb://event/<id>`   → `/events/<id>`
///   * `sbb://recipe/<id>`  → `/recipes/<id>`
///   * `sbb://ar/<id>`      → `/ar-camera` (Çevremde AR — kamera overlay)
///
/// Diğer her şey (özellikle `https?://...`) `url_launcher` ile harici
/// tarayıcıda açılır.
class SbbDeepLinkResolver {
  SbbDeepLinkResolver._();

  static const String _scheme = 'sbb';

  /// Map `sbb://` host'larını route prefix'lerine.
  static const Map<String, String> _hostToRoute = {
    'place': '/places',
    'route': '/routes',
    'event': '/events',
    'recipe': '/recipes',
  };

  /// `deepLink` çözümlenebildi mi, çözümlendi mi? Caller'a sonuç bildirilir.
  static Future<SbbDeepLinkResult> open(
    BuildContext context,
    String deepLink,
  ) async {
    final uri = Uri.tryParse(deepLink.trim());
    if (uri == null) {
      LogService.w('SbbDeepLink: invalid URI: $deepLink', tag: 'DeepLink');
      return SbbDeepLinkResult.invalid;
    }

    // Harici URL → tarayıcı
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      return ok ? SbbDeepLinkResult.launchedExternal : SbbDeepLinkResult.invalid;
    }

    if (uri.scheme != _scheme) {
      LogService.w('SbbDeepLink: unsupported scheme: ${uri.scheme}', tag: 'DeepLink');
      return SbbDeepLinkResult.invalid;
    }

    final host = uri.host;
    // sbb://ar/<id> — 3B AR sahnesini özel ele al. Sahne konuma göre yakındaki
    // tüm AR noktalarını gösterir; `id` doğrulanır ama route paramı gerekmez.
    if (host == 'ar') {
      final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      if (!DeepLinkValidator.isValidRouteSegmentId(id)) {
        return SbbDeepLinkResult.invalid;
      }
      if (!context.mounted) return SbbDeepLinkResult.invalid;
      context.push('/ar-camera');
      return SbbDeepLinkResult.navigated;
    }

    final prefix = _hostToRoute[host];
    if (prefix == null) {
      LogService.w('SbbDeepLink: unknown host: $host', tag: 'DeepLink');
      return SbbDeepLinkResult.invalid;
    }

    final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    if (!DeepLinkValidator.isValidRouteSegmentId(id)) {
      LogService.w('SbbDeepLink: invalid id for $host: $id', tag: 'DeepLink');
      return SbbDeepLinkResult.invalid;
    }

    if (!context.mounted) return SbbDeepLinkResult.invalid;
    context.push('$prefix/$id');
    return SbbDeepLinkResult.navigated;
  }
}

enum SbbDeepLinkResult {
  /// Router içine push edildi.
  navigated,

  /// `url_launcher` ile harici uygulamada açıldı.
  launchedExternal,

  /// URI parse edilemedi veya host/id geçersiz.
  invalid,
}
