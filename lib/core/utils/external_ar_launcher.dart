import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/log_service.dart';
import 'image_url_helper.dart';
import 'ios_ar_quicklook.dart';

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

  // iOS: AR Quick Look YALNIZCA .usdz/.reality açar; .glb'yi Safari yalnızca
  // "indir" olarak sunar (ARKit gelmez). Native köprü .glb'yi cihazda .usdz'ye
  // çevirip AR Quick Look ile sunar → Android Scene Viewer'ın iOS eşdeğeri.
  if (Platform.isIOS) {
    final ok = await IosArQuickLook.present(resolved, title: title);
    if (!ok) {
      LogService.w('iOS AR Quick Look açılamadı: $resolved', tag: _tag);
    }
    return ok;
  }

  try {
    // Android → Google Scene Viewer (.glb'yi doğrudan AR'da açar).
    final params = <String, String>{
      'file': resolved,
      'mode': 'ar_preferred',
    };
    if (title != null) params['title'] = title;
    final uri = Uri.https('arvr.google.com', '/scene-viewer/1.0', params);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) LogService.w('External AR launch returned false: $uri', tag: _tag);
    return ok;
  } catch (e) {
    LogService.w('External AR launch failed: $e', tag: _tag);
    return false;
  }
}

/// [launchExternalArViewer]'ı kullanıcı geri bildirimiyle çağırır.
///
/// iOS'ta ilk açılışta `.glb` indir + `.usdz`'ye çevir birkaç saniye
/// sürebildiği için, dönüşüm boyunca kısa bir yükleniyor göstergesi (spinner)
/// sunulur — dokunup "hiçbir şey olmadı" hissi olmasın. Android'de Scene Viewer
/// anında açıldığı için gösterge atlanır. Başarısızsa `false` döner (ve
/// isteğe bağlı [errorMessage] snackbar'ı gösterilir).
Future<bool> launchArViewerWithProgress(
  BuildContext context,
  String modelUrl, {
  String? title,
  String? errorMessage,
}) async {
  if (!Platform.isIOS) {
    return launchExternalArViewer(modelUrl, title: title);
  }

  final navigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.maybeOf(context);

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    useRootNavigator: true,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  var dialogClosed = false;
  void closeDialog() {
    if (dialogClosed) return;
    dialogClosed = true;
    if (navigator.canPop()) navigator.pop();
  }

  bool ok;
  try {
    ok = await launchExternalArViewer(modelUrl, title: title);
  } catch (e) {
    LogService.w('launchArViewerWithProgress failed: $e', tag: _tag);
    ok = false;
  }
  closeDialog();

  if (!ok && errorMessage != null) {
    messenger?.showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  return ok;
}
