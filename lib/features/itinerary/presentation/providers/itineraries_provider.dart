import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/api_client.dart' show ApiException;
import '../../../../core/services/analytics_events.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/utils/image_url_helper.dart';
import '../../../../data/models/models.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../places/presentation/providers/places_provider.dart';

/// Şartname §6.5.2 — Gezi planları için Riverpod notifier.
///
/// Liste durumu in-memory tutulur; her değişiklik repository'ye yazılır.
/// Şu an `LocalItineraryRepository` (SharedPreferences) kullanır;
/// API repository'si eklendiğinde provider switch'i ile değişir.
class ItinerariesState {
  const ItinerariesState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  final List<Itinerary> items;
  final bool isLoading;
  final String? error;

  ItinerariesState copyWith({
    List<Itinerary>? items,
    bool? isLoading,
    Object? error = _sentinel,
  }) {
    return ItinerariesState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }

  static const _sentinel = Object();
}

class ItinerariesNotifier extends Notifier<ItinerariesState> {
  late ItineraryRepository _repo;

  @override
  ItinerariesState build() {
    _repo = ref.watch(itineraryRepositoryProvider);

    // Auth status'unu da izle. `itineraryRepositoryProvider` zaten auth'a göre
    // API↔Local switch yapıyor ama cold start race condition'larını önlemek
    // için notifier'ın kendisi de auth değişimini doğrudan görmeli — auth
    // restore tamamlandığında yeniden fetch tetiklenir.
    final authStatus = ref.watch(authProvider.select((s) => s.status));
    if (authStatus == AuthStatus.initial ||
        authStatus == AuthStatus.loading) {
      // Restore akışı bitmesini bekle.
      return const ItinerariesState(isLoading: true);
    }
    Future.microtask(refresh);
    return const ItinerariesState(isLoading: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final list = await _repo.list();
      final enriched = list.map(_enrichItinerary).toList(growable: false);
      state = state.copyWith(items: enriched, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Backend `/api/v1/itineraries/...` response'unda item'lar genelde sadece
  /// `entity_type` + `entity_id` döner; ad ve görsel **dönmez**. UI'da boş
  /// kart çıkmaması için `placesProvider` cache'inden zenginleştiriyoruz.
  ///
  /// Event/recipe için aynı yapı genişletilebilir.
  Itinerary _enrichItinerary(Itinerary itinerary) {
    final placesState = ref.read(placesProvider);
    if (placesState.allPlaces.isEmpty) return itinerary;

    final byId = {for (final p in placesState.allPlaces) p.id: p};
    final enrichedItems = itinerary.items.map((item) {
      if (item.entityType != ItineraryEntityType.place) return item;
      if (item.entityName.isNotEmpty &&
          (item.entityImageUrl ?? '').isNotEmpty) {
        return item;
      }
      final place = byId[item.entityId];
      if (place == null) return item;
      final resolvedName =
          item.entityName.isNotEmpty ? item.entityName : place.name;
      final resolvedImage = (item.entityImageUrl ?? '').isNotEmpty
          ? item.entityImageUrl
          : buildImageUrl(place.imageUrl);
      return item.copyWith(
        entityName: resolvedName,
        entityImageUrl: resolvedImage,
      );
    }).toList(growable: false);

    return itinerary.copyWith(items: enrichedItems);
  }

  /// Detay endpoint'inden tek plan'ı tazele (items dolu döner).
  ///
  /// Liste endpoint'i sadece `items_count` döndürdüğü için, detay ekranı
  /// açıldığında bu metodu çağırmak gerekiyor. Aksi durumda UI "0 yer"
  /// göstermeye devam eder.
  Future<void> loadDetail(String id) async {
    try {
      final fresh = await _repo.getById(id);
      if (fresh != null) {
        // State'te bu plan yoksa ekle, varsa item'larıyla güncelle.
        final exists = state.items.any((e) => e.id == fresh.id);
        if (exists) {
          _replaceLocal(fresh);
        } else {
          final enriched = _enrichItinerary(fresh);
          state = state.copyWith(items: [enriched, ...state.items]);
        }
      }
    } catch (e) {
      // Sessizce yut — state'te zaten partial veri var, UI çökmesin.
      // Hata mesajı state.error'a yazılırsa screen banner ile gösterebilir.
      state = state.copyWith(error: _humanError(e));
    }
  }

  Future<Itinerary?> createItinerary({
    required String title,
    DateTime? startsAt,
    DateTime? endsAt,
    String? notes,
  }) async {
    try {
      final created = await _repo.create(
        title: title,
        startsAt: startsAt,
        endsAt: endsAt,
        notes: notes,
      );
      state = state.copyWith(items: [created, ...state.items]);
      ref.read(analyticsServiceProvider).track(
        AnalyticsEvents.itineraryCreated,
        properties: {'itinerary_id': created.id},
      );
      return created;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<void> deleteItinerary(String id) async {
    await _repo.delete(id);
    state = state.copyWith(
      items: state.items.where((e) => e.id != id).toList(),
    );
  }

  Future<Itinerary?> renameItinerary(String id, String title) async {
    final current = await _repo.getById(id);
    if (current == null) return null;
    final updated = await _repo.update(current.copyWith(title: title));
    _replaceLocal(updated);
    return updated;
  }

  Future<Itinerary?> addItem(String itineraryId, ItineraryItem draft) async {
    try {
      final updated = await _repo.addItem(itineraryId, draft);
      _replaceLocal(updated);
      ref.read(analyticsServiceProvider).track(
        AnalyticsEvents.itineraryItemAdded,
        properties: {
          'itinerary_id': itineraryId,
          'entity_type': draft.entityType.value,
          'entity_id': draft.entityId,
        },
      );
      return updated;
    } catch (e) {
      state = state.copyWith(error: _humanError(e));
      return null;
    }
  }

  /// `ApiException`'ı kullanıcı dostu kısa mesaja çevir.
  /// Diğer Exception tipleri için ham mesajı döndürür.
  String _humanError(Object e) {
    final s = e.toString();
    // "ApiException: <msg> (code: <code>)" → sadece <msg>
    final match = RegExp(r'^ApiException:\s*(.+?)(?:\s*\(code:.*)?$').firstMatch(s);
    if (match != null) return match.group(1) ?? s;
    return s;
  }

  Future<Itinerary?> updateItem(
      String itineraryId, ItineraryItem item) async {
    try {
      final updated = await _repo.updateItem(itineraryId, item);
      _replaceLocal(updated);
      return updated;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<Itinerary?> removeItem(String itineraryId, String itemId) async {
    try {
      final updated = await _repo.removeItem(itineraryId, itemId);
      _replaceLocal(updated);
      return updated;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<Itinerary?> reorderItems(
      String itineraryId, List<String> orderedIds) async {
    try {
      final updated = await _repo.reorderItems(itineraryId, orderedIds);
      _replaceLocal(updated);
      return updated;
    } on ApiException catch (e) {
      // mobile_integ.md §5.2 — 409 ORDER_MISMATCH: sessizce sunucudan tazele.
      if (e.statusCode == 409 ||
          e.code == ApiException.codeOrderMismatch) {
        final fresh = await _repo.getById(itineraryId);
        if (fresh != null) _replaceLocal(fresh);
        return fresh;
      }
      state = state.copyWith(error: e.message);
      return null;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  void _replaceLocal(Itinerary updated) {
    // Backend item'lara name/image dönmediği için her replace'te enrich et.
    final enriched = _enrichItinerary(updated);
    final next = state.items
        .map((e) => e.id == enriched.id ? enriched : e)
        .toList(growable: false);
    state = state.copyWith(items: next);
  }
}

final itinerariesProvider =
    NotifierProvider<ItinerariesNotifier, ItinerariesState>(
  ItinerariesNotifier.new,
);

/// Tek bir planı reaktif şekilde almak için yardımcı.
final itineraryByIdProvider =
    Provider.family<Itinerary?, String>((ref, id) {
  final list = ref.watch(itinerariesProvider.select((s) => s.items));
  for (final it in list) {
    if (it.id == id) return it;
  }
  return null;
});
