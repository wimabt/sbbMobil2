import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../models/gastronomy.dart';

/// Gastronomy Repository Provider
final gastronomyRepositoryProvider = Provider<GastronomyRepository>((ref) {
  return GastronomyRepository(ref.watch(apiClientProvider));
});

/// Gastronomy Repository - Yöresel Lezzetler için veri katmanı
class GastronomyRepository {
  const GastronomyRepository(this._client);

  final ApiClient _client;

  /// Fetch gastronomy detail by ID
  Future<Gastronomy?> getById(String id) async {
    try {
      final response = await _client.get(
        '/menus/$id',
        queryParameters: {
          // Detay endpoint'inde tüm alanlar otomatik döndüğü için
          // ekstra fields parametresi göndermiyoruz; sadece dil bilgisi gönderiyoruz.
          'lang': 'tr',
        },
      );

      final raw = response.data;

      if (raw is Map<String, dynamic>) {
        final status = raw['success'] ?? raw['status'];
        final data = raw['data'];

        if (status == true && data != null) {
          return Gastronomy.fromJson(data as Map<String, dynamic>);
        }
      }
      return null;
    } on ApiException catch (e) {
      throw Exception('Gastronomy fetch failed: ${e.message}');
    }
  }

  /// Fetch all gastronomy items (list view)
  Future<List<Gastronomy>> getAll({int page = 1, int limit = 20}) async {
    try {
      final response = await _client.get(
        '/menus',
        queryParameters: {
          'page': page,
          'limit': limit,
          // Liste görünümü için optimize alanlar
          'fields': 'id,name,image_url,thumbnail_url,description',
          'lang': 'tr',
        },
      );

      final raw = response.data;

      if (raw is Map<String, dynamic>) {
        final status = raw['success'] ?? raw['status'];
        final data = raw['data'];

        if (status == true && data is List<dynamic>) {
          return data
              .map((e) => Gastronomy.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } on ApiException catch (e) {
      throw Exception('Gastronomy list fetch failed: ${e.message}');
    }
  }
}

