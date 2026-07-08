import 'dart:io' show Platform;

import 'package:url_launcher/url_launcher.dart';

import '../services/log_service.dart';
import 'image_url_helper.dart';

const _tag = 'ExternalAR';

/// Cihazın **native AR uygulamasında** bir 3B modeli açar (uygulama-içi ARCore
/// kullanılamadığında — eski/düşük cihazlar için fallback yolu).
///
///   • Android → Google **Scene Viewer**
///     (`https://arvr.google.com/scene-viewer/1.0?file=<glb>&mode=ar_preferred`)
///   • iOS → **AR Quick Look** (modeli doğrudan URL ile açar; .usdz/.reality
///     ideal, .glb için de Safari/Quick Look devreye girer)
///
/// `modelUrl` iç (Docker/MinIO) host içeriyorsa [rewriteStorageUrl] ile public
/// adrese çevrilir. Başarı durumunda `true` döner.
Future<bool> launchExternalArViewer(String modelUrl, {String? title}) async {
  final resolved = rewriteStorageUrl(modelUrl);
  try {
    final Uri uri;
    if (Platform.isAndroid) {
      final params = <String, String>{
        'file': resolved,
        'mode': 'ar_preferred',
      };
      if (title != null) params['title'] = title;
      uri = Uri.https('arvr.google.com', '/scene-viewer/1.0', params);
    } else {
      // iOS AR Quick Look: model URL'sini doğrudan aç.
      uri = Uri.parse(resolved);
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) LogService.w('External AR launch returned false: $uri', tag: _tag);
    return ok;
  } catch (e) {
    LogService.w('External AR launch failed: $e', tag: _tag);
    return false;
  }
}
