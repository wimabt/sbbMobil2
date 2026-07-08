import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../api/api.dart';
import '../../../../core/services/log_service.dart';

/// Ana sayfa hero görselinin panelden yönetilen yapılandırması.
///
/// Backend `GET /api/v1/mobile/home-config` → `{ hero: { imageUrl, thumbnailUrl,
/// focalX, focalY, fit } }`. `imageUrl` null ise mobil bundle'daki varsayılan
/// asset (`assets/images/hero-city.jpg`) kullanılır.
///
/// `focalX/focalY` (0..1) odak noktasıdır: görsel her cihaz genişliğinde
/// `BoxFit.cover` ile kırpıldığından, bu nokta her zaman görünür kalır.
@immutable
class HomeHeroConfig {
  const HomeHeroConfig({
    this.imageUrl,
    this.focalX = 0.5,
    this.focalY = 0.5,
    this.fit = 'cover',
  });

  final String? imageUrl;
  final double focalX;
  final double focalY;
  final String fit;

  static const HomeHeroConfig defaults = HomeHeroConfig();

  bool get isContain => fit == 'contain';

  /// Odak noktasından Flutter [Alignment] (-1..1) üretir.
  Alignment get alignment => Alignment(focalX * 2 - 1, focalY * 2 - 1);

  factory HomeHeroConfig.fromJson(Map<String, dynamic> j) {
    double clamp01(dynamic v, double fallback) {
      final n = (v is num) ? v.toDouble() : double.tryParse('$v');
      if (n == null || n.isNaN) return fallback;
      return n.clamp(0.0, 1.0);
    }

    final raw = j['imageUrl'];
    final url = (raw is String && raw.trim().isNotEmpty) ? raw.trim() : null;
    return HomeHeroConfig(
      imageUrl: url,
      focalX: clamp01(j['focalX'], 0.5),
      focalY: clamp01(j['focalY'], 0.5),
      fit: j['fit'] == 'contain' ? 'contain' : 'cover',
    );
  }

  Map<String, dynamic> toJson() => {
        'imageUrl': imageUrl,
        'focalX': focalX,
        'focalY': focalY,
        'fit': fit,
      };

  bool sameAs(HomeHeroConfig o) =>
      imageUrl == o.imageUrl &&
      focalX == o.focalX &&
      focalY == o.focalY &&
      fit == o.fit;
}

const String _kHeroPrefsKey = 'home_hero_config_v1';

/// Süreç ömrü boyunca son bilinen config (provider yeniden kurulsa da kalır;
/// ilk frame'de senkron seed için).
HomeHeroConfig? _heroMemCache;

/// Hero config provider'ı.
///
/// **Neden Notifier (FutureProvider değil):** Eskiden `autoDispose` bir
/// FutureProvider'dı; ana sayfaya her dönüşte yeniden yükleniyor, yüklenirken
/// varsayılan (ortalı) gösterilip sonra odak noktasına "kayıyordu". Artık:
///   1. keepAlive (autoDispose yok) → dönüşlerde yeniden çekme yok.
///   2. build() senkron olarak bellekteki/cihazdaki son config'i döndürür →
///      ilk frame doğru görsel + hizalamayla çizilir (kayma yok).
///   3. Arka planda backend'den tazelenir; değişmişse state + cache güncellenir.
final homeHeroConfigProvider =
    NotifierProvider<HomeHeroConfigNotifier, HomeHeroConfig>(
  HomeHeroConfigNotifier.new,
);

class HomeHeroConfigNotifier extends Notifier<HomeHeroConfig> {
  @override
  HomeHeroConfig build() {
    // Senkron seed: bellekte varsa onu, yoksa varsayılanı hemen döndür.
    final seed = _heroMemCache ?? HomeHeroConfig.defaults;
    // Arka planda yükle/tazele (prefs → backend).
    Future.microtask(_load);
    return seed;
  }

  Future<void> _load() async {
    // 1) Cihazdaki son config (cold start'ta anında doğru kare).
    if (_heroMemCache == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_kHeroPrefsKey);
        if (raw != null && raw.isNotEmpty) {
          final cfg = HomeHeroConfig.fromJson(
            jsonDecode(raw) as Map<String, dynamic>,
          );
          _heroMemCache = cfg;
          if (!state.sameAs(cfg)) state = cfg;
        }
      } catch (_) {/* yok say */}
    }

    // 2) Backend'den tazele (authApiClient — CMS değil).
    try {
      final client = ref.read(authApiClientProvider);
      final res = await client.get(ApiEndpoints.homeConfig);

      final data = res.data;
      Map<String, dynamic>? payload;
      if (data is Map<String, dynamic>) {
        payload = (data['data'] is Map<String, dynamic>)
            ? data['data'] as Map<String, dynamic>
            : data;
      }
      final hero = payload?['hero'];
      if (hero is Map<String, dynamic>) {
        final cfg = HomeHeroConfig.fromJson(hero);
        _heroMemCache = cfg;
        if (!state.sameAs(cfg)) state = cfg;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_kHeroPrefsKey, jsonEncode(cfg.toJson()));
        } catch (_) {/* yok say */}
      }
    } catch (e) {
      LogService.w('homeHeroConfig fetch failed: $e', tag: 'Home');
      // Mevcut state (seed/prefs) korunur — kullanıcı bir şey kaybetmez.
    }
  }

  /// İsteğe bağlı: panelde değişiklikten sonra elle tazeleme.
  Future<void> refresh() => _load();
}
