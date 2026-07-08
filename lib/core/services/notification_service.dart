import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/active_locale.dart';
import '../routing/deep_link_validator.dart';
import '../../l10n/l10n.dart';
import 'log_service.dart';

// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  ONESIGNAL NOTIFICATION SERVICE - Remote Push Only                       ║
// ╠══════════════════════════════════════════════════════════════════════════╣
// ║  CRITICAL: OneSignal SADECE remote push (Events/News) için kullanılır.  ║
// ║  Geofencing için OneSignal KULLANILMAZ (ücretli olduğu için).           ║
// ║  Geofencing → GeofenceService (geofence_service.dart)                   ║
// ╠══════════════════════════════════════════════════════════════════════════╣
// ║  CONSTRAINTS (Zero Cost Protocol):                                       ║
// ║  1. Mobile Only: Never initialize Web SDK                                ║
// ║  2. Free Plan Guard: Max 2 Data Tags (location, interests)              ║
// ║  3. NO Location Triggers: OneSignal.Location is NOT used                ║
// ╚══════════════════════════════════════════════════════════════════════════╝

/// OneSignal App ID — `--dart-define=ONESIGNAL_APP_ID=xxx` ile override edilebilir.
/// Geliştirme ortamında fallback olarak mevcut ID kullanılır.
/// CI/CD'de: flutter build apk --dart-define=ONESIGNAL_APP_ID=your-id
const String _kOneSignalAppId = String.fromEnvironment(
  'ONESIGNAL_APP_ID',
  defaultValue: 'b457f34f-c0a4-4378-90ea-c0fc1c175ad8',
);

/// Typedef for notification payload data
typedef NotificationPayload = Map<String, dynamic>;

/// Typedef for navigation callback (Deep Linking)
typedef OnNotificationClickCallback = void Function(
  String target,
  String id,
);

/// State class for notification service
@immutable
class NotificationState {
  final bool isInitialized;
  final bool hasPushPermission;
  final String? oneSignalUserId;
  final String? currentDistrict;

  const NotificationState({
    this.isInitialized = false,
    this.hasPushPermission = false,
    this.oneSignalUserId,
    this.currentDistrict,
  });

  NotificationState copyWith({
    bool? isInitialized,
    bool? hasPushPermission,
    String? oneSignalUserId,
    String? currentDistrict,
  }) {
    return NotificationState(
      isInitialized: isInitialized ?? this.isInitialized,
      hasPushPermission: hasPushPermission ?? this.hasPushPermission,
      oneSignalUserId: oneSignalUserId ?? this.oneSignalUserId,
      currentDistrict: currentDistrict ?? this.currentDistrict,
    );
  }
}

/// Callback type for foreground notification events
/// Used to show in-app UI (SnackBar/Dialog) instead of system notification
typedef OnForegroundNotificationCallback = void Function(
  String title,
  String body,
  NotificationPayload data,
);

/// NotificationService - Riverpod-based OneSignal integration
/// 
/// Features:
/// - Push notifications with foreground handling
/// - Deep linking to specific app routes
/// - Free-tier compliant (max 2 tags)
/// 
/// NOTE: Geofencing is NOT handled here. See GeofenceService.
class NotificationNotifier extends Notifier<NotificationState> {
  /// Callback for handling notification clicks (deep linking)
  OnNotificationClickCallback? _onNotificationClick;
  
  /// Callback for handling foreground notifications (in-app UI)
  OnForegroundNotificationCallback? _onForegroundNotification;

  /// Stream controller for notification events (alternative to callback)
  final _notificationEventController = StreamController<NotificationPayload>.broadcast();
  
  /// Stream of notification click events for GoRouter integration
  Stream<NotificationPayload> get notificationEvents => _notificationEventController.stream;

  @override
  NotificationState build() {
    ref.onDispose(() {
      _notificationEventController.close();
    });
    return const NotificationState();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 1: INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Initialize OneSignal SDK
  /// 
  /// Call this in main.dart BEFORE runApp() or early in app lifecycle.
  /// Sets up SDK with appropriate log level based on build mode.
  Future<void> initialize() async {
    if (state.isInitialized) {
      LogService.w('NotificationService already initialized', tag: 'OneSignal');
      return;
    }

    try {
      LogService.i('Initializing OneSignal SDK...', tag: 'OneSignal');

      // Set log level based on build mode
      if (kDebugMode) {
        OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
        LogService.d('OneSignal log level: VERBOSE (Debug Mode)', tag: 'OneSignal');
      } else {
        OneSignal.Debug.setLogLevel(OSLogLevel.none);
      }

      // Initialize with App ID
      OneSignal.initialize(_kOneSignalAppId);

      // Setup notification listeners
      _setupNotificationListeners();

      // §10.6.3 — Bildirim izni artık BAŞLANGIÇTA otomatik (soğuk) istenmez.
      // İzin, açıklamalı ön-izin akışıyla istenir:
      //   • İlk açılışta onboarding sonrası tek seferlik rationale (home_screen)
      //   • Profil → Bildirim Ayarları "Genel Bildirimler" toggle'ı
      // Her ikisi de `PrePermissionSheet` gösterip kullanıcı onaylarsa
      // `requestPushPermission()` çağırır. Bu hem KVKK/şartname uyumu hem de
      // store best-practice (yüksek opt-in) açısından doğru yaklaşımdır.

      // Get initial permission states
      final hasPush = _checkPushPermission();

      state = state.copyWith(
        isInitialized: true,
        hasPushPermission: hasPush,
      );

      // Abonelik hizalama: "Genel Bildirimler" tercihi açıksa (varsayılan açık)
      // push aboneliğini opt-in yap. Aksi halde cihazda geçerli FCM token olsa
      // bile OneSignal subscription'ı opt-out kalabiliyor ve segment ("Total
      // Subscriptions") gönderimleri "All included players are not subscribed"
      // ile düşüyordu (duyuru→bildirim buna takılıyordu). Bu, kullanıcının
      // ayarlardan toggle'la uğraşmasına gerek bırakmadan durumu düzeltir.
      await _alignPushSubscription();

      LogService.s(
        'OneSignal initialized successfully. Push: $hasPush',
        tag: 'OneSignal',
      );
    } catch (e, stack) {
      LogService.e(
        'Failed to initialize OneSignal',
        tag: 'OneSignal',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// FCM token'ı log için güvenli kısaltır. Token null **veya boş** olabilir
  /// (OneSignal abonelik henüz atanmadan boş string dönebilir); bu yüzden
  /// `substring` kullanmadan önce uzunluk kontrolü şart (RangeError fix).
  static String _previewToken(String? token) {
    if (token == null || token.isEmpty) return 'NULL';
    return token.length > 20 ? '${token.substring(0, 20)}...' : token;
  }

  /// Setup all notification event listeners
  void _setupNotificationListeners() {
    // ─────────────────────────────────────────────────────────────────────────
    // PUSH SUBSCRIPTION OBSERVER
    // ─────────────────────────────────────────────────────────────────────────
    OneSignal.User.pushSubscription.addObserver((state) {
      final subscriptionId = state.current.id;
      final token = state.current.token;
      final optedIn = state.current.optedIn;
      
      LogService.i(
        '═══════════════════════════════════════════════════════════════',
        tag: 'OneSignal',
      );
      LogService.i('📱 PUSH SUBSCRIPTION STATE CHANGED', tag: 'OneSignal');
      LogService.i('   Subscription ID: ${subscriptionId ?? "NULL"}', tag: 'OneSignal');
      LogService.i(
        '   FCM Token: ${_previewToken(token)}',
        tag: 'OneSignal',
      );
      LogService.i('   Opted In: $optedIn', tag: 'OneSignal');
      LogService.i(
        '═══════════════════════════════════════════════════════════════',
        tag: 'OneSignal',
      );
      
      if (subscriptionId != null && subscriptionId.isNotEmpty) {
        LogService.s('✅ Device successfully subscribed to OneSignal!', tag: 'OneSignal');
      } else if (token == null) {
        LogService.w('⚠️ No FCM token received - Check Firebase configuration!', tag: 'OneSignal');
      }
    });
    
    // Log initial subscription state
    final currentSubscription = OneSignal.User.pushSubscription;
    LogService.i(
      '📱 Initial Subscription ID: ${currentSubscription.id ?? "Not yet assigned"}',
      tag: 'OneSignal',
    );
    LogService.i(
      '📱 Initial Token: ${currentSubscription.token != null ? "Present" : "NULL"}',
      tag: 'OneSignal',
    );
    LogService.i(
      '📱 Initial Opted In: ${currentSubscription.optedIn}',
      tag: 'OneSignal',
    );

    // ─────────────────────────────────────────────────────────────────────────
    // Foreground notification handling
    // ─────────────────────────────────────────────────────────────────────────
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      LogService.i(
        'Foreground notification received: ${event.notification.title}',
        tag: 'OneSignal',
      );

      final notification = event.notification;
      final data = notification.additionalData ?? {};

      if (_onForegroundNotification != null) {
        event.preventDefault();
        
        _onForegroundNotification!(
          notification.title ??
              lookupAppLocalizations(Locale(ActiveLocale.cachedLanguageCode))
                  .lblNotification,
          notification.body ?? '',
          Map<String, dynamic>.from(data),
        );

        LogService.d(
          'Foreground notification suppressed, showing custom UI',
          tag: 'OneSignal',
        );
      } else {
        event.notification.display();
      }
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Notification click handling (Deep Linking)
    // ─────────────────────────────────────────────────────────────────────────
    OneSignal.Notifications.addClickListener((event) {
      LogService.i(
        'Notification clicked: ${event.notification.title}',
        tag: 'OneSignal',
      );

      final data = event.notification.additionalData ?? {};
      
      _notificationEventController.add(Map<String, dynamic>.from(data));

      final target = data['target']?.toString().trim();
      final idRaw = data['id'];
      final id = idRaw == null ? '' : idRaw.toString().trim();

      if (target == null || target.isEmpty || _onNotificationClick == null) {
        return;
      }

      if (!DeepLinkValidator.isNotificationTargetAllowed(target)) {
        DeepLinkValidator.logBlockedNotificationPayload(
          'Blocked unknown notification deep link target',
        );
        return;
      }

      if (DeepLinkValidator.notificationTargetRequiresId(target)) {
        if (!DeepLinkValidator.isValidRouteSegmentId(id)) {
          DeepLinkValidator.logBlockedNotificationPayload(
            'Blocked malformed notification deep link id',
          );
          return;
        }
      }

      LogService.d('Deep linking to: $target/${id.isEmpty ? "(none)" : id}', tag: 'OneSignal');
      _onNotificationClick!(target, id);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Permission change observer
    // ─────────────────────────────────────────────────────────────────────────
    OneSignal.Notifications.addPermissionObserver((permission) {
      LogService.i('Push permission changed: $permission', tag: 'OneSignal');
      state = state.copyWith(hasPushPermission: permission);
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 2: PERMISSION MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Check current push notification permission status
  bool _checkPushPermission() {
    try {
      return OneSignal.Notifications.permission;
    } catch (e) {
      LogService.w('Error checking push permission: $e', tag: 'OneSignal');
      return false;
    }
  }

  /// Push aboneliğini kullanıcı tercihine göre hizalar.
  ///
  /// "Genel Bildirimler" (`notif_pref_general`, varsayılan AÇIK) açıksa
  /// aboneliği `optIn()` yapar — böylece cihaz "Total Subscriptions" segmentine
  /// dahil olur ve server-side (REST) segment push'larını alır. Tercih açıkça
  /// kapatılmışsa dokunmaz (NotificationPrefsService zaten optOut çağırır).
  ///
  /// Not: `notif_pref_general` anahtarı `notification_prefs_service.dart` ile
  /// AYNI olmalı. Background isolate / Riverpod bağımsız çalışsın diye burada
  /// doğrudan SharedPreferences okunur.
  Future<void> _alignPushSubscription() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final general = prefs.getBool('notif_pref_general') ?? true;
      if (general) {
        OneSignal.User.pushSubscription.optIn();
        LogService.d(
          'Push subscription opted-in (general preference on)',
          tag: 'OneSignal',
        );
      }
    } catch (e) {
      LogService.w('Push subscription align failed: $e', tag: 'OneSignal');
    }
  }

  /// Request Push Notification Permission
  Future<bool> requestPushPermission() async {
    try {
      LogService.i('Requesting push notification permission...', tag: 'OneSignal');

      final granted = await OneSignal.Notifications.requestPermission(true);

      state = state.copyWith(hasPushPermission: granted);
      
      LogService.i(
        'Push permission ${granted ? 'GRANTED' : 'DENIED'}',
        tag: 'OneSignal',
      );

      return granted;
    } catch (e, stack) {
      LogService.e(
        'Error requesting push permission',
        tag: 'OneSignal',
        error: e,
        stackTrace: stack,
      );
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 3: DATA TAGGING (Free Plan: 2 Tags Max)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Subscribe to a district for targeted notifications
  /// Uses the "location" tag (1/2 of free plan allocation).
  Future<void> subscribeToDistrict(String slug) async {
    try {
      LogService.i('Subscribing to district: $slug', tag: 'OneSignal');
      await OneSignal.User.addTags({'location': slug});
      state = state.copyWith(currentDistrict: slug);
      LogService.s('Subscribed to district: $slug', tag: 'OneSignal');
    } catch (e, stack) {
      LogService.e(
        'Error subscribing to district',
        tag: 'OneSignal',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Unsubscribe from district notifications
  Future<void> unsubscribeFromDistrict() async {
    try {
      LogService.i('Unsubscribing from district', tag: 'OneSignal');
      await OneSignal.User.removeTags(['location']);
      state = state.copyWith(currentDistrict: null);
      LogService.s('Unsubscribed from district', tag: 'OneSignal');
    } catch (e, stack) {
      LogService.e(
        'Error unsubscribing from district',
        tag: 'OneSignal',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Update user interests for targeted notifications
  /// Uses the "interests" tag (2/2 of free plan allocation).
  Future<void> updateInterests(List<String> interests) async {
    try {
      final interestsString = interests.join(',');
      LogService.i('Updating interests: $interestsString', tag: 'OneSignal');
      await OneSignal.User.addTags({'interests': interestsString});
      LogService.s('Interests updated', tag: 'OneSignal');
    } catch (e, stack) {
      LogService.e(
        'Error updating interests',
        tag: 'OneSignal',
        error: e,
        stackTrace: stack,
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 4: USER MANAGEMENT (Phase 2 - Login System)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Login user with external ID
  @pragma('vm:entry-point')
  Future<void> login(String userId) async {
    try {
      LogService.i('Logging in user: $userId', tag: 'OneSignal');
      await OneSignal.login(userId);
      state = state.copyWith(oneSignalUserId: userId);
      LogService.s('User logged in to OneSignal: $userId', tag: 'OneSignal');
    } catch (e, stack) {
      LogService.e(
        'Error logging in user',
        tag: 'OneSignal',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      LogService.i('Logging out user', tag: 'OneSignal');
      await OneSignal.logout();
      state = state.copyWith(oneSignalUserId: null);
      LogService.s('User logged out from OneSignal', tag: 'OneSignal');
    } catch (e, stack) {
      LogService.e(
        'Error logging out user',
        tag: 'OneSignal',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Update all user tags at once
  /// WARNING: Free plan allows only 2 tags!
  Future<void> updateTags(Map<String, String> tags) async {
    try {
      if (tags.length > 2) {
        LogService.w(
          'FREE PLAN WARNING: Only 2 tags allowed. '
          'Using first 2 tags: ${tags.keys.take(2).join(", ")}',
          tag: 'OneSignal',
        );
        tags = Map.fromEntries(tags.entries.take(2));
      }

      LogService.i('Updating tags: $tags', tag: 'OneSignal');
      await OneSignal.User.addTags(tags);
      LogService.s('Tags updated', tag: 'OneSignal');
    } catch (e, stack) {
      LogService.e(
        'Error updating tags',
        tag: 'OneSignal',
        error: e,
        stackTrace: stack,
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 5: CALLBACKS REGISTRATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Set callback for notification clicks (deep linking)
  void setOnNotificationClick(OnNotificationClickCallback callback) {
    _onNotificationClick = callback;
    LogService.d('Notification click callback set', tag: 'OneSignal');
  }

  /// Set callback for foreground notifications
  void setOnForegroundNotification(OnForegroundNotificationCallback callback) {
    _onForegroundNotification = callback;
    LogService.d('Foreground notification callback set', tag: 'OneSignal');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 6: UTILITY METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get the OneSignal subscription ID
  Future<String?> getSubscriptionId() async {
    try {
      return OneSignal.User.pushSubscription.id;
    } catch (e) {
      LogService.w('Error getting subscription ID: $e', tag: 'OneSignal');
      return null;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// RIVERPOD PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Main notification service provider (Singleton pattern via Riverpod)
final notificationProvider =
    NotifierProvider<NotificationNotifier, NotificationState>(() {
  return NotificationNotifier();
});

/// Convenience provider for checking if push notifications are enabled
final isPushEnabledProvider = Provider<bool>((ref) {
  return ref.watch(notificationProvider).hasPushPermission;
});

/// Stream provider for notification events (for GoRouter deep linking)
final notificationEventsProvider = StreamProvider<NotificationPayload>((ref) {
  final notifier = ref.watch(notificationProvider.notifier);
  return notifier.notificationEvents;
});
