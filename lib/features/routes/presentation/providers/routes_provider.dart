import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import '../../../../l10n/l10n.dart';

import '../../../../api/api_client.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/services/discovery_service.dart';
import '../../../../core/services/route_id_resolver.dart';
import '../../../../core/utils/image_url_helper.dart';
import '../../../../data/models/models.dart' as data_models;
import '../../../../data/repositories/repositories.dart';
import '../models/route_data.dart';
import 'route_gamification_provider.dart';

String _formatRouteDurationLabel(int? minutes) {
  if (minutes == null || minutes <= 0) return '-';
  if (minutes >= 60) {
    final hours = minutes / 60.0;
    final roundedTenth = (hours * 10).round() / 10;
    if ((roundedTenth - roundedTenth.round()).abs() < 0.05) {
      return '${roundedTenth.round()} SAAT';
    }
    return '${roundedTenth.toStringAsFixed(1)} SAAT';
  }
  return '$minutes DK';
}

String _routeListCategoryLabel({
  required String langCode,
  String? travelMode,
  String? difficultyLevel,
}) {
  // Provider'da BuildContext yok → aktif dile göre ARB'yi senkron çöz.
  final l10n = lookupAppLocalizations(Locale(langCode));
  final tm = (travelMode ?? '').toLowerCase().trim();
  if (tm.contains('walk') || tm == 'foot' || tm.contains('yürü')) {
    return l10n.routeModeWalking.toUpperCase();
  }
  if (tm.contains('bike') || tm.contains('cycle') || tm.contains('bisiklet')) {
    return l10n.routeModeBike.toUpperCase();
  }
  if (tm.contains('drive') ||
      tm.contains('car') ||
      tm.contains('vehicle') ||
      tm.contains('araç')) {
    return l10n.routeModeCar.toUpperCase();
  }
  final d = (difficultyLevel ?? '').toLowerCase();
  switch (d) {
    case 'easy':
    case 'kolay':
      return l10n.routeDiffEasy.toUpperCase();
    case 'medium':
    case 'orta':
      return l10n.routeDiffMedium.toUpperCase();
    case 'hard':
    case 'zor':
      return l10n.routeDiffHard.toUpperCase();
    default:
      if (d.isNotEmpty && d != '-') {
        return d.toUpperCase();
      }
      return l10n.routeLabelDefault.toUpperCase();
  }
}

/// Routes feature state
/// §6.4.5 — Rota listesi sıralama seçenekleri. (Presentation modelinde mesafe/
/// süre serbest metin olduğundan sayısal `stops`/`points` alanları kullanılır.)
enum RouteSortMode {
  name, // İsme göre (A-Z) — varsayılan
  stops, // Durak sayısı (çoktan aza)
  points, // Puan (yüksekten)
}

String routeSortLabel(AppLocalizations l10n, RouteSortMode m) {
  switch (m) {
    case RouteSortMode.name:
      return l10n.sortByName;
    case RouteSortMode.stops:
      return l10n.sortStopCount;
    case RouteSortMode.points:
      return l10n.lblPoints;
  }
}

class RoutesState {
  const RoutesState({
    this.routes = const [],
    this.filteredRoutes = const [],
    this.selectedCategory = 'all',
    this.searchQuery = '',
    this.categories = const [],
    this.isLoading = false,
    this.error,
    this.sortMode = RouteSortMode.name,
  });

  final List<TourRoute> routes;
  final List<TourRoute> filteredRoutes;
  final String selectedCategory;
  final String searchQuery;
  final List<RouteCategory> categories;
  final bool isLoading;
  final String? error;
  final RouteSortMode sortMode;

  RoutesState copyWith({
    List<TourRoute>? routes,
    List<TourRoute>? filteredRoutes,
    String? selectedCategory,
    String? searchQuery,
    List<RouteCategory>? categories,
    bool? isLoading,
    String? error,
    RouteSortMode? sortMode,
  }) {
    return RoutesState(
      routes: routes ?? this.routes,
      filteredRoutes: filteredRoutes ?? this.filteredRoutes,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      sortMode: sortMode ?? this.sortMode,
    );
  }
}

/// Routes Notifier
class RoutesNotifier extends Notifier<RoutesState> {
  static const _defaultCategories = [
    RouteCategory(id: 'all', label: 'Tümü', icon: Icons.explore),
    RouteCategory(id: 'historic', label: 'Tarihi', icon: Icons.museum),
    RouteCategory(id: 'nature', label: 'Doğa', icon: Icons.nature_people),
    RouteCategory(id: 'food', label: 'Gastronomi', icon: Icons.restaurant),
    RouteCategory(id: 'culture', label: 'Kültür', icon: Icons.theater_comedy),
  ];

  late RouteRepository _repository;
  String _languageCode = 'tr';
  bool _loadInFlight = false;

  @override
  RoutesState build() {
    _repository = ref.watch(routeRepositoryProvider);
    
    // PERFORMANS: Sadece languageCode değiştiğinde rebuild
    final currentLanguageCode = ref.watch(
      localeProvider.select((s) => s.locale.languageCode),
    );
    _languageCode = currentLanguageCode;

    // KULLANICI DEĞİŞİMİ: Farklı bir hesaba geçildiğinde rotaları güncelle (puanlar vb için).
    // Logout durumunda tekrar loadRoutes çağırmıyoruz — CMS verisi zaten var,
    // gamification datası auth guard ile zaten atlanacak.
    ref.listen<AuthState>(authProvider, (prev, next) {
      final wasAuthed = prev?.status == AuthStatus.authenticated;
      final isAuthed = next.status == AuthStatus.authenticated;
      final prevUserId = prev?.user?.id;
      final nextUserId = next.user?.id;

      if (isAuthed && (!wasAuthed || prevUserId != nextUserId)) {
        Future.microtask(() => loadRoutes(refresh: true));
      }
    });
    
    // Provider rebuild olduğunda (örneğin invalidate sonucu) isLoading
    // state'inde kalmaması ve tekrar yüklemeyi garanti etmesi için
    // Future.microtask içinde loadRoutes tetikleniyor.
    Future.microtask(() {
      loadRoutes(refresh: true);
    });
    
    return const RoutesState(
      isLoading: true,
      categories: _defaultCategories,
    );
  }

  Future<void> loadRoutes({bool refresh = false}) async {
    if (state.isLoading && !refresh && state.routes.isNotEmpty) return;
    if (_loadInFlight) {
      return;
    }
    _loadInFlight = true;

    state = state.copyWith(isLoading: true, error: null);
    

    try {
      // Liste ekranı için yalnızca ihtiyaç duyulan alanları çek.
      // Route card'da kullanılan alanlar:
      //   id, name, description, cover_url, distance_km, difficulty_level
      //   + puan kartı için total_possible_points
      const listFields =
          'id,name,description,cover_url,distance_km,duration_minutes,difficulty_level,travel_mode,completion_points,bonus_points,total_possible_points';

      final response = await _repository.getRoutes(
        limit: 100,
        lang: _languageCode,
        fields: listFields,
      ).timeout(const Duration(seconds: 15));


      if (response.status) {
        final apiRoutes = response.data ?? [];

        // Gamification backend'den rota puanlarını çek (/api/v1/mobile/routes)
        // Backend auth-optional: token yokken public data (points, stop_points),
        // token varken full data (+ progress, visited) döner.
        Map<String, Map<String, dynamic>> gamificationById = {};
        try {
          final discovery = ref.read(discoveryServiceProvider);
          final mobileRoutes = await discovery
              .getRoutes()
              .timeout(const Duration(seconds: 4));
          final resolverItems = <Map<String, dynamic>>[];
          for (final item in mobileRoutes) {
            if (item is Map<String, dynamic>) {
              resolverItems.add(item);
              final externalId = item['external_id']?.toString();
              if (externalId == null) continue;
              gamificationById[externalId] = item;
            }
          }
          ref.read(routeIdResolverProvider.notifier).populate(resolverItems);
          debugPrint(
            '🏆 [RoutesProvider] Loaded gamification data for '
            '${gamificationById.length} routes from mobile API',
          );
        } on TimeoutException {
          debugPrint(
            '⚠️ [RoutesProvider] Gamification routes timed out; continuing without points',
          );
        } catch (e) {
          debugPrint('⚠️ [RoutesProvider] Failed to load gamification routes: $e');
        }

        // API'den gelen Route'ları, gamification datayla birlikte TourRoute'a dönüştür
        final routes = apiRoutes
            .map(
              (api) => mapApiRouteToUi(
                api,
                gamificationById[api.id.toString()],
              ),
            )
            .toList();

        
        state = state.copyWith(
          routes: routes,
          filteredRoutes: _filterRoutes(routes, state.selectedCategory, state.searchQuery),
          isLoading: false,
        );
      } else {
        debugPrint('❌ [RoutesProvider] API returned error: ${response.message}');
        state = state.copyWith(
          isLoading: false,
          error: response.message.isNotEmpty
              ? response.message
              : lookupAppLocalizations(Locale(_languageCode)).errRoutesLoadFailed,
        );
      }
    } catch (e, stackTrace) {
      debugPrint('🔥 [RoutesProvider] Exception in loadRoutes: $e');
      debugPrint('🔥 [RoutesProvider] Stack trace: $stackTrace');
      state = state.copyWith(
        isLoading: false,
        error: 'Hata: ${e.toString()}',
      );
    } finally {
      _loadInFlight = false;
    }
  }

  /// API'den gelen Route modelini, UI'da kullanılan TourRoute modeline dönüştürür.
  ///
  /// [gamification] parametresi, auth backend'den (`/api/v1/mobile/routes`)
  /// gelen rota puan datasıdır. Eğer null ise puan 0 kabul edilir.
  TourRoute mapApiRouteToUi(
    data_models.Route api,
    Map<String, dynamic>? gamification,
  ) {
    // Mesafe formatı: "X.X km" veya "-"
    final distanceText = api.distanceKm != null
        ? '${api.distanceKm!.toStringAsFixed(1)} km'
        : '-';

    // Zorluk seviyesi: API'den gelen değer veya "-"
    final difficulty = api.difficultyLevel ?? '-';

    final durationText = _formatRouteDurationLabel(api.durationMinutes);

    final categoryLabel = _routeListCategoryLabel(
      langCode: _languageCode,
      travelMode: api.travelMode,
      difficultyLevel: api.difficultyLevel,
    );

    // Durak sayısı: places listesinden veya "-"
    final stops = api.places.isNotEmpty ? api.places.length : 0;

    // Puan: öncelik mobil auth backend'den gelen `total_possible_points`,
    // yoksa city backend'deki `totalPossiblePoints` alanı kullanılır.
    final rawTotal = gamification?['total_possible_points'] ??
        api.totalPossiblePoints ??
        0;
    final points = int.tryParse(rawTotal.toString()) ?? 0;

    debugPrint(
      '🏁 [RoutesProvider] routeId=${api.id} '
      'gamification.total_possible_points=${gamification?['total_possible_points']} '
      'api.totalPossiblePoints=${api.totalPossiblePoints} '
      '→ resolved points=$points',
    );

    // Cover URL - API'den gelen URL'i base URL ile birleştir
    const config = ApiConfig.prod;
    final baseUrl = config.baseUrl;
    final coverUrl = buildImageUrl(api.coverUrl, baseUrl: baseUrl);
    final imageUrl = coverUrl ?? 'assets/images/route-nature.jpg';
    
    if (api.coverUrl != null) {
    } else {
    }

    return TourRoute(
      id: api.id,
      image: imageUrl,
      title: api.name.isNotEmpty ? api.name : '-',
      description: api.description ?? '-',
      category: categoryLabel,
      duration: durationText,
      distance: distanceText,
      difficulty: difficulty,
      stops: stops,
      points: points,
      travelMode: api.travelMode,
    );
  }

  void setCategory(String categoryId) {
    if (state.selectedCategory == categoryId) return;

    state = state.copyWith(
      selectedCategory: categoryId,
      // API çağrısı YOK - cache'den client-side filtreleme
      filteredRoutes: _filterRoutes(state.routes, categoryId, state.searchQuery),
    );
    
  }

  void search(String query) {
    state = state.copyWith(
      searchQuery: query,
      filteredRoutes: _filterRoutes(state.routes, state.selectedCategory, query),
    );
  }

  void clearSearch() {
    state = state.copyWith(
      searchQuery: '',
      filteredRoutes:
          _filterRoutes(state.routes, state.selectedCategory, ''),
    );
  }

  /// §6.4.5 — Sıralama tercihini değiştirir ve listeyi yeniden uygular.
  /// Önce mod state'e yazılır ([_filterRoutes] → [_sortRoutes] onu okur).
  void setSortMode(RouteSortMode mode) {
    if (state.sortMode == mode) return;
    state = state.copyWith(sortMode: mode);
    state = state.copyWith(
      filteredRoutes:
          _filterRoutes(state.routes, state.selectedCategory, state.searchQuery),
    );
  }

  /// §6.4.5 — Seçili [RouteSortMode]'a göre sırala.
  List<TourRoute> _sortRoutes(List<TourRoute> routes) {
    final sorted = List<TourRoute>.of(routes);
    int byName(TourRoute a, TourRoute b) =>
        a.title.toLowerCase().compareTo(b.title.toLowerCase());
    switch (state.sortMode) {
      case RouteSortMode.name:
        sorted.sort(byName);
        return sorted;
      case RouteSortMode.stops:
        sorted.sort((a, b) {
          final byStops = b.stops.compareTo(a.stops); // çok → az
          if (byStops != 0) return byStops;
          return byName(a, b);
        });
        return sorted;
      case RouteSortMode.points:
        sorted.sort((a, b) {
          final byPoints = b.points.compareTo(a.points); // yüksek → düşük
          if (byPoints != 0) return byPoints;
          return byName(a, b);
        });
        return sorted;
    }
  }

  List<TourRoute> _filterRoutes(List<TourRoute> routes, String category, String query) {
    var filtered = routes;

    // Search filter
    if (query.isNotEmpty) {
      final lowerQuery = query.toLowerCase();
      filtered = filtered.where((r) {
        return r.title.toLowerCase().contains(lowerQuery) ||
            r.description.toLowerCase().contains(lowerQuery);
      }).toList();
    }

    return _sortRoutes(filtered);
  }

  Future<void> refresh() => loadRoutes(refresh: true);
}

/// Provider
final routesProvider = NotifierProvider<RoutesNotifier, RoutesState>(
  RoutesNotifier.new,
);

/// Dual-backend orchestrator for route detail.
///
/// **ID Routing:**
/// - CMS content (System A): uses `cmsContentId` (= `externalId ?? id`)
/// - Gamification (System B): uses `id` (gamification internal ID)
///
/// Fetches CMS content and gamification status in parallel via `Future.wait`,
/// then merges the results into a single `Route` model.
final routeDetailProvider = FutureProvider.family<data_models.Route?, String>((ref, id) async {
  final repository = ref.watch(routeRepositoryProvider);

  final languageCode = ref.watch(
    localeProvider.select((s) => s.locale.languageCode),
  );

  // Auth değiştiğinde (login/logout) rebuild tetikle
  ref.watch(authProvider.select((s) => s.status));

  // ── ID Resolution ──────────────────────────────────────────────
  // Read resolver (don't watch — avoids rebuild when resolver populates)
  final resolved = ref
      .read(routeIdResolverProvider.notifier)
      .resolveForRoutePath(id);
  final gamificationId = resolved.gamificationId;

  // ── Step 1: Fetch gamification data (has external_id for CMS) ──
  Map<String, dynamic>? gamificationData;
  try {
    final routeIdInt = int.tryParse(gamificationId);
    if (routeIdInt != null) {
      gamificationData = await ref.read(discoveryServiceProvider).getRouteDetail(routeIdInt);
    }
  } catch (e) {
    debugPrint('⚠️ [routeDetailProvider] Gamification API failed: $e');
  }

  // CMS ID: resolver; resolver ayrımı yoksa gamification external_id (profil mobil route id).
  final gamificationExternalId = gamificationData?['external_id']?.toString();
  var cmsId = resolved.cmsId;
  if (gamificationExternalId != null &&
      gamificationExternalId.isNotEmpty &&
      resolved.cmsId == resolved.gamificationId &&
      gamificationExternalId != resolved.cmsId) {
    cmsId = gamificationExternalId;
    debugPrint(
      '🔀 [routeDetailProvider] id=$id: resolver had no mobile↔CMS split — '
      'CMS fetch uses external_id=$cmsId (gamification id=$gamificationId)',
    );
  } else {
    debugPrint(
      '🔀 [routeDetailProvider] id=$id → cmsId=$cmsId, gamificationId=$gamificationId, lang=$languageCode',
    );
  }

  // Cache raw gamification data so routeGamificationProvider can read
  // it without making a duplicate API call.
  if (gamificationData != null) {
    ref.read(routeGamificationCacheProvider.notifier).put(id, gamificationData);
  }

  // ── Step 2: Fetch CMS content ──────────────────────────────────
  data_models.Route? route;
  try {
    route = await repository.getRoute(cmsId, lang: languageCode);
  } on ApiException catch (e) {
    if (e.statusCode == 404 &&
        gamificationExternalId != null &&
        gamificationExternalId.isNotEmpty &&
        gamificationExternalId != cmsId) {
      debugPrint(
        '⚠️ [routeDetailProvider] CMS 404 for cmsId=$cmsId — retry /travel-routes/$gamificationExternalId',
      );
      route = await repository.getRoute(gamificationExternalId, lang: languageCode);
    } else {
      rethrow;
    }
  }
  if (route == null) return null;

  if (gamificationData == null) return route;

  final totalPossiblePoints = int.tryParse(
    gamificationData['total_possible_points']?.toString() ?? '0',
  ) ?? route.totalPossiblePoints;
  final completionPoints = gamificationData['completion_points'] as int? ?? route.completionPoints;
  final bonusPoints = gamificationData['bonus_points'] as int? ?? route.bonusPoints;
  final progress = gamificationData['progress'] as Map<String, dynamic>? ?? route.progress;

  return route.copyWith(
    externalId: route.externalId ?? gamificationExternalId,
    totalPossiblePoints: totalPossiblePoints,
    completionPoints: completionPoints,
    bonusPoints: bonusPoints,
    progress: progress,
  );
});
