import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Çevrimdışı içerik önbelleği (§5.1.2, §6.8.5).
///
/// Başarılı GET yanıtlarını diske yazar; internet koptuğunda daha önce
/// görüntülenen içerik (yer detayı, etkinlik, tarif vb.) cache'ten servis
/// edilir. [OfflineCacheInterceptor] tarafından kullanılır.
///
/// **Neden dosya tabanlı (sqflite değil):** path_provider tüm platformlarda
/// (Android/iOS + masaüstü dev) çalışır; sqflite masaüstünde ek FFI kurulumu
/// ister. Yanıtlar URL'e göre tek tek JSON dosyasında tutulur — basit, hızlı,
/// platformdan bağımsız.
class OfflineContentCache {
  OfflineContentCache._();
  static final OfflineContentCache instance = OfflineContentCache._();

  Directory? _dir;
  bool _ready = false;

  /// Tutulacak azami kayıt sayısı (aşılınca en eskiler silinir).
  static const int _maxEntries = 400;

  /// Mutlak azami yaş — bu süreden eski kayıt servis edilmez, silinir.
  static const Duration _maxAge = Duration(days: 30);

  bool get isReady => _ready;

  /// Startup'ta çağrılır: cache dizinini hazırlar ve eski kayıtları temizler.
  Future<void> init() async {
    try {
      final base = await getApplicationSupportDirectory();
      final dir = Directory('${base.path}/offline_content_cache');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      _dir = dir;
      _ready = true;
      await _evict();
    } catch (e) {
      if (kDebugMode) debugPrint('[OfflineContentCache] init failed: $e');
      _ready = false;
    }
  }

  /// URL → deterministik, platformlar arası tutarlı dosya adı (FNV-1a 32-bit).
  String _keyFor(String url) {
    var hash = 0x811c9dc5;
    for (final c in url.codeUnits) {
      hash ^= c;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16);
  }

  File? _fileFor(String url) {
    final dir = _dir;
    if (dir == null) return null;
    return File('${dir.path}/${_keyFor(url)}.json');
  }

  /// Başarılı bir GET yanıtını saklar.
  Future<void> store({
    required String url,
    required int statusCode,
    required Object data,
  }) async {
    final file = _fileFor(url);
    if (file == null) return;
    try {
      final payload = jsonEncode({
        'url': url,
        'status': statusCode,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
        'data': data,
      });
      await file.writeAsString(payload);
    } catch (e) {
      if (kDebugMode) debugPrint('[OfflineContentCache] store failed: $e');
    }
  }

  /// Cache'ten okur. Mutlak yaş aşılmışsa null döner ve dosyayı siler.
  Future<CachedEntry?> read(String url) async {
    final file = _fileFor(url);
    if (file == null || !file.existsSync()) return null;
    try {
      final map =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final cachedAt =
          DateTime.fromMillisecondsSinceEpoch(map['cachedAt'] as int);
      if (DateTime.now().difference(cachedAt) > _maxAge) {
        await file.delete();
        return null;
      }
      return CachedEntry(
        statusCode: map['status'] as int? ?? 200,
        data: map['data'],
        cachedAt: cachedAt,
      );
    } catch (e) {
      return null;
    }
  }

  /// Yaşı geçen ve sayı limitini aşan kayıtları temizler.
  Future<void> _evict() async {
    final dir = _dir;
    if (dir == null) return;
    try {
      final now = DateTime.now();
      for (final f in dir.listSync().whereType<File>()) {
        if (now.difference(f.statSync().modified) > _maxAge) {
          f.deleteSync();
        }
      }
      final remaining = dir.listSync().whereType<File>().toList()
        ..sort(
            (a, b) => a.statSync().modified.compareTo(b.statSync().modified));
      while (remaining.length > _maxEntries) {
        remaining.removeAt(0).deleteSync();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[OfflineContentCache] evict failed: $e');
    }
  }

  /// Tüm önbelleği siler (örn. çıkış / "verileri temizle").
  Future<void> clear() async {
    final dir = _dir;
    if (dir == null) return;
    try {
      for (final f in dir.listSync().whereType<File>()) {
        f.deleteSync();
      }
    } catch (_) {}
  }
}

/// Cache'ten okunan kayıt.
class CachedEntry {
  const CachedEntry({
    required this.statusCode,
    required this.data,
    required this.cachedAt,
  });

  final int statusCode;
  final Object? data;
  final DateTime cachedAt;
}
