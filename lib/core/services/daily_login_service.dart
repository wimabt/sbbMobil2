import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/feature_flags.dart';
import '../network/api_service.dart';
import '../../api/api.dart';

/// Günlük giriş ve seri (streak) servisi
///
/// flutter-integration.md §18.4 ve §16'daki `DailyLoginService` akışına göre
/// `POST /api/v1/mobile/daily-login` ve `GET /api/v1/mobile/streak` endpoint'lerini
/// sarmalar.
class DailyLoginService {
  DailyLoginService(this._apiService);

  final ApiService _apiService;

  Dio get _dio => _apiService.dio;

  /// Günlük giriş puanını talep et.
  ///
  /// Endpoint: `POST /api/v1/mobile/daily-login`
  /// Dönen `data` objesini direkt geçirir:
  /// {
  ///   "awarded": true/false,
  ///   "points": ...,
  ///   "streak": ...,
  ///   ...
  /// }
  Future<Map<String, dynamic>> claimDailyLogin() async {
    // Points/gamification feature flag — kapalıyken HTTP atılmaz.
    // Defense-in-depth: UI katmanı zaten flag'li olmalı; buraya düşerse no-op.
    if (!FeatureFlags.pointsEnabled) {
      return const <String, dynamic>{
        'awarded': false,
        'points': 0,
        'streak': 0,
      };
    }
    try {
      final response = await _dio.post(ApiEndpoints.mobileDailyLogin);
      final data = response.data as Map<String, dynamic>;
      return data['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      // `mobile_pending_changes.md` P0/4 — Backend feature kapalıyken sessiz skip.
      if (e.isFeatureDisabled) {
        if (kDebugMode) {
          debugPrint('🟡 [DailyLoginService] claimDailyLogin: feature disabled (503)');
        }
        return const <String, dynamic>{
          'awarded': false,
          'points': 0,
          'streak': 0,
        };
      }
      if (kDebugMode) {
        debugPrint('🔥 [DailyLoginService] claimDailyLogin error: $e');
      }
      rethrow;
    }
  }

  /// Kullanıcının seri (streak) bilgisi.
  ///
  /// Endpoint: `GET /api/v1/mobile/streak`
  Future<Map<String, dynamic>> getStreak() async {
    if (!FeatureFlags.pointsEnabled) {
      return const <String, dynamic>{
        'streak': 0,
        'longest_streak': 0,
        'last_login': null,
      };
    }
    try {
      final response = await _dio.get(ApiEndpoints.mobileStreak);
      final data = response.data as Map<String, dynamic>;
      return data['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      // `mobile_pending_changes.md` P0/4 — Backend feature kapalıyken sessiz skip.
      if (e.isFeatureDisabled) {
        if (kDebugMode) {
          debugPrint('🟡 [DailyLoginService] getStreak: feature disabled (503)');
        }
        return const <String, dynamic>{
          'streak': 0,
          'longest_streak': 0,
          'last_login': null,
        };
      }
      if (kDebugMode) {
        debugPrint('🔥 [DailyLoginService] getStreak error: $e');
      }
      rethrow;
    }
  }
}

/// Riverpod provider – Günlük giriş servisi
final dailyLoginServiceProvider = Provider<DailyLoginService>((ref) {
  final api = ref.watch(apiServiceProvider);
  return DailyLoginService(api);
});

