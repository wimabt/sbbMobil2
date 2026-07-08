import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api_service.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../models/itinerary.dart';
import 'api_itinerary_repository.dart';

/// Şartname §6.5.2 — Itinerary repository.
///
/// Şu anki implementasyon yerel: planlar `SharedPreferences` içinde tek bir
/// JSON dizisi olarak tutulur (`itineraries_v1`). Backend hazır olunca
/// (`backend_todo.md` → A5) bu interface'in API tabanlı bir
/// implementasyonu eklenir; provider tek satırla değiştirilebilir.
abstract class ItineraryRepository {
  Future<List<Itinerary>> list();
  Future<Itinerary?> getById(String id);
  Future<Itinerary> create({
    required String title,
    DateTime? startsAt,
    DateTime? endsAt,
    String? notes,
  });
  Future<Itinerary> update(Itinerary itinerary);
  Future<void> delete(String id);
  Future<Itinerary> addItem(String itineraryId, ItineraryItem item);
  Future<Itinerary> updateItem(String itineraryId, ItineraryItem item);
  Future<Itinerary> removeItem(String itineraryId, String itemId);
  Future<Itinerary> reorderItems(String itineraryId, List<String> orderedIds);
}

class LocalItineraryRepository implements ItineraryRepository {
  static const _kStorageKey = 'itineraries_v1';

  Future<List<Itinerary>> _readAll() async {
    final prefs = await SharedPreferences.getInstance();
    // Defensive copy — caller `.sort/add/removeWhere` yapacak; const list
    // mutation crash'i yaşanmasın.
    return List<Itinerary>.of(decodeItineraries(prefs.getString(_kStorageKey)));
  }

  Future<void> _writeAll(List<Itinerary> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStorageKey, encodeItineraries(list));
  }

  String _newId() {
    return 'itn_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
  }

  @override
  Future<List<Itinerary>> list() async {
    final list = await _readAll();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  @override
  Future<Itinerary?> getById(String id) async {
    final list = await _readAll();
    for (final it in list) {
      if (it.id == id) return it;
    }
    return null;
  }

  @override
  Future<Itinerary> create({
    required String title,
    DateTime? startsAt,
    DateTime? endsAt,
    String? notes,
  }) async {
    final now = DateTime.now().toUtc();
    final created = Itinerary(
      id: _newId(),
      title: title,
      items: const [],
      startsAt: startsAt,
      endsAt: endsAt,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
    final list = await _readAll();
    list.add(created);
    await _writeAll(list);
    return created;
  }

  @override
  Future<Itinerary> update(Itinerary itinerary) async {
    final list = await _readAll();
    final index = list.indexWhere((e) => e.id == itinerary.id);
    if (index < 0) {
      throw StateError('Itinerary ${itinerary.id} not found');
    }
    final updated = itinerary.copyWith(updatedAt: DateTime.now().toUtc());
    list[index] = updated;
    await _writeAll(list);
    return updated;
  }

  @override
  Future<void> delete(String id) async {
    final list = await _readAll();
    list.removeWhere((e) => e.id == id);
    await _writeAll(list);
  }

  @override
  Future<Itinerary> addItem(String itineraryId, ItineraryItem item) async {
    final current = await getById(itineraryId);
    if (current == null) {
      throw StateError('Itinerary $itineraryId not found');
    }
    final nextOrder = current.items.isEmpty
        ? 0
        : current.items.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b) +
            1;
    final newItem = ItineraryItem(
      id: 'iti_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
      entityType: item.entityType,
      entityId: item.entityId,
      entityName: item.entityName,
      entityImageUrl: item.entityImageUrl,
      visitAt: item.visitAt,
      notes: item.notes,
      sortOrder: nextOrder,
    );
    final updated = current.copyWith(items: [...current.items, newItem]);
    return update(updated);
  }

  @override
  Future<Itinerary> updateItem(
      String itineraryId, ItineraryItem item) async {
    final current = await getById(itineraryId);
    if (current == null) {
      throw StateError('Itinerary $itineraryId not found');
    }
    final items = current.items
        .map((e) => e.id == item.id ? item : e)
        .toList(growable: false);
    return update(current.copyWith(items: items));
  }

  @override
  Future<Itinerary> removeItem(String itineraryId, String itemId) async {
    final current = await getById(itineraryId);
    if (current == null) {
      throw StateError('Itinerary $itineraryId not found');
    }
    final items =
        current.items.where((e) => e.id != itemId).toList(growable: false);
    return update(current.copyWith(items: items));
  }

  @override
  Future<Itinerary> reorderItems(
      String itineraryId, List<String> orderedIds) async {
    final current = await getById(itineraryId);
    if (current == null) {
      throw StateError('Itinerary $itineraryId not found');
    }
    final byId = {for (final item in current.items) item.id: item};
    final reordered = <ItineraryItem>[];
    for (var i = 0; i < orderedIds.length; i++) {
      final item = byId[orderedIds[i]];
      if (item != null) {
        reordered.add(item.copyWith(sortOrder: i));
      }
    }
    return update(current.copyWith(items: reordered));
  }
}

/// mobile_integ.md §5.2 — Login durumu API/Local repo seçimini belirler.
/// Auth varsa `ApiItineraryRepository`, yoksa `LocalItineraryRepository`.
final itineraryRepositoryProvider = Provider<ItineraryRepository>((ref) {
  final auth = ref.watch(authProvider);
  if (auth.status == AuthStatus.authenticated) {
    final dio = ref.watch(apiServiceProvider).dio;
    return ApiItineraryRepository(dio);
  }
  return LocalItineraryRepository();
});

/// Local repo'ya doğrudan erişim — migration sırasında kullanılır.
final localItineraryRepositoryProvider =
    Provider<LocalItineraryRepository>((ref) {
  return LocalItineraryRepository();
});
