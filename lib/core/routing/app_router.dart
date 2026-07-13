import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/feature_flags.dart';
import '../../features/shell/scaffold_shell.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/announcements/presentation/announcements_screen.dart';
import '../../features/announcements/presentation/announcement_detail_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/blog/presentation/blog_list_screen.dart';
import '../../features/blog/presentation/blog_detail_screen.dart';
import '../../data/models/blog.dart';
import '../../features/campaigns/presentation/campaigns_screen.dart';
import '../../features/campaigns/presentation/campaign_detail_screen.dart';
import '../../features/map/presentation/map_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/legal/presentation/legal_hub_screen.dart';
import '../../features/legal/presentation/legal_document_screen.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/staff_pos/presentation/pages/staff_login_screen.dart';
import '../../features/staff_pos/presentation/pages/staff_home_screen.dart';
import '../../features/staff_pos/presentation/providers/staff_auth_provider.dart';
import '../../features/places/presentation/places_screen.dart';
import '../../features/places/presentation/place_detail_screen.dart';
import '../../features/routes/presentation/routes_screen.dart';
import '../../features/routes/presentation/route_detail_screen.dart';
import '../../features/recipes/presentation/recipes_screen.dart';
import '../../features/recipes/presentation/recipe_detail_screen.dart';
import '../../features/culture/presentation/events_screen.dart';
import '../../features/culture/presentation/event_detail_screen.dart';
import '../../features/favorites/presentation/favorites_screen.dart';
import '../../features/profile/presentation/account_screen.dart';
import '../../features/itinerary/presentation/itineraries_screen.dart';
import '../../features/itinerary/presentation/itinerary_detail_screen.dart';
import '../../features/itinerary/presentation/itinerary_map_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/onboarding/presentation/providers/onboarding_provider.dart';
import '../../features/gastronomy/presentation/gastronomy_detail_screen.dart';
import '../../features/ar/presentation/ar_camera_overlay_screen.dart';
import '../../features/ar/presentation/qr_ar_scanner_screen.dart';
import '../../features/ar/presentation/widgets/ar_readiness_gate.dart';
import '../../features/chatbot/presentation/chatbot_screen.dart';
import '../../features/debug/presentation/point_test_panel.dart';
import '../../features/debug/presentation/route_stop_test_panel.dart';
import '../../features/not_found/presentation/not_found_screen.dart';
import '../services/analytics_route_observer.dart';
import '../services/analytics_service.dart';
import 'deep_link_validator.dart';
import 'navigation_utils.dart';
import '../widgets/stable_system_padding.dart';
import '../utils/layout_debugger.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final analytics = ref.read(analyticsServiceProvider);
  // Bir NavigatorObserver örneği aynı anda yalnızca tek bir Navigator'a
  // bağlanabilir; root ve shell için ayrı örnekler oluşturuyoruz.
  final rootAnalyticsObserver = AnalyticsRouteObserver(analytics);
  final shellAnalyticsObserver = AnalyticsRouteObserver(analytics);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    observers: [rootAnalyticsObserver],
    errorBuilder: (context, state) => const NotFoundScreen(),
    redirect: (context, state) {
      final deepGuard = DeepLinkValidator.redirectIfInvalidPublicDeepLink(
        state.uri,
      );
      if (deepGuard != null) return deepGuard;

      final loc = state.uri.toString();

      // Onboarding gating (§6.3.5): ilk açılışta tanıtım akışına yönlendir.
      // Auth/staff/onboarding ekranları zaten dışarıda kalır.
      final onboardingDone = ref.read(onboardingProvider).isCompleted;
      final isOnboarding = loc.startsWith('/onboarding');
      final isAuthFlow =
          loc == '/login' ||
          loc.startsWith('/register') ||
          loc.startsWith('/otp');
      final isStaffRoute = loc.startsWith('/staff');
      // Yasal metinler her aşamada (onboarding/kayıt dahil) açılabilmeli.
      final isLegal = loc.startsWith('/legal');
      if (!onboardingDone &&
          !isOnboarding &&
          !isAuthFlow &&
          !isStaffRoute &&
          !isLegal) {
        return '/onboarding';
      }
      if (onboardingDone && isOnboarding) {
        return '/';
      }

      if (!isStaffRoute) return null;

      final staffAuth = ref.read(staffAuthProvider);
      final isLoggedIn = staffAuth.status == StaffAuthStatus.authenticated;
      final isLogin = loc == '/staff/login';

      if (!isLoggedIn && !isLogin) return '/staff/login';
      if (isLoggedIn && isLogin) return '/staff';
      return null;
    },
    routes: [
      // Auth routes (outside shell)
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const AuthLoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) {
          final phone = state.uri.queryParameters['phone'];
          return AuthRegisterScreen(initialPhone: phone);
        },
      ),
      GoRoute(
        path: '/otp',
        name: 'otp',
        builder: (context, state) => const OtpScreen(),
      ),
      // Onboarding (§6.3.5) — ilk açılışta gösterilir, akış tamamlanınca '/' yönlendirilir.
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      // Yasal metinler (§10.6.3, §14.2.3) — shell dışında; kayıt/onboarding/profil
      // her yerden push edilebilir.
      GoRoute(
        path: '/legal',
        name: 'legal',
        builder: (context, state) => const LegalHubScreen(),
        routes: [
          GoRoute(
            path: ':docId',
            name: 'legal-document',
            builder: (context, state) =>
                LegalDocumentScreen(docId: state.pathParameters['docId']!),
          ),
        ],
      ),
      // Staff routes (outside shell)
      GoRoute(
        path: '/staff/login',
        name: 'staff-login',
        builder: (context, state) => const StaffLoginScreen(),
      ),
      GoRoute(
        path: '/staff',
        name: 'staff-home',
        builder: (context, state) => const StaffHomeScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        observers: [shellAnalyticsObserver],
        builder: (context, state, child) {
          // ── DEBUG: Canlı MediaQuery değerlerini ekranda göster ──
          // Teşhis bittikten sonra enabled: false yap veya satırı sil.
          return LayoutDebuggerOverlay(
            enabled: false, // ← Teşhis tamamlandı, kapatıldı
            child: StableSystemPadding(child: ScaffoldShell(child: child)),
          );
        },
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: HomeScreen()),
          ),
          // NOT: Ana sayfa ('/') dışındaki tüm shell rotaları PopOrHomeScope
          // ile sarılır: yığın boşken sistem geri hareketi uygulamayı
          // kapatmak yerine ana sayfaya döndürür. Uygulamadan çıkış yalnızca
          // ana sayfadan geri ile olur.
          GoRoute(
            path: '/map',
            name: 'map',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PopOrHomeScope(child: MapScreen()),
            ),
          ),
          GoRoute(
            path: '/announcements',
            name: 'announcements',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PopOrHomeScope(child: AnnouncementsScreen()),
            ),
            routes: [
              GoRoute(
                path: ':id',
                name: 'announcement-detail',
                builder: (context, state) {
                  final id = state.pathParameters['id'];
                  if (id == null) return const NotFoundScreen();
                  // Extra ile announcement objesi gelirse kullan, yoksa ID ile çek
                  final announcement = state.extra;
                  return AnnouncementDetailScreen(
                    id: id,
                    announcement: announcement,
                  );
                },
              ),
            ],
          ),
          // Bildirimler — push olarak gönderilmiş duyurular
          GoRoute(
            path: '/notifications',
            name: 'notifications',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PopOrHomeScope(child: NotificationsScreen()),
            ),
          ),
          // Şehir Rehberi & Blog
          GoRoute(
            path: '/blog',
            name: 'blog',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PopOrHomeScope(child: BlogListScreen()),
            ),
            routes: [
              GoRoute(
                path: ':slug',
                name: 'blog-detail',
                builder: (context, state) {
                  final slug = state.pathParameters['slug'];
                  if (slug == null) return const NotFoundScreen();
                  final extra = state.extra;
                  return BlogDetailScreen(
                    slugOrId: slug,
                    post: extra is BlogPost ? extra : null,
                  );
                },
              ),
            ],
          ),
          // Points/gamification feature flag — /campaigns ve alt rotaları
          // kapalıyken hiç register edilmez. Dış linkler NotFoundScreen'e düşer.
          if (FeatureFlags.pointsEnabled)
            GoRoute(
              path: '/campaigns',
              name: 'campaigns',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: PopOrHomeScope(child: CampaignsScreen()),
              ),
              routes: [
                GoRoute(
                  path: ':id',
                  name: 'campaign-detail',
                  builder: (context, state) {
                    final id = state.pathParameters['id'];
                    if (id == null) return const NotFoundScreen();
                    return CampaignDetailScreen(id: id);
                  },
                ),
              ],
            ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PopOrHomeScope(child: ProfileScreen()),
            ),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) =>
                const PopOrHomeScope(child: SettingsScreen()),
          ),

          // Other sections (outside bottom tabs but same shell)
          GoRoute(
            path: '/places',
            name: 'places',
            builder: (context, state) => PopOrHomeScope(
              child: PlacesScreen(
                initialCategorySlug: state.uri.queryParameters['category'],
                initialSearchQuery: state.uri.queryParameters['q'],
              ),
            ),
            routes: [
              GoRoute(
                path: ':id',
                name: 'place-detail',
                builder: (context, state) {
                  final id = state.pathParameters['id'];
                  if (id == null) return const NotFoundScreen();
                  final extra = state.extra;
                  int? routeId;
                  if (extra is Map<String, dynamic>) {
                    routeId = extra['routeId'] as int?;
                  }
                  return PlaceDetailScreen(id: id, routeId: routeId);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/routes',
            name: 'routes',
            builder: (context, state) =>
                const PopOrHomeScope(child: RoutesScreen()),
            routes: [
              GoRoute(
                path: ':id',
                name: 'route-detail',
                builder: (context, state) {
                  final id = state.pathParameters['id'];
                  if (id == null) return const NotFoundScreen();
                  return RouteDetailScreen(id: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/recipes',
            name: 'recipes',
            builder: (context, state) =>
                const PopOrHomeScope(child: RecipesScreen()),
            routes: [
              GoRoute(
                path: ':id',
                name: 'recipe-detail',
                builder: (context, state) {
                  final id = state.pathParameters['id'];
                  if (id == null) return const NotFoundScreen();
                  return RecipeDetailScreen(id: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/events',
            name: 'events',
            builder: (context, state) =>
                const PopOrHomeScope(child: EventsScreen()),
            routes: [
              GoRoute(
                path: ':id',
                name: 'event-detail',
                builder: (context, state) {
                  final id = state.pathParameters['id'];
                  if (id == null) return const NotFoundScreen();
                  return EventDetailScreen(id: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/favorites',
            name: 'favorites',
            builder: (context, state) =>
                const PopOrHomeScope(child: FavoritesScreen()),
          ),
          // Hesap Bilgileri — e-posta doğrulama + (ileride) e-posta/telefon değiştirme
          GoRoute(
            path: '/account',
            name: 'account',
            builder: (context, state) =>
                const PopOrHomeScope(child: AccountScreen()),
          ),
          // §6.5.2 — Gezi planları
          GoRoute(
            path: '/itinerary',
            name: 'itinerary-list',
            builder: (context, state) =>
                const PopOrHomeScope(child: ItinerariesScreen()),
            routes: [
              GoRoute(
                path: ':id',
                name: 'itinerary-detail',
                builder: (context, state) {
                  final id = state.pathParameters['id'];
                  if (id == null) return const NotFoundScreen();
                  return ItineraryDetailScreen(id: id);
                },
                routes: [
                  GoRoute(
                    path: 'map',
                    name: 'itinerary-map',
                    builder: (context, state) {
                      final id = state.pathParameters['id'];
                      if (id == null) return const NotFoundScreen();
                      return ItineraryMapScreen(id: id);
                    },
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/gastronomy/:id',
            name: 'gastronomy-detail',
            builder: (context, state) {
              final id = state.pathParameters['id'];
              if (id == null) return const NotFoundScreen();
              return GastronomyDetailScreen(id: id);
            },
          ),
          GoRoute(
            path: '/debug/points',
            name: 'debug-points',
            builder: (context, state) =>
                const PopOrHomeScope(child: PointTestPanel()),
          ),
          GoRoute(
            path: '/debug/route-stops',
            name: 'debug-route-stops',
            builder: (context, state) =>
                const PopOrHomeScope(child: RouteStopTestPanel()),
          ),
        ],
      ),
      // NOT: In-app AR viewer (`/ar` + ArViewerScreen) KALDIRILDI. QR ve mekan
      // detayı modelleri artık cihazın native AR'ında (Scene Viewer / Quick
      // Look) `launchExternalArViewer` ile açılıyor — orta-segment cihazlarda
      // in-app SceneView render'ı donduğu için (bkz. pubspec AR notu).

      // QR AR Scanner - full screen, outside shell
      GoRoute(
        path: '/qr-ar-scanner',
        name: 'qr-ar-scanner',
        builder: (context, state) => const ArReadinessGate(
          titleWhenBlocked: 'QR Tarayıcı',
          child: QrArScannerScreen(),
        ),
      ),
      // §6.8.3.3 + §6.8.3.7 — Kamera arkaplanlı AR overlay (kart bazlı).
      // ARCore/ARKit desteklemeyen cihazlarda fallback olarak kullanılır.
      // Gate ile sarmalı (kamera + konum). 3B AR sahnesinden toggle ile
      // geçilebilir.
      GoRoute(
        path: '/ar-camera',
        name: 'ar-camera',
        builder: (context, state) => const ArReadinessGate(
          requireLocation: true,
          titleWhenBlocked: 'AR Kamera',
          child: ArCameraOverlayScreen(),
        ),
      ),
      // §6.9 — Chatbot / Akıllı Asistan modülü (full screen, shell dışı).
      // Konuşma sırasında bottom nav görünmemeli, klavyeye odak için.
      GoRoute(
        path: '/chatbot',
        name: 'chatbot',
        builder: (context, state) => const ChatbotScreen(),
      ),
      // Catch-all route for 404 - must be outside ShellRoute
      GoRoute(
        path: '/:pathMatch(.*)*',
        name: 'not-found',
        builder: (context, state) => const NotFoundScreen(),
      ),
    ],
  );
});
