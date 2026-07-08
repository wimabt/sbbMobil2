import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/image_url_helper.dart';
import 'log_service.dart';

const _tag = 'ArCache';

/// Manages offline caching of .glb 3D models for AR viewing.
///
/// Models are downloaded once and stored in the app's documents directory.
/// Subsequent loads serve from the local file system, eliminating network
/// radio usage during AR sessions (critical for battery optimization).
class ArCacheManager {
  ArCacheManager({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              // §6.8.4 — AR model indirme makul timeout'larla sınırlanır,
              // aksi halde sessiz takılmalar olur. 30s connect / 60s receive
              // 12 MB'lık modeller için 3G'de bile yeterli olmalı.
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 60),
              sendTimeout: const Duration(seconds: 30),
            ));

  final Dio _dio;
  CancelToken? _activeCancelToken;

  /// Prefetch için ayrı token — talep-üzerine (viewer) indirmesini İPTAL ETMEZ.
  CancelToken? _prefetchCancelToken;

  /// Returns the local file path for a cached model, or `null` if not cached.
  Future<String?> getLocalModelPath(String modelUrl, String modelId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final fileName = _buildFileName(modelUrl, modelId);
      final file = File('${dir.path}/ar_models/$fileName');

      if (await file.exists()) {
        LogService.d('Cache hit: $fileName', tag: _tag);
        return file.path;
      }

      LogService.d('Cache miss: $fileName', tag: _tag);
      return null;
    } catch (e) {
      LogService.e('Failed to check cache', tag: _tag, error: e);
      return null;
    }
  }

  /// Downloads with a Future-based API that reports progress via callback.
  /// (Tek indirme yolu — eski `Stream<ArDownloadProgress>` çifti kaldırıldı.)
  Future<String?> downloadModel({
    required String modelUrl,
    required String modelId,
    void Function(double progress)? onProgress,
  }) async {
    _activeCancelToken?.cancel('New download started');
    _activeCancelToken = CancelToken();

    final resolvedUrl = rewriteStorageUrl(modelUrl);

    final dir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${dir.path}/ar_models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }

    final fileName = _buildFileName(modelUrl, modelId);
    final filePath = '${modelsDir.path}/$fileName';

    await _clearStaleVariants(
      modelsDir: modelsDir,
      currentFileName: fileName,
      modelId: modelId,
    );

    if (modelUrl != resolvedUrl) {
      LogService.i(
        'URL rewritten: $modelUrl → $resolvedUrl',
        tag: _tag,
      );
    }
    LogService.i('Downloading model: $resolvedUrl -> $filePath', tag: _tag);

    try {
      var lastLoggedPercent = -1;
      await _dio.download(
        resolvedUrl,
        filePath,
        cancelToken: _activeCancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onProgress?.call(received / total);
            // Diagnoz: her %10'da bir log düş, sessiz takılmaları görelim.
            final percent = (received * 10 / total).floor() * 10;
            if (percent != lastLoggedPercent) {
              lastLoggedPercent = percent;
              LogService.d(
                'Download progress $percent% ($received/$total bytes)',
                tag: _tag,
              );
            }
          } else {
            // total == -1 → sunucu Content-Length göndermedi.
            LogService.d(
              'Download streaming (no Content-Length): $received bytes',
              tag: _tag,
            );
          }
        },
      );

      LogService.s('Model downloaded: $filePath', tag: _tag);
      return filePath;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        LogService.w('Download cancelled: $modelUrl', tag: _tag);
      } else {
        LogService.e(
          'Download failed (${e.type.name}): ${e.message} '
          'status=${e.response?.statusCode}',
          tag: _tag,
          error: e,
        );
      }
      // Yarım kalan dosyayı temizle ki sonraki retry'da cache hit yapmasın.
      try {
        final f = File(filePath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
      return null;
    } catch (e) {
      LogService.e('Download failed', tag: _tag, error: e);
      return null;
    }
  }

  /// Cancels any active download.
  void cancelDownload() {
    _activeCancelToken?.cancel('User cancelled');
    _activeCancelToken = null;
  }

  /// §6.8.3.9 — Bölgedeki POI 3B modellerini **proaktif** önbelleğe alır.
  ///
  /// Kamera/AR ekranı açıldığında modeller hazır olsun (bekleme süresi azalsın)
  /// diye, kullanıcı bir bölgeye girdiğinde çağrılır. Sıralı + best-effort
  /// indirir; çağıran [refs]'i öncelik/yakınlığa göre sıralamalı (önce en olası).
  ///
  /// • Zaten önbellektekiler atlanır (idempotent).
  /// • Talep-üzerine (viewer) indirmesini iptal ETMEZ — ayrı [_prefetchCancelToken].
  /// • Batarya/veri için [maxModels] ile sınırlı (§6.8.4).
  /// • Yarım dosya `.part` olarak inip tamamlanınca rename edilir; iptal/hata
  ///   durumunda asla "tam" görünen bozuk dosya bırakmaz.
  ///
  /// İndirilen (yeni) model sayısını döner.
  Future<int> prefetchModels(
    List<ArModelRef> refs, {
    int maxModels = 6,
  }) async {
    if (refs.isEmpty) return 0;
    _prefetchCancelToken?.cancel('New prefetch started');
    final token = CancelToken();
    _prefetchCancelToken = token;

    final dir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${dir.path}/ar_models');
    if (!await modelsDir.exists()) await modelsDir.create(recursive: true);

    var fetched = 0;
    var attempted = 0;
    for (final ref in refs) {
      if (token.isCancelled) break;
      if (attempted >= maxModels) break;
      final fileName = _buildFileName(ref.url, ref.id);
      final filePath = '${modelsDir.path}/$fileName';
      if (await File(filePath).exists()) continue; // zaten önbellekte
      attempted++;
      final ok = await _prefetchOne(
        url: ref.url,
        modelsDir: modelsDir,
        fileName: fileName,
        modelId: ref.id,
        token: token,
      );
      if (ok) fetched++;
    }
    if (fetched > 0) {
      LogService.i('Prefetched $fetched AR model(s)', tag: _tag);
    }
    return fetched;
  }

  Future<bool> _prefetchOne({
    required String url,
    required Directory modelsDir,
    required String fileName,
    required String modelId,
    required CancelToken token,
  }) async {
    final resolvedUrl = rewriteStorageUrl(url);
    final filePath = '${modelsDir.path}/$fileName';
    final tmpPath = '$filePath.part';
    await _clearStaleVariants(
      modelsDir: modelsDir,
      currentFileName: fileName,
      modelId: modelId,
    );
    try {
      await _dio.download(resolvedUrl, tmpPath, cancelToken: token);
      await File(tmpPath).rename(filePath);
      LogService.d('Prefetched model: $fileName', tag: _tag);
      return true;
    } on DioException catch (e) {
      if (e.type != DioExceptionType.cancel) {
        LogService.w('Prefetch failed $fileName: ${e.message}', tag: _tag);
      }
      await _safeDelete(tmpPath);
      return false;
    } catch (e) {
      LogService.w('Prefetch failed $fileName: $e', tag: _tag);
      await _safeDelete(tmpPath);
      return false;
    }
  }

  Future<void> _safeDelete(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Aktif prefetch'i iptal eder (AR ekranı kapanınca).
  void cancelPrefetch() {
    _prefetchCancelToken?.cancel('Prefetch cancelled');
    _prefetchCancelToken = null;
  }

  /// Deletes all cached AR models.
  Future<void> clearCache() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory('${dir.path}/ar_models');
      if (await modelsDir.exists()) {
        await modelsDir.delete(recursive: true);
        LogService.i('AR model cache cleared', tag: _tag);
      }
    } catch (e) {
      LogService.e('Failed to clear AR cache', tag: _tag, error: e);
    }
  }

  /// `modelId` aynı kalıp `modelUrl` değişse de cache hit etmeyecek şekilde
  /// dosya adına URL'nin SHA-256 prefix'ini ekliyoruz. Şartname §6.8.3.9
  /// önbelleğe izin veriyor ama admin panelden model yeniden yüklenince
  /// (yeni URL veya `?v=...` query string) mobil eski dosyayı dönmesin.
  ///
  /// Eski format: `{modelId}_model.glb`
  /// Yeni format: `{modelId}_{hash8}_model.glb`
  ///
  /// Eski dosyalar `clearStaleVariants` ile silinir; aynı modelId için yeni
  /// hash gelirse eski varyantlar diskten temizlenir (yer şişmesin).
  String _buildFileName(String modelUrl, String modelId) {
    final extension = modelUrl.split('.').last.split('?').first.split('#').first;
    final safeExt = extension.length <= 5 ? extension : 'glb';
    final urlHash =
        sha256.convert(utf8.encode(modelUrl)).toString().substring(0, 8);
    return '${modelId}_${urlHash}_model.$safeExt';
  }

  /// Aynı `modelId` için farklı URL hash'i tutan eski dosyaları siler.
  /// Yeni indirme başlamadan önce çağrılır; admin model URL'sini güncellediyse
  /// eski .glb'leri kaldırarak disk şişmesini önler.
  Future<void> _clearStaleVariants({
    required Directory modelsDir,
    required String currentFileName,
    required String modelId,
  }) async {
    try {
      if (!await modelsDir.exists()) return;
      await for (final entity in modelsDir.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (name == currentFileName) continue;
        if (!name.startsWith('${modelId}_')) continue;
        try {
          await entity.delete();
          LogService.d('Removed stale variant: $name', tag: _tag);
        } catch (e) {
          LogService.w('Failed to delete stale variant $name: $e', tag: _tag);
        }
      }
    } catch (e) {
      LogService.w('Stale variant scan failed: $e', tag: _tag);
    }
  }
}

/// Prefetch için hafif model referansı (url + stabil id).
class ArModelRef {
  const ArModelRef({required this.url, required this.id});
  final String url;
  final String id;
}

/// Riverpod provider for the AR cache manager.
///
/// `.autoDispose` garantisi: AR ekranından çıkıldığında provider dispose edilir,
/// aktif indirme işlemi iptal edilir ve dosya handle'ları serbest bırakılır.
/// Bu sayede arka planda orphan network request kalmaz (P2 M3 bellek sızıntısı düzeltmesi).
final arCacheManagerProvider = Provider.autoDispose<ArCacheManager>((ref) {
  final manager = ArCacheManager();

  // AR ekranı kapatıldığında aktif indirmeyi + prefetch'i iptal et
  ref.onDispose(() {
    manager.cancelDownload();
    manager.cancelPrefetch();
  });

  return manager;
});
