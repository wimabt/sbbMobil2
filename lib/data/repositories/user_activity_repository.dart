import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/endpoints.dart';
import '../../core/network/api_service.dart';

/// Kullanıcının ziyaret ettiği yerler + tamamladığı rotalar — **backend kaynaklı**,
/// kullanıcıya bağlı. Cihaz-geneli `LocalActivityTracker`'ın yerini alır;
/// hesap değiştiğinde veri otomatik kullanıcıya göre gelir, cihazlar arası senkron olur.
@immutable
class UserActivity {
  const UserActivity({
    this.visitedPlaceIds = const {},
    this.completedRouteIds = const {},
  });

  final Set<String> visitedPlaceIds;
  final Set<String> completedRouteIds;

  int get visitedCount => visitedPlaceIds.length;
  int get completedRoutesCount => completedRouteIds.length;

  UserActivity copyWith({
    Set<String>? visitedPlaceIds,
    Set<String>? completedRouteIds,
  }) {
    return UserActivity(
      visitedPlaceIds: visitedPlaceIds ?? this.visitedPlaceIds,
      completedRouteIds: completedRouteIds ?? this.completedRouteIds,
    );
  }

  /// Backend yanıtını parse eder. Esnek: alanlar farklı isimlerle gelebilir.
  /// Beklenen:
  /// ```json
  /// { "data": {
  ///     "visited_place_ids": ["12","45"],
  ///     "completed_route_ids": ["3"],
  ///     "places_visited": 2,
  ///     "routes_completed": 1
  /// } }
  /// ```
  factory UserActivity.fromJson(Map<String, dynamic> json) {
    final payload = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : json;

    Set<String> ids(dynamic v) {
      if (v is List) {
        return v.map((e) => e.toString()).where((s) => s.isNotEmpty).toSet();
      }
      return <String>{};
    }

    return UserActivity(
      visitedPlaceIds: ids(
        payload['visited_place_ids'] ?? payload['visited_places'],
      ),
      completedRouteIds: ids(
        payload['completed_route_ids'] ?? payload['completed_routes'],
      ),
    );
  }
}

/// Backend uç noktalarını saran depo. Tüm metotlar başarısızlıkta exception
/// fırlatır; çağıran (notifier) optimistic state'i geri sarar.
class UserActivityRepository {
  UserActivityRepository(this._dio);

  final Dio _dio;

  /// GET /api/v1/mobile/user/activity — kullanıcının tüm aktivitesi.
  Future<UserActivity> fetch() async {
    final response = await _dio.get(ApiEndpoints.mobileUserActivity);
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return UserActivity.fromJson(data);
    }
    return const UserActivity();
  }

  Future<void> markPlaceVisited(String placeId) =>
      _dio.post(ApiEndpoints.mobilePlaceVisit(placeId));

  Future<void> unmarkPlaceVisited(String placeId) =>
      _dio.delete(ApiEndpoints.mobilePlaceVisit(placeId));

  Future<void> markRouteCompleted(String routeId) =>
      _dio.post(ApiEndpoints.mobileRouteComplete(routeId));

  Future<void> unmarkRouteCompleted(String routeId) =>
      _dio.delete(ApiEndpoints.mobileRouteComplete(routeId));
}

/// Repo, paylaşılan auth'lu Dio üzerinden çalışır (ApiService.dio).
final userActivityRepositoryProvider = Provider<UserActivityRepository>((ref) {
  final dio = ref.watch(apiServiceProvider).dio;
  return UserActivityRepository(dio);
});
