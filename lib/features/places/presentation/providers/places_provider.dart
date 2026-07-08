import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/l10n.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/providers/locale_provider.dart';
import '../../../../core/services/discovery_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/place_id_resolver.dart';
import '../../../../core/utils/distance_helper.dart';
import '../../../../data/models/models.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../auth/providers/auth_provider.dart';
import 'place_detail_provider.dart';
import '../places_category_display.dart';

/// Konum durumu enum'u
enum LocationStatus {
  unknown,      // Henüz kontrol edilmedi
  available,    // Konum alındı
  serviceDisabled, // Konum servisleri kapalı
  permissionDenied, // İzin reddedildi
  permissionDeniedForever, // İzin kalıcı olarak reddedildi
  error,        // Başka bir hata
}

/// §6.4.5 — Liste sıralama seçenekleri. `recommended` mevcut davranış
/// (öne çıkanlar önce + alfabetik); diğerleri kullanıcı seçimli.
enum PlaceSortMode {
  recommended, // Önerilen (öne çıkanlar + A-Z) — varsayılan
  name, // İsme göre (A-Z)
  popularity, // Popülerlik (ziyaret sayısı / puan)
  nearest, // Yakınlık (mesafe)
}

String placeSortLabel(AppLocalizations l10n, PlaceSortMode m) {
  switch (m) {
    case PlaceSortMode.recommended:
      return l10n.sortRecommended;
    case PlaceSortMode.name:
      return l10n.sortByName;
    case PlaceSortMode.popularity:
      return l10n.sortPopularity;
    case PlaceSortMode.nearest:
      return l10n.sortProximity;
  }
}

/// Places feature state
class PlacesState {
  const PlacesState({
    this.allPlaces = const [], // Tüm place'ler (filtrelenmemiş)
    this.places = const [], // Kategoriye göre filtrelenmiş place'ler
    this.filteredPlaces = const [], // Arama + kategori filtrelenmiş place'ler
    this.selectedCategory = 'all',
    this.searchQuery = '',
    this.categories = const [],
    this.filteredCategories = const [], // Arama sonuçlarına göre filtrelenmiş kategoriler
    this.isLoading = false,
    this.error,
    this.meta,
    this.locationStatus = LocationStatus.unknown, // Konum durumu
    this.sortMode = PlaceSortMode.recommended,
    this.distancesMeters = const {}, // §6.4.5 yakınlık sıralaması (id → metre)
  });

  final List<Place> allPlaces; // Tüm place'ler (client-side filtreleme için)
  final List<Place> places; // Kategoriye göre filtrelenmiş
  final List<Place> filteredPlaces; // Arama + kategori filtrelenmiş
  final String selectedCategory;
  final String searchQuery;
  final List<PlaceCategory> categories;
  final List<PlaceCategory> filteredCategories; // Arama sonuçlarına göre filtrelenmiş kategoriler
  final bool isLoading;
  final String? error;
  final ApiMeta? meta;
  final LocationStatus locationStatus; // Konum durumu
  final PlaceSortMode sortMode;
  final Map<String, double> distancesMeters;

  PlacesState copyWith({
    List<Place>? allPlaces,
    List<Place>? places,
    List<Place>? filteredPlaces,
    String? selectedCategory,
    String? searchQuery,
    List<PlaceCategory>? categories,
    List<PlaceCategory>? filteredCategories,
    bool? isLoading,
    String? error,
    ApiMeta? meta,
    LocationStatus? locationStatus,
    PlaceSortMode? sortMode,
    Map<String, double>? distancesMeters,
  }) {
    return PlacesState(
      allPlaces: allPlaces ?? this.allPlaces,
      places: places ?? this.places,
      filteredPlaces: filteredPlaces ?? this.filteredPlaces,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      categories: categories ?? this.categories,
      filteredCategories: filteredCategories ?? this.filteredCategories,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      meta: meta ?? this.meta,
      locationStatus: locationStatus ?? this.locationStatus,
      sortMode: sortMode ?? this.sortMode,
      distancesMeters: distancesMeters ?? this.distancesMeters,
    );
  }
}

/// Places Notifier - State management for places feature
class PlacesNotifier extends Notifier<PlacesState> {
  late PlaceRepository _repository;
  String? _lastLanguageCode;

  /// Cold start'ta auth + language tetikleyicileri art arda fetch çağırıyor.
  /// In-flight ve minimum aralık guard'ı duplicate API call önler.
  bool _loadInFlight = false;
  DateTime? _lastLoadAt;
  static const Duration _kMinLoadInterval = Duration(seconds: 3);
  bool _enrichInFlight = false;

  /// Ana sayfa `/places?category=health_tourism` gibi derin bağlantılar için
  String? _pendingRouteCategorySlug;

  // Default categories (mock data kullanırken)
  static const _defaultCategories = [
    PlaceCategory(id: 'all', label: 'Tümü'),
    PlaceCategory(id: 'historic', label: 'Tarihi'),
    PlaceCategory(id: 'park', label: 'Parklar'),
    PlaceCategory(id: 'culture', label: 'Kültür'),
    PlaceCategory(id: 'food', label: 'Yeme-İçme'),
  ];

  @override
  PlacesState build() {
    _repository = ref.watch(placeRepositoryProvider);
    
    // PERFORMANS: Sadece languageCode değiştiğinde rebuild — diğer locale alanları değişince rebuild YOK
    final currentLanguageCode = ref.watch(
      localeProvider.select((s) => s.locale.languageCode),
    );

    // Auth değişikliğini dinle: login/logout olduğunda kullanıcıya özel
    // verileri (puanlar, visited, claimed) güncelle — CMS verisini tekrar çekme.
    ref.listen<AuthState>(authProvider, (previous, next) {
      final wasAuthed = previous?.status == AuthStatus.authenticated;
      final isAuthed = next.status == AuthStatus.authenticated;
      final prevUserId = previous?.user?.id;
      final nextUserId = next.user?.id;

      if (isAuthed && (!wasAuthed || prevUserId != nextUserId)) {
        // Yeni giriş veya kullanıcı değişimi → sadece puan verisini güncelle
        debugPrint('🔑 [Places] Auth changed (login/user switch), re-enriching points...');
        if (state.allPlaces.isNotEmpty) {
          _enrichWithMobilePoints(state.allPlaces);
        }
      } else if (!isAuthed && wasAuthed) {
        // Logout → kullanıcıya özel alanları sıfırla, CMS verisini koru
        debugPrint('🔑 [Places] Logout detected, clearing user-specific data...');
        if (state.allPlaces.isNotEmpty) {
          final cleared = state.allPlaces.map((p) => p.copyWith(
            points: 0,
            visited: false,
            claimed: false,
            visitCount: 0,
          )).toList();
          state = state.copyWith(allPlaces: cleared);
          _applyFilters();
        }
      }
    });
    
    // İlk build veya dil değişikliği varsa verileri yükle
    final shouldReload = _lastLanguageCode == null || _lastLanguageCode != currentLanguageCode;
    
    if (shouldReload) {
      debugPrint('🌍 [Places] Language changed: $_lastLanguageCode -> $currentLanguageCode, reloading data...');
      _lastLanguageCode = currentLanguageCode;
      
      // Microtask ile veri yüklemesini başlat
      Future.microtask(() {
        // refresh: true ile çağırıyoruz çünkü dil değiştiğinde yeni veri lazım
        // ignore: discarded_futures
        loadPlaces(refresh: true);
      });
    }

    return const PlacesState(
      isLoading: true,
      categories: _defaultCategories,
    );
  }

  /// Mekanları yükle (sadece ilk yüklemede veya refresh'te API çağrısı yapar)
  Future<void> loadPlaces({bool refresh = false}) async {
    // Eğer zaten tüm place'ler yüklenmişse ve refresh değilse, sadece filtreleme yap
    if (state.allPlaces.isNotEmpty && !refresh) {
      _applyFilters();
      _tryApplyPendingRouteCategorySlug();
      return;
    }

    // Aynı anda paralel fetch'i engelle. Auth change + language change
    // birden tetiklediğinde 4× page1..4 patlamasını önler.
    if (_loadInFlight) {
      debugPrint('⏭️ [Places] loadPlaces skipped — already in flight');
      return;
    }
    // Refresh olmayan istekler için: min interval kontrolü.
    if (!refresh && _lastLoadAt != null) {
      final since = DateTime.now().difference(_lastLoadAt!);
      if (since < _kMinLoadInterval) {
        debugPrint('⏭️ [Places] loadPlaces skipped — last fetch ${since.inSeconds}s ago');
        return;
      }
    }

    _loadInFlight = true;
    debugPrint('🔄 [Places] loadPlaces(refresh=$refresh) - Loading from API');
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Önce kategorileri çek (eğer yoksa)
      if (state.categories.isEmpty || state.categories.length == _defaultCategories.length) {
        try {
          final categoriesResponse = await _repository.getCategories();
          if (categoriesResponse.status && categoriesResponse.data != null) {
            final categories = categoriesResponse.data!;
            // "Tümü" kategorisini başa ekle (aktif dile göre)
            final allCategories = [
              PlaceCategory(
                id: 'all',
                label: lookupAppLocalizations(
                        Locale(_lastLanguageCode ?? 'tr'))
                    .lblAll,
              ),
              ...categories,
            ];
            state = state.copyWith(categories: allCategories);
          }
        } catch (e) {
          debugPrint('⚠️ [Places] Failed to load categories: $e');
          // Kategoriler yüklenemezse default kategorileri kullan
        }
      }

      // Kategori map'i oluştur (categoryId -> category name)
      final categoriesMap = <int, PlaceCategory>{};
      for (var cat in state.categories) {
        final catId = int.tryParse(cat.id);
        if (catId != null) {
          categoriesMap[catId] = cat;
        }
      }

      // Tüm mekanları çek - sadece liste için gerekli alanları iste (fields parametresi)
      // Bu optimizasyon ~%80 daha az veri transferi sağlar
      List<Place> allPlacesList = [];
      int currentPage = 1;
      bool hasMore = true;
      const pageLimit = 100;
      
      // Liste görünümü için gerekli alanlar (rating ve review_count ileride eklenecek)
      // `points`: CMS’den kampanya/puan önizlemesi (giriş olmadan da görülebilir)
      const listFields =
          'id,name,description,category_id,lat,lng,image_url,thumbnail_url,featured,points';

      while (hasMore) {
        final response = await _repository.getPlaces(
          category: null, // Tüm kategorileri çek
          page: currentPage,
          limit: pageLimit,
          fields: listFields, // ✅ Sadece gerekli alanları çek
        );

        if (response.status && response.data != null && response.data!.isNotEmpty) {
          // Place'lerin category bilgisini categoryId'den resolve et
          final places = response.data!.map((place) {
            if (place.categoryId != null && categoriesMap.containsKey(place.categoryId)) {
              final category = categoriesMap[place.categoryId]!;
              return place.copyWith(category: category.label);
            }
            return place;
          }).toList();

          allPlacesList.addAll(places);

          // Bir sonraki sayfa var mı kontrol et
          hasMore = response.meta?.hasNext ?? false;
          currentPage++;
        } else {
          hasMore = false;
        }

        // Sonsuz döngüyü önlemek için maksimum sayfa kontrolü
        if (currentPage > 100) {
          debugPrint('⚠️ [Places] Reached maximum page limit (100)');
          hasMore = false;
        }
      }

      debugPrint('✅ [Places] Loaded total ${allPlacesList.length} places from ${currentPage - 1} pages');

      // Sıralama: Önce featured olanlar, sonra alfabetik
      final sortedPlaces = _sortPlaces(allPlacesList);

      state = state.copyWith(
        allPlaces: sortedPlaces,
        isLoading: false,
        meta: ApiMeta(
          page: 1,
          limit: allPlacesList.length,
          total: allPlacesList.length,
          totalPages: 1,
          hasNext: false,
          hasPrev: false,
        ),
      );

      // Filtreleri uygula
      _applyFilters();

      _tryApplyPendingRouteCategorySlug();

      // TÜM yerlerin mesafesini tek seferde hesapla
      // OSRM Table API tek istekte tüm mesafeleri döndürür
      _calculateDistancesForAllPlaces(sortedPlaces);

      // Kullanıcı giriş yapmışsa mobile API'den puan bilgilerini enrich et
      _enrichWithMobilePoints(sortedPlaces);

      _lastLoadAt = DateTime.now();
    } catch (e, st) {
      debugPrint('🔥 [Places] loadPlaces error: $e');
      debugPrintStack(stackTrace: st);
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    } finally {
      _loadInFlight = false;
    }
  }

  /// Kategori ve arama filtrelerini uygula (client-side)
  void _applyFilters() {
    if (state.allPlaces.isEmpty) return;

    // Kategoriye göre filtrele
    List<Place> categoryFiltered;
    if (state.selectedCategory == 'all' || state.selectedCategory.isEmpty) {
      categoryFiltered = state.allPlaces;
    } else {
      // Kategori ID'sini bul
      final selectedCat = state.categories.firstWhere(
        (cat) => cat.id == state.selectedCategory || cat.label == state.selectedCategory,
        orElse: () => const PlaceCategory(id: '', label: ''),
      );

      if (selectedCat.id.isEmpty) {
        categoryFiltered = state.allPlaces;
      } else {
        categoryFiltered = state.allPlaces.where((place) {
          return place.categoryId?.toString() == selectedCat.id;
        }).toList();
      }
    }

    // Arama filtresi + seçili sıralama (§6.4.5) — sıralama, arama olsun
    // olmasın her zaman uygulanır.
    final filtered = _sortPlaces(_filterPlaces(categoryFiltered, state.searchQuery));

    // Arama sonuçlarına göre kategorileri filtrele
    final filteredCategories = _getFilteredCategories(filtered);

    state = state.copyWith(
      places: categoryFiltered,
      filteredPlaces: filtered,
      filteredCategories: filteredCategories,
    );
  }

  /// Arama sonuçlarına göre kategorileri filtrele
  /// Sadece içinde place olan kategorileri göster
  List<PlaceCategory> _getFilteredCategories(List<Place> filteredPlaces) {
    // Arama yapılmamışsa tüm kategorileri göster
    if (state.searchQuery.isEmpty) {
      return state.categories;
    }

    // Filtrelenmiş place'lerdeki kategori ID'lerini topla
    final categoryIdsInResults = filteredPlaces
        .where((place) => place.categoryId != null)
        .map((place) => place.categoryId!.toString())
        .toSet();

    // "Tümü" kategorisini her zaman göster
    final filtered = state.categories.where((category) {
      if (category.id == 'all' || category.label == 'Tümü') {
        return true;
      }
      // Kategori ID'si sonuçlarda varsa göster
      return categoryIdsInResults.contains(category.id);
    }).toList();

    return filtered;
  }

  /// Rota sorgusu (`?category=`) — kategoriler yüklendikçe veya sayfa açılınca
  void applyRouteCategorySlug(String? slug) {
    if (slug == null || slug.trim().isEmpty) {
      _pendingRouteCategorySlug = null;
      return;
    }
    _pendingRouteCategorySlug = slug.trim();
    _tryApplyPendingRouteCategorySlug();
  }

  void _tryApplyPendingRouteCategorySlug() {
    final slug = _pendingRouteCategorySlug;
    if (slug == null || slug.isEmpty) return;
    if (state.categories.length <= 1) return;

    final id = _resolveRouteSlugToCategoryId(slug);
    if (id == null) return;

    _pendingRouteCategorySlug = null;
    setCategory(id);
  }

  String? _resolveRouteSlugToCategoryId(String slug) {
    final normalized = slug.toLowerCase().replaceAll('-', '_');
    for (final cat in state.categories) {
      if (cat.id == 'all' || cat.label == 'Tümü') continue;
      final cs = cat.slug?.toLowerCase().replaceAll('-', '_');
      if (cs != null && cs.isNotEmpty && cs == normalized) {
        return cat.id;
      }
    }

    final matcher = switch (normalized) {
      'health_tourism' => isHealthTourismCategory,
      'discover_samsun' => isDiscoverSamsunCategory,
      'gastronomy' => isGastronomyCategory,
      'historical_museums' => isHistoricalMuseumsCategory,
      'nature_parks' => isNatureParksCategory,
      'beaches' => isBeachesCategory,
      _ => null,
    };
    if (matcher != null) {
      for (final cat in state.categories) {
        if (matcher(cat)) return cat.id;
      }
    }
    return null;
  }

  /// Kategori değiştir (client-side filtreleme)
  void setCategory(String categoryId) {
    if (state.selectedCategory == categoryId) return;
    state = state.copyWith(selectedCategory: categoryId);
    
    // Eğer place'ler yüklenmemişse API'den çek, yoksa sadece filtrele
    if (state.allPlaces.isEmpty) {
      loadPlaces(refresh: false);
    } else {
      _applyFilters();
    }
  }

  /// Arama yap (client-side filtreleme)
  void search(String query) {
    state = state.copyWith(searchQuery: query);
    _applyFilters();
  }

  /// Arama temizle
  void clearSearch() {
    state = state.copyWith(searchQuery: '');
    _applyFilters();
  }

  /// §6.4.5 — Place'leri seçili [PlaceSortMode]'a göre sırala.
  List<Place> _sortPlaces(List<Place> places) {
    final sorted = List<Place>.of(places);
    switch (state.sortMode) {
      case PlaceSortMode.name:
        sorted.sort((a, b) => _byName(a, b));
        return sorted;

      case PlaceSortMode.popularity:
        // Ziyaret sayısı ↓, eşitlikte puan ↓, sonra isim. Veri yoksa sona.
        sorted.sort((a, b) {
          final byVisit = (b.visitCount ?? 0).compareTo(a.visitCount ?? 0);
          if (byVisit != 0) return byVisit;
          final byRating = (b.rating ?? 0).compareTo(a.rating ?? 0);
          if (byRating != 0) return byRating;
          return _byName(a, b);
        });
        return sorted;

      case PlaceSortMode.nearest:
        // Mesafe ↑ (bilinmeyen mesafeler sona). Mesafe henüz hesaplanmadıysa
        // (distancesMeters boş) tetikleyici setSortMode'da çalışır.
        final d = state.distancesMeters;
        sorted.sort((a, b) {
          final da = d[a.id] ?? double.infinity;
          final db = d[b.id] ?? double.infinity;
          if (da != db) return da.compareTo(db);
          return _byName(a, b);
        });
        return sorted;

      case PlaceSortMode.recommended:
        // Gerçek öneri sıralaması (alfabetikten anlamlı şekilde FARKLI):
        //   öne çıkan (featured) + popülerlik (ziyaret sayısı) + kalite (puan).
        // Ziyaret sayısı log ile sönümlenir. Alfabetik yalnız son-çare tiebreak.
        double score(Place p) {
          final featuredBoost = p.featured ? 1000.0 : 0.0;
          final popularity = math.log(1 + (p.visitCount ?? 0)) * 8.0;
          final quality = (p.rating ?? 0) * 10.0;
          return featuredBoost + popularity + quality;
        }

        sorted.sort((a, b) {
          final byScore = score(b).compareTo(score(a));
          if (byScore != 0) return byScore;
          final byVisit = (b.visitCount ?? 0).compareTo(a.visitCount ?? 0);
          if (byVisit != 0) return byVisit;
          return _byName(a, b);
        });
        return sorted;
    }
  }

  int _byName(Place a, Place b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());

  /// §6.4.5 — Kullanıcı sıralama tercihini değiştirir ve listeyi yeniden uygular.
  /// `nearest` seçilip mesafeler henüz yoksa konum-bazlı hesabı tetikler;
  /// hesap bitince ([_calculateDistancesForAllPlaces]) liste otomatik yenilenir.
  void setSortMode(PlaceSortMode mode) {
    if (state.sortMode == mode) return;
    state = state.copyWith(sortMode: mode);
    if (mode == PlaceSortMode.nearest && state.distancesMeters.isEmpty) {
      _ensureNearestDistances();
    }
    _applyFilters();
  }

  /// §6.4.5 yakınlık — kullanıcı konumuna göre tüm yerlerin düz-çizgi
  /// (haversine) mesafesini hesaplar ve state'e yazar. OSRM-bağımsız ve anlık;
  /// sıralama için yön/yol gerekmez. İzin/servis yoksa durum işaretlenir
  /// (soğuk OS dialog'u tetiklemeden — §10.6.3).
  void _ensureNearestDistances() {
    Future.microtask(() async {
      try {
        if (!await LocationService.isLocationServiceEnabled()) {
          state = state.copyWith(locationStatus: LocationStatus.serviceDisabled);
          return;
        }
        final permission = await LocationService.checkPermission();
        if (permission == LocationPermission.denied) {
          state = state.copyWith(locationStatus: LocationStatus.permissionDenied);
          return;
        } else if (permission == LocationPermission.deniedForever) {
          state = state.copyWith(
              locationStatus: LocationStatus.permissionDeniedForever);
          return;
        }
        final origin = await LocationService.getCurrentLocation() ??
            await LocationService.getLastKnownLocation();
        if (origin == null) {
          state = state.copyWith(locationStatus: LocationStatus.error);
          return;
        }
        final map = <String, double>{};
        for (final p in state.allPlaces) {
          if (p.lat != null && p.lng != null) {
            map[p.id] = DistanceHelper.calculateHaversineDistance(
              origin,
              LatLng(p.lat!, p.lng!),
            );
          }
        }
        state = state.copyWith(
          distancesMeters: map,
          locationStatus: LocationStatus.available,
        );
        // Mesafeler geldi; kullanıcı hâlâ yakınlık modundaysa listeyi yenile.
        if (state.sortMode == PlaceSortMode.nearest) {
          _applyFilters();
        }
      } catch (e) {
        debugPrint('⚠️ [Places] Nearest distance calc failed: $e');
      }
    });
  }

  /// Filtreleme helper
  List<Place> _filterPlaces(List<Place> places, String query) {
    if (query.isEmpty) return places;

    final lowerQuery = query.toLowerCase();
    // Sıralama çağıran tarafta (_applyFilters) uygulanır.
    return places.where((place) {
      return place.name.toLowerCase().contains(lowerQuery) ||
          (place.description?.toLowerCase().contains(lowerQuery) ?? false) ||
          (place.category?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  /// Yenile
  Future<void> refresh() => loadPlaces(refresh: true);

  /// Sadece mesafeleri yeniden hesapla (API'den veri çekmeden).
  /// Sayfadan çıkıp tekrar girildiğinde güncel konuma göre
  /// distance değerlerini yenilemek için kullanılabilir.
  /// Throttle: places ekranına her girişte tetikleniyor, ama 60 saniye
  /// içinde tekrar OSRM Table API'sini bombardımana tutmak gereksiz.
  DateTime? _lastRecalcAt;
  static const Duration _kMinRecalcInterval = Duration(seconds: 60);

  void recalculateDistances({bool force = false}) {
    if (state.allPlaces.isEmpty) return;
    // `force`: konum izni yeni verildiğinde throttle'ı atla — kullanıcı izni
    // onayladıktan hemen sonra mesafeler beklemeden hesaplansın.
    if (!force &&
        _lastRecalcAt != null &&
        DateTime.now().difference(_lastRecalcAt!) < _kMinRecalcInterval) {
      return;
    }
    _lastRecalcAt = DateTime.now();
    _calculateDistancesForAllPlaces(state.allPlaces);
  }

  /// Mobile API'den (System B) puan bilgilerini çeker,
  /// mevcut place listesine merge eder (points, visited, visit_count, externalId),
  /// ve [PlaceIdResolver]'ı populate eder.
  ///
  /// Backend auth-optional: token yokken public data (points),
  /// token varken full data (+ visited, claimed, last_visited_at) döner.
  void _enrichWithMobilePoints(List<Place> currentPlaces) {
    if (_enrichInFlight) {
      debugPrint('⏭️ [Places] Skipping _enrichWithMobilePoints — already in flight');
      return;
    }
    _enrichInFlight = true;
    final notifierRef = ref;

    Future.microtask(() async {
      try {

        final discovery = notifierRef.read(discoveryServiceProvider);

        // Mobile API'den tüm yerleri çek (pagination ile)
        final mobilePlaces = <String, Map<String, dynamic>>{};
        final resolverItems = <Map<String, dynamic>>[];
        int page = 1;
        bool hasMore = true;

        while (hasMore) {
          final result = await discovery.getPlaces(page: page, limit: 100);
          final data = result['data'] as List? ?? [];

          for (final item in data) {
            final map = item as Map<String, dynamic>;
            final id = map['id']?.toString();
            if (id != null) {
              mobilePlaces[id] = map;
              resolverItems.add(map);
            }
          }

          final pagination = result['pagination'] as Map<String, dynamic>?;
          final totalPages = pagination?['totalPages'] as int? ?? 1;
          hasMore = page < totalPages;
          page++;

          if (page > 50) break;
        }

        // Populate PlaceIdResolver with gamification↔CMS ID mappings
        if (resolverItems.isNotEmpty) {
          notifierRef.read(placeIdResolverProvider.notifier).populate(resolverItems);
        }

        if (mobilePlaces.isEmpty) return;

        // Build a reverse lookup: externalId → gamification map
        // so CMS-sourced places (whose id = CMS ID) can also be matched.
        final byExternalId = <String, Map<String, dynamic>>{};
        for (final map in mobilePlaces.values) {
          final extId = map['external_id']?.toString();
          if (extId != null) {
            byExternalId[extId] = map;
          }
        }

        // Mevcut place listesini enrich et (kampanya bazlı puan sistemi dahil)
        final enriched = state.allPlaces.map((place) {
          // Match by gamification ID first, then by CMS external_id
          final mobile = mobilePlaces[place.id] ?? byExternalId[place.id];
          if (mobile == null) return place;

          final points = mobile['points'] as int?;
          final visited = mobile['visited'] == true;
          final claimed = mobile['claimed'] == true;
          final visitCount = mobile['visit_count'] as int?;
          final lastVisitedAt = mobile['last_visited_at'] != null
              ? DateTime.tryParse(mobile['last_visited_at'] as String)
              : null;
          final campaignJson = mobile['campaign'] as Map<String, dynamic>?;
          final campaign = campaignJson != null
              ? CampaignMeta.fromJson(campaignJson)
              : null;
          final mobileExternalId = mobile['external_id']?.toString();
          final gamificationId = mobile['id']?.toString();

          if (points == null && !visited && !claimed) {
            // Still carry the externalId even if no points data
            if (mobileExternalId != null && place.externalId == null) {
              return place.copyWith(externalId: mobileExternalId);
            }
            return place;
          }

          return place.copyWith(
            id: gamificationId ?? place.id,
            externalId: mobileExternalId ?? place.externalId,
            points: points ?? place.points,
            visited: visited,
            claimed: claimed,
            visitCount: visitCount ?? place.visitCount,
            lastVisitedAt: lastVisitedAt ?? place.lastVisitedAt,
            campaign: campaign,
          );
        }).toList();

        state = state.copyWith(allPlaces: enriched);
        _applyFilters();
      } catch (e) {
        debugPrint('⚠️ [Places] Points enrichment failed: $e');
      } finally {
        _enrichInFlight = false;
      }
    });
  }

  /// TÜM yerlerin mesafesini tek seferde hesapla
  /// OSRM Table API tek istekte tüm mesafeleri döndürür - lazy loading'e gerek yok
  /// CACHE-AWARE: Sadece henüz hesaplanmamış yerler için OSRM çağrısı yapar
  void _calculateDistancesForAllPlaces(List<Place> places) {
    // ref'i capture et (async işlem için)
    final notifierRef = ref;
    
    // Background'da çalıştır - UI'ı bloklamaz
    Future.microtask(() async {
      try {
        // Önce cache'i kontrol et - zaten hesaplanmış olanları atla
        final existingDistances = notifierRef.read(placeDistancesProvider);
        final placesNeedingCalculation = places.where((p) => 
          !existingDistances.containsKey(p.id) && 
          p.lat != null && 
          p.lng != null
        ).toList();
        
        if (placesNeedingCalculation.isEmpty) return;
        // Önce konum servislerini ve izinleri kontrol et
        final serviceEnabled = await LocationService.isLocationServiceEnabled();
        if (!serviceEnabled) {
          state = state.copyWith(locationStatus: LocationStatus.serviceDisabled);
          return;
        }

        final permission = await LocationService.checkPermission();
        if (permission == LocationPermission.denied) {
          // §10.6.3 — açıklama göstermeden soğuk OS konum dialog'u TETİKLEME.
          // Burada yalnız durum işaretlenir; kullanıcı izni açıklayıcı
          // DiscoveryLocationCta veya harita "konumum" butonundan verir.
          state =
              state.copyWith(locationStatus: LocationStatus.permissionDenied);
          return;
        } else if (permission == LocationPermission.deniedForever) {
          state = state.copyWith(locationStatus: LocationStatus.permissionDeniedForever);
          return;
        }

        // Kullanıcı konumunu al
        final userLocation = await LocationService.getCurrentLocation() ??
            await LocationService.getLastKnownLocation();
        if (userLocation == null) {
          state = state.copyWith(locationStatus: LocationStatus.error);
          return;
        }
        
        // Konum başarıyla alındı
        state = state.copyWith(locationStatus: LocationStatus.available);

        // Sadece hesaplanmamış yerleri topla
        final placesWithLocation = <String, LatLng>{};
        for (final place in placesNeedingCalculation) {
          placesWithLocation[place.id] = LatLng(place.lat!, place.lng!);
        }

        // OSRM Table API ile tek seferde TÜM mesafeleri hesapla
        final allDistances = await DistanceHelper.calculateDistancesForPlaces(
          origin: userLocation,
          places: placesWithLocation,
          useHaversineFallback: true,
        );

        // PERFORMANS: Toplu güncelleme — tek seferde tek rebuild
        // Eski: 280x updateDistance() = 280 map copy + 280 rebuild
        // Yeni: 1x updateAllDistances() = 1 map merge + 1 rebuild
        final formattedDistances = <String, String>{};
        for (final entry in allDistances.entries) {
          formattedDistances[entry.key] = DistanceHelper.formatDistance(entry.value);
        }
        notifierRef.read(placeDistancesProvider.notifier).updateAllDistances(formattedDistances);
      } catch (e) {
        debugPrint('⚠️ [Places] Error calculating distances: $e');
      }
    });
  }

}

/// Provider
final placesProvider = NotifierProvider<PlacesNotifier, PlacesState>(
  PlacesNotifier.new,
);

// ============================================================================
// ANA SAYFA İÇİN OPTİMİZE EDİLMİŞ PROVIDER
// Tüm mekanları yüklemek yerine sadece öne çıkan mekanları çeker (~%80 daha az veri)
// ============================================================================

/// Featured places provider (ana sayfa için optimize)
/// Bu ayrı API çağrısı yapıyor - /places/featured endpoint'ini kullanır
/// Ana sayfa tüm mekanları (280+) beklemek zorunda kalmaz
final featuredPlacesProvider = FutureProvider.autoDispose<List<Place>>((ref) async {
  final repository = ref.watch(placeRepositoryProvider);
  
  // PERFORMANS: Sadece languageCode değiştiğinde rebuild
  ref.watch(localeProvider.select((s) => s.locale.languageCode));

  try {
    final response = await repository.getFeaturedPlaces(limit: 20);
    if (response.status && response.data != null) {
      return response.data!;
    }
    return [];
  } catch (e) {
    debugPrint('❌ [featuredPlacesProvider] Error: $e');
    return [];
  }
});

/// Featured places için kategori bilgisi ile birlikte döner
/// Home screen'de kategori label'ları göstermek için kullanılır
/// 
/// PERFORMANCE OPTIMIZATION: API calls are parallelized using Future.wait
/// to reduce startup time by ~50%
final featuredPlacesWithCategoriesProvider = FutureProvider.autoDispose<List<Place>>((ref) async {
  final repository = ref.watch(placeRepositoryProvider);
  
  // PERFORMANS: Sadece languageCode değiştiğinde rebuild
  ref.watch(localeProvider.select((s) => s.locale.languageCode));

  try {
    // ============================================================================
    // OPTIMIZATION: Fetch categories and featured places IN PARALLEL
    // Previously: await getCategories() THEN await getFeaturedPlaces() (~1.5s)
    // Now: Future.wait([getCategories(), getFeaturedPlaces()]) (~0.8s)
    // ============================================================================
    final results = await Future.wait([
      repository.getCategories().catchError((e) {
        debugPrint('⚠️ [featuredPlacesWithCategoriesProvider] Categories failed: $e');
        return ApiResponse<List<PlaceCategory>>(
          status: false,
          message: e.toString(),
          data: <PlaceCategory>[],
        );
      }),
      repository.getFeaturedPlaces(limit: 20).catchError((e) {
        debugPrint('⚠️ [featuredPlacesWithCategoriesProvider] Featured places failed: $e');
        return ApiResponse<List<Place>>(
          status: false,
          message: e.toString(),
          data: <Place>[],
        );
      }),
    ]);
    
    // Extract results from parallel calls
    final categoriesResponse = results[0] as ApiResponse<List<PlaceCategory>>;
    final featuredResponse = results[1] as ApiResponse<List<Place>>;
    
    // Build categories map
    Map<int, PlaceCategory> categoriesMap = {};
    if (categoriesResponse.status && categoriesResponse.data != null) {
      for (var cat in categoriesResponse.data!) {
        final catId = int.tryParse(cat.id);
        if (catId != null) {
          categoriesMap[catId] = cat;
        }
      }
    }

    // Get featured places
    List<Place> featuredPlaces = [];
    if (featuredResponse.status && featuredResponse.data != null) {
      featuredPlaces = featuredResponse.data!;
    }

    if (featuredPlaces.isEmpty) return [];
    
    // Place'lerin category bilgisini resolve et
    final placesWithCategories = featuredPlaces.map((place) {
      if (place.categoryId != null && categoriesMap.containsKey(place.categoryId)) {
        final category = categoriesMap[place.categoryId]!;
        return place.copyWith(category: category.label);
      }
      return place;
    }).toList();
    
    // Featured places için mesafeleri hesapla (background'da)
    // CACHE-AWARE: Sadece henüz hesaplanmamış yerler için OSRM çağrısı yapar
    _calculateFeaturedDistances(ref, placesWithCategories);

    return placesWithCategories;
  } catch (e) {
    debugPrint('❌ [featuredPlacesWithCategoriesProvider] Error: $e');
    return [];
  }
});

/// Featured places için mesafe hesaplama (background'da çalışır)
/// CACHE-AWARE: Sadece henüz hesaplanmamış yerler için OSRM çağrısı yapar
void _calculateFeaturedDistances(Ref ref, List<Place> places) {
  // Background'da çalıştır - UI'ı bloklamaz
  Future.microtask(() async {
    try {
      // Önce cache'i kontrol et - zaten hesaplanmış olanları atla
      final existingDistances = ref.read(placeDistancesProvider);
      final placesNeedingCalculation = places.where((p) => 
        !existingDistances.containsKey(p.id) && 
        p.lat != null && 
        p.lng != null
      ).toList();
      
      if (placesNeedingCalculation.isEmpty) return;

      // Konum servislerini kontrol et
      final serviceEnabled = await LocationService.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      final permission = await LocationService.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      // Kullanıcı konumunu al
      final userLocation = await LocationService.getCurrentLocation() ??
          await LocationService.getLastKnownLocation();
      if (userLocation == null) return;

      // Sadece hesaplanmamış yerleri topla
      final placesWithLocation = <String, LatLng>{};
      for (final place in placesNeedingCalculation) {
        placesWithLocation[place.id] = LatLng(place.lat!, place.lng!);
      }

      // OSRM Table API ile mesafeleri hesapla
      final allDistances = await DistanceHelper.calculateDistancesForPlaces(
        origin: userLocation,
        places: placesWithLocation,
        useHaversineFallback: true,
      );

      // PERFORMANS: Toplu güncelleme — tek seferde tek rebuild
      final formattedDistances = <String, String>{};
      for (final entry in allDistances.entries) {
        formattedDistances[entry.key] = DistanceHelper.formatDistance(entry.value);
      }
      ref.read(placeDistancesProvider.notifier).updateAllDistances(formattedDistances);
    } catch (e) {
      debugPrint('⚠️ [FeaturedDistances] Error calculating distances: $e');
    }
  });
}

// Place detail provider artık place_detail_provider.dart'da