import 'dart:convert';

/// Şartname §6.5.2 — Gezi planı (Itinerary) modeli.
///
/// Bir kullanıcı birden fazla plan oluşturabilir; her plan birden fazla
/// duraktan oluşur. Mobil tarafta `LocalItineraryRepository` ile cihaz
/// üzerinde tutulur; backend hazır olduğunda (`backend_todo.md` → A5)
/// API tarafına aynalanacak.
class Itinerary {
  const Itinerary({
    required this.id,
    required this.title,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
    this.startsAt,
    this.endsAt,
    this.notes,
    this.itemsCount,
  });

  /// İstemci tarafında üretilen lokal benzersiz ID. Backend hazır olunca
  /// senkronizasyon esnasında server-issued ID ile değiştirilebilir.
  final String id;
  final String title;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? notes;

  /// Plan'ın durakları. **List endpoint'i bu alanı doldurmaz** (sadece özet
  /// döner); detay endpoint'i (`GET /itineraries/:id`) item'ları getirir.
  /// Liste ekranında item sayısını göstermek için [itemsCount] kullanılır.
  final List<ItineraryItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Backend list endpoint'inden gelen toplam durak sayısı. UI listede
  /// "9 durak" gibi gösterim yapmak için. Detail'de items.length kullan.
  final int? itemsCount;

  /// UI helper — list/detail farkını kaplayan tek "kaç durak var" alanı.
  int get displayItemCount => itemsCount ?? items.length;

  Itinerary copyWith({
    String? title,
    DateTime? startsAt,
    DateTime? endsAt,
    String? notes,
    List<ItineraryItem>? items,
    DateTime? updatedAt,
    int? itemsCount,
  }) {
    return Itinerary(
      id: id,
      title: title ?? this.title,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      notes: notes ?? this.notes,
      items: items ?? this.items,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
      itemsCount: itemsCount ?? this.itemsCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'starts_at': startsAt?.toIso8601String(),
        'ends_at': endsAt?.toIso8601String(),
        'notes': notes,
        'items': items.map((e) => e.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Itinerary.fromJson(Map<String, dynamic> json) {
    return Itinerary(
      id: json['id'].toString(),
      title: json['title'] as String? ?? '',
      startsAt: _parseDate(json['starts_at']),
      endsAt: _parseDate(json['ends_at']),
      notes: json['notes'] as String?,
      items: (json['items'] as List?)
              ?.map((e) =>
                  ItineraryItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          // Modifiable empty — sonradan add/sort yapılabilsin diye.
          <ItineraryItem>[],
      // Backend list endpoint'i `items_count` döndürür; detay endpoint'i
      // hem items hem items_count döndürebilir.
      itemsCount: (json['items_count'] as num?)?.toInt(),
      createdAt: _parseDate(json['created_at']) ?? DateTime.now().toUtc(),
      updatedAt: _parseDate(json['updated_at']) ?? DateTime.now().toUtc(),
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

/// Plan içerisindeki tek bir durak.
///
/// `entityType` şu an `place` veya `event` olabilir; ileride `route` /
/// `gastronomy` da eklenebilir.
class ItineraryItem {
  const ItineraryItem({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.entityName,
    required this.sortOrder,
    this.entityImageUrl,
    this.visitAt,
    this.notes,
  });

  final String id;
  final ItineraryEntityType entityType;
  final String entityId;
  final String entityName;
  final String? entityImageUrl;
  final DateTime? visitAt;
  final String? notes;
  final int sortOrder;

  ItineraryItem copyWith({
    DateTime? visitAt,
    String? notes,
    int? sortOrder,
    String? entityName,
    String? entityImageUrl,
  }) {
    return ItineraryItem(
      id: id,
      entityType: entityType,
      entityId: entityId,
      entityName: entityName ?? this.entityName,
      entityImageUrl: entityImageUrl ?? this.entityImageUrl,
      visitAt: visitAt ?? this.visitAt,
      notes: notes ?? this.notes,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'entity_type': entityType.value,
        'entity_id': entityId,
        'entity_name': entityName,
        'entity_image_url': entityImageUrl,
        'visit_at': visitAt?.toIso8601String(),
        'notes': notes,
        'sort_order': sortOrder,
      };

  factory ItineraryItem.fromJson(Map<String, dynamic> json) {
    return ItineraryItem(
      id: json['id'].toString(),
      entityType: ItineraryEntityType.fromString(
        json['entity_type'] as String? ?? 'place',
      ),
      entityId: json['entity_id'].toString(),
      entityName: json['entity_name'] as String? ?? '',
      entityImageUrl: json['entity_image_url'] as String?,
      visitAt: json['visit_at'] != null
          ? DateTime.tryParse(json['visit_at'] as String)
          : null,
      notes: json['notes'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

enum ItineraryEntityType {
  place('place'),
  event('event');

  const ItineraryEntityType(this.value);
  final String value;

  static ItineraryEntityType fromString(String value) {
    return ItineraryEntityType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ItineraryEntityType.place,
    );
  }
}

/// Liste serileştirme yardımcısı — repository tarafında JSON `String`
/// olarak SharedPreferences'a yazılırken kullanılır.
String encodeItineraries(List<Itinerary> list) =>
    jsonEncode(list.map((e) => e.toJson()).toList());

List<Itinerary> decodeItineraries(String? raw) {
  // Modifiable boş list — caller `.sort/add/removeWhere` çağırıyor.
  // `const []` döndürürsek `Unsupported operation: Cannot modify an
  // unmodifiable list` crash'i yaşanıyor.
  if (raw == null || raw.isEmpty) return <Itinerary>[];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <Itinerary>[];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(Itinerary.fromJson)
        .toList();
  } catch (_) {
    return <Itinerary>[];
  }
}
