import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart' show ApiException;
import '../../api/endpoints.dart';
import '../../core/network/api_service.dart';

/// mobile_integ.md A1 + A4 — Kullanıcının sunucu tarafında tutulan
/// kişisel tercih API'lerine erişim.
///
/// Auth gerektiren tüm endpoint'ler `ApiService.dio` üzerinden çağrılır;
/// JWT interceptor ve 401 → refresh akışı otomatik devrededir.
class UserPreferencesRepository {
  UserPreferencesRepository(this._dio);

  final Dio _dio;

  // ─── A1: İlgi alanları ─────────────────────────────────────────────

  /// Sunucudaki ilgi alanı slug listesini getirir.
  /// Hata durumunda [ApiException] fırlatır.
  Future<List<String>> fetchInterests() async {
    try {
      final response = await _dio.get(ApiEndpoints.userInterests);
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final payload = data['data'];
        if (payload is Map<String, dynamic>) {
          final list = payload['interests'];
          if (list is List) {
            return list.map((e) => e.toString()).toList();
          }
        } else if (payload is List) {
          return payload.map((e) => e.toString()).toList();
        }
      }
      return const [];
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Sunucuya tam liste push'lar (set-replace).
  /// Boş liste geçerlidir → tüm seçimleri temizler.
  Future<List<String>> updateInterests(List<String> slugs) async {
    try {
      final response = await _dio.put(
        ApiEndpoints.userInterests,
        data: {'interests': slugs},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final payload = data['data'];
        if (payload is Map<String, dynamic>) {
          final list = payload['interests'];
          if (list is List) {
            return list.map((e) => e.toString()).toList();
          }
        }
      }
      return slugs;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // ─── A4: Bildirim tercihleri ───────────────────────────────────────

  /// Sunucudaki bildirim tercihleri snapshot'ı. Kayıt yoksa default'lar döner.
  Future<NotificationPrefsRemote> fetchNotificationPrefs() async {
    try {
      final response = await _dio.get(ApiEndpoints.userNotificationPrefs);
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final payload = data['data'];
        if (payload is Map<String, dynamic>) {
          return NotificationPrefsRemote.fromJson(payload);
        }
      }
      return const NotificationPrefsRemote();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Bir veya birden fazla tercihi günceller. `null` alanlar gönderilmez.
  Future<NotificationPrefsRemote> updateNotificationPrefs({
    bool? general,
    bool? campaigns,
    bool? events,
    bool? geofence,
  }) async {
    final body = <String, dynamic>{
      'general': ?general,
      'campaigns': ?campaigns,
      'events': ?events,
      'geofence': ?geofence,
    };
    if (body.isEmpty) return fetchNotificationPrefs();
    try {
      final response = await _dio.put(
        ApiEndpoints.userNotificationPrefs,
        data: body,
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final payload = data['data'];
        if (payload is Map<String, dynamic>) {
          return NotificationPrefsRemote.fromJson(payload);
        }
      }
      return NotificationPrefsRemote(
        general: general,
        campaigns: campaigns,
        events: events,
        geofence: geofence,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}

/// Backend'den dönen bildirim tercih snapshot'ı.
/// Tüm alanlar opsiyonel — `updatedAt == null` sunucuda hiç kayıt olmadığı
/// anlamına gelir ve A4 reconciliation stratejisinde kullanılır.
@immutable
class NotificationPrefsRemote {
  const NotificationPrefsRemote({
    this.general,
    this.campaigns,
    this.events,
    this.geofence,
    this.updatedAt,
  });

  final bool? general;
  final bool? campaigns;
  final bool? events;
  final bool? geofence;
  final DateTime? updatedAt;

  /// Sunucuda hiç tercih kaydı yoksa `true`.
  bool get isEmpty => updatedAt == null;

  factory NotificationPrefsRemote.fromJson(Map<String, dynamic> json) {
    DateTime? parsed;
    final raw = json['updated_at'];
    if (raw is String && raw.isNotEmpty) {
      parsed = DateTime.tryParse(raw);
    }
    return NotificationPrefsRemote(
      general: json['general'] as bool?,
      campaigns: json['campaigns'] as bool?,
      events: json['events'] as bool?,
      geofence: json['geofence'] as bool?,
      updatedAt: parsed,
    );
  }
}

final userPreferencesRepositoryProvider =
    Provider<UserPreferencesRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return UserPreferencesRepository(apiService.dio);
});
