import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/endpoints.dart';
import '../../data/models/place.dart';
import '../network/api_service.dart';
import '../utils/image_url_helper.dart';
import 'log_service.dart';

const _tag = 'ArService';

/// AR backend service — fetches AR-specific place data and resolves QR URLs.
///
/// Uses the authenticated Dio instance from [ApiService] for JWT-protected
/// endpoints defined in ar_bcknd.md.
class ArService {
  ArService(this._apiService);

  final ApiService _apiService;
  Dio get _dio => _apiService.dio;

  /// Fetches AR-specific place data by place ID.
  ///
  /// Endpoint: `GET /api/v1/mobile/ar/place/{id}`
  /// Used when a QR code contains a `modelId` (place ID).
  Future<ArPlaceResult> fetchArPlace(String placeId) async {
    try {
      final response = await _dio.get(ApiEndpoints.mobileArPlace(placeId));
      final data = response.data;

      if (data['success'] == true && data['data'] != null) {
        final placeJson = data['data'] as Map<String, dynamic>;
        final rawUrl = placeJson['ar_model_url'] as String?;
        return ArPlaceResult(
          place: Place.fromJson(placeJson),
          modelUrl: rawUrl != null ? rewriteStorageUrl(rawUrl) : null,
          modelName: placeJson['ar_model_name'] as String?,
        );
      }

      LogService.w('AR place not found: $placeId', tag: _tag);
      return const ArPlaceResult();
    } on DioException catch (e) {
      LogService.e('fetchArPlace failed', tag: _tag, error: e);
      return ArPlaceResult(error: e.message);
    } catch (e) {
      LogService.e('fetchArPlace failed', tag: _tag, error: e);
      return ArPlaceResult(error: e.toString());
    }
  }

  /// Resolves a raw model URL to find the associated place.
  ///
  /// Endpoint: `GET /api/v1/mobile/ar/resolve?url={ENCODED_URL}`
  /// Used when a QR code contains only a plain .glb URL.
  Future<ArResolveResult> resolveArUrl(String modelUrl) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.mobileArResolve,
        queryParameters: {'url': modelUrl},
      );
      final data = response.data;

      if (data['success'] == true && data['data'] != null) {
        final resultJson = data['data'] as Map<String, dynamic>;
        final resolved = resultJson['resolved'] == true;
        final rawArUrl = resultJson['ar_model_url'] as String?;
        final resolvedModelUrl = rewriteStorageUrl(rawArUrl ?? modelUrl);

        if (resolved && resultJson['id'] != null) {
          return ArResolveResult(
            resolved: true,
            place: Place.fromJson(resultJson),
            modelUrl: resolvedModelUrl,
            modelName: resultJson['ar_model_name'] as String?,
          );
        }

        return ArResolveResult(
          resolved: false,
          modelUrl: resolvedModelUrl,
        );
      }

      return ArResolveResult(resolved: false, modelUrl: rewriteStorageUrl(modelUrl));
    } on DioException catch (e) {
      LogService.e('resolveArUrl failed', tag: _tag, error: e);
      return ArResolveResult(resolved: false, modelUrl: modelUrl, error: e.message);
    } catch (e) {
      LogService.e('resolveArUrl failed', tag: _tag, error: e);
      return ArResolveResult(resolved: false, modelUrl: modelUrl, error: e.toString());
    }
  }
}

/// Result from [ArService.fetchArPlace].
class ArPlaceResult {
  const ArPlaceResult({this.place, this.modelUrl, this.modelName, this.error});

  final Place? place;
  final String? modelUrl;
  final String? modelName;
  final String? error;

  bool get hasModel => modelUrl != null && modelUrl!.isNotEmpty;
  bool get hasError => error != null;
}

/// Result from [ArService.resolveArUrl].
class ArResolveResult {
  const ArResolveResult({
    required this.resolved,
    this.place,
    this.modelUrl,
    this.modelName,
    this.error,
  });

  final bool resolved;
  final Place? place;
  final String? modelUrl;
  final String? modelName;
  final String? error;

  bool get hasModel => modelUrl != null && modelUrl!.isNotEmpty;
  bool get hasError => error != null;
}

/// Riverpod provider for [ArService].
final arServiceProvider = Provider<ArService>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return ArService(apiService);
});
