import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';
/// Auth Repository - Kullanıcı yönetimi / authentication için data layer
abstract class AuthRepository {
  /// Backend health check
  ///
  /// flutter-integration.md dokümanındaki `/health` endpoint'ini çağırır.
  Future<bool> checkHealth();
}

/// API implementation - Docker + NestJS auth backend
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._client);

  final ApiClient _client;

  @override
  Future<bool> checkHealth() async {
    try {
      final response = await _client.get(ApiEndpoints.health);

      final ok = response.statusCode == 200;
      debugPrint('✅ [AuthRepository] /health status=${response.statusCode}, ok=$ok, body=${response.data}');
      return ok;
    } on DioException catch (e) {
      debugPrint('🔥 [AuthRepository] /health DioException: ${e.message}');
      throw ApiException.fromDioError(e);
    } catch (e) {
      debugPrint('🔥 [AuthRepository] /health error: $e');
      rethrow;
    }
  }
}

/// Provider - Sadece auth backend (Docker + NestJS) için
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(authApiClientProvider);
  return ApiAuthRepository(client);
});

