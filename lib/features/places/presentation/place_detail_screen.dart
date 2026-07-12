import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/feature_flags.dart';
import '../../../../core/services/analytics_events.dart';
import '../../../../core/services/analytics_service.dart';
import '../../profile/presentation/providers/user_activity_provider.dart';
import '../../../../core/widgets/cached_image.dart';
import '../../../../core/widgets/circular_icon_button.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../../core/design/design_tokens.dart';
import '../../../../core/mixins/collapsing_scroll_mixin.dart';
import '../../../../core/utils/image_url_helper.dart';
import '../../../../core/utils/external_ar_launcher.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/discovery_service.dart';
import '../../../../core/utils/distance_helper.dart';
import '../../map/presentation/providers/route_intent_provider.dart';
import '../../../../l10n/l10n.dart';
import '../../../../api/api.dart';
import '../../../../data/models/models.dart';
import '../../favorites/presentation/providers/favorites_provider.dart';
import '../../itinerary/presentation/widgets/add_to_itinerary_sheet.dart';
import '../../../../core/services/point_collection_service.dart';
import '../../../../core/widgets/collect_points_card.dart';
import '../../home/presentation/providers/point_collection_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'providers/place_detail_provider.dart';
import 'providers/places_provider.dart';
import 'widgets/photo_gallery_viewer.dart';
import 'widgets/video_player_viewer.dart';

/// Belirli bir mekanın listeden gelen puan bilgisini izler.
/// placesProvider enrichment tamamlandığında reactive olarak güncellenir.
/// Kampanya bazlı puan sistemi: claimed + campaign alanları dahil.
final _placePointsProvider = Provider.family<({int? points, bool visited, bool claimed, CampaignMeta? campaign})?, String>((ref, placeId) {
  final allPlaces = ref.watch(placesProvider.select((s) => s.allPlaces));
  if (allPlaces.isEmpty) return null;

  for (final p in allPlaces) {
    final matches =
        p.id == placeId || p.cmsContentId == placeId;
    if (matches && p.points != null && p.points! > 0) {
      return (points: p.points, visited: p.visited, claimed: p.claimed, campaign: p.campaign);
    }
  }
  return null;
});

/// Media item type
enum MediaType {
  photo,
  video,
}

/// Media item model
class MediaItem {
  const MediaItem({
    required this.type,
    required this.url,
  });

  final MediaType type;
  final String url;
}

class PlaceDetailScreen extends ConsumerStatefulWidget {
  const PlaceDetailScreen({super.key, required this.id, this.routeId});

  final String id;

  /// Eğer bu yer bir rotanın durağı olarak açılıyorsa, rota ID'si buraya gelir.
  /// Bu durumda puan toplama, yer puanı değil rota durağı puanı üzerinden yapılır.
  final int? routeId;

  @override
  ConsumerState<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends ConsumerState<PlaceDetailScreen>
    with CollapsingScrollMixin {
  Timer? _distanceTimer;
  bool _proximityCheckStarted = false;

  // Riverpod 3.x: ref.read() dispose'da kullanılamaz, initState'te kaydet
  late final DiscoveryService _discoveryService;
  late final PointCollectionNotifier _pointCollectionNotifier;

  /// Extracted from build() — renders the place detail content.
  /// Previously a 177-line closure inside build(), now a proper method.
  Widget _buildBody({
    required Place place,
    required String? overrideDistance,
    required bool isDark,
    required Color buttonBgColor,
    required Color buttonIconColor,
    required String baseUrl,
  }) {
    // Eğer mesafe provider'da varsa, place.distance üzerine yaz
    if (overrideDistance != null) {
      place = place.copyWith(distance: overrideDistance);
    }

    final isFavorite = ref.watch(
      isFavoriteProvider((FavoriteEntityType.place, place.id)),
    );

    // "Rotama ekle" yalnızca girişli kullanıcıya gösterilir (ürün kararı).
    final isAuthenticated = ref.watch(
      authProvider.select((s) => s.status == AuthStatus.authenticated),
    );

    final imageUrl = buildImageUrl(place.imageUrl, baseUrl: baseUrl);
    final photoUrls = buildImageUrls(place.photoUrls, baseUrl: baseUrl);
    final videoUrl = place.videoUrl != null
        ? buildImageUrl(place.videoUrl, baseUrl: baseUrl, isVideo: true)
        : null;
    final videoUrls = buildImageUrls(place.videoUrls, baseUrl: baseUrl, isVideo: true);

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          title: buildCollapsingTitle(
            context,
            title: place.name,
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                imageUrl != null
                    ? CachedImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: SkeletonLoader(
                          width: double.infinity,
                          height: double.infinity,
                          borderRadius: BorderRadius.zero,
                        ),
                        errorWidget: Container(
                          color: isDark
                              ? AppColors.darkSurface
                              : Colors.grey[200],
                          child: Icon(
                            Icons.place,
                            size: 64,
                            color: isDark
                                ? AppColors.neonBlue.withAlpha(100)
                                : Colors.grey,
                          ),
                        ),
                      )
                    : Container(
                        color: isDark
                            ? AppColors.darkSurface
                            : Colors.grey[200],
                        child: Icon(
                          Icons.place,
                          size: 64,
                          color: isDark
                              ? AppColors.neonBlue.withAlpha(100)
                              : Colors.grey,
                        ),
                      ),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black87,
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),

                // Badge'ler ve başlık
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: buildFlexibleContent(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            if (place.category != null)
                              _badge(
                                context,
                                place.category!,
                                Colors.blue,
                                isDark,
                              ),
                            if (place.category != null)
                              const SizedBox(width: 8),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          place.name,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          automaticallyImplyLeading: false,
          leading: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: CircularIconButton(
              icon: Icons.arrow_back,
              backgroundColor: buttonBgColor,
              iconColor: buttonIconColor,
              onPressed: () => context.pop(),
            ),
          ),
          actions: [
            // "Burayı ziyaret ettim" — sadece local sayaç. Puan sistemi açıkken
            // PointCollectionService ek olarak çalışır; bu toggle her zaman aktif.
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Consumer(
                builder: (context, ref, _) {
                  final isVisited = ref.watch(
                    userActivityProvider
                        .select((s) => s.isPlaceVisited(place.id)),
                  );
                  return CircularIconButton(
                    icon: isVisited
                        ? Icons.check_circle_rounded
                        : Icons.check_circle_outline_rounded,
                    backgroundColor: buttonBgColor,
                    iconColor: isVisited
                        ? Theme.of(context).colorScheme.primary
                        : buttonIconColor,
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final added = await ref
                          .read(userActivityProvider.notifier)
                          .togglePlaceVisited(place.id);
                      if (!context.mounted) return;
                      messenger.removeCurrentSnackBar();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            added
                                ? context.l10n.placeMarkedVisited
                                : context.l10n.placeUnmarkedVisited,
                          ),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (isAuthenticated)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: CircularIconButton(
                  icon: Icons.add_location_alt_outlined,
                  backgroundColor: buttonBgColor,
                  iconColor: buttonIconColor,
                  onPressed: () => AddToItinerarySheet.show(
                    context,
                    entityId: place.id,
                    entityName: place.name,
                    entityType: ItineraryEntityType.place,
                    entityImageUrl: imageUrl,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CircularIconButton(
                icon: isFavorite ? Icons.favorite : Icons.favorite_border,
                backgroundColor: buttonBgColor,
                iconColor: isFavorite
                    ? (Theme.of(context).brightness == Brightness.dark
                        ? AppColors.neonPink
                        : Theme.of(context).colorScheme.error)
                    : buttonIconColor,
                onPressed: () {
                  ref.read(favoritesProvider.notifier).toggleFavorite(
                        FavoriteEntityType.place,
                        place.id,
                      );
                },
              ),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 8),
              _buildQuickStats(context, place),
              if ((place.distance != null && place.distance!.isNotEmpty) ||
                  (FeatureFlags.pointsEnabled &&
                      place.points != null &&
                      place.points! > 0))
                const SizedBox(height: 24),
              // Puan: girişli kullanıcıda toplama kartı; misafirde giriş çağrısı
              // Points/gamification feature flag — kapalıyken section çıkmaz.
              if (FeatureFlags.pointsEnabled)
                _buildPointCollectionSection(context, place),
              if (place.description != null)
                _buildDescription(context, place.description!),
              if (place.description != null) const SizedBox(height: 24),
              if (place.notes != null && place.notes!.isNotEmpty)
                _buildNotes(context, place.notes!),
              if (place.notes != null && place.notes!.isNotEmpty) const SizedBox(height: 24),
              if (place.tags.isNotEmpty)
                _buildTags(context, place.tags),
              if (place.tags.isNotEmpty) const SizedBox(height: 24),
              if (photoUrls.isNotEmpty || videoUrl != null || videoUrls.isNotEmpty)
                _buildMediaGallery(context, photoUrls, videoUrl, videoUrls, baseUrl),
              if (photoUrls.isNotEmpty || videoUrl != null || videoUrls.isNotEmpty) const SizedBox(height: 24),
              if (place.address != null || place.phone != null)
                _buildContact(context, place),
              if (place.address != null || place.phone != null) const SizedBox(height: 24),
              if (place.openHours != null && place.openHours!.isNotEmpty)
                _buildOpeningHours(context, place.openHours!),
              if (place.openHours != null && place.openHours!.isNotEmpty) const SizedBox(height: 24),
              _buildActionButtons(context, place),
              SizedBox(height: AppNavBar.bottomPadding + 80),
            ]),
          ),
        ),
      ],
    );
  }

  /// mobile_analytics_todo.md §2.5 — scroll_75 (ekran başına bir kez).
  void _maybeFireScroll75() {
    if (_scroll75Fired) return;
    if (!scrollController.hasClients) return;
    final pos = scrollController.position;
    final max = pos.maxScrollExtent;
    if (max <= 0) return;
    if (pos.pixels / max >= 0.75) {
      _scroll75Fired = true;
      ref.read(analyticsServiceProvider).track(
        AnalyticsEvents.scroll75,
        properties: {
          'screen_name': 'place-detail',
          'entity_type': 'place',
          'entity_id': widget.id,
        },
      );
    }
  }

  /// Privacy-safe short hash for video URLs (analytics only).
  /// Same URL → same hash; ham URL gönderilmez.
  String _shortHash(String url) {
    var h = 0;
    for (final cu in url.codeUnits) {
      h = ((h << 5) - h + cu) & 0x7fffffff;
    }
    return h.toRadixString(16).padLeft(8, '0').substring(0, 8);
  }

  Future<void> _launchPhone(String phone) async {
    final sanitized = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (sanitized.isEmpty) return;

    // mobile_analytics_todo.md §2.4 — phone_tapped
    // Telefon numarası KENDİSİ analytics'e gitmiyor (PII). Sadece entity bilgisi.
    ref.read(analyticsServiceProvider).track(
      AnalyticsEvents.phoneTapped,
      properties: {
        'entity_type': 'place',
        'entity_id': widget.id,
      },
    );

    final uri = Uri(scheme: 'tel', path: sanitized);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchMapsForAddress(String address) async {
    if (address.trim().isEmpty) return;

    // mobile_analytics_todo.md §2.4 — directions_requested
    ref.read(analyticsServiceProvider).track(
      AnalyticsEvents.directionsRequested,
      properties: {
        'entity_type': 'place',
        'entity_id': widget.id,
        'mode': 'driving', // Google Maps default
      },
    );

    final query = Uri.encodeComponent(address);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  bool _scroll75Fired = false;

  @override
  void initState() {
    super.initState();
    initScrollController();
    scrollController.addListener(_maybeFireScroll75);
    _discoveryService = ref.read(discoveryServiceProvider);
    _pointCollectionNotifier = ref.read(pointCollectionProvider.notifier);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startDistanceUpdates();
    });

    // mobile_analytics_todo.md §2.2 — place_detail_opened
    // routeId varsa kullanıcı bir rota durağından açtı.
    ref.read(analyticsServiceProvider).track(
      AnalyticsEvents.placeDetailOpened,
      properties: {
        'place_id': widget.id,
        'source': widget.routeId != null
            ? AnalyticsSource.routeStop
            : AnalyticsSource.list,
      },
    );
  }

  @override
  void dispose() {
    _distanceTimer?.cancel();
    _discoveryService.cancelPending();
    final routeId = widget.routeId;
    if (routeId == null) {
      // Bağımsız mekan: Bu ekran timer'ın sahibi, kapatılınca durdur.
      _pointCollectionNotifier.stopProximityCheck(
        placeId: widget.id,
      );
    }
    // routeId != null ise (rota durağı): Timer'ı DURDURMUYORUZ.
    // Timer'ın sahipliği RouteDetailScreen'e ait — o ekran dispose olunca
    // tüm durak timer'larını kendisi temizler.
    // Burada durdurursak, kullanıcı geri döndüğünde
    // _routeProximityStarted=true olduğu için timer tekrar başlamaz → BUG.
    disposeScrollController();
    super.dispose();
  }

  /// Mesafeyi periyodik olarak güncelle (sadece distance alanı, sayfa yenilenmeden)
  void _startDistanceUpdates() {
    // İlk hesaplama
    _updateDistanceOnce();

    // 15 saniyede bir sessizce güncelle
    _distanceTimer?.cancel();
    _distanceTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _updateDistanceOnce(),
    );
  }

  Future<void> _updateDistanceOnce() async {
    try {
      final asyncPlace = ref.read(placeDetailProvider(widget.id));
      final place = asyncPlace.value;

      if (place == null || place.lat == null || place.lng == null) {
        return;
      }

      final userLocation = await LocationService.getCurrentLocation() ??
          await LocationService.getLastKnownLocation();

      if (userLocation == null) {
        return;
      }

      final distanceMeters = await DistanceHelper.calculateOSRMDistance(
        origin: userLocation,
        destination: LatLng(place.lat!, place.lng!),
      );

      if (distanceMeters == null) return;

      if (!mounted) return;

      final formatted = DistanceHelper.formatDistance(distanceMeters);
      ref.read(placeDistancesProvider.notifier).updateDistance(widget.id, formatted);

      // OSRM mesafesi kabul yarıçapı içindeyse proximity state'ini hemen güncelle.
      // Proximity timer bağımsız çalıştığı için GPS race condition nedeniyle
      // "tooFar" kalabilir; burada OSRM onayı ile zorla tetikleriz.
      if (distanceMeters <= kNearbyNotificationRadiusMeters && mounted) {
        final notifier = ref.read(pointCollectionProvider.notifier);
        final routeId = widget.routeId;
        if (routeId != null) {
          final pointsFromList = ref.read(_placePointsProvider(widget.id));
          notifier.updateRouteStopProximity(
            routeId: routeId,
            stop: RoutePlace(
              id: place.id,
              name: place.name,
              imageUrl: place.imageUrl,
              lat: place.lat,
              lng: place.lng,
              stopPoints: pointsFromList?.points ?? place.points,
              visited: place.visited || place.claimed,
            ),
          );
        } else if (place.points != null && place.points! > 0) {
          notifier.startProximityCheck(place);
        }
      }
    } catch (_) {
      // Mesafe isteğinde hata olursa sessizce yut
    }
  }

  void _startPointCollectionCheck(Place place) {
    final routeId = widget.routeId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final authed =
          ref.read(authProvider).status == AuthStatus.authenticated;
      if (!authed) {
        debugPrint('\u{1f6ab} [PlaceDetail] _startPointCollectionCheck skipped: not authenticated');
        return;
      }

      debugPrint(
        '\u{1f680} [PlaceDetail] _startPointCollectionCheck place.id=${place.id} '
        'points=${place.points} routeId=$routeId claimed=${place.claimed}',
      );

      if (routeId != null) {
        // Rota durağı olarak açıldı — rota stop proximity timer'ı başlat
        final stop = RoutePlace(
          id: place.id,
          name: place.name,
          imageUrl: place.imageUrl,
          lat: place.lat,
          lng: place.lng,
          stopPoints: place.points,
          visited: place.visited || place.claimed,
        );
        ref.read(pointCollectionProvider.notifier).startRouteStopProximityCheck(
          routeId: routeId,
          stop: stop,
        );
      } else {
        if (place.points == null || place.points == 0) return;
        // startProximityCheck her çağrıda claimed/campaign durumunu yeniden değerlendirir.
        // Timer de-duplication notifier tarafında yapılır.
        ref.read(pointCollectionProvider.notifier).startProximityCheck(place);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buttonBgColor = isDark
        ? Colors.black.withValues(alpha: 0.4)
        : Colors.white.withValues(alpha: 0.9);
    final buttonIconColor = isDark ? Colors.white : Colors.black87;
    
    final placeAsync = ref.watch(placeDetailProvider(widget.id));
    // Sadece BU place'in distance'ını izle — diğer place distance değişimleri rebuild tetiklemez
    final overrideDistance = ref.watch(
      placeDistancesProvider.select((distances) => distances[widget.id]),
    );
    // Listeden gelen puan bilgisini izle (enrichment tamamlandiginda reactive guncellenir)
    final pointsFromList = ref.watch(_placePointsProvider(widget.id));
    const config = ApiConfig.prod;
    final baseUrl = config.baseUrl;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && context.canPop()) {
          context.pop();
        }
      },
      child: Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: false,
        body: placeAsync.when(
          data: (rawPlace) {
            if (rawPlace != null) {
              if (rawPlace.name.isEmpty || rawPlace.id.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              // Listeden gelen puan + kampanya bilgisini merge et.
              // claimed/visited/campaign her zaman list enrichment'tan gelir;
              // detail API bunları döndürmez.
              var place = rawPlace;
              if (pointsFromList != null) {
                place = place.copyWith(
                  points: pointsFromList.points ?? place.points,
                  visited: pointsFromList.visited,
                  claimed: pointsFromList.claimed,
                  campaign: pointsFromList.campaign,
                );
              }
              // Puan toplama proximity kontrolünü sadece bir kez başlat.
              // Her build'de çağrılırsa claimed place'lerde sonsuz
              // rebuild döngüsü oluşur (update → rebuild → update → ...).
              if (!_proximityCheckStarted) {
                _proximityCheckStarted = true;
                _startPointCollectionCheck(place);
              }
              return _buildBody(
                place: place,
                overrideDistance: overrideDistance,
                isDark: isDark,
                buttonBgColor: buttonBgColor,
                buttonIconColor: buttonIconColor,
                baseUrl: baseUrl,
              );
            }
            // place null: fallback olarak "bulunamadı"
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Theme.of(context).hintColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.errPlaceNotFound,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Text(context.l10n.btnGoBack),
                  ),
                ],
              ),
            );
          },
          loading: () => _buildLoadingSkeleton(context, isDark, buttonBgColor, buttonIconColor),
          error: (error, stack) {
            // Hata durumunda cached place varsa onu göster, yoksa hata mesajı
            var cached = placeAsync.value;
            if (cached != null && cached.name.isNotEmpty && cached.id.isNotEmpty) {
              if (pointsFromList != null) {
                cached = cached.copyWith(
                  points: pointsFromList.points ?? cached.points,
                  visited: pointsFromList.visited,
                  claimed: pointsFromList.claimed,
                  campaign: pointsFromList.campaign,
                );
              }
              return _buildBody(
                place: cached,
                overrideDistance: overrideDistance,
                isDark: isDark,
                buttonBgColor: buttonBgColor,
                buttonIconColor: buttonIconColor,
                baseUrl: baseUrl,
              );
            }
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Theme.of(context).hintColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    error.toString(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Text(context.l10n.btnGoBack),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Giriş yapmış kullanıcı: [CollectPointsCard]. Misafir: giriş çağrısı + puan bilgisi.
  Widget _buildPointCollectionSection(BuildContext context, Place place) {
    final authed =
        ref.watch(authProvider.select((s) => s.status == AuthStatus.authenticated));
    if (!authed) {
      return _buildGuestPointsPrompt(context, place);
    }
    return _buildPointCollectionCard(context, place);
  }

  /// Misafir kullanıcılar için: CMS’den gelen puan varsa göster, yoksa genel uyarı.
  Widget _buildGuestPointsPrompt(BuildContext context, Place place) {
    final pts = place.points;
    final hasPoints = pts != null && pts > 0;
    final message = hasPoints
        ? context.l10n.msgPointsGuestLoginWithValue(pts)
        : context.l10n.msgPointsGuestLoginGeneric;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => context.push('/login'),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.stars_rounded,
                  color: AppColors.neonOrange,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: hasPoints
                        ? Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            )
                        : Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).hintColor,
                            ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () => context.push('/login'),
                  child: Text(context.l10n.btnLogin),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPointCollectionCard(BuildContext context, Place place) {
    final routeId = widget.routeId;

    final effectivePoints = routeId != null ? place.points : place.points;
    if (effectivePoints == null || effectivePoints == 0) return const SizedBox.shrink();

    final allStates = ref.watch(pointCollectionProvider);

    PointCollectionState collectionState;
    if (routeId != null) {
      final key = '$routeId:${place.id}';
      final raw = allStates[key] ?? const PointCollectionState();
      collectionState = (raw.status == PointCollectionStatus.noPoints && effectivePoints > 0)
          ? raw.copyWith(status: PointCollectionStatus.tooFar, availablePoints: effectivePoints)
          : raw;
    } else {
      final raw = allStates[place.id] ?? const PointCollectionState();
      collectionState = (raw.status == PointCollectionStatus.noPoints && effectivePoints > 0)
          ? raw.copyWith(status: PointCollectionStatus.tooFar, availablePoints: effectivePoints)
          : raw;
      debugPrint(
        '\u{1f3af} [PlaceDetail] _buildCard place.id=${place.id} '
        'stateKeys=${allStates.keys.toList()} '
        'raw=${raw.status.name} final=${collectionState.status.name} pts=$effectivePoints',
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: CollectPointsCard(
        state: collectionState,
        onCollect: () {
          final authState = ref.read(authProvider);
          if (authState.status != AuthStatus.authenticated) {
            context.push('/login');
            return;
          }
          if (routeId != null) {
            ref.read(pointCollectionProvider.notifier).collectRouteStop(
              routeId: routeId,
              placeId: place.id,
            );
          } else {
            ref.read(pointCollectionProvider.notifier).collectPlace(place.id);
          }
        },
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context, Place place) {
    final hasDistance = place.distance != null && place.distance!.isNotEmpty;
    // Points/gamification feature flag — puan istatistiği gizlenir.
    final hasPoints = FeatureFlags.pointsEnabled &&
        place.points != null &&
        place.points! > 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!hasDistance && !hasPoints) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (hasDistance)
            _statItem(
              context,
              icon: Icons.near_me_outlined,
              iconColor: isDark
                  ? AppColors.neonCyan
                  : Theme.of(context).colorScheme.primary,
              title: place.distance!,
              subtitle: context.l10n.lblDistanceLabel,
            ),
          if (hasDistance && hasPoints) _divider(context),
          if (hasPoints)
            _buildPointsStatItem(context, place, isDark),
        ],
      ),
    );
  }

  Widget _statItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).hintColor,
              ),
        ),
      ],
    );
  }

  Widget _divider(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: Theme.of(context).dividerColor.withAlpha(102),
    );
  }

  /// Kampanya durumuna göre puan stat item'ı.
  Widget _buildPointsStatItem(BuildContext context, Place place, bool isDark) {
    final isClaimed = place.isPointsClaimed;
    final campaign = place.campaign;

    // Kampanya yakında
    if (campaign != null && campaign.isUpcoming) {
      return _statItem(
        context,
        icon: Icons.schedule_rounded,
        iconColor: isDark ? AppColors.neonBlue : Colors.blueGrey,
        title: '+${place.points}',
        subtitle: context.l10n.lblComingSoon,
      );
    }

    // Kampanya bitti
    if (campaign != null && campaign.isExpired) {
      return _statItem(
        context,
        icon: Icons.event_busy_rounded,
        iconColor: Colors.grey,
        title: '${place.points}',
        subtitle: 'Bitti',
      );
    }

    // Puan alındı — yeşil ikon, puan değeri görünür
    if (isClaimed) {
      return _statItem(
        context,
        icon: Icons.check_circle,
        iconColor: AppColors.success,
        title: '+${place.points}',
        subtitle: context.l10n.pointsCollected,
      );
    }

    // Aktif kampanya, henüz alınmamış
    return _statItem(
      context,
      icon: Icons.stars_rounded,
      iconColor: isDark ? AppColors.neonOrange : AppColors.warningDark,
      title: '+${place.points}',
      subtitle: 'Puan',
    );
  }

  Widget _buildDescription(BuildContext context, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.lblAbout,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).hintColor,
                height: 1.6,
              ),
        ),
      ],
    );
  }

  Widget _buildNotes(BuildContext context, String notes) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.neonBlue.withAlpha(20)
            : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? AppColors.neonBlue.withAlpha(60)
              : Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.note_outlined,
                size: 18,
                color: isDark
                    ? AppColors.neonBlue
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.lblNotes,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.neonBlue
                          : Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            notes,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? Colors.white.withAlpha(220)
                      : Theme.of(context).colorScheme.onSurface,
                  height: 1.6,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTags(BuildContext context, List<String> tags) {
    if (tags.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.lblTags,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags.map((tag) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.neonPurple.withAlpha(30)
                    : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? AppColors.neonPurple.withAlpha(100)
                      : Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                tag,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.neonPurple
                          : Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMediaGallery(
      BuildContext context, 
      List<String> photoUrls, 
      String? videoUrl,
      List<String> videoUrls,
      String baseUrl) {
    final hasPhotos = photoUrls.isNotEmpty;
    
    // Unique video URL'leri topla (duplicate'leri önle)
    final Set<String> uniqueVideoUrls = {};
    if (videoUrl != null) {
      uniqueVideoUrls.add(videoUrl);
    }
    for (final video in videoUrls) {
      uniqueVideoUrls.add(video);
    }
    
    final hasVideo = uniqueVideoUrls.isNotEmpty;
    final videoCount = uniqueVideoUrls.length;
    
    if (!hasPhotos && !hasVideo) return const SizedBox.shrink();

    // Tüm medya öğelerini birleştir (videolar başta)
    final List<MediaItem> mediaItems = [];
    
    // Unique videoları ekle
    for (final video in uniqueVideoUrls) {
      mediaItems.add(MediaItem(type: MediaType.video, url: video));
    }
    
    // Fotoğrafları ekle
    mediaItems.addAll(
      photoUrls.map((url) => MediaItem(type: MediaType.photo, url: url)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hasVideo && hasPhotos 
              ? context.l10n.lblPhotosAndVideo
              : hasVideo 
                  ? context.l10n.lblVideo
                  : context.l10n.lblPhotos,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: mediaItems.length,
            separatorBuilder: (context, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final item = mediaItems[index];
              return GestureDetector(
                onTap: () {
                  if (item.type == MediaType.video) {
                    // mobile_analytics_todo.md §2.3 — video_play_started
                    ref.read(analyticsServiceProvider).track(
                      AnalyticsEvents.videoPlayStarted,
                      properties: {
                        'entity_type': 'place',
                        'entity_id': widget.id,
                        // Tam URL göndermiyoruz (privacy); ilk 12 char MD5-style
                        // hash yeterli (hangi videonun başlatıldığını ayırt eder).
                        'video_url_hash': _shortHash(item.url),
                      },
                    );
                    // Video oynatıcıyı aç
                    // rootNavigator: true => shell'in (bottom bar) üstünde yeni tam ekran route açar
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (context) => VideoPlayerViewer(
                          videoUrl: item.url,
                          analyticsEntityType: 'place',
                          analyticsEntityId: widget.id,
                        ),
                      ),
                    );
                  } else {
                    // mobile_analytics_todo.md §2.3 — gallery_opened
                    ref.read(analyticsServiceProvider).track(
                      AnalyticsEvents.galleryOpened,
                      properties: {
                        'entity_type': 'place',
                        'entity_id': widget.id,
                        'image_count': photoUrls.length,
                      },
                    );
                    // Fotoğraf galerisini aç
                    // photoIndex = index - video sayısı
                    final photoIndex = index - videoCount;
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (context) => PhotoGalleryViewer(
                          photoUrls: photoUrls,
                          initialIndex: photoIndex.clamp(0, photoUrls.length - 1),
                        ),
                      ),
                    );
                  }
                },
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: item.type == MediaType.video
                          ? Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.grey[900]!,
                                    Colors.grey[800]!,
                                  ],
                                ),
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Video thumbnail - ilk fotoğraf varsa onu göster
                                  if (photoUrls.isNotEmpty)
                                    CachedImage(
                                      imageUrl: photoUrls[0],
                                      width: 120,
                                      height: 120,
                                      fit: BoxFit.cover,
                                      memCacheWidth: (120 * MediaQuery.of(context).devicePixelRatio).round(),
                                      memCacheHeight: (120 * MediaQuery.of(context).devicePixelRatio).round(),
                                    ),
                                  // Dark overlay
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.3),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Play icon overlay
                                  Center(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.9),
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(10),
                                      child: const Icon(
                                        Icons.play_arrow,
                                        color: Colors.black87,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : CachedImage(
                              imageUrl: item.url,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              memCacheWidth: (120 * MediaQuery.of(context).devicePixelRatio).round(),
                              memCacheHeight: (120 * MediaQuery.of(context).devicePixelRatio).round(),
                              errorWidget: Container(
                                width: 120,
                                height: 120,
                                color: Colors.grey[200],
                                child: const Icon(Icons.image_not_supported),
                              ),
                            ),
                    ),
                    // Video badge
                    if (item.type == MediaType.video)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.play_circle_outline,
                                color: Colors.white,
                                size: 12,
                              ),
                              SizedBox(width: 2),
                              Text(
                                'Video',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContact(BuildContext context, Place place) {
    final hasAddress = place.address != null && place.address!.isNotEmpty;
    final hasPhone = place.phone != null && place.phone!.isNotEmpty;
    
    if (!hasAddress && !hasPhone) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.lblContact,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        if (hasAddress)
          _contactItem(
            context,
            icon: Icons.place_outlined,
            iconColor: Theme.of(context).colorScheme.primary,
            title: place.address!,
            onTap: () {
              _launchMapsForAddress(place.address!);
            },
          ),
        if (hasAddress && hasPhone) const SizedBox(height: 8),
        if (hasPhone)
          _contactItem(
            context,
            icon: Icons.phone_outlined,
            iconColor: Colors.green,
            title: place.phone!,
            onTap: () {
              _launchPhone(place.phone!);
            },
          ),
      ],
    );
  }

  Widget _contactItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).hintColor,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: Theme.of(context).hintColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOpeningHours(BuildContext context, String openHours) {
    // API'den gelen openHours string'ini parse et
    // Format: "09:00 - 17:00" veya "Pazartesi: 09:00 - 17:00" gibi olabilir
    final lines = openHours.split('\n').where((l) => l.trim().isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.lblOpeningHours,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          line,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, Place place) {
    final hasArModel = place.hasArModel;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  if (place.lat != null && place.lng != null) {
                    ref.read(routeIntentProvider.notifier).set(RouteIntent(
                      destination: LatLng(place.lat!, place.lng!),
                      placeId: place.id,
                    ));
                    context.go('/map');
                  } else {
                    context.go('/map');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.navigation, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.btnGetDirections,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (hasArModel) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    // Native AR (Scene Viewer / Quick Look) — in-app SceneView
                    // render'ı orta-segment cihazlarda donduğu için. iOS'ta
                    // .glb → .usdz dönüşümü sırasında spinner göster.
                    launchArViewerWithProgress(
                      context,
                      place.arModelUrl!,
                      title: place.name,
                      errorMessage: 'AR görüntüleyici açılamadı',
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.view_in_ar, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.arViewWith,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _badge(BuildContext context, String label, Color color, bool isDark) {
    final badgeColor = isDark
        ? color.withValues(alpha: 0.8)
        : color.withAlpha(230);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton(
    BuildContext context,
    bool isDark,
    Color buttonBgColor,
    Color buttonIconColor,
  ) {
    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          title: buildCollapsingTitle(
            context,
            title: context.l10n.loadingMessage,
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                SkeletonLoader(
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: BorderRadius.zero,
                ),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black87,
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          automaticallyImplyLeading: false,
          leading: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: CircularIconButton(
              icon: Icons.arrow_back,
              backgroundColor: buttonBgColor,
              iconColor: buttonIconColor,
              onPressed: () => context.pop(),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 8),
              // Quick stats skeleton
              SkeletonLoader(
                width: double.infinity,
                height: 80,
                borderRadius: BorderRadius.circular(18),
              ),
              const SizedBox(height: 24),
              // Description skeleton
              SkeletonLoader(
                width: double.infinity,
                height: 20,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              SkeletonLoader(
                width: double.infinity,
                height: 20,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              SkeletonLoader(
                width: MediaQuery.of(context).size.width * 0.7,
                height: 20,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 24),
              // Tags skeleton
              Row(
                children: [
                  SkeletonLoader(
                    width: 80,
                    height: 32,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  const SizedBox(width: 8),
                  SkeletonLoader(
                    width: 100,
                    height: 32,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  const SizedBox(width: 8),
                  SkeletonLoader(
                    width: 70,
                    height: 32,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Media gallery skeleton
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 3,
                  separatorBuilder: (context, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    return SkeletonLoader(
                      width: 120,
                      height: 120,
                      borderRadius: BorderRadius.circular(12),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              // Contact skeleton
              SkeletonLoader(
                width: double.infinity,
                height: 100,
                borderRadius: BorderRadius.circular(12),
              ),
              const SizedBox(height: 24),
              // Opening hours skeleton
              SkeletonLoader(
                width: double.infinity,
                height: 80,
                borderRadius: BorderRadius.circular(12),
              ),
              const SizedBox(height: 24),
              // Action buttons skeleton
              SkeletonLoader(
                width: double.infinity,
                height: 56,
                borderRadius: BorderRadius.circular(14),
              ),
              SizedBox(height: AppNavBar.bottomPadding + 80),
            ]),
          ),
        ),
      ],
    );
  }
}
