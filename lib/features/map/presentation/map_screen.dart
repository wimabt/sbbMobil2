import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' hide RouteData;
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/services/analytics_events.dart';
import '../../../core/services/analytics_service.dart';

import '../../../core/services/osrm_service.dart';
import '../../../core/utils/distance_helper.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/providers/user_location_provider.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/widgets/cached_image.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/map_heatmap_repository.dart';
import '../../../data/repositories/place_repository.dart';
import '../../places/presentation/providers/place_detail_provider.dart';
import '../../places/presentation/providers/places_provider.dart';
import 'models/map_place.dart';
import 'providers/map_camera_provider.dart';
import 'providers/route_navigation_provider.dart';
import 'providers/route_intent_provider.dart';
import 'providers/route_places_on_route_only_intent_provider.dart';
import '../../../core/utils/subcategory_labels.dart';
import 'utils/map_cluster_manager.dart';
import 'utils/map_styles.dart';
import 'utils/marker_builder.dart';
import 'widgets/widgets.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  /// Alt kategori filtresi görünüm varyantı (karşılaştırma için iki
  /// uygulama da kodda mevcut):
  /// * `false` (aktif): kategori chip'lerinin altında yatay alt kategori
  ///   chip satırı.
  /// * `true`: arama yanındaki liste butonu, alt kategori varken filtre
  ///   butonuna dönüşür ve bottom sheet açar (liste butonu o sırada gizlenir).
  static const bool _kSubcategoryFilterAsButton = false;

  GoogleMapController? _mapController;
  String? _mapError;
  String? _selectedCategory;
  // Alt kategori filtresi — seçili kategorinin alt kategori slug'ları.
  // Çoklu seçim: kullanıcı "Müzeler" + "Ören Yerleri" gibi birden fazla
  // alt kategoriyi aynı anda işaretleyebilir. Boş küme = alt kategori
  // filtresi yok (kategorinin tamamı gösterilir).
  final Set<String> _selectedSubcategorySlugs = {};
  String _searchQuery = ''; // Arama sorgusu

  static const LatLng _defaultCenter = LatLng(41.2867, 36.3300);
  static const double _defaultZoom = 13.0;

  List<PlaceCategory> _categories = [];
  List<MapPlace> _allMapPlaces = []; // Tüm place'ler (filtrelenmemiş)
  List<MapPlace> _mapPlaces = []; // Filtrelenmiş place'ler
  Set<Marker> _markers = {};
  MapClusterManager<MapPlace>? _clusterManager;
  bool _isLoadingPlaces = false;
  bool _isUpdatingMarkers = false;
  CameraPosition? _currentCameraPosition;
  // PERFORMANS: Debounce timer — kamera her durduğunda değil,
  // 300ms sessizlik sonrası marker'ları güncelle
  Timer? _cameraIdleTimer;
  MapPlace? _selectedPlace;
  // Store clusters for tap handling
  final Map<String, MapCluster<MapPlace>> _clusterMap = {};
  // Modal yüksekliğini ölçmek için
  final GlobalKey _modalKey = GlobalKey();
  double _modalHeight = 0;
  // Tema değişikliği takibi
  Brightness? _previousBrightness;
  // User location
  LatLng? _userLocation;
  // _didMoveToUserLocation is now tracked in mapCameraProvider (session-scoped).

  /// dispose() içinde `ref` kullanılamaz; kamera kalıcılığı için notifier burada tutulur.
  late final MapCameraNotifier _mapCameraNotifier;

  // Route polylines drawn on the map (OSRM navigation)
  Set<Polyline> _polylines = {};

  // Route-based marker filtering (UX: "Places on Route")
  bool _showPlacesOnRouteOnly = false;

  // Track last route to avoid repeated auto-zoom on theme rebuilds
  int _lastRoutePointCount = 0;
  LatLng? _lastRouteStart;
  LatLng? _lastRouteEnd;

  // Route intent guard (prevents repeated triggers on rebuild)
  LatLng? _lastHandledIntentDestination;

  // Language tracking for category reload
  String? _lastLanguageCode;

  // Prevents re-applying the "auto-enable places on route" intent
  // multiple times for the same route.
  String? _lastAutoPlacesOnRouteKey;

  // ── `mobile_pending_changes.md` B4 — Isı haritası (opsiyonel feature) ─────
  // google_maps_flutter 2.10+ native Heatmap renderer (iOS: CAEmitterLayer,
  // Android: HeatmapTileProvider) kullanır — L.heatLayer-benzeri görsel.
  bool _heatmapEnabled = false;
  Set<Heatmap> _heatmaps = const {};
  Timer? _heatmapFetchDebounce;
  bool _heatmapFetchInFlight = false;

  @override
  void initState() {
    super.initState();
    _mapCameraNotifier = ref.read(mapCameraProvider.notifier);
    _loadPlaces();
    _initUserLocation();

    // mobile_analytics_todo.md §2.7 — map_opened
    ref.read(analyticsServiceProvider).track(AnalyticsEvents.mapOpened);
  }

  Future<void> _initUserLocation() async {
    final location = await ref.read(userLocationProvider.notifier).getOrFetch();
    if (!mounted) return;
    if (location == null) return;

    setState(() => _userLocation = location);

    // Move camera to user location only ONCE per entire app session.
    // After that, the user returns to whatever region they were exploring.
    if (!mounted) return;
    final cameraState = ref.read(mapCameraProvider);
    if (_mapController != null && !cameraState.didInitialMoveToUser) {
      _mapCameraNotifier.markInitialMoveDone();
      if (!mounted) return;
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(location, _defaultZoom),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentBrightness = Theme.of(context).brightness;
    if (_previousBrightness != null && _previousBrightness != currentBrightness) {
      // Tema değişti, marker'ları yeniden oluştur
      _isUpdatingMarkers = false; // Reset flag to allow update
      _updateMarkers();
    }
    _previousBrightness = currentBrightness;
  }

  Future<void> _loadPlaces({bool refreshCategories = false}) async {
    if (_isLoadingPlaces) return;
    setState(() => _isLoadingPlaces = true);

    try {
      // Get current language
      final currentLanguageCode = ref.read(localeProvider).locale.languageCode;
      final isTr = currentLanguageCode == 'tr';
      final allCategoryLabel = isTr ? context.l10n.lblAll : 'All';
      
      // Önce placesProvider'dan cache'lenmiş verileri kontrol et
      final placesState = ref.read(placesProvider);
      
      // Kategorileri placesProvider'dan al veya API'den çek
      // Eğer dil değiştiyse veya refreshCategories true ise API'den çek
      final shouldReloadCategories = refreshCategories || 
          _lastLanguageCode == null || 
          _lastLanguageCode != currentLanguageCode;
      
      if (!shouldReloadCategories && 
          placesState.categories.isNotEmpty && 
          placesState.categories.length > 1) {
        // placesProvider'dan kategorileri kullan (aynı dilde)
        if (mounted) {
          setState(() {
            _categories = placesState.categories;
          });
        }
      } else {
        // Kategorileri API'den çek (dil parametresi ile)
        final repository = ref.read(placeRepositoryProvider);
        final categoriesResponse = await repository.getCategories(lang: currentLanguageCode);
        if (categoriesResponse.status && categoriesResponse.data != null) {
          if (mounted) {
            setState(() {
              _categories = [
                PlaceCategory(id: 'all', label: allCategoryLabel),
                ...categoriesResponse.data!,
              ];
              _lastLanguageCode = currentLanguageCode;
            });
            // Kategoriler güncellendi, mevcut place'lerin kategori etiketlerini güncelle
            _remapPlaceCategories();
          }
        } else {
          if (mounted) {
            setState(() {
              _categories = [
                PlaceCategory(id: 'all', label: allCategoryLabel),
              ];
              _lastLanguageCode = currentLanguageCode;
            });
            // Kategoriler güncellendi, mevcut place'lerin kategori etiketlerini güncelle
            _remapPlaceCategories();
          }
        }
      }

      List<MapPlace> allMapPlaces = [];

      // placesProvider'dan cache'lenmiş verileri kullan
      if (placesState.allPlaces.isNotEmpty) {
        // Global mesafe haritasını kullan
        final distances = ref.read(placeDistancesProvider);

        allMapPlaces = placesState.allPlaces
            .where((place) => place.lat != null && place.lng != null)
            .map((place) {
          // Kategori bilgilerini bul
          String? categorySlug;
          String? categoryIcon;
          String? categoryId;
          String? categoryLabel;
          if (place.categoryId != null) {
            categoryId = place.categoryId.toString();
            final category = _categories.firstWhere(
              (cat) => cat.id == categoryId,
              orElse: () => const PlaceCategory(id: '', label: ''),
            );
            categorySlug = category.slug;
            categoryIcon = category.icon;
            categoryLabel = category.id.isNotEmpty ? category.label : null;
          }

          return MapPlace(
            id: place.cmsContentId,
            title: place.name,
            description: place.description,
            category: categoryLabel,
            categoryId: categoryId,
            categorySlug: categorySlug,
            categoryIcon: categoryIcon,
            rating: place.rating ?? 0.0, // Rating eksikse 0.0 kullan
            distance: distances[place.cmsContentId] ?? distances[place.id] ?? place.distance ?? '',
            address: place.address ?? '',
            position: LatLng(place.lat!, place.lng!),
            imageUrl: place.imageUrl,
            // Alt kategori filtresi — ham API değerleri kanonik slug'a çevrilir
            // (CMS bazen slug yerine "Sivil Yapılar" gibi ham ad döndürüyor).
            subcategories: place.subcategories
                .map(SubcategoryLabels.canonicalSlug)
                .where((s) => s.isNotEmpty)
                .toList(),
          );
        }).toList();
      } else {
        // Cache'de veri yoksa API'den çek (fallback)
        final repository = ref.read(placeRepositoryProvider);
        final currentLanguageCode = ref.read(localeProvider).locale.languageCode;
        
        int currentPage = 1;
        bool hasMore = true;
        const pageLimit = 100;
        // ── ESKİ (alt kategori filtresi öncesi) — geri dönüş için saklandı ──
        // const mapFields = 'id,name,category_id,category,description,address,lat,lng,image_url,thumbnail_url,rating,review_count,featured';
        const mapFields = 'id,name,category_id,category,subcategories,description,address,lat,lng,image_url,thumbnail_url,rating,review_count,featured';

        while (hasMore) {
          final placesResponse = await repository.getPlaces(
            category: null,
            page: currentPage,
            limit: pageLimit,
            fields: mapFields,
            lang: currentLanguageCode,
          );

          if (!mounted) return;

          if (placesResponse.status &&
              placesResponse.data != null &&
              placesResponse.data!.isNotEmpty) {
            final distances = ref.read(placeDistancesProvider);

            allMapPlaces.addAll(
              placesResponse.data!
                  .where((place) => place.lat != null && place.lng != null)
                  .map((place) {
                String? categorySlug;
                String? categoryIcon;
                String? categoryId;
                String? categoryLabel;
                if (place.categoryId != null) {
                  categoryId = place.categoryId.toString();
                  final category = _categories.firstWhere(
                    (cat) => cat.id == categoryId,
                    orElse: () => const PlaceCategory(id: '', label: ''),
                  );
                  categorySlug = category.slug;
                  categoryIcon = category.icon;
                  categoryLabel = category.id.isNotEmpty ? category.label : null;
                }

                return MapPlace(
                  id: place.cmsContentId,
                  title: place.name,
                  description: place.description,
                  category: categoryLabel,
                  categoryId: categoryId,
                  categorySlug: categorySlug,
                  categoryIcon: categoryIcon,
                  rating: place.rating ?? 0.0,
                  distance: distances[place.cmsContentId] ?? distances[place.id] ?? place.distance ?? '',
                  address: place.address ?? '',
                  position: LatLng(place.lat!, place.lng!),
                  imageUrl: place.imageUrl,
                  // Alt kategori filtresi — kanonik slug'lar (yukarıdaki
                  // cache'li yol ile aynı normalize kuralı).
                  subcategories: place.subcategories
                      .map(SubcategoryLabels.canonicalSlug)
                      .where((s) => s.isNotEmpty)
                      .toList(),
                );
              }),
            );

            hasMore = placesResponse.meta?.hasNext ?? false;
            currentPage++;
          } else {
            hasMore = false;
          }

          if (currentPage > 100) {
            hasMore = false;
          }
        }
      }

      if (mounted) {
        setState(() {
          _allMapPlaces = allMapPlaces;
        });

        _applyFilters();
      }
    } catch (e) {
      debugPrint('❌ [MapScreen] Error loading places: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingPlaces = false);
      }
    }
  }


  void _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;

    if (mounted) {
      setState(() {
        _mapError = null;
      });
      // Google Maps başarıyla yüklendi
      
      // İlk marker güncellemesi
      if (_mapPlaces.isNotEmpty) {
        _updateMarkers();
      }
    }

    // If we already have a cached user location, center once per app session.
    final cameraState = ref.read(mapCameraProvider);
    if (!cameraState.didInitialMoveToUser) {
      final cached = ref.read(userLocationProvider);
      if (cached != null) {
        _mapCameraNotifier.markInitialMoveDone();
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(cached, _defaultZoom),
        );
      }
    }
  }

  void _onCameraMove(CameraPosition position) {
    _currentCameraPosition = position;
    _clusterManager?.onCameraMove(position);
    // Persist camera position so it survives tab switches.
    _mapCameraNotifier.savePosition(position);
  }

  /// PERFORMANS: 300ms debounce ile marker güncelleme.
  /// Kullanıcı hızlıca zoom/pan yaparken her _onCameraIdle çağrısında
  /// marker'ları yeniden render etmek yerine, 300ms bekleyip son durumda
  /// tek bir güncelleme yapar. Bu sayede gereksiz bitmap rendering engellenir.
  Future<void> _onCameraIdle() async {
    if (_mapController == null || _clusterManager == null) return;

    // Önceki timer'ı iptal et (debounce)
    _cameraIdleTimer?.cancel();
    _cameraIdleTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted || _mapController == null || _clusterManager == null) return;
      try {
        final bounds = await _mapController!.getVisibleRegion();
        _clusterManager!.setVisibleBounds(bounds);
        _updateMarkers();

        // `mobile_pending_changes.md` B4 — heatmap aktifse görünür bölge için
        // taze veri çek. Repository 5dk cache'liyor; aynı bbox tekrar fetch
        // etmez. Cluster update ile aynı debounce penceresinde çalışıyor.
        if (_heatmapEnabled) {
          _scheduleHeatmapFetch(bounds);
        }
      } catch (e) {
        debugPrint('❌ [MapScreen] Error getting visible region: $e');
      }
    });
  }

  // ─── Heatmap (B4) ─────────────────────────────────────────────────────────

  void _scheduleHeatmapFetch(LatLngBounds bounds) {
    _heatmapFetchDebounce?.cancel();
    _heatmapFetchDebounce = Timer(const Duration(milliseconds: 200), () {
      _fetchHeatmap(bounds);
    });
  }

  Future<void> _fetchHeatmap(LatLngBounds bounds) async {
    if (_heatmapFetchInFlight || !mounted) return;
    _heatmapFetchInFlight = true;
    try {
      final bbox = '${bounds.southwest.latitude.toStringAsFixed(5)},'
          '${bounds.southwest.longitude.toStringAsFixed(5)},'
          '${bounds.northeast.latitude.toStringAsFixed(5)},'
          '${bounds.northeast.longitude.toStringAsFixed(5)}';
      // Son 14 gün — backend opsiyonel, kapsam darsa daha taze sayı çıkar.
      final since = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 14))
          .toIso8601String();

      final points = await ref
          .read(mapHeatmapRepositoryProvider)
          .getHeatmap(bbox: bbox, since: since);

      if (!mounted || !_heatmapEnabled) return;
      setState(() {
        _heatmaps = _buildHeatmaps(points);
      });
    } finally {
      _heatmapFetchInFlight = false;
    }
  }

  /// `HeatmapPoint` listesinden Google Maps native `Heatmap` overlay'i üret.
  /// Native renderer kendi smoothing/blending'ini yapar — L.heatLayer'a
  /// yakın görsel kalitesi. Tüm noktalar tek `Heatmap` örneğinde toplanır.
  Set<Heatmap> _buildHeatmaps(List<HeatmapPoint> points) {
    if (points.isEmpty) return const {};

    // Weight'leri 0-1 normalize et (max baseline) — relative intensity.
    final maxWeight = points
        .map((p) => p.weight)
        .reduce((a, b) => a > b ? a : b)
        .clamp(0.0001, double.infinity);

    final data = points.map((p) {
      final norm = (p.weight / maxWeight).clamp(0.0, 1.0);
      return WeightedLatLng(LatLng(p.lat, p.lng), weight: norm);
    }).toList(growable: false);

    return {
      Heatmap(
        heatmapId: const HeatmapId('places_popularity'),
        data: data,
        // L.heatLayer benzeri yeşil → sarı → kırmızı gradient.
        gradient: HeatmapGradient(
          const [
            HeatmapGradientColor(Color(0x0066BB6A), 0.0),  // şeffaf yeşil
            HeatmapGradientColor(Color(0xFF66BB6A), 0.25), // yeşil
            HeatmapGradientColor(Color(0xFFFFEB3B), 0.5),  // sarı
            HeatmapGradientColor(Color(0xFFFB8C00), 0.75), // turuncu
            HeatmapGradientColor(Color(0xFFE53935), 1.0),  // kırmızı
          ],
        ),
        // Piksel cinsinden yarıçap; zoom'dan bağımsız sabit yumuşaklık.
        radius: HeatmapRadius.fromPixels(40),
        opacity: 0.7,
      ),
    };
  }

  Future<void> _toggleHeatmap() async {
    // Kullanıcı manuel basıyorsa cooldown'u temizle — backend deploy edilmiş
    // olabilir, tekrar denemeye değer.
    final repo = ref.read(mapHeatmapRepositoryProvider);
    repo.resetAvailability();

    final willEnable = !_heatmapEnabled;

    setState(() {
      _heatmapEnabled = willEnable;
      if (!_heatmapEnabled) _heatmaps = const {};
    });

    if (willEnable) {
      // Pinler gizlendi — kullanıcı bilsin. Kısa, müdahaleci olmayan snackbar.
      _showHeatmapModeSnackBar(enabled: true);

      if (_mapController != null) {
        try {
          final bounds = await _mapController!.getVisibleRegion();
          await _fetchHeatmap(bounds);

          // Fetch sonrası endpoint hâlâ 404 veriyorsa toggle'ı kapat.
          if (!mounted) return;
          if (repo.isEndpointUnavailable) {
            setState(() {
              _heatmapEnabled = false;
              _heatmaps = const {};
            });
            _showHeatmapUnavailableMessage();
            // Pinleri geri yükle
            _updateMarkers();
          }
        } catch (e) {
          debugPrint('❌ [MapScreen] Heatmap toggle fetch failed: $e');
        }
      }
    } else {
      // Heatmap kapatıldı — pinler geri gelsin.
      _updateMarkers();
    }
  }

  void _showHeatmapModeSnackBar({required bool enabled}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled
              ? 'Yoğunluk görünümü aktif — pinler için butonu tekrar bas.'
              : 'Pinler geri geldi.',
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showHeatmapUnavailableMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Isı haritası şu an hazırlık aşamasında. Yakında aktif olacak.',
        ),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─── Heatmap tıklama → yakındaki yerler ───────────────────────────────

  /// Heatmap modu açıkken haritaya tıklandığında, o noktanın etrafındaki
  /// yerleri (300m yarıçap) Haversine ile bul, bottom sheet ile sun.
  ///
  /// Heatmap layer'ı doğrudan tıklanamadığı için (Google Maps SDK kısıtı),
  /// kullanıcı yoğun bir bölgeye tıkladığında oradaki POI'leri sıralı listede
  /// gösteriyoruz. Tap → detail navigation.
  static const int _kHeatmapTapMaxItems = 8;

  /// Tıklama anındaki zoom seviyesine göre dinamik tap yarıçapı.
  ///
  /// **Neden gerekli?** Sabit 300m yarıçap: yakın zoom'da çok kalabalık
  /// liste, uzak zoom'da çok seyrek sonuç verir. Kullanıcı görsel olarak
  /// hangi sıcak alana tıkladıysa sadece o alanı kapsayan yerleri
  /// listeleriz.
  ///
  /// Heatmap kendisi 40 piksel görsel yarıçap kullanıyor; biz 60 piksel
  /// (radius + 50% buffer) eşdeğeri metre hesaplıyoruz — kullanıcı parmak
  /// bastığı yerin etrafında hafif tolerans tanırız.
  Future<double> _computeHeatmapTapRadius(LatLng tapPosition) async {
    try {
      final zoom = await _mapController?.getZoomLevel();
      if (zoom == null) return 200.0;

      // Google Maps ground resolution formülü:
      //   meters/pixel = 156543.03392 * cos(lat) / 2^zoom
      final latRad = tapPosition.latitude * (math.pi / 180.0);
      final metersPerPixel =
          156543.03392 * math.cos(latRad) / math.pow(2, zoom);
      // 60 piksel ≈ heatmap görsel yarıçapı + buffer
      final dynamicRadius = metersPerPixel * 60;
      // 25m–500m arasında kıs — uç durumlarda absürd değer üretmesin.
      return dynamicRadius.clamp(25.0, 500.0);
    } catch (_) {
      return 200.0; // güvenli default
    }
  }

  Future<void> _onHeatmapTap(LatLng position) async {
    if (!mounted) return;
    final allPlaces = ref.read(placesProvider).allPlaces;
    if (allPlaces.isEmpty) return;

    final radius = await _computeHeatmapTapRadius(position);
    if (!mounted) return;

    final ranked = <({Place place, double distM})>[];
    for (final p in allPlaces) {
      if (p.lat == null || p.lng == null) continue;
      final d = DistanceHelper.calculateHaversineDistance(
        position,
        LatLng(p.lat!, p.lng!),
      );
      if (d <= radius) {
        ranked.add((place: p, distM: d));
      }
    }

    if (ranked.isEmpty) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.mapNoPlacesInArea),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ranked.sort((a, b) => a.distM.compareTo(b.distM));
    final shown = ranked.take(_kHeatmapTapMaxItems).toList();

    await Haptics.light();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _HeatmapNearbySheet(
        items: shown,
        radiusM: radius,
        onItemTap: (place) {
          Navigator.of(sheetCtx).pop();
          context.push('/places/${place.id}');
        },
      ),
    );
  }

  void _goToMyLocation() async {
    // Önce kullanıcı konumunu al (cached)
    _userLocation ??= await ref.read(userLocationProvider.notifier).getOrFetch();
    if (_userLocation != null && mounted) {
      ref.read(userLocationProvider.notifier).set(_userLocation!);
    }

    // Kullanıcı konumuna git veya varsayılan merkeze
    final targetLocation = _userLocation ?? _defaultCenter;
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(targetLocation, _defaultZoom),
    );
  }

  // ── ESKİ (alt kategori filtresi öncesi) — geri dönüş için saklandı ──
  // void _onCategorySelected(String category) {
  //   // Check if it's "All" category by ID or label (supports both languages)
  //   final isAllCategory = category == context.l10n.lblAll ||
  //                        category == 'All' ||
  //                        category == 'all';
  //   setState(() {
  //     _selectedCategory = isAllCategory ? null : category;
  //   });
  //   // Filtreleri uygula (kategori + arama)
  //   _applyFilters();
  // }
  void _onCategorySelected(String category) {
    // Check if it's "All" category by ID or label (supports both languages)
    final isAllCategory = category == context.l10n.lblAll ||
                         category == 'All' ||
                         category == 'all';
    setState(() {
      _selectedCategory = isAllCategory ? null : category;
      // Kategori değişince alt kategori seçimi anlamını yitirir — sıfırla.
      // (Aynı kategoriye tekrar basılması da temiz başlangıç sayılır.)
      _selectedSubcategorySlugs.clear();
    });
    // Filtreleri uygula (kategori + arama)
    _applyFilters();
  }

  /// Alt kategori chip'ine basıldığında toggle (çoklu seçim).
  void _onSubcategoryToggled(String slug) {
    setState(() {
      if (!_selectedSubcategorySlugs.remove(slug)) {
        _selectedSubcategorySlugs.add(slug);
      }
    });

    // mobile_analytics_todo.md §2.6 — filter_applied (places ekranı ile
    // aynı event; scope alt kategoriyi ayırt eder).
    ref.read(analyticsServiceProvider).track(
      AnalyticsEvents.filterApplied,
      properties: {'scope': 'map_subcategory', 'value': slug},
    );

    _applyFilters();
  }

  /// Tüm alt kategori seçimlerini temizle (bottom sheet "Temizle" butonu).
  void _onSubcategoriesCleared() {
    if (_selectedSubcategorySlugs.isEmpty) return;
    setState(() => _selectedSubcategorySlugs.clear());
    _applyFilters();
  }

  /// Arama sorgusu değiştiğinde çağrılır
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.trim();
    });
    // Filtreleri uygula (kategori + arama)
    _applyFilters();
  }

  /// Arama sorgusu submit edildiğinde çağrılır
  void _onSearchSubmitted(String query) {
    setState(() {
      _searchQuery = query.trim();
    });
    // Filtreleri uygula
    _applyFilters();
    
    // Eğer sonuç varsa, ilk sonuca zoom yap
    if (_mapPlaces.isNotEmpty && _mapController != null) {
      final firstPlace = _mapPlaces.first;
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(firstPlace.position, 15.0),
      );
    }
  }

  /// Tüm filtreleri uygula (kategori + arama)
  /// **NOT:** Tüm filtreleme LOCAL'de yapılır, API çağrısı YOK.
  /// `_allMapPlaces` listesi üzerinde client-side filtreleme yapılır.
  void _applyFilters() {
    if (_allMapPlaces.isEmpty) {
      // Henüz place'ler yüklenmemişse marker'ları güncelleme
      return;
    }

    // LOCAL filtreleme - API çağrısı yok
    final intent = ref.read(routePlacesOnRouteOnlyIntentProvider);
    final routePlaceIds = intent?.placeIds ?? const <String>{};
    final isStopsFilterActive =
        _showPlacesOnRouteOnly && routePlaceIds.isNotEmpty;

    List<MapPlace> filteredPlaces = List.from(_allMapPlaces);

    if (isStopsFilterActive) {
      // Stop filtresi aktifken sadece route duraklarını göster.
      filteredPlaces = filteredPlaces
          .where((place) => routePlaceIds.contains(place.id))
          .toList();
    } else {
      // 1. Kategori filtresi (local)
      if (_selectedCategory != null &&
          _selectedCategory != context.l10n.lblAll &&
          _selectedCategory != 'All') {
        final selectedCat = _categories.firstWhere(
          (cat) =>
              cat.label == _selectedCategory || cat.id == _selectedCategory,
          orElse: () => const PlaceCategory(id: '', label: ''),
        );

        if (selectedCat.id.isNotEmpty && selectedCat.id != 'all') {
          filteredPlaces = filteredPlaces.where((place) {
            return place.categoryId == selectedCat.id;
          }).toList();
          debugPrint(
              '🗺️ [MapScreen] Local category filter: ${filteredPlaces.length} places');

          // 1b. Alt kategori filtresi (local) — yalnızca bir kategori
          // seçiliyken anlamlı. Çoklu seçim OR mantığıyla çalışır:
          // seçili alt kategorilerden en az birine sahip place'ler kalır.
          if (_selectedSubcategorySlugs.isNotEmpty) {
            filteredPlaces = filteredPlaces.where((place) {
              return place.subcategories
                  .any(_selectedSubcategorySlugs.contains);
            }).toList();
            debugPrint(
                '🗺️ [MapScreen] Local subcategory filter: ${filteredPlaces.length} places');
          }
        }
      }

      // 2. Arama filtresi (local - Türkçe karakter desteği ile)
      if (_searchQuery.isNotEmpty) {
        final normalizedQuery =
            _normalizeTurkish(_searchQuery.toLowerCase());
        filteredPlaces = filteredPlaces.where((place) {
          // İsimde ara (Türkçe karakter desteği)
          final normalizedTitle =
              _normalizeTurkish(place.title.toLowerCase());
          final nameMatch = normalizedTitle.contains(normalizedQuery);

          // Kategori adında ara
          final normalizedCategory = place.category != null
              ? _normalizeTurkish(place.category!.toLowerCase())
              : '';
          final categoryMatch = normalizedCategory.contains(normalizedQuery);

          // Adreste ara
          final normalizedAddress =
              _normalizeTurkish(place.address.toLowerCase());
          final addressMatch = normalizedAddress.contains(normalizedQuery);

          return nameMatch || categoryMatch || addressMatch;
        }).toList();
      }
    }

    // 3. Route-based filter:
    //    - Primary: keep only places whose IDs are part of the route stops.
    //    - Fallback: if IDs are empty, keep places near the active route polyline.
    if (_showPlacesOnRouteOnly) {
      final intent = ref.read(routePlacesOnRouteOnlyIntentProvider);
      final routePlaceIds = intent?.placeIds ?? const <String>{};

      if (routePlaceIds.isNotEmpty) {
        filteredPlaces = filteredPlaces
            .where((place) => routePlaceIds.contains(place.id))
            .toList();
      } else {
        final route = ref.read(routeNavigationProvider);
        if (route != null && route.points.isNotEmpty) {
          filteredPlaces = _filterPlacesNearRoute(
            places: filteredPlaces,
            routePoints: route.points,
            radiusMeters: 1000,
          );
        } else {
          // Route cleared but flag still set (should be rare); reset.
          _showPlacesOnRouteOnly = false;
        }
      }
    }

    setState(() {
      _mapPlaces = filteredPlaces;
    });

    // PERFORMANS: ClusterManager'ı yeniden oluşturmak yerine
    // mevcut olanı güncelle. Böylece cluster ID'leri korunur ve
    // MarkerBuilder bitmap cache'i geçerli kalır.
    if (_clusterManager == null) {
      _clusterManager = MapClusterManager<MapPlace>(
        items: filteredPlaces,
        getLocation: (place) => place.position,
        stopClusteringZoom: 16.0,
      );
    } else {
      _clusterManager!.updateItems(filteredPlaces);
    }

    // Marker'ları güncelle
    _updateMarkers();
  }

  /// Filter POIs that are within [radiusMeters] of the route polyline.
  ///
  /// For performance, we sample the route points to a max of ~200 points and
  /// use a Haversine distance-to-nearest-point approximation (good enough for UX).
  List<MapPlace> _filterPlacesNearRoute({
    required List<MapPlace> places,
    required List<LatLng> routePoints,
    required double radiusMeters,
  }) {
    if (places.isEmpty || routePoints.isEmpty) return places;

    const maxSamples = 200;
    final stride = routePoints.length <= maxSamples
        ? 1
        : (routePoints.length / maxSamples).ceil();

    final sampled = <LatLng>[];
    for (int i = 0; i < routePoints.length; i += stride) {
      sampled.add(routePoints[i]);
    }

    return places.where((place) {
      for (final p in sampled) {
        final d =
            DistanceHelper.calculateHaversineDistance(place.position, p);
        if (d <= radiusMeters) return true;
      }
      return false;
    }).toList();
  }

  /// Arama sonuçlarına göre kategorileri filtrele
  /// Sadece içinde place olan kategorileri göster
  List<PlaceCategory> _getFilteredCategories() {
    // Arama yapılmamışsa tüm kategorileri göster
    if (_searchQuery.isEmpty) {
      return _categories;
    }

    // Filtrelenmiş place'lerdeki kategori ID'lerini topla
    final categoryIdsInResults = _mapPlaces
        .where((place) => place.categoryId != null && place.categoryId!.isNotEmpty)
        .map((place) => place.categoryId!)
        .toSet();

    // "Tümü"/"All" kategorisini her zaman göster
    final filtered = _categories.where((category) {
      if (category.id == 'all' || 
          category.label == context.l10n.lblAll || 
          category.label == 'All') {
        return true;
      }
      // Kategori ID'si sonuçlarda varsa göster
      return categoryIdsInResults.contains(category.id);
    }).toList();

    return filtered;
  }

  /// Seçili kategorinin alt kategori seçeneklerini üretir.
  ///
  /// **Neden client-side?** CMS kategori yanıtında alt kategori listesi yok
  /// (`/categories/{id}/subcategories` boş dönüyor); alt kategoriler yalnız
  /// place'lerin `subcategories` alanında slug olarak geliyor. Bu yüzden
  /// yüklü place'lerden distinct slug'lar toplanır — böylece yalnızca içinde
  /// gerçekten place olan alt kategoriler chip olarak görünür.
  /// Sıralama: place sayısı çok olan önce, eşitse alfabetik.
  List<MapSubcategoryOption> _getSubcategoriesForSelectedCategory() {
    if (_selectedCategory == null) return const [];

    final selectedCat = _categories.firstWhere(
      (cat) => cat.label == _selectedCategory || cat.id == _selectedCategory,
      orElse: () => const PlaceCategory(id: '', label: ''),
    );
    if (selectedCat.id.isEmpty || selectedCat.id == 'all') return const [];

    final counts = <String, int>{};
    for (final place in _allMapPlaces) {
      if (place.categoryId != selectedCat.id) continue;
      for (final slug in place.subcategories) {
        counts[slug] = (counts[slug] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return const [];

    final isTr = ref.read(localeProvider).locale.languageCode == 'tr';
    final options = counts.entries
        .map((e) => MapSubcategoryOption(
              slug: e.key,
              label: SubcategoryLabels.label(e.key, isTr: isTr),
              count: e.value,
            ))
        .toList()
      ..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        return byCount != 0 ? byCount : a.label.compareTo(b.label);
      });
    return options;
  }


  /// Mevcut place'lerin kategori etiketlerini güncelle (dil değiştiğinde)
  void _remapPlaceCategories() {
    if (_allMapPlaces.isEmpty) return;
    
    final updatedPlaces = _allMapPlaces.map((place) {
      if (place.categoryId != null && place.categoryId!.isNotEmpty) {
        final category = _categories.firstWhere(
          (cat) => cat.id == place.categoryId,
          orElse: () => const PlaceCategory(id: '', label: ''),
        );
        
        if (category.id.isNotEmpty) {
          return MapPlace(
            id: place.id,
            title: place.title,
            description: place.description,
            category: category.label,
            categoryId: place.categoryId,
            categorySlug: category.slug,
            categoryIcon: category.icon,
            rating: place.rating,
            distance: place.distance,
            address: place.address,
            position: place.position,
            imageUrl: place.imageUrl,
            subcategories: place.subcategories,
          );
        }
      }
      return place;
    }).toList();
    
    setState(() {
      _allMapPlaces = updatedPlaces;
    });
    
    // Filtreleri yeniden uygula
    _applyFilters();
  }

  /// Türkçe karakterleri normalize eder (ı->i, ş->s, ğ->g, ü->u, ö->o, ç->c)
  /// Böylece "samsun" ile "Samsun" veya "şehir" ile "sehir" eşleşir
  String _normalizeTurkish(String text) {
    return text
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ş', 's')
        .replaceAll('Ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('Ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('Ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('Ç', 'c');
  }

  @override
  Widget build(BuildContext context) {
    // Watch for language changes and reload categories
    final currentLanguageCode = ref.watch(
      localeProvider.select((s) => s.locale.languageCode),
    );
    
    // Reload categories when language changes
    if (_lastLanguageCode != null && _lastLanguageCode != currentLanguageCode) {
      debugPrint('🌍 [MapScreen] Language changed: $_lastLanguageCode -> $currentLanguageCode, reloading categories...');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadPlaces(refreshCategories: true);
        }
      });
    }
    
    // Keep UI in sync with provider state changes (listeners must be in build).
    ref.listen<RouteData?>(routeNavigationProvider, (previous, next) {
      // Only auto-disable the filter when it is *not* driven by the
      // "route stops only" intent.
      if (next == null && _showPlacesOnRouteOnly) {
        final intent = ref.read(routePlacesOnRouteOnlyIntentProvider);
        if (intent == null) {
          if (!mounted) return;
          setState(() => _showPlacesOnRouteOnly = false);
          _applyFilters();
        }
      }
    });

    // If a non-map screen requested navigation, start routing now.
    // NOTE: intent might already be set before MapScreen is built, so we also
    // handle the current value below (not only changes).
    ref.listen<RouteIntent?>(routeIntentProvider, (previous, next) {
      if (next == null) return;
      _startRouteToDestination(next.destination);
    });

    final routeIntent = ref.watch(routeIntentProvider);
    if (routeIntent != null &&
        (_lastHandledIntentDestination == null ||
            _lastHandledIntentDestination!.latitude !=
                routeIntent.destination.latitude ||
            _lastHandledIntentDestination!.longitude !=
                routeIntent.destination.longitude)) {
      _lastHandledIntentDestination = routeIntent.destination;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _startRouteToDestination(routeIntent.destination);
      });
    }

    // Watch route navigation state — rebuild polylines & pill on change
    final routeData = ref.watch(routeNavigationProvider);
    _syncPolylines(routeData, Theme.of(context).colorScheme.primary);

    // Auto-enable the "places on route" filter when route detail sets the
    // active place-id payload.
    final routeStopsIntent = ref.watch(routePlacesOnRouteOnlyIntentProvider);
    if (routeStopsIntent != null && routeStopsIntent.placeIds.isNotEmpty) {
      final key = routeStopsIntent.placeIds.toList()..sort();
      final stableKey = key.join(',');

      if (_lastAutoPlacesOnRouteKey != stableKey) {
        _lastAutoPlacesOnRouteKey = stableKey;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          setState(() => _showPlacesOnRouteOnly = true);
          _applyFilters();
        });
      }
    }

    final showStopsFilterBar =
        routeStopsIntent != null && _showPlacesOnRouteOnly;

    // Seçili kategorinin alt kategorileri (boşsa chip satırı görünmez).
    final subcategoryOptions = _getSubcategoriesForSelectedCategory();

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_mapError != null)
            MapErrorState(
              errorMessage: _mapError!,
              onRetry: () => setState(() => _mapError = null),
            )
          else
            _buildGoogleMap(),
          // ── ESKİ (alt kategori filtresi öncesi) — geri dönüş için saklandı ──
          // MapSearchHeader(
          //   categories: _getFilteredCategories(),
          //   selectedCategory: _selectedCategory ??
          //       (ref.read(localeProvider).locale.languageCode == 'tr' ? context.l10n.lblAll : 'All'),
          //   onCategorySelected: _onCategorySelected,
          //   onSearch: _onSearchSubmitted,
          //   onSearchChanged: _onSearchChanged,
          // ),
          // _buildMyLocationButton(hasRoute: routeData != null),
          // _buildHeatmapToggleButton(),
          MapSearchHeader(
            categories: _getFilteredCategories(),
            selectedCategory: _selectedCategory ??
                (ref.read(localeProvider).locale.languageCode == 'tr' ? context.l10n.lblAll : 'All'),
            onCategorySelected: _onCategorySelected,
            onSearch: _onSearchSubmitted,
            onSearchChanged: _onSearchChanged,
            subcategories: subcategoryOptions,
            selectedSubcategorySlugs: _selectedSubcategorySlugs,
            onSubcategoryToggled: _onSubcategoryToggled,
            onSubcategoriesCleared: _onSubcategoriesCleared,
            subcategoryFilterAsButton: _kSubcategoryFilterAsButton,
          ),
          _buildMyLocationButton(hasRoute: routeData != null),
          _buildHeatmapToggleButton(
            // Chip satırı yalnız satır varyantında yer kaplar; buton
            // varyantında heatmap butonu eski konumunda kalır.
            hasSubcategoryRow: !_kSubcategoryFilterAsButton &&
                subcategoryOptions.isNotEmpty,
          ),
          _buildBottomGradient(),
          // Place bottom sheet modal
          if (_selectedPlace != null) _buildPlaceModal(),

          // Route info bottom sheet — slides out when place modal is open
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: 0,
            right: 0,
            bottom: ((showStopsFilterBar || (routeData != null)) &&
                    _selectedPlace == null)
                ? 0
                : -220, // off-screen when no route or detail sheet open
            child: SafeArea(
              top: false,
              left: false,
              right: false,
              minimum: const EdgeInsets.only(bottom: 0),
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: AppNavBar.compactBottomPadding,
                ),
                child: showStopsFilterBar
                    ? _buildRouteStopsFilterPill(
                        routeTitle: routeStopsIntent.routeTitle ?? '',
                        onClosePressed: _onCloseRoutePressed,
                      )
                    : RouteInfoPill(
                        placesOnRouteActive: _showPlacesOnRouteOnly,
                        onPlacesOnRoutePressed: _onPlacesOnRoutePressed,
                        onClosePressed: _onCloseRoutePressed,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Sync the polyline set with the current [routeData].
  /// Uses the theme [primaryColor] for consistent brand identity.
  /// Also triggers an auto-zoom when a new route appears.
  void _syncPolylines(RouteData? routeData, Color primaryColor) {
    if (routeData != null && routeData.points.isNotEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final base = isDark
          ? (Color.lerp(primaryColor, Colors.white, 0.16) ?? primaryColor)
          : primaryColor;

      // Prestijli, oturaklı tek stroke (glow yok).
      final mainPolyline = Polyline(
        polylineId: const PolylineId('osrm_route_main'),
        points: routeData.points,
        color: base,
        width: 7,
        zIndex: 1,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      );

      // Always keep styling in sync (e.g. theme change), but only auto-zoom on a new route.
      _polylines = {mainPolyline};

      final isNewRoute = _lastRoutePointCount != routeData.points.length ||
          _lastRouteStart == null ||
          _lastRouteEnd == null ||
          _lastRouteStart!.latitude != routeData.points.first.latitude ||
          _lastRouteStart!.longitude != routeData.points.first.longitude ||
          _lastRouteEnd!.latitude != routeData.points.last.latitude ||
          _lastRouteEnd!.longitude != routeData.points.last.longitude;

      if (isNewRoute) {
        _lastRoutePointCount = routeData.points.length;
        _lastRouteStart = routeData.points.first;
        _lastRouteEnd = routeData.points.last;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _animateCameraToRoute(routeData.points);
        });
      }
    } else {
      if (_polylines.isNotEmpty) {
        _polylines = {};
      }
      _lastRoutePointCount = 0;
      _lastRouteStart = null;
      _lastRouteEnd = null;
    }
  }

  void _onCloseRoutePressed() {
    // Clear UI state first (prevents stale filter if route provider is slow).
    if (_showPlacesOnRouteOnly) {
      setState(() => _showPlacesOnRouteOnly = false);
      _applyFilters();
    }
    ref.read(routeNavigationProvider.notifier).clearRoute();
    ref.read(routePlacesOnRouteOnlyIntentProvider.notifier).clear();
  }

  void _onPlacesOnRoutePressed() {
    final route = ref.read(routeNavigationProvider);
    if (route == null || route.points.isEmpty) return;

    setState(() => _showPlacesOnRouteOnly = !_showPlacesOnRouteOnly);
    _applyFilters();
  }

  Future<void> _startRouteToDestination(LatLng destination) async {
    // Ensure we have origin (cached).
    final origin = _userLocation ?? await ref.read(userLocationProvider.notifier).getOrFetch();
    if (!mounted) return;
    if (origin == null) return;

    if (mounted) {
      setState(() => _userLocation = origin);
    }

    await ref.read(routeNavigationProvider.notifier).fetchRoute(origin, destination);
    if (!mounted) return;
    // Clear intent so it won't re-trigger.
    ref.read(routeIntentProvider.notifier).clear();
  }

  /// Animate the camera to fit all route points with comfortable padding.
  void _animateCameraToRoute(List<LatLng> points) {
    if (_mapController == null || points.isEmpty) return;

    final bounds = _createBounds(points);
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80.0),
    );
  }

  Widget _buildGoogleMap() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // RepaintBoundary: Overlay rebuild'leri (search header, modal, gradient)
    // GoogleMap'in pahalı re-composite'ini tetiklemesin
    return RepaintBoundary(
      child: GoogleMap(
      onMapCreated: _onMapCreated,
      onCameraMove: _onCameraMove,
      onCameraIdle: _onCameraIdle,
      initialCameraPosition: ref.read(mapCameraProvider).lastCameraPosition ??
          const CameraPosition(
            target: _defaultCenter,
            zoom: _defaultZoom,
          ),
      // Heatmap aktifken pinler gizleniyor — iki katman üst üste binmesin,
      // görsel hiyerarşi temiz kalsın. Polyline (rota) gizlenmiyor çünkü
      // farklı bir kullanıcı niyeti.
      markers: _heatmapEnabled ? const <Marker>{} : _markers,
      polylines: _polylines,
      heatmaps: _heatmaps,
      style: isDark ? darkMapStyle : minimalMapStyle, // Dark mode'da koyu tema kullan
      myLocationEnabled: true, // Kullanıcı konumunu göster
      myLocationButtonEnabled: false, // Custom buton kullanıyoruz
      mapType: MapType.normal,
      zoomControlsEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      rotateGesturesEnabled: true,
      scrollGesturesEnabled: true,
      tiltGesturesEnabled: false,
      zoomGesturesEnabled: true,
      buildingsEnabled: true,
      trafficEnabled: false,
      liteModeEnabled: false,
      minMaxZoomPreference: const MinMaxZoomPreference(5.0, 20.0),
      // Heatmap aktifken haritaya tıklama → o bölgedeki yerleri bottom sheet
      // ile listele. Heatmap layer'ı tıklanabilir değil (SDK kısıtı), bu
      // yüzden tıklamayı yakalayıp 300m yarıçapı içindeki place'leri buluyoruz.
      // Heatmap kapalıyken null — eski davranış korunuyor.
      onTap: _heatmapEnabled ? _onHeatmapTap : null,
    ),
    );
  }

  Widget _buildMyLocationButton({required bool hasRoute}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBarHeight = AppNavBar.compactHeight;
    const modalBottomOffset = 28.0; // Modal'ın bottom bar'dan uzaklığı
    const buttonSpacing = 8.0; // Buton ile modal arası boşluk
    const pillEstimatedHeight = 140.0; // yeni bottom sheet tahmini yüksekliği
    const pillGap = 24.0; // UX: minimum separation to prevent fat-finger taps
    
    // Modal açıkken butonu modal'ın üstüne dinamik kaydır
    double bottomPosition;
    if (_selectedPlace != null && _modalHeight > 0) {
      // Modal'ın gerçek yüksekliği + modal pozisyonu + buton boşluğu
      bottomPosition = navBarHeight + modalBottomOffset + _modalHeight + buttonSpacing;
    } else if (_selectedPlace != null) {
      // Modal henüz ölçülmediyse tahmini yükseklik
      const estimatedModalHeight = 260.0;
      bottomPosition = navBarHeight + modalBottomOffset + estimatedModalHeight + buttonSpacing;
    } else {
      // Normal durumda eski pozisyon
      bottomPosition = AppNavBar.compactBottomPadding + 16;
    }

    // If the route panel is visible, ensure minimum vertical separation.
    if (hasRoute) {
      final minBottom =
          AppNavBar.compactBottomPadding + 12 + pillEstimatedHeight + pillGap;
      if (bottomPosition < minBottom) {
        bottomPosition = minBottom;
      }
    }
    
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      bottom: bottomPosition,
      right: 16,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark ? AppElevation.level1 : AppElevation.level2,
          border: isDark ? Border.all(color: Colors.white.withAlpha(20), width: 1) : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _goToMyLocation,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Icon(
                Icons.my_location_rounded,
                // Marka yeşili — eski mavi (`neonBlue` / `lightGradientStart`)
                // değiştirildi.
                color: Theme.of(context).colorScheme.primary,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// `mobile_pending_changes.md` B4 — Heatmap (Isı haritası) toggle butonu.
  /// Sağ üst köşe; search header'ın altına yerleşir. Açıkken vurgulu renk.
  /// [hasSubcategoryRow] true ise alt kategori chip satırı görünür durumda —
  /// buton, satırın altında kalacak şekilde aşağı kaydırılır.
  Widget _buildHeatmapToggleButton({bool hasSubcategoryRow = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Active rengi marka primary — eskiden dark'ta neonOrange kullanılıyordu,
    // ısı haritası kavramı için turuncu hoş ama tema tutarlılığı için yeşil.
    final activeColor = Theme.of(context).colorScheme.primary;

    // Search bar (~52) + spacing (~12) + chip strip (~40) + spacing (~12) +
    // güvenlik buffer (~40) = ~156. Her ekran oranında chip'in altında kalır.
    // Alt kategori satırı açıkken +44 (satır ~36 + spacing ~8).
    // AnimatedPositioned: satır açılıp kapanırken buton yumuşak kayar
    // (header'daki AnimatedSize ile aynı süre/curve).
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      // ── ESKİ (alt kategori filtresi öncesi) — geri dönüş için saklandı ──
      // top: MediaQuery.of(context).padding.top + 156,
      top: MediaQuery.of(context).padding.top +
          156 +
          (hasSubcategoryRow ? 44 : 0),
      right: 16,
      child: Container(
        decoration: BoxDecoration(
          color: _heatmapEnabled
              ? activeColor
              : (isDark ? AppColors.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark ? AppElevation.level1 : AppElevation.level2,
          border: isDark
              ? Border.all(color: Colors.white.withAlpha(20), width: 1)
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _toggleHeatmap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                Icons.local_fire_department_rounded,
                color: _heatmapEnabled
                    ? Colors.white
                    : (isDark ? Colors.white70 : activeColor),
                size: 22,
                semanticLabel: _heatmapEnabled
                    ? 'Isı haritasını kapat'
                    : 'Isı haritasını aç',
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomGradient() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColor = isDark ? AppColors.darkBackground : Colors.white;
    
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                gradientColor.withValues(alpha: 0),
                gradientColor.withValues(alpha: 0.8),
                gradientColor,
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  /// Marker'ları güncelle (clustering ile)
  ///
  /// PERFORMANS OPTİMİZASYONLARI:
  /// 1. Delta update: Mevcut marker set ile karşılaştırma yaparak
  ///    sadece değişen/yeni/silinen marker'ları günceller.
  /// 2. Cache-aware: MarkerBuilder cache'indeki bitmap'ler tekrar render edilmez.
  /// 3. Minimal setState: Eğer marker set değişmediyse rebuild tetiklenmez.
  Future<void> _updateMarkers() async {
    if (_isUpdatingMarkers || _clusterManager == null || _mapController == null) return;

    // Heatmap modu — pinler hiç render edilmiyor; cluster hesaplama da gereksiz.
    // Bu hem CPU'yu rahatlatır hem görsel kalabalığı önler.
    if (_heatmapEnabled) {
      return;
    }

    _isUpdatingMarkers = true;
    
    // Tema durumunu al (async işlemler için sakla)
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeKey = isDark ? 'dark' : 'light';
    
    try {
      // Mevcut kamera pozisyonunu kullan
      if (_currentCameraPosition != null) {
        _clusterManager!.onCameraMove(_currentCameraPosition!);
      }

      // Görünür bölgeyi al
      try {
        final bounds = await _mapController!.getVisibleRegion();
        _clusterManager!.setVisibleBounds(bounds);
      } catch (e) {
        debugPrint('⚠️ [MapScreen] Could not get visible region: $e');
      }

      // Cluster'ları al
      final clusters = _clusterManager!.getClusters();
      
      // Cluster map'i güncelle (tap handling için)
      _clusterMap.clear();
      for (final cluster in clusters) {
        _clusterMap[cluster.getId()] = cluster;
      }
      
      // PERFORMANS: Delta update — mevcut marker ID'lerini topla
      final existingMarkerIds = _markers.map((m) => m.markerId.value).toSet();
      final newClusterIds = <String>{};
      final newMarkers = <Marker>{};
      
      for (final cluster in clusters) {
        if (cluster.isMultiple) {
          // Cluster marker
          final clusterId = cluster.getId();
          newClusterIds.add(clusterId);
          
          // Eğer bu cluster ID zaten mevcutsa ve cache'deyse, mevcut marker'ı kullan
          final cacheKey = 'cluster_${cluster.count}_$themeKey';
          final alreadyExists = existingMarkerIds.contains(clusterId);
          
          if (alreadyExists && MarkerBuilder.isCached(cacheKey)) {
            // Mevcut marker'ı yeniden kullan — pozisyon aynıysa bitmap rendering ATLA
            final existingMarker = _markers.firstWhere((m) => m.markerId.value == clusterId);
            if (existingMarker.position == cluster.location) {
              newMarkers.add(existingMarker);
              continue;
            }
          }
          
          final icon = await MarkerBuilder.widgetToBitmap(
            widget: ClusterMarker(count: cluster.count, isDark: isDark),
            logicalSize: const Size(ClusterMarker.bitmapSize, ClusterMarker.bitmapSize),
            cacheKey: cacheKey,
          );
          
          newMarkers.add(
            Marker(
              markerId: MarkerId(clusterId),
              position: cluster.location,
              icon: icon,
              anchor: const Offset(0.5, 0.5),
              consumeTapEvents: true,
              onTap: () => _onClusterTap(cluster),
            ),
          );
        } else {
          // Tekil place marker (pill)
          final place = cluster.first;
          newClusterIds.add(place.id);
          
          final cacheKey = 'place_${place.id}_$themeKey';
          final alreadyExists = existingMarkerIds.contains(place.id);
          
          if (alreadyExists && MarkerBuilder.isCached(cacheKey)) {
            // Mevcut marker'ı yeniden kullan — pozisyon değişmez, bitmap cache'de
            final existingMarker = _markers.firstWhere((m) => m.markerId.value == place.id);
            newMarkers.add(existingMarker);
            continue;
          }
          
          final icon = await MarkerBuilder.widgetToBitmap(
            widget: PillMarker(
              title: place.title,
              isDark: isDark,
              categoryIcon: (place.categorySlug != null || place.categoryIcon != null)
                  ? CategoryIcon(
                      categorySlug: place.categorySlug,
                      iconString: place.categoryIcon,
                      isDark: isDark,
                    )
                  : null,
            ),
            logicalSize: const Size(PillMarker.bitmapWidth, PillMarker.bitmapHeight),
            cacheKey: cacheKey,
          );
          
          newMarkers.add(
            Marker(
              markerId: MarkerId(place.id),
              position: place.position,
              icon: icon,
              anchor: const Offset(0.5, 1.0),
              consumeTapEvents: true,
              onTap: () => _onPillMarkerTap(place),
            ),
          );
        }
      }

      // PERFORMANS: Sadece marker set gerçekten değiştiyse setState çağır
      final markersChanged = newMarkers.length != _markers.length ||
          newClusterIds.difference(existingMarkerIds).isNotEmpty ||
          existingMarkerIds.difference(newClusterIds).isNotEmpty;

      if (markersChanged && mounted) {
        setState(() {
          _markers = newMarkers;
        });
      }
    } catch (e) {
      debugPrint('❌ [MapScreen] Error updating markers: $e');
    } finally {
      _isUpdatingMarkers = false;
    }
  }

  /// Handle cluster tap - zoom to fit all points in the cluster
  void _onClusterTap(MapCluster<MapPlace> cluster) {
    if (_mapController == null) return;

    try {
      // Get all positions from cluster items
      final positions = cluster.items.map((place) => place.position).toList();

      if (positions.isEmpty) return;

      // If all positions are the same, zoom to a fixed high level
      final firstPos = positions.first;
      final allSame = positions.every((pos) =>
          pos.latitude == firstPos.latitude && pos.longitude == firstPos.longitude);

      if (allSame) {
        // Zoom to fixed high level
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(firstPos, 18.0),
        );
      } else {
        // Calculate bounds and animate to fit
        final bounds = _createBounds(positions);
        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 50.0),
        );
      }
    } catch (e) {
      debugPrint('❌ [MapScreen] Error handling cluster tap: $e');
      // Fallback: zoom to cluster center
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(cluster.location, 16.0),
      );
    }
  }

  /// Handle pill marker tap - show place bottom sheet modal
  void _onPillMarkerTap(MapPlace place) {
    // mobile_analytics_todo.md §2.7 — map_marker_tapped
    ref.read(analyticsServiceProvider).track(
      AnalyticsEvents.mapMarkerTapped,
      properties: {
        'entity_type': 'place',
        'entity_id': place.id,
      },
    );
    // Set selected place to show modal in Stack
    setState(() {
      _selectedPlace = place;
    });
  }

  /// Create LatLngBounds from a list of positions
  /// Returns bounds that encompass all positions
  LatLngBounds _createBounds(List<LatLng> positions) {
    if (positions.isEmpty) {
      // Fallback to default center if empty
      return LatLngBounds(
        southwest: LatLng(_defaultCenter.latitude - 0.01, _defaultCenter.longitude - 0.01),
        northeast: LatLng(_defaultCenter.latitude + 0.01, _defaultCenter.longitude + 0.01),
      );
    }

    if (positions.length == 1) {
      // Single position - create small bounds around it
      final pos = positions.first;
      return LatLngBounds(
        southwest: LatLng(pos.latitude - 0.001, pos.longitude - 0.001),
        northeast: LatLng(pos.latitude + 0.001, pos.longitude + 0.001),
      );
    }

    // Find min/max lat/lng
    double minLat = positions.first.latitude;
    double maxLat = positions.first.latitude;
    double minLng = positions.first.longitude;
    double maxLng = positions.first.longitude;

    for (final pos in positions) {
      minLat = minLat < pos.latitude ? minLat : pos.latitude;
      maxLat = maxLat > pos.latitude ? maxLat : pos.latitude;
      minLng = minLng < pos.longitude ? minLng : pos.longitude;
      maxLng = maxLng > pos.longitude ? maxLng : pos.longitude;
    }

    // Add small padding to prevent zero-width bounds
    final latPadding = (maxLat - minLat) * 0.1;
    final lngPadding = (maxLng - minLng) * 0.1;

    return LatLngBounds(
      southwest: LatLng(
        minLat - (latPadding > 0 ? latPadding : 0.001),
        minLng - (lngPadding > 0 ? lngPadding : 0.001),
      ),
      northeast: LatLng(
        maxLat + (latPadding > 0 ? latPadding : 0.001),
        maxLng + (lngPadding > 0 ? lngPadding : 0.001),
      ),
    );
  }

  Widget _buildPlaceModal() {
    if (_selectedPlace == null) return const SizedBox.shrink();

    final navBarHeight = AppNavBar.compactHeight;
    // Modal'ı bottom bar'dan 8px yukarıda konumlandır
    const modalBottomOffset = 28.0;
    // Modal'ın maksimum yüksekliği
    const maxModalHeight = 300.0;

    return Positioned(
      left: 0,
      right: 0,
      bottom: navBarHeight + modalBottomOffset,
      child: Container(
        key: _modalKey,
        constraints: const BoxConstraints(maxHeight: maxModalHeight),
        child: NotificationListener<SizeChangedLayoutNotification>(
          onNotification: (notification) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final renderBox = _modalKey.currentContext?.findRenderObject() as RenderBox?;
              if (renderBox != null && mounted) {
                final newHeight = renderBox.size.height;
                if (_modalHeight != newHeight) {
                  setState(() => _modalHeight = newHeight);
                }
              }
            });
            return true;
          },
          child: SizeChangedLayoutNotifier(
            child: PlaceBottomSheet(
              place: _selectedPlace!,
              onClose: () {
                setState(() {
                  _selectedPlace = null;
                  _modalHeight = 0;
                });
              },
              onNavigate: () {
                _navigateToPlace(_selectedPlace!);
              },
              onSwipeUp: () {
                // Place detay sayfasına git
                context.push('/places/${_selectedPlace!.id}');
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Bottom bar for route detail "stops-only" filtering.
  /// It intentionally does NOT draw any route polyline; it only shows the
  /// route name and provides the close (X) action that turns the filter off.
  Widget _buildRouteStopsFilterPill({
    required String routeTitle,
    required VoidCallback onClosePressed,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final surface = colorScheme.surface;
    final tintColor =
        isDark ? surface.withValues(alpha: 0.95) : surface.withValues(alpha: 0.96);
    final borderColor = isDark
        ? colorScheme.onSurface.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: tintColor,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    routeTitle.isNotEmpty ? routeTitle : 'Rota',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                  ),
                ),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Material(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onClosePressed,
                      customBorder: const CircleBorder(),
                      child: Center(
                        child: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.7)
                              : Colors.black.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Fetch an OSRM route from the user's current location to [place].
  /// Dismisses the bottom sheet and draws the polyline on the map.
  Future<void> _navigateToPlace(MapPlace place) async {
    // Determine origin: current user location or fallback to default
    final origin = _userLocation ?? await _resolveUserLocation();
    if (!mounted) return;
    if (origin == null) {
      debugPrint('⚠️ [MapScreen] Cannot navigate: user location unavailable');
      return;
    }

    // Close the place bottom sheet
    setState(() {
      _selectedPlace = null;
      _modalHeight = 0;
    });

    // Fetch route via provider
    await ref
        .read(routeNavigationProvider.notifier)
        .fetchRoute(origin, place.position);
  }

  /// Try to resolve user location if not yet available.
  Future<LatLng?> _resolveUserLocation() async {
    final location = await ref.read(userLocationProvider.notifier).getOrFetch();
    if (location != null && mounted) {
      setState(() => _userLocation = location);
    }
    return location;
  }

  @override
  void dispose() {
    _cameraIdleTimer?.cancel();
    _heatmapFetchDebounce?.cancel();
    // Defer provider write: sync notifier updates during dispose can trigger
    // "Tried to modify a provider while the widget tree was building".
    final lastPosition = _currentCameraPosition;
    final cameraNotifier = _mapCameraNotifier;
    if (lastPosition != null) {
      Future.microtask(() {
        cameraNotifier.savePosition(lastPosition);
      });
    }
    _mapController?.dispose();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Heatmap nearby sheet — Heatmap tap'inde tıklanan koordinatın etrafındaki
// yerleri listeler. Tap → place detail navigation.
// ─────────────────────────────────────────────────────────────────────────────

class _HeatmapNearbySheet extends StatelessWidget {
  const _HeatmapNearbySheet({
    required this.items,
    required this.onItemTap,
    required this.radiusM,
  });

  final List<({Place place, double distM})> items;
  final ValueChanged<Place> onItemTap;

  /// Tıklama anındaki dinamik tap yarıçapı (m). Header'da "120 m içinde"
  /// gibi bilgilendirici göstergeye dönüşür — kullanıcı kaç metrelik bir
  /// alanı incelediğini bilsin.
  final double radiusM;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
      ),
      padding: EdgeInsets.only(
        top: AppSpacing.sm,
        bottom: bottomPadding + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  color: colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bu bölgedeki yerler',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatRadius(radiusM)} içinde',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${items.length} sonuç',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, i) {
                final item = items[i];
                return _HeatmapNearbyItem(
                  place: item.place,
                  distance: _formatDistance(item.distM),
                  onTap: () => onItemTap(item.place),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  /// Header için: "120 m", "1.2 km" gibi okunabilir bir radius etiketi.
  static String _formatRadius(double meters) {
    if (meters < 1000) return '~${meters.round()} m';
    return '~${(meters / 1000).toStringAsFixed(1)} km';
  }
}

class _HeatmapNearbyItem extends StatelessWidget {
  const _HeatmapNearbyItem({
    required this.place,
    required this.distance,
    required this.onTap,
  });

  final Place place;
  final String distance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: () {
          Haptics.light();
          onTap();
        },
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm + 2),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: (place.imageUrl != null && place.imageUrl!.isNotEmpty)
                      ? CachedImage(
                          imageUrl: place.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: Icon(
                            Icons.place_outlined,
                            color: colorScheme.primary,
                          ),
                        )
                      : Container(
                          color: colorScheme.primaryContainer
                              .withValues(alpha: 0.4),
                          child: Icon(
                            Icons.place_outlined,
                            color: colorScheme.primary,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                        letterSpacing: -0.1,
                        height: 1.25,
                      ),
                    ),
                    if ((place.category ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        place.category!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  distance,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
