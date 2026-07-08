import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/locale_provider.dart';
import '../../../../data/models/models.dart';
import '../../../../data/repositories/repositories.dart';

/// Okunmamış bildirim rozeti (ana sayfadaki zil ikonunun kırmızı noktası).
///
/// Mantık (saat sapmasına dayanıklı): "en son görüldü" işareti olarak
/// SİSTEM saati değil, görülen bildirimlerin **sunucu** zaman damgası saklanır.
/// Bir bildirim, zaman damgası bu işaretten yeniyse "okunmamış" sayılır.
///
///   • Kullanıcı Bildirimler sayfasını açınca [markAllSeen] çağrılır → o anki en
///     yeni bildirimin zamanı `notif_badge_last_seen_millis` olarak kaydedilir
///     ve nokta kaybolur.
///   • Yeni bir push geldiğinde (createdAt > kayıtlı işaret) nokta tekrar belirir.
const String _kLastSeenKey = 'notif_badge_last_seen_millis';

/// Bir duyurunun sıralama (yenilik) zamanını epoch-ms olarak verir.
int _sortMillis(Announcement a) {
  final date = a.publishedAt ?? a.createdAt;
  return date?.millisecondsSinceEpoch ?? 0;
}

/// Listedeki en yeni bildirimin epoch-ms değeri (yoksa 0).
int newestNotificationMillis(List<Announcement> items) {
  var newest = 0;
  for (final a in items) {
    final ms = _sortMillis(a);
    if (ms > newest) newest = ms;
  }
  return newest;
}

class NotificationBadgeNotifier extends AsyncNotifier<bool> {
  /// build() sırasında hesaplanan, sunucudaki en yeni bildirim zamanı.
  int _newestMillis = 0;

  @override
  Future<bool> build() async {
    // Dil değişince yeniden çek (liste dile göre döner).
    final lang = ref.watch(localeProvider.select((s) => s.locale.languageCode));
    final repo = ref.watch(announcementRepositoryProvider);

    final prefs = await SharedPreferences.getInstance();
    final lastSeen = prefs.getInt(_kLastSeenKey) ?? 0;

    try {
      // Rozet için küçük bir sayfa yeterli — sadece "en yeni" lazım.
      final items = await repo.getNotifications(limit: 20, lang: lang);
      _newestMillis = newestNotificationMillis(items);
      return _newestMillis > lastSeen;
    } catch (e) {
      debugPrint('⚠️ [NotificationBadge] fetch failed: $e');
      // Hata → rozet gösterme (yanlış pozitif olmasın).
      return false;
    }
  }

  /// Bildirimler görüldü → en yeni bildirim zamanını "görüldü" işaretle.
  ///
  /// [newestMillis] verilirse (Bildirimler ekranının kendi listesinden) onu,
  /// yoksa build() sırasında hesaplanan değeri kullanır. Hiç veri yoksa
  /// işaret güncellenmez (yanlışlıkla gelecekteki bildirimleri gizlememek için).
  Future<void> markAllSeen([int? newestMillis]) async {
    final seen = (newestMillis != null && newestMillis > 0)
        ? newestMillis
        : _newestMillis;

    if (seen > 0) {
      try {
        final prefs = await SharedPreferences.getInstance();
        // Geri gitmeyi önle: mevcut işaretten küçük bir değeri yazma.
        final current = prefs.getInt(_kLastSeenKey) ?? 0;
        if (seen > current) {
          await prefs.setInt(_kLastSeenKey, seen);
        }
      } catch (e) {
        debugPrint('⚠️ [NotificationBadge] persist failed: $e');
      }
    }

    state = const AsyncData(false);
  }
}

/// Ana sayfadaki zil ikonu bu provider'ı izler.
final notificationBadgeProvider =
    AsyncNotifierProvider<NotificationBadgeNotifier, bool>(
  NotificationBadgeNotifier.new,
);

/// Kolaylık: yalnızca bool (yükleniyor/hata → false).
final hasUnseenNotificationsProvider = Provider<bool>((ref) {
  return ref.watch(notificationBadgeProvider).value ?? false;
});
