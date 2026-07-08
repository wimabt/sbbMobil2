import 'dart:io' show Platform;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:geolocator/geolocator.dart' show LocationPermission;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../l10n/l10n.dart';
import '../../auth/providers/auth_provider.dart';
import '../../notifications/presentation/providers/notification_badge_provider.dart';
import '../../profile/presentation/widgets/user_qr_modal.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/permissions/pre_permission_sheet.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/providers/user_location_provider.dart';
import '../../places/presentation/providers/place_detail_provider.dart';
import '../../places/presentation/providers/places_provider.dart';
import '../../routes/presentation/providers/routes_provider.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../api/api_client.dart';
import '../../../data/repositories/mobile_categories_repository.dart';
import 'providers/discovery_feed_provider.dart';
import 'providers/home_config_provider.dart';
import 'providers/personalized_places_provider.dart';
import 'providers/points_provider.dart';
import '../../personalization/domain/personalization_engine.dart';
import '../../personalization/domain/personalization_profile.dart';
import '../../personalization/providers/personalization_profile_provider.dart';
import '../../personalization/providers/category_interest_map_provider.dart';
import '../../onboarding/presentation/providers/onboarding_provider.dart';
import '../../../core/services/analytics_events.dart';
import '../../../core/services/analytics_service.dart';
import '../../../data/models/discovery_feed.dart';
import '../../../data/models/place.dart';
import 'widgets/active_campaign_section.dart';
import 'widgets/featured_places_section.dart';
import 'widgets/home_discovery_routes_section.dart';
import 'widgets/home_city_guide_blog_section.dart';
import 'models/city_guide_blog_item.dart';
import '../../blog/presentation/providers/blog_provider.dart';
import '../../../data/models/blog.dart';
import 'widgets/hero_section.dart';
import 'widgets/points_card.dart';
import 'widgets/categories_section.dart';
import 'widgets/quick_access_grid.dart' show QuickAccessItem, quickAccessIconColorForRoute;
import '../../../core/widgets/nearby_points_banner.dart';
import '../../auth/presentation/widgets/pending_deletion_banner.dart';

// =============================================================================
// Derived Providers — Filtreleme/sıralama build() dışında, sadece veri
// değiştiğinde yeniden hesaplanır (her frame'de değil)
// =============================================================================

/// Home ekranı için öne çıkan mekanları hazır tutan derived provider.
/// placesProvider.allPlaces veya placeDistancesProvider değiştiğinde yeniden hesaplanır.
/// Build() içinde O(n log n) iş yapmak yerine, Riverpod cache'inde tutulur.
final homeFeaturedPlacesProvider = Provider.autoDispose<List<FeaturedPlace>>((ref) {
  final allPlaces = ref.watch(placesProvider.select((s) => s.allPlaces));
  final distances = ref.watch(placeDistancesProvider);
  final categoryNames = ref.watch(mobileCategoryNamesSyncProvider);

  // CMS base URL — içerik panelindeki görseller için
  final config = ApiConfig.current;
  final baseUrl = config.baseUrl;

  return allPlaces
      .where((p) => p.featured)
      .map((p) {
        // Place.imageUrl genelde relative path (/uploads/...) olabilir.
        // Ana sayfa kartı için tam URL'ye çevir.
        final rawImage = p.imageUrl ?? '';
        final resolvedImage =
            buildImageUrl(rawImage, baseUrl: baseUrl) ?? rawImage;

        return FeaturedPlace(
          id: p.id,
          title: p.name,
          category: resolveCategoryDisplayName(
            p.categoryId,
            p.category,
            categoryNames,
          ),
          distance: distances[p.id] ?? p.distance ?? '',
          image: resolvedImage,
          points: p.points,
          visited: p.visited,
          claimed: p.claimed,
          campaignStatus: p.campaign?.status.value,
        );
      })
      .where((fp) => fp.category.isNotEmpty)
      .toList()
    ..sort((a, b) => a.title.compareTo(b.title));
});

/// Home ekranı loading durumu — sadece ilk yüklemede true döner.
final homePlacesLoadingProvider = Provider.autoDispose<bool>((ref) {
  final isLoading = ref.watch(placesProvider.select((s) => s.isLoading));
  final isEmpty = ref.watch(placesProvider.select((s) => s.allPlaces.isEmpty));
  return isLoading && isEmpty;
});

/// Home ekranı hata durumu — sadece veri yokken hata varsa döner.
final homePlacesErrorProvider = Provider.autoDispose<String?>((ref) {
  final error = ref.watch(placesProvider.select((s) => s.error));
  final isEmpty = ref.watch(placesProvider.select((s) => s.allPlaces.isEmpty));
  return (error != null && isEmpty) ? error : null;
});

/// Ana içerikte üst üste gelen bölümler (öne çıkan → kampanya → duyuru) arası tutarlı boşluk.
/// lg (16) çok sıkıydı; xl (24) rahat ama xxl kadar geniş değil.
const double _homeSectionSpacing = AppSpacing.xxl;

/// §6.4 — "Sizin İçin" bölümünü göstermek için gereken minimum öneri sayısı.
/// Zayıf öneriyle (1–2 sonuç) kullanıcı güvenini sarsmamak için eşik.
const int _kMinPersonalized = 3;

/// Home Screen - City Guide Application
/// 
/// Light Theme: Clean, airy, and inviting with soft pale grey-blue background
/// Dark Theme: Sleek, premium, and cinematic with OLED-friendly dark charcoal
/// 
/// Material Design 3 influence, minimalist, ample whitespace, professional layout
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // mobile_integ.md §3.2 madde 3 — Discovery feed önbellekte olmayan place ID
  // döndürdüğünde tek seferlik `placesProvider` refresh tetikliyoruz. Tekrar
  // tetiklenmemesi için bir bayrak tutuyoruz.
  bool _refreshingForMissingIds = false;

  // §6.4 — "Sizin İçin" bölümü ilk kez göründüğünde tek seferlik analytics.
  bool _personalizedTracked = false;

  // mobile_integ.md §3.2 madde 7 — Foreground'a dönüşte 5 dk eski feed'i
  // otomatik yenile.
  static const Duration _foregroundStaleThreshold = Duration(minutes: 5);
  DateTime? _backgroundedAt;

  // Edge-to-edge hero: status bar ikonları hero üstündeyken beyaz, kullanıcı
  // hero'yu geçip içeriğe (tema zemini) kaydırınca temaya göre olmalı. Aksi
  // halde açık temada beyaz ikonlar açık zeminde kaybolur.
  final ScrollController _scrollController = ScrollController();
  bool _overHero = true;

  /// Hero'nun "geçildi" sayılacağı eşik (≈ başlık/arama çubuğu görünürken hâlâ
  /// hero üstünde sayılır). Hero yüksekliğine yakın bir değer.
  static const double _heroOverlayThreshold = 220;

  void _onScroll() {
    final over = _scrollController.offset < _heroOverlayThreshold;
    if (over != _overHero) {
      setState(() => _overHero = over);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    // §10.6.3 — onboarding sonrası ilk home açılışında, açıklamalı tek seferlik
    // bildirim izni teklifi (soğuk OS prompt yerine).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Sıralı: önce bildirim, ardından konum — iki sheet aynı anda açılmasın.
      await _maybePromptNotificationPermission();
      await _maybePromptLocationPermission();
    });
  }

  /// İlk açılışta bir kez: bildirim izni yoksa önce [PrePermissionSheet] ile
  /// "ne için" açıklanır, kullanıcı onaylarsa OS izni istenir. Seçimden
  /// bağımsız olarak bir daha gösterilmez (ayarlardan her zaman açılabilir).
  Future<void> _maybePromptNotificationPermission() async {
    if (!(Platform.isAndroid || Platform.isIOS)) return;
    const flag = 'notif_rationale_shown_v1';
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(flag) == true) return;
    if (ref.read(notificationProvider).hasPushPermission) {
      await prefs.setBool(flag, true);
      return;
    }
    await prefs.setBool(flag, true); // tek sefer — kullanıcı seçiminden bağımsız
    if (!mounted) return;
    final proceed =
        await PrePermissionSheet.show(context, PrePermissionKind.notification);
    if (!proceed || !mounted) return;
    await ref.read(notificationProvider.notifier).requestPushPermission();
  }

  /// §10.6.3 — İlk açılışta bir kez: konum izni yoksa açıklamalı
  /// [PrePermissionSheet] ile "ne için" anlatılır, kullanıcı onaylarsa OS izni
  /// istenir. İzin verilirse mesafeler beklemeden (throttle'sız) hesaplanır.
  /// Ana sayfadaki eski [DiscoveryLocationCta] kaldırıldığı için ilk kez
  /// kullananlar mesafe alamıyordu (illa harita/detay gerekiyordu) — bu akış
  /// o regresyonu kapatır. Seçimden bağımsız bir daha gösterilmez.
  Future<void> _maybePromptLocationPermission() async {
    if (!(Platform.isAndroid || Platform.isIOS)) return;
    const flag = 'location_rationale_shown_v1';
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(flag) == true) return;

    final current = await LocationService.checkPermission();
    final alreadyGranted = current == LocationPermission.whileInUse ||
        current == LocationPermission.always;
    // Zaten verilmiş veya kalıcı reddedilmiş (ayarlardan açılır) → sadece
    // bayrağı işaretle, rationale gösterme.
    if (alreadyGranted || current == LocationPermission.deniedForever) {
      await prefs.setBool(flag, true);
      return;
    }

    await prefs.setBool(flag, true); // tek sefer — kullanıcı seçiminden bağımsız
    if (!mounted) return;
    final proceed =
        await PrePermissionSheet.show(context, PrePermissionKind.location);
    if (!proceed || !mounted) return;

    final result = await LocationService.requestPermission();
    final granted = result == LocationPermission.whileInUse ||
        result == LocationPermission.always;
    if (!granted || !mounted) return;

    // İzin alındı → konumu ısıt ve mesafeleri hemen hesapla.
    await ref.read(userLocationProvider.notifier).getOrFetch();
    ref.read(placesProvider.notifier).recalculateDistances(force: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final since = _backgroundedAt;
      _backgroundedAt = null;
      if (since != null &&
          DateTime.now().difference(since) >= _foregroundStaleThreshold) {
        ref.invalidate(discoveryFeedProvider);
      }
      // Arka planda push gelmiş olabilir → okunmamış bildirim noktasını tazele.
      ref.invalidate(notificationBadgeProvider);
    }
  }

  /// §6.9 — AppBar sağ üstünden chatbot'a giriş.
  /// Eski harita kısayolu yerine eklendi; haritaya alttaki merkez FAB
  /// (ScaffoldShell) üzerinden erişim devam ediyor.
  Future<void> _openChatbot() async {
    await Haptics.selection();
    if (!mounted) return;
    context.push('/chatbot');
  }

  void _maybeRefreshPlacesForMissingIds(DiscoveryFeed feed) {
    if (_refreshingForMissingIds) return;
    final allIds = <String>{
      ...feed.nearby.where((r) => r.isPlace).map((r) => r.id),
      ...feed.popular.where((r) => r.isPlace).map((r) => r.id),
      // "Yeni Eklenenler" gösterilmiyor → ID'leri prefetch'e dahil edilmez.
    };
    if (allIds.isEmpty) return;
    final known =
        ref.read(placesProvider).allPlaces.map((p) => p.id).toSet();
    final missing = allIds.difference(known);
    if (missing.isEmpty) return;
    _refreshingForMissingIds = true;
    ref
        .read(placesProvider.notifier)
        .loadPlaces(refresh: true)
        .whenComplete(() {
      if (mounted) _refreshingForMissingIds = false;
    });
  }

  /// §6.4 — "Sizin İçin" ilk kez render edildiğinde tek seferlik analytics.
  /// `source`: yalnızca açık ilgi (`explicit`), yalnızca davranış (`implicit`)
  /// veya ikisi birden (`mixed`).
  void _maybeTrackPersonalized(
    bool shown,
    int itemCount,
    PersonalizationProfile profile,
  ) {
    if (!shown || _personalizedTracked) return;
    _personalizedTracked = true;
    final explicitCount =
        ref.read(onboardingProvider.select((s) => s.interests)).length;
    final String source;
    if (explicitCount == 0) {
      source = 'implicit';
    } else if (profile.weights.length > explicitCount) {
      source = 'mixed';
    } else {
      source = 'explicit';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(analyticsServiceProvider).track(
        AnalyticsEvents.personalizedSectionShown,
        properties: {
          'item_count': itemCount,
          'interests_count': profile.weights.length,
          'source': source,
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    // Auth state — giriş durumu için
    final authState = ref.watch(authProvider);
    final isLoggedIn = authState.status == AuthStatus.authenticated;

    final quickAccess = [
      // Kampanyalar puan/gamification feature'ının parçası — flag arkasında.
      if (FeatureFlags.pointsEnabled)
        QuickAccessItem(
          icon: Icons.campaign_rounded,
          label: l10n.quickCampaigns,
          route: '/campaigns',
        ),
      QuickAccessItem(
        icon: Icons.alt_route_rounded,
        label: l10n.quickRoutes,
        route: '/routes',
      ),
      QuickAccessItem(
        icon: Icons.restaurant_rounded,
        label: l10n.quickFood,
        route: '/recipes',
      ),
      QuickAccessItem(
        icon: Icons.event_rounded,
        label: l10n.quickEvents,
        route: '/events',
      ),
      QuickAccessItem(
        icon: Icons.view_in_ar_rounded,
        label: l10n.quickArScanner,
        route: '/qr-ar-scanner',
      ),
      // §6.8.3 — Çevremdeki AR noktaları (geospatial). Canlı kamera üzerine
      // yön/mesafe tabanlı POI kartları bindiren kamera-overlay ekranı.
      QuickAccessItem(
        icon: Icons.travel_explore_rounded,
        label: l10n.homeAroundMeAr,
        route: '/ar-camera',
      ),
    ];

    // ============================================================================
    // OPTİMİZASYON: Derived provider'lar kullanılıyor
    // Filtreleme/sıralama build() dışında yapılır, sonuç Riverpod cache'inde tutulur
    // Sadece kaynak veri değiştiğinde yeniden hesaplanır (her rebuild'de değil)
    // ============================================================================
    // mobile_integ.md §3.2 madde 3 — Discovery feed referansları geldiğinde,
    // önbellekte olmayan ID'ler varsa arka planda `placesProvider` refresh
    // tetikle. Kart skip + arka plan refresh kontratı.
    ref.listen<AsyncValue<DiscoveryFeed>>(discoveryFeedProvider,
        (_, next) {
      final feed = next.asData?.value;
      if (feed != null) _maybeRefreshPlacesForMissingIds(feed);
    });

    final featured = ref.watch(homeFeaturedPlacesProvider);
    final personalized = ref.watch(personalizedPlacesProvider);
    final discoveryAsync = ref.watch(discoveryFeedProvider);
    final isLoading = ref.watch(homePlacesLoadingProvider);
    final hasError = ref.watch(homePlacesErrorProvider) != null;
    // Points feature flag — kapalıyken bu provider'ı dinleme bile yapma.
    final pointsAsync = FeatureFlags.pointsEnabled
        ? ref.watch(pointsBalanceProvider)
        : null;

    // Hero görseli: panelden yönetilen config (önbellekli; ilk frame'de doğru
    // hizalamayla gelir → kayma yok). Hata/boş → bundle varsayılanı.
    final heroConfig = ref.watch(homeHeroConfigProvider);
    final heroImageUrl = heroConfig.imageUrl == null
        ? null
        : rewriteStorageUrl(
            buildImageUrl(
                  heroConfig.imageUrl,
                  baseUrl: AuthApiConfig.current.baseUrl,
                ) ??
                '',
          );

    final discoveryFeed = discoveryAsync.asData?.value;
    // §6.4 — "Sizin İçin" artık sunucu feed'i varken de en üstte gösterilir
    // (eski "yalnızca feed null ise göster" fallback davranışı kaldırıldı).
    // En az [_kMinPersonalized] sonuç şartıyla zayıf öneri gizlenir.
    final showPersonalized = personalized.length >= _kMinPersonalized;
    final profile = ref.watch(personalizationProfileProvider);
    _maybeTrackPersonalized(showPersonalized, personalized.length, profile);

    void openMyWalletQr() {
      UserQrModal.show(
        context,
        userId: authState.user?.id ?? 'USR',
        userName: _homeQrDisplayName(authState.user),
      );
    }

    // Ortak padding sabiti — her sliver'da tekrar yazmamak için
    const hPad = EdgeInsets.symmetric(horizontal: AppSpacing.lg);

    // Edge-to-edge hero: hero üstündeyken status bar ikonları beyaz; içeriğe
    // kaydırınca temaya göre (açık temada koyu ikon) — okunabilirlik için.
    final overlayStyle = _overHero
        ? SystemUiOverlayStyle.light
        : (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: isDark
            ? AppColors.darkBackground
            : AppColors.lightBackground,
        // Hero, status bar'ın arkasına kadar uzasın (eski opak üst bar kaldırıldı).
        extendBodyBehindAppBar: true,
        drawer: _HomeNavigationDrawer(
          isDark: isDark,
          appTitle: l10n.appTitle,
          quickAccessItems: quickAccess,
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            await Haptics.selection();
            if (FeatureFlags.pointsEnabled) {
              ref.invalidate(pointsBalanceProvider);
            }
            ref.invalidate(placesProvider);
            ref.invalidate(routesProvider);
            ref.invalidate(discoveryFeedProvider);
            try {
              await ref.read(placesProvider.notifier).loadPlaces();
            } catch (_) {}
          },
          child: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
            // ── 1) Hero Section ──────────────────────────────────────
            // Menü (sol) ve asistan (sağ) butonları artık görselin üstünde
            // yüzer; eski 52px opak şerit kaldırıldı.
            SliverToBoxAdapter(
              child: RepaintBoundary(
                child: HeroSection(
                  title: l10n.heroWelcome,
                  subtitle: l10n.heroSubtitle,
                  imageUrl: heroImageUrl,
                  imageAlignment: heroConfig.alignment,
                  imageFit:
                      heroConfig.isContain ? BoxFit.contain : BoxFit.cover,
                  topLeading: _HeroGlassIconButton(
                    icon: Icons.menu_rounded,
                    semanticLabel: l10n.lblMenu,
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  topTrailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _NotificationBellButton(
                        onTap: () => context.push('/notifications'),
                      ),
                      const SizedBox(width: 8),
                      _AssistantTopBarButton(
                        semanticLabel: 'Samsun Asistan',
                        onTap: _openChatbot,
                        primary: Theme.of(context).colorScheme.primary,
                        tertiary: Theme.of(context).colorScheme.tertiary,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // KVKK — hesap silme pending banner (cold start /account/status).
            // Banner sadece pending durumda görünür; aksi takdirde 0px alır.
            const SliverToBoxAdapter(child: PendingDeletionBanner()),

            // ── 2) Rounded-top background overlap + top spacing ──────
            SliverToBoxAdapter(
              child: Transform.translate(
                offset: const Offset(0, -16),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark 
                        ? AppColors.darkBackground 
                        : AppColors.lightBackground,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.xxl),
                    ),
                  ),
                  height: AppSpacing.xl + 16, // spacing + overlap compensation
                ),
              ),
            ),

            // ── 3) Points Card (giriş yapılmışsa) ───────────────────
            // Points/gamification feature flag — kapalıyken hem kart hem
            // ardından gelen spacing & nearby banner çıkar.
            if (FeatureFlags.pointsEnabled && isLoggedIn && pointsAsync != null)
              SliverToBoxAdapter(
                child: RepaintBoundary(
                  child: Padding(
                    padding: hPad,
                    child: pointsAsync.when(
                      data: (balance) => balance != null
                          ? PointsCard(
                              points: balance.totalPoints.toString(),
                              myQrLabel: l10n.titleQrCode,
                              onMyQrPressed: openMyWalletQr,
                            )
                          : const SizedBox.shrink(),
                      loading: () => PointsCard(
                        points: '...',
                        myQrLabel: l10n.titleQrCode,
                        onMyQrPressed: openMyWalletQr,
                      ),
                      error: (_, _) => PointsCard(
                        points: '0',
                        myQrLabel: l10n.titleQrCode,
                        onMyQrPressed: openMyWalletQr,
                      ),
                    ),
                  ),
                ),
              ),

            if (FeatureFlags.pointsEnabled && isLoggedIn)
              const SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.xl),
              ),

            // ── 4) Nearby Points Banner ──────────────────────────────
            if (FeatureFlags.pointsEnabled && isLoggedIn)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: hPad,
                  child: NearbyPointsBanner(),
                ),
              ),

            // ── 5) Categories (Kategoriler) ────────────────────────────
            SliverToBoxAdapter(
              child: RepaintBoundary(
                child: Padding(
                  padding: hPad,
                  child: CategoriesSection(
                    onSeeAll: () {
                      ref.read(placesProvider.notifier).setCategory('all');
                      context.go('/places');
                    },
                    onCategoryTap: (id) {
                      const homeCategoryRoutes = {
                        'health_tourism',
                        'discover_samsun',
                        'gastronomy',
                        'historical_museums',
                        'nature_parks',
                        'beaches',
                      };
                      if (homeCategoryRoutes.contains(id)) {
                        context.go('/places?category=$id');
                      }
                    },
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: _homeSectionSpacing),
            ),

            // ── 5b) Discovery Feed §6.4 — 3 sunucu bölümü ────────────
            // Sunucu hazırsa "Yakındakiler / Popüler / Yeni Eklenenler"
            // gösterilir. ID lookup ile `placesProvider.allPlaces` üzerinden
            // kart üretilir — tek kaynak ilkesi.
            // "Öne Çıkanlar" bucket'ı kaldırıldı (zaten 6. bölümde CMS
            // `place.featured` bayrağıyla geliyor).
            // "Yakındaki yerleri görmek için dokunun" CTA kaldırıldı — Konum
            // izni map ekranına girince zaten istendiği için ana sayfada
            // tekrar tetiklemeye gerek yok. UI sadeleşti.
            // §6.4 — "Sizin İçin" (ilgi alanı + davranış) her zaman en üstte.
            if (showPersonalized) ...[
              SliverToBoxAdapter(
                child: RepaintBoundary(
                  child: Padding(
                    padding: hPad,
                    child: FeaturedPlacesSection(
                      places: personalized,
                      title: l10n.sectionForYou,
                      analyticsBucket: 'for_you',
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: _homeSectionSpacing),
              ),
            ],

            // §6.4 — Sunucu feed'i: Yakındakiler / Popüler / Yeni Eklenenler.
            // "Popüler" bucket'ı profile göre client-side stable re-rank edilir.
            if (discoveryFeed != null) ...[
              for (final section in _buildDiscoverySections(
                discoveryFeed,
                ref.watch(placesProvider.select((s) => s.allPlaces)),
                ref.watch(placeDistancesProvider),
                ref.watch(mobileCategoryNamesSyncProvider),
                ApiConfig.current.baseUrl,
                profile,
                ref.watch(categoryInterestMapProvider),
                l10n,
              )) ...[
                SliverToBoxAdapter(
                  child: RepaintBoundary(
                    child: Padding(
                      padding: hPad,
                      child: FeaturedPlacesSection(
                        places: section.places,
                        title: section.title,
                        analyticsBucket: section.bucket,
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: _homeSectionSpacing),
                ),
              ],
            ],

            // ── 6) Featured Places ───────────────────────────────────
            SliverToBoxAdapter(
              child: RepaintBoundary(
                child: Padding(
                  padding: hPad,
                  child: isLoading
                      ? const FeaturedPlacesSkeleton(count: 3)
                      : hasError
                          ? const SizedBox.shrink()
                          : featured.isNotEmpty
                              ? FeaturedPlacesSection(places: featured)
                              : const SizedBox.shrink(),
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: _homeSectionSpacing),
            ),

            // ── 6b) Keşif Rotaları — görsel-öncelikli hero kartlar (öne çıkan
            // mekanlarla aynı dil). Kendi yatay padding'ini yönetir; hPad
            // sarmalı YOK ki kartlar kenardan kaydırılabilsin.
            const SliverToBoxAdapter(
              child: RepaintBoundary(
                child: HomeDiscoveryRoutesSection(),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: _homeSectionSpacing),
            ),

            // ── 6c) Şehir Rehberi & Blog (backend: sbbMobilBackend /mobile/blog)
            SliverToBoxAdapter(
              child: RepaintBoundary(
                child: Padding(
                  padding: hPad,
                  child: Consumer(
                    builder: (context, ref, _) {
                      final asyncPosts = ref.watch(homeBlogPreviewProvider);
                      final posts =
                          asyncPosts.asData?.value ?? const <BlogPost>[];
                      // Veri yoksa bölümü gizle (boş placeholder gösterme).
                      if (posts.isEmpty) return const SizedBox.shrink();
                      final l10n = context.l10n;
                      final items = posts
                          .map((p) => CityGuideBlogItem(
                                id: p.slug,
                                title: p.title,
                                categoryLabel: p.categoryName ?? '',
                                imageUrl: p.displayImageUrl,
                                readTimeLabel: p.readTimeMin != null
                                    ? l10n.blogReadMinutes(p.readTimeMin!)
                                    : '',
                                dateLabel: _blogDateLabel(p.publishedAt),
                              ))
                          .toList();
                      return HomeCityGuideBlogSection(
                        items: items,
                        onSeeAll: () => context.push('/blog'),
                        onItemTap: (item) => context.push('/blog/${item.id}'),
                      );
                    },
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: _homeSectionSpacing),
            ),

            // ── 7) Active Campaigns ──────────────────────────────────
            // Points/gamification feature flag — kampanya bölümü gizlenir.
            if (FeatureFlags.pointsEnabled) ...[
              const SliverToBoxAdapter(
                child: RepaintBoundary(
                  child: Padding(
                    padding: hPad,
                    child: ActiveCampaignSection(),
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: _homeSectionSpacing),
              ),
            ],

            // ── 8) Duyurular bölümü KALDIRILDI ───────────────────────
            // Ana sayfada artık duyuru kartı gösterilmiyor. Duyurulara
            // "Duyurular" sayfasından, bildirimlere ise üstteki zil ikonundan
            // erişilir (duyuru = resmi/kalıcı, bildirim = push ayrımı).

            // ── 9) Bottom padding for navbar + center FAB overhang ─────
            // Shell'in center docked FAB'ı (~56px daire) bottom nav'ın
            // ~28px üstüne çıkıyor. Son kart bunun altında kalmasın diye
            // padding artırıldı.
            SliverToBoxAdapter(
              child: SizedBox(
                height: AppNavBar.bottomPadding + AppSpacing.xxxl,
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

/// mobile_integ.md §3 — Discovery feed bölümlerini ekrana basmak için
/// kullanılan içsel veri yapısı + factory.
class _DiscoverySection {
  const _DiscoverySection({
    required this.title,
    required this.places,
    required this.bucket,
  });
  final String title;
  final List<FeaturedPlace> places;
  /// `mobile_analytics_todo.md` §2.6 — discovery_card_tapped.bucket için
  /// kanonik değer: `nearby` / `popular` / `new`.
  final String bucket;
}

/// Discovery feed sıralı ID listesini, halihazırda yüklü place'ler ve
/// mesafe önbelleği üzerinden `FeaturedPlace` kartlarına dönüştürür.
///
/// Yeni mimari (12 Mayıs 2026): backend sadece `{type, id}` çiftleri gönderir,
/// kart datası (ad, görsel, kategori, puan, ziyaret durumu) **tek kaynaktan**
/// — `placesProvider.allPlaces` — okunur. Böylece kategori/lokalizasyon
/// tutarsızlıkları ortadan kalkar; payload boyutu kritik şekilde küçülür.
///
/// "Öne Çıkanlar" bucket'ı kaldırıldı; CMS'in `place.featured` bayrağı
/// üzerinden çalışan `homeFeaturedPlacesProvider` o görevi zaten yapıyor.
List<_DiscoverySection> _buildDiscoverySections(
  DiscoveryFeed feed,
  List<Place> allPlaces,
  Map<String, String> distances,
  Map<int, String> categoryNames,
  String baseUrl,
  PersonalizationProfile profile,
  Map<int, Set<String>> categoryInterests,
  AppLocalizations l10n,
) {
  // O(1) lookup için id → Place haritası.
  final placeById = {for (final p in allPlaces) p.id: p};

  // Sıralı ref listesini yüklü place'lere çevirir (route + cache-miss atlanır).
  List<Place> resolvePlaces(List<DiscoveryFeedRef> refs) {
    final out = <Place>[];
    for (final ref in refs) {
      if (!ref.isPlace) continue; // route lookup'u ayrı section'da yapılır
      final place = placeById[ref.id];
      if (place == null) continue; // önbellek dışı, sessizce atla
      out.add(place);
    }
    return out;
  }

  List<FeaturedPlace> toCards(List<Place> places) {
    return [
      for (final place in places)
        FeaturedPlace(
          id: place.id,
          title: place.name,
          category: resolveCategoryDisplayName(
            place.categoryId,
            place.category,
            categoryNames,
          ),
          distance: distances[place.id] ?? place.distance ?? '',
          image: buildImageUrl(place.imageUrl ?? '', baseUrl: baseUrl) ??
              (place.imageUrl ?? ''),
          points: place.points,
          visited: place.visited,
          claimed: place.claimed,
          campaignStatus: place.campaign?.status.value,
        ),
    ];
  }

  final out = <_DiscoverySection>[];
  void addIfNotEmpty(String title, String bucket, List<FeaturedPlace> places) {
    if (places.isNotEmpty) {
      out.add(_DiscoverySection(title: title, places: places, bucket: bucket));
    }
  }

  addIfNotEmpty(l10n.sectionNearby, 'nearby', toCards(resolvePlaces(feed.nearby)));
  // §6.4 — "Popüler" sunucu adaylarını profile göre stable yeniden sıralar.
  // Profil boşsa sunucu sırası aynen korunur (regresyon yok).
  addIfNotEmpty(
    l10n.sectionPopular,
    'popular',
    toCards(
      PersonalizationEngine.rankByProfile(
        resolvePlaces(feed.popular),
        profile,
        categoryInterests,
        distances,
      ),
    ),
  );
  // "Yeni Eklenenler" bölümü kaldırıldı (2026-06-09 — ürün kararı). Backend
  // `feed.newItems`'i hâlâ dönebilir ama ana sayfada gösterilmez.
  return out;
}

/// Hero görselinin üstüne bindirilen yüzen "cam" (glassmorphism) ikon butonu.
///
/// Eski opak üst şerit kaldırıldıktan sonra menü gibi kontroller doğrudan
/// görselin üzerinde yüzer. Yarı saydam koyu cam + ince beyaz kenar her iki
/// temada da fotoğraf üzerinde okunur kalır; asistan butonuyla (sağ) aynı
/// 36px daire boyutunu paylaşır.
class _HeroGlassIconButton extends StatelessWidget {
  const _HeroGlassIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.showBadge = false,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  /// true → ikonun sağ-üstünde kırmızı "okunmamış" noktası gösterilir.
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Material(
                color: Colors.black.withValues(alpha: 0.28),
                shape: CircleBorder(
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.22),
                    width: 0.8,
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    Haptics.selection();
                    onTap();
                  },
                  customBorder: const CircleBorder(),
                  child: SizedBox(
                    width: 38,
                    height: 38,
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),
          ),
          if (showBadge)
            Positioned(
              top: 2,
              right: 2,
              child: IgnorePointer(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30),
                    shape: BoxShape.circle,
                    // Cam zemine karşı görünürlük için ince beyaz halka.
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Hero üstündeki bildirim (zil) butonu — okunmamış bildirim varsa kırmızı nokta.
///
/// `notificationBadgeProvider` izlenir; Bildirimler sayfası açılınca işaret
/// "görüldü" olarak kaydedilir ve nokta reaktif olarak kaybolur.
class _NotificationBellButton extends ConsumerWidget {
  const _NotificationBellButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasUnseen = ref.watch(hasUnseenNotificationsProvider);
    return _HeroGlassIconButton(
      icon: Icons.notifications_outlined,
      semanticLabel: context.l10n.titleNotifications,
      showBadge: hasUnseen,
      onTap: onTap,
    );
  }
}

/// Hero üstündeki sağ "Samsun Asistan" butonu.
///
/// Gradient çemberli sparkle ikon → AI ürünlerinde standart "asistan" iconografisi.
/// İlk açılışlarda kullanıcının dikkatini çekmek için yumuşak bir pulse animasyonu
/// uygulanır; ilk tap'tan sonra kapanır (FAz 5'te kalıcılaştırılacak).
class _AssistantTopBarButton extends StatefulWidget {
  const _AssistantTopBarButton({
    required this.semanticLabel,
    required this.onTap,
    required this.primary,
    required this.tertiary,
  });

  final String semanticLabel;
  final VoidCallback onTap;
  final Color primary;
  final Color tertiary;

  @override
  State<_AssistantTopBarButton> createState() => _AssistantTopBarButtonState();
}

class _AssistantTopBarButtonState extends State<_AssistantTopBarButton>
    with SingleTickerProviderStateMixin {
  static const String _seenKey = 'chatbot_assistant_discovered_v1';

  late final AnimationController _pulseCtrl;
  bool _interacted = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    // Kullanıcı asistanı daha önce keşfetmediyse 5 saniye pulse, sonra
    // kalıcı olarak sustur. SharedPreferences ile cihaza yazılır.
    _maybeStartPulse();
  }

  Future<void> _maybeStartPulse() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool(_seenKey) ?? false;
      if (!mounted || seen) return;
      _pulseCtrl.repeat(reverse: true);
      Future<void>.delayed(const Duration(seconds: 5), () {
        if (mounted && !_interacted) _pulseCtrl.stop();
      });
    } catch (_) {
      // Sessizce yut — pulse bir UX gimmick'i, fail olmamalı.
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    _interacted = true;
    _pulseCtrl.stop();
    // Tap'dan sonra bir daha pulse'ı görmesin.
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setBool(_seenKey, true))
        .catchError((_) => false);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      button: true,
      child: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, child) {
              final scale = 1.0 + (_pulseCtrl.value * 0.08);
              return Transform.scale(scale: scale, child: child);
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [widget.primary, widget.tertiary],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 19,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Yandan açılan menü — kampanya, rota, yemek, etkinlik ve AR kısayolları.
/// Ana sayfa yan menüsü (drawer).
///
/// Gradient marka header'ı + içine gömülü kompakt tema segmenti (tema kontrolü
/// en üstte tutulur ki shell'in ortadaki yüzen harita FAB'ı ile çakışmasın),
/// ardından route-renkli yumuşak ikon kutularıyla menü satırları. Liste altına
/// FAB için boşluk bırakılır.
class _HomeNavigationDrawer extends StatelessWidget {
  const _HomeNavigationDrawer({
    required this.isDark,
    required this.appTitle,
    required this.quickAccessItems,
  });

  final bool isDark;
  final String appTitle;
  final List<QuickAccessItem> quickAccessItems;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Drawer(
      width: 312,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DrawerBrandHeader(isDark: isDark, appTitle: appTitle),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                96, // shell'in yüzen harita FAB'ı için alt boşluk
              ),
              children: [
                _DrawerSectionLabel(label: l10n.drawerExplore, isDark: isDark),
                for (final item in quickAccessItems)
                  _DrawerMenuTile(item: item, isDark: isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Çekmecede bölüm başlığı — büyük harf, seyrek harf aralıklı, soluk.
class _DrawerSectionLabel extends StatelessWidget {
  const _DrawerSectionLabel({required this.label, required this.isDark});

  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 4, AppSpacing.sm, 8),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: isDark
                  ? AppColors.textSecondaryDark.withAlpha(160)
                  : AppColors.textSecondaryLight,
            ),
      ),
    );
  }
}

/// Gradient marka başlığı: logo + uygulama adı + slogan + kompakt tema segmenti.
class _DrawerBrandHeader extends StatelessWidget {
  const _DrawerBrandHeader({required this.isDark, required this.appTitle});

  final bool isDark;
  final String appTitle;

  @override
  Widget build(BuildContext context) {
    final gradient = isDark
        ? AppGradients.darkNeonGradient
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.lightGradientStart,
              AppColors.lightGradientEnd,
            ],
          );

    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                    ),
                    child: const Icon(
                      Icons.location_city_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          appTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.drawerSlogan,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.82),
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              // Tema segmenti — gradient üzerinde frosted pill (FAB'dan uzakta).
              _DrawerThemeToggle(isDark: isDark),
              const SizedBox(height: AppSpacing.sm),
              // Dil segmenti — girişsiz kullanıcılar dahil herkes değiştirebilir.
              _DrawerLanguageToggle(isDark: isDark),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gradient header üzerinde frosted, 3 segmentli kompakt tema seçici.
/// Profil giriş gerektirdiği için tema buradan da değiştirilebilir
/// (girişsiz kullanıcılar dahil — §5.2.4 / §7.4.5).
class _DrawerThemeToggle extends ConsumerWidget {
  const _DrawerThemeToggle({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeProvider).mode;
    final activeFg =
        isDark ? const Color(0xFF12121E) : AppColors.brandGreen;

    Widget seg(IconData icon, String label, ThemeMode m, AppThemeMode target) {
      final active = mode == m;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Haptics.selection();
            ref.read(themeProvider.notifier).setTheme(target);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            margin: const EdgeInsets.all(3),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: active
                  ? Colors.white.withValues(alpha: 0.95)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: active
                      ? activeFg
                      : Colors.white.withValues(alpha: 0.92),
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active
                        ? activeFg
                        : Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          seg(Icons.light_mode_rounded, context.l10n.themeShortLight,
              ThemeMode.light, AppThemeMode.light),
          seg(Icons.dark_mode_rounded, context.l10n.themeShortDark,
              ThemeMode.dark, AppThemeMode.dark),
          seg(Icons.brightness_auto_rounded, context.l10n.themeShortSystem,
              ThemeMode.system, AppThemeMode.system),
        ],
      ),
    );
  }
}

/// Gradient header üzerinde frosted, 2 segmentli kompakt dil seçici.
/// Tema gibi dil de profile/girişe bağlı değildir; girişsiz kullanıcılar dahil
/// herkes ana menüden değiştirebilir.
class _DrawerLanguageToggle extends ConsumerWidget {
  const _DrawerLanguageToggle({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeProvider).locale.languageCode;
    final activeFg =
        isDark ? const Color(0xFF12121E) : AppColors.brandGreen;

    Widget seg(String flag, String label, String code) {
      final active = current == code;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (active) return;
            Haptics.selection();
            ref.read(localeProvider.notifier).setLocale(Locale(code));
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            margin: const EdgeInsets.all(3),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: active
                  ? Colors.white.withValues(alpha: 0.95)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(flag, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active
                        ? activeFg
                        : Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          seg('🇹🇷', 'Türkçe', 'tr'),
          seg('🇬🇧', 'English', 'en'),
        ],
      ),
    );
  }
}

/// Tek menü satırı: route-renkli yumuşak köşeli ikon kutusu + etiket + chevron.
class _DrawerMenuTile extends StatelessWidget {
  const _DrawerMenuTile({required this.item, required this.isDark});

  final QuickAccessItem item;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final accent = quickAccessIconColorForRoute(item.route, context);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () {
            Haptics.selection();
            Navigator.of(context).pop();
            context.push(item.route);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.20 : 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(item.icon, color: accent, size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: onSurface,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: onSurface.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _homeQrDisplayName(AuthUser? user) {
  if (user == null) return 'Kayıtlı Kullanıcı';
  final parts = [
    user.firstName?.trim() ?? '',
    user.lastName?.trim() ?? '',
  ].where((e) => e.isNotEmpty).toList();
  if (parts.isNotEmpty) {
    return parts.join(' ');
  }
  return 'Kayıtlı Kullanıcı';
}

/// Blog kartı için kısa tarih etiketi (örn. "12 Nis 2026"). Boşsa ''.
String _blogDateLabel(DateTime? d) {
  if (d == null) return '';
  const months = [
    'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
  ];
  final local = d.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}
