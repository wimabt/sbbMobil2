/// Event (Etkinlik) model – Events API alanlarına uyumlu
/// EVENTS_API_MOBILE_KULLANIM.md fields: id, date, type, title, place, location,
/// category_label, ticket_url, is_free, image, image_url, time, created_at, updated_at
class Event {
  const Event({
    required this.id,
    required this.title,
    required this.date,
    required this.time,
    required this.place,
    required this.imageUrl,
    required this.type,
    required this.isFree,
    this.description,
    this.location,
    this.categoryLabel,
    this.ticketUrl,
    this.image,
    this.createdAt,
    this.updatedAt,
    this.price,
    this.attendeeCount,
  });

  final String id;
  final String title;
  final String date;
  final String time;
  final String place;
  final String imageUrl;
  final String type;
  final bool isFree;
  final String? description;
  /// place ile aynı (API alias)
  final String? location;
  /// type ile aynı (API alias)
  final String? categoryLabel;
  final String? ticketUrl;
  /// Ham görsel yolu
  final String? image;
  final String? createdAt;
  final String? updatedAt;
  final String? price;
  final int? attendeeCount;

  String get displayLocation => location ?? place;
  String get displayCategory => categoryLabel ?? type;
  
  /// Parses the date string into a DateTime object for filtering
  DateTime? get parsedStartDate {
    if (date.isEmpty) return null;
    
    try {
      // Try ISO format first (2026-02-03)
      if (date.contains('-')) {
        return DateTime.parse(date.split('T').first);
      }
      
      // Try Turkish format (03.02.2026)
      if (date.contains('.')) {
        final parts = date.split('.');
        if (parts.length == 3) {
          return DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        }
      }
      
      // Try slash format (03/02/2026)
      if (date.contains('/')) {
        final parts = date.split('/');
        if (parts.length == 3) {
          return DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        }
      }
    } catch (_) {
      return null;
    }
    
    return null;
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    return Event(
      id: id?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      place: json['place']?.toString() ?? json['location']?.toString() ?? '',
      imageUrl: _parseImageUrl(json),
      type: json['type']?.toString() ?? json['category_label']?.toString() ?? '',
      isFree: json['is_free'] == true,
      description: json['description']?.toString(),
      location: json['location']?.toString(),
      categoryLabel: json['category_label']?.toString() ?? json['type']?.toString(),
      ticketUrl: json['ticket_url']?.toString(),
      image: json['image']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      price: json['price']?.toString(),
      attendeeCount: json['attendee_count'] is int
          ? json['attendee_count'] as int
          : (json['attendee_count'] is num ? (json['attendee_count'] as num).toInt() : null),
    );
  }

  static String _parseImageUrl(Map<String, dynamic> json) {
    final url = json['image_url']?.toString();
    if (url != null && url.isNotEmpty) return url;
    final path = json['image']?.toString();
    if (path != null && path.isNotEmpty) return path;
    return '';
  }
}

/// API /events/categories yanıtındaki kategori
class EventCategoryItem {
  const EventCategoryItem({
    required this.id,
    required this.name,
    required this.slug,
    this.count = 0,
  });

  final int id;
  final String name;
  final String slug;
  final int count;

  factory EventCategoryItem.fromJson(Map<String, dynamic> json) {
    return EventCategoryItem(
      id: json['id'] as int? ?? 0,
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      count: json['count'] is int ? json['count'] as int : (json['count'] is num ? (json['count'] as num).toInt() : 0),
    );
  }
}
