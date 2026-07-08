/// Announcement model - Duyurular
/// API Guide'a uygun olarak tasarlandı
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    this.excerpt,
    this.content,
    this.imageUrl,
    this.thumbnailUrl,
    this.categoryId,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
    this.tags = const [],
    this.isImportant = false,
    this.isNew = false,
    this.status = 'published',
    this.authorName,
    this.publishedAt,
    this.expiresAt,
    this.createdAt,
    this.viewCount,
  });

  final String id;
  final String title;
  final String? excerpt;
  final String? content;
  final String? imageUrl;
  final String? thumbnailUrl;
  final int? categoryId;
  final String? categoryName;
  final String? categoryIcon;
  final String? categoryColor;
  final List<String> tags;
  final bool isImportant;
  final bool isNew;
  final String status;
  final String? authorName;
  final DateTime? publishedAt;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final int? viewCount;

  /// Göreceli tarih metni (örn: "2 saat önce")
  String get relativeDate {
    if (publishedAt == null && createdAt == null) return '';
    final date = publishedAt ?? createdAt!;
    final diff = DateTime.now().difference(date);

    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dakika önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} hafta önce';
    return '${(diff.inDays / 30).floor()} ay önce';
  }

  /// "Yeni" etiketi gösterilmeli mi?
  /// API'den gelen isNew değeri veya yayınlanma tarihinden itibaren 7 gün içindeyse true
  bool get shouldShowNewBadge {
    // API'den gelen isNew değeri varsa onu kullan
    if (isNew) return true;
    
    // Tarih bazlı kontrol: Yayınlanma tarihinden itibaren 7 gün içindeyse "yeni" sayılır
    if (publishedAt == null && createdAt == null) return false;
    final date = publishedAt ?? createdAt!;
    final diff = DateTime.now().difference(date);
    
    // 7 gün (168 saat) içindeyse "yeni" olarak göster
    return diff.inDays < 7;
  }

  /// Kategori isme göre "Ulaşım", "Etkinlik" vb.
  String get category => categoryName ?? '';

  /// Factory from JSON (API Guide uyumlu)
  factory Announcement.fromJson(Map<String, dynamic> json) {
    // Helper to parse int from int or String
    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }
    
    return Announcement(
      id: json['id'].toString(),
      title: json['title'] as String? ?? '',
      excerpt: json['excerpt'] as String?,
      content: json['content'] as String?,
      imageUrl: json['image_url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      categoryId: parseInt(json['category_id']),
      categoryName: json['category_name'] as String? ?? json['category'] as String?,
      categoryIcon: json['category_icon'] as String?,
      categoryColor: json['category_color'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      isImportant: json['is_important'] == true || json['is_important'] == 1,
      isNew: json['is_new'] == true || json['is_new'] == 1,
      status: json['status'] as String? ?? 'published',
      authorName: json['author_name'] as String? ?? json['author'] as String?,
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'] as String)
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      viewCount: parseInt(json['view_count']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'excerpt': excerpt,
      'content': content,
      'image_url': imageUrl,
      'thumbnail_url': thumbnailUrl,
      'category_id': categoryId,
      'category_name': categoryName,
      'category_icon': categoryIcon,
      'category_color': categoryColor,
      'tags': tags,
      'is_important': isImportant,
      'is_new': isNew,
      'status': status,
      'author_name': authorName,
      'published_at': publishedAt?.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'view_count': viewCount,
    };
  }

  Announcement copyWith({
    String? id,
    String? title,
    String? excerpt,
    String? content,
    String? imageUrl,
    String? thumbnailUrl,
    int? categoryId,
    String? categoryName,
    String? categoryIcon,
    String? categoryColor,
    List<String>? tags,
    bool? isImportant,
    bool? isNew,
    String? status,
    String? authorName,
    DateTime? publishedAt,
    DateTime? expiresAt,
    DateTime? createdAt,
    int? viewCount,
  }) {
    return Announcement(
      id: id ?? this.id,
      title: title ?? this.title,
      excerpt: excerpt ?? this.excerpt,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      categoryIcon: categoryIcon ?? this.categoryIcon,
      categoryColor: categoryColor ?? this.categoryColor,
      tags: tags ?? this.tags,
      isImportant: isImportant ?? this.isImportant,
      isNew: isNew ?? this.isNew,
      status: status ?? this.status,
      authorName: authorName ?? this.authorName,
      publishedAt: publishedAt ?? this.publishedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      viewCount: viewCount ?? this.viewCount,
    );
  }
}

/// Announcement Category - API Guide uyumlu
class AnnouncementCategory {
  const AnnouncementCategory({
    required this.id,
    required this.name,
    this.icon,
    this.color,
    this.announcementCount = 0,
  });

  final int id;
  final String name;
  final String? icon;
  final String? color;
  final int announcementCount;

  /// Label getter for compatibility
  String get label => name;

  factory AnnouncementCategory.fromJson(Map<String, dynamic> json) {
    // Handle id as int or String
    int parseId(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }
    
    // Handle announcement_count as int or String
    int parseCount(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }
    
    return AnnouncementCategory(
      id: parseId(json['id']),
      name: json['name'] as String? ?? json['label'] as String? ?? '',
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      announcementCount: parseCount(json['announcement_count']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
      'announcement_count': announcementCount,
    };
  }
}
