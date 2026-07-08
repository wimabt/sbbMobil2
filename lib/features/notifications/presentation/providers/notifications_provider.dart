import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/locale_provider.dart';
import '../../../../data/models/models.dart';
import '../../../../data/repositories/repositories.dart';

/// Bildirimler sayfası provider'ı.
///
/// Backend'de "bildirim olarak gönder" işaretlenip push olarak gönderilmiş
/// duyuruları döner (en yeni önce). Duyurular sayfasından farkı: yalnız
/// bildirim olarak gidenleri gösterir.
final notificationsProvider =
    FutureProvider.autoDispose<List<Announcement>>((ref) async {
  final repository = ref.watch(announcementRepositoryProvider);

  // Dil değiştiğinde listeyi yeniden çek.
  final lang = ref.watch(
    localeProvider.select((s) => s.locale.languageCode),
  );

  try {
    return await repository.getNotifications(limit: 50, lang: lang);
  } catch (e) {
    debugPrint('❌ [notificationsProvider] Error: $e');
    return [];
  }
});
