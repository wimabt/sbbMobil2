import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/feature_flags.dart';
import '../../../../core/services/discovery_service.dart';
import '../../../../data/models/points.dart';
import '../../../auth/providers/auth_provider.dart';

/// Kullanıcının güncel puan bakiyesi için provider.
///
/// **Auth-aware**: `authProvider` durumunu dinler.
///   - Kullanıcı giriş yapmamışsa → `null` döner (UI gizlenir).
///   - Kullanıcı giriş yaptığında veya auth durumu değiştiğinde
///     otomatik olarak taze veri çeker (eski cache kullanılmaz).
///
/// Backend: `GET /api/v1/mobile/points/balance`
final pointsBalanceProvider = FutureProvider.autoDispose<PointsBalance?>((ref) async {
  // Points/gamification feature flag — kapalıyken UI bu provider'a hiç bakmayacak
  // ama defense-in-depth için yine de null dön (HTTP atılmaz).
  if (!FeatureFlags.pointsEnabled) {
    return null;
  }

  final authState = ref.watch(authProvider);

  // Giriş yapılmamışsa veya henüz belirlenemiyorsa null dön
  if (authState.status != AuthStatus.authenticated) {
    return null;
  }

  final discovery = ref.watch(discoveryServiceProvider);
  try {
    return await discovery.getPointsBalance();
  } catch (_) {
    // Hata durumunda UI'nın tamamen çökmesini engellemek için
    // boş bir bakiye dönüyoruz. Ekranlar fallback değer gösterebilir.
    return PointsBalance.empty();
  }
});
