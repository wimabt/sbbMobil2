import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/repositories.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'log_service.dart';

/// Şartname §7.4.2 — Bildirim türleri için ayrı toggle'lar.
///
/// Tasarım kararları:
///   • **Genel** anahtar OneSignal push subscription'ı opt-in / opt-out eder.
///     Kapatıldığında diğer kategoriler de pratik olarak susar.
///   • **Kampanya / Etkinlik** kategorileri tek bir OneSignal tag (`prefs`)
///     altında comma-separated saklanır. Free plan 2 tag limiti aşılmaz
///     (`location` zaten kullanılıyor).
///   • **Lokasyon (geofence)** ayrı bir akış (`GeofenceService`) tarafından
///     yönetildiği için bu provider'da yer almaz; ayar ekranında dördüncü
///     toggle olarak yan yana gösterilir.
///
/// Backend tarafında `/api/v1/user/notification-prefs` endpoint'i
/// (bkz. `backend_todo.md` → B1) hazır olduğunda `_pushToBackend` metodu
/// HTTP isteği yapacak; çağrı tarafı değişmeyecek.
const String _kGeneralKey = 'notif_pref_general';
const String _kCampaignsKey = 'notif_pref_campaigns';
const String _kEventsKey = 'notif_pref_events';

@immutable
class NotificationPrefsState {
  const NotificationPrefsState({
    this.general = true,
    this.campaigns = true,
    this.events = true,
    this.isLoaded = false,
  });

  /// Push bildirimi açık mı? Kapalıysa cihaz OneSignal'dan opt-out.
  final bool general;
  final bool campaigns;
  final bool events;
  final bool isLoaded;

  NotificationPrefsState copyWith({
    bool? general,
    bool? campaigns,
    bool? events,
    bool? isLoaded,
  }) {
    return NotificationPrefsState(
      general: general ?? this.general,
      campaigns: campaigns ?? this.campaigns,
      events: events ?? this.events,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

class NotificationPrefsNotifier extends Notifier<NotificationPrefsState> {
  /// mobile_integ.md §4.2 — Kullanıcı toggle'ı hızlıca değiştirirse her
  /// değişim için ayrı PUT atmamak adına son hali 500 ms debounce ile gönder.
  Timer? _debounceTimer;
  static const Duration _debounceDuration = Duration(milliseconds: 500);

  @override
  NotificationPrefsState build() {
    ref.onDispose(() => _debounceTimer?.cancel());
    return const NotificationPrefsState();
  }

  /// Uygulama açılışında çağrılır (`main.dart`).
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = NotificationPrefsState(
        general: prefs.getBool(_kGeneralKey) ?? true,
        campaigns: prefs.getBool(_kCampaignsKey) ?? true,
        events: prefs.getBool(_kEventsKey) ?? true,
        isLoaded: true,
      );
    } catch (_) {
      state = state.copyWith(isLoaded: true);
    }
  }

  Future<void> setGeneral(bool enabled) async {
    state = state.copyWith(general: enabled);
    await _persistBool(_kGeneralKey, enabled);
    try {
      if (enabled) {
        OneSignal.User.pushSubscription.optIn();
      } else {
        OneSignal.User.pushSubscription.optOut();
      }
    } catch (e, stack) {
      LogService.e(
        'Failed to toggle OneSignal opt-in',
        tag: 'NotifPrefs',
        error: e,
        stackTrace: stack,
      );
    }
    await _syncCategoryTag();
    _schedulePush();
  }

  Future<void> setCampaigns(bool enabled) async {
    state = state.copyWith(campaigns: enabled);
    await _persistBool(_kCampaignsKey, enabled);
    await _syncCategoryTag();
    _schedulePush();
  }

  Future<void> setEvents(bool enabled) async {
    state = state.copyWith(events: enabled);
    await _persistBool(_kEventsKey, enabled);
    await _syncCategoryTag();
    _schedulePush();
  }

  /// mobile_integ.md §4.2 — Login akışı sonrası reconcile.
  /// Strateji: sunucu kaydı varsa kazanır; yoksa cihaz değerleriyle PUT.
  Future<void> reconcileWithServer() async {
    final auth = ref.read(authProvider);
    if (auth.status != AuthStatus.authenticated) return;
    final repo = ref.read(userPreferencesRepositoryProvider);
    try {
      final remote = await repo.fetchNotificationPrefs();
      if (remote.isEmpty) {
        // Sunucuda kayıt yok → cihaz değerlerini yükle (backfill).
        await repo.updateNotificationPrefs(
          general: state.general,
          campaigns: state.campaigns,
          events: state.events,
        );
        return;
      }
      // Sunucu kazandı; lokali güncelle.
      final newState = state.copyWith(
        general: remote.general ?? state.general,
        campaigns: remote.campaigns ?? state.campaigns,
        events: remote.events ?? state.events,
      );
      state = newState;
      final prefs = await SharedPreferences.getInstance();
      if (remote.general != null) {
        await prefs.setBool(_kGeneralKey, remote.general!);
      }
      if (remote.campaigns != null) {
        await prefs.setBool(_kCampaignsKey, remote.campaigns!);
      }
      if (remote.events != null) {
        await prefs.setBool(_kEventsKey, remote.events!);
      }
      // OneSignal subscription state'i de senkronla.
      try {
        if (remote.general == true) {
          OneSignal.User.pushSubscription.optIn();
        } else if (remote.general == false) {
          OneSignal.User.pushSubscription.optOut();
        }
      } catch (_) {}
      await _syncCategoryTag();
    } catch (e, stack) {
      LogService.e(
        'NotifPrefs reconcileWithServer failed',
        tag: 'NotifPrefs',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// 500ms debounce — son toggle değişiminden sonra tek PUT atar.
  void _schedulePush() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, _pushToBackend);
  }

  Future<void> _pushToBackend() async {
    final auth = ref.read(authProvider);
    if (auth.status != AuthStatus.authenticated) return;
    try {
      await ref.read(userPreferencesRepositoryProvider).updateNotificationPrefs(
            general: state.general,
            campaigns: state.campaigns,
            events: state.events,
          );
    } catch (e, stack) {
      LogService.w(
        'NotifPrefs push failed: $e',
        tag: 'NotifPrefs',
      );
      if (kDebugMode) debugPrint('$stack');
    }
  }

  Future<void> _persistBool(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      LogService.w(
        'Failed to persist notif pref [$key]: $e',
        tag: 'NotifPrefs',
      );
    }
  }

  /// `prefs` tag'ini OneSignal tarafına push'lar. Free plan tag limitini
  /// aşmamak için tek anahtar altında comma-separated değer kullanırız.
  /// Örn: `prefs=campaigns,events` veya `prefs=campaigns` veya tag yok.
  Future<void> _syncCategoryTag() async {
    try {
      final active = <String>[
        if (state.campaigns) 'campaigns',
        if (state.events) 'events',
      ];
      if (active.isEmpty) {
        await OneSignal.User.removeTags(['prefs']);
      } else {
        await OneSignal.User.addTags({'prefs': active.join(',')});
      }
    } catch (e, stack) {
      LogService.e(
        'Failed to sync OneSignal prefs tag',
        tag: 'NotifPrefs',
        error: e,
        stackTrace: stack,
      );
    }
  }
}

final notificationPrefsProvider =
    NotifierProvider<NotificationPrefsNotifier, NotificationPrefsState>(
  NotificationPrefsNotifier.new,
);
