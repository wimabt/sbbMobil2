import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/providers/locale_provider.dart';
import 'core/cache/offline_content_cache.dart';
import 'features/auth/providers/post_login_sync_provider.dart';
import 'features/legal/providers/consent_provider.dart';
import 'features/onboarding/presentation/providers/onboarding_provider.dart';
import 'core/services/background_geofence_worker.dart';
import 'core/services/local_activity_tracker.dart';
import 'core/services/log_service.dart';
import 'core/services/notification_prefs_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/safe_shared_preferences.dart';
import 'core/security/device_integrity_service.dart';
import 'core/security/threat_monitor_service.dart';
import 'core/widgets/geofence_handler.dart';
import 'core/widgets/notification_handler.dart';
import 'l10n/generated/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Tersine mühendislik / bilgi sızıntısı sertleştirmesi (§5.5.3, §10.4.2) ──
  // Release ve profile build'lerinde tüm `debugPrint` çağrılarını no-op yap.
  // Aksi halde uygulamanın iç akışı, endpoint isimleri, state geçişleri vb.
  // logcat / Console üzerinden okunabilir; bu da tersine mühendisliği
  // kolaylaştırır. Debug build'lerde loglar aynen korunur.
  if (!kDebugMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  if (kDebugMode) {
    await LogService.enableFileLogging();
  }

  // Bazı cihazlarda legacy SharedPreferences XML'i bozulmuş olabiliyor
  // (java.io.EOFException). Aşağıdaki paralel başlatma görevleri prefs'e
  // dokunduğu için bu init **ilk** yapılmalı; bozuk dosya varsa silinir
  // ve plugin cache temiz şekilde ısıtılır. Bkz. safe_shared_preferences.dart.
  try {
    await SafeSharedPreferences.init();
  } catch (e, st) {
    debugPrint('[SafeSharedPreferences] init failed: $e');
    debugPrint('$st');
  }

  // ── Edge-to-Edge: OS System Navigation Bar'ın arkasına çiz ──
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    statusBarColor: Colors.transparent,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Local activity tracker — UI'da sync erişim için container'dan ÖNCE
  // başlatılır ve override ile enjekte edilir. SafeSharedPreferences zaten
  // yüklü olduğundan saniye altı tamamlanır.
  LocalActivityTracker? activityTracker;
  try {
    activityTracker = await LocalActivityTracker.create();
  } catch (e) {
    debugPrint('[LocalActivityTracker] init failed: $e');
  }

  final container = ProviderContainer(
    overrides: [
      if (activityTracker != null)
        localActivityTrackerProvider.overrideWithValue(activityTracker),
    ],
  );
  
  Future<void> safeStartupTask({
    required String name,
    required Future<void> Function() task,
  }) async {
    try {
      await task();
    } catch (e, stack) {
      // Optional servislerde hata olsa bile uygulama anasayfaya açılmalı.
      debugPrint('[$name] startup failed: $e');
      debugPrint('$stack');
    }
  }

  // Paralel başlatma: kritik olmayan servisler hata verse de app açılışını bloklama.
  await Future.wait([
    safeStartupTask(
      name: 'Theme',
      task: () => container.read(themeProvider.notifier).loadTheme(),
    ),
    safeStartupTask(
      name: 'Locale',
      task: () => container.read(localeProvider.notifier).loadLocale(),
    ),
    safeStartupTask(
      name: 'Onboarding',
      task: () => container.read(onboardingProvider.notifier).loadStatus(),
    ),
    safeStartupTask(
      name: 'Consent',
      task: () => container.read(consentProvider.notifier).load(),
    ),
    safeStartupTask(
      name: 'OfflineCache',
      task: () => OfflineContentCache.instance.init(),
    ),
    safeStartupTask(
      name: 'OneSignal',
      task: () => container.read(notificationProvider.notifier).initialize(),
    ),
    safeStartupTask(
      name: 'NotifPrefs',
      task: () => container.read(notificationPrefsProvider.notifier).load(),
    ),
    safeStartupTask(
      name: 'GeofenceWorker',
      task: initializeGeofenceWorker,
    ),
    // RASP: Frida/hook, debugger, emülatör, repack, root tespiti (freeRASP).
    // Native tarafta izler; hata verse de uygulama açılışını bloke etmez.
    safeStartupTask(
      name: 'ThreatMonitor',
      task: ThreatMonitorService.start,
    ),
  ]);

  // NOT: WorkManager periodic polling ARTIK KULLANILMIYOR — geofence bildirimleri
  // tek kaynak olan native (OS) event geofencing'e taşındı (Android GeofencingClient
  // / iOS region monitoring). initializeGeofenceWorker yalnızca eski kurulumlardan
  // kalmış periyodik görevi güvenle iptal edebilmek için kayıt edilir; callback
  // tetiklenirse bildirim göstermez (bkz. background_geofence_worker.dart).

  // Post-login sync koordinatörü — Auth state değişimini dinler, A1/A4/A5
  // reconcile/migration akışlarını tetikler. Eager subscription gerekli.
  container.read(postLoginSyncProvider);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SbbApp(),
    ),
  );
}

class SbbApp extends ConsumerWidget {
  const SbbApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final localeState = ref.watch(localeProvider);
    final router = ref.watch(appRouterProvider);

    return NotificationHandler(
      child: MaterialApp.router(
        title: 'SBB Mobile',
        debugShowCheckedModeBanner: false,
        themeMode: themeState.mode,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        // Dynamic locale from LocaleProvider
        locale: localeState.locale,
        supportedLocales: supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
        // GeofenceHandler: Lifecycle-based geofencing
        // autoStart: false → Kullanıcı profil ayarlarından etkinleştirir
        // WidgetsBindingObserver ile app resume olduğunda checkLocation() çağrılır
        builder: (context, child) {
          // İlk frame çizildikten sonra güvenlik kontrolü yap
          WidgetsBinding.instance.addPostFrameCallback((_) {
            DeviceIntegrityService.checkAndWarn(context);
          });
          
          return GeofenceHandler(
            autoStart: false,
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
