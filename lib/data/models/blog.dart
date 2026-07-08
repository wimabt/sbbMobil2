// Şehir Rehberi & Blog modelleri.
//
// Backend (sbbMobilBackend) `/api/v1/mobile/blog/*` endpoint'leri dil-çözümlü
// (TR↔EN fallback) tek dil döndürür: `title`, `excerpt`, `content`,
// `category_name`, `tags[].name`. Bu yüzden modeller tek-dil alan tutar.

/// Blog etiketi.
class BlogTag {
  const BlogTag({required this.id, required this.slug, required this.name});

  final String id;
  final String slug;
  final String name;

  factory BlogTag.fromJson(Map<String, dynamic> json) => BlogTag(
        id: json['id'].toString(),
        slug: json['slug'] as String? ?? '',
        name: json['name'] as String? ?? '',
      );
}

/// Blog / şehir rehberi kategorisi.
class BlogCategory {
  const BlogCategory({
    required this.id,
    required this.slug,
    required this.name,
    this.icon,
    this.color,
    this.postCount = 0,
  });

  final String id;
  final String slug;
  final String name;
  final String? icon;
  final String? color;
  final int postCount;

  factory BlogCategory.fromJson(Map<String, dynamic> json) {
    int parseCount(dynamic v) {
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    return BlogCategory(
      id: json['id'].toString(),
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      postCount: parseCount(json['post_count']),
    );
  }
}

/// Blog yazısı (dil-çözümlü).
class BlogPost {
  const BlogPost({
    required this.id,
    required this.slug,
    required this.title,
    this.excerpt,
    this.content,
    this.coverImageUrl,
    this.thumbnailUrl,
    this.categoryId,
    this.categoryName,
    this.categorySlug,
    this.categoryColor,
    this.categoryIcon,
    this.readTimeMin,
    this.authorName,
    this.isFeatured = false,
    this.publishedAt,
    this.viewCount = 0,
    this.tags = const [],
  });

  final String id;
  final String slug;
  final String title;
  final String? excerpt;

  /// HTML içerik — yalnız detay endpoint'inde dolu gelir (liste'de null).
  final String? content;
  final String? coverImageUrl;
  final String? thumbnailUrl;
  final String? categoryId;
  final String? categoryName;
  final String? categorySlug;
  final String? categoryColor;
  final String? categoryIcon;
  final int? readTimeMin;
  final String? authorName;
  final bool isFeatured;
  final DateTime? publishedAt;
  final int viewCount;
  final List<BlogTag> tags;

  /// Liste kartı için görsel: thumbnail varsa onu, yoksa kapağı kullan.
  String get displayImageUrl => (thumbnailUrl != null && thumbnailUrl!.isNotEmpty)
      ? thumbnailUrl!
      : (coverImageUrl ?? '');

  factory BlogPost.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is String) return int.tryParse(v);
      return null;
    }

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    return BlogPost(
      id: json['id'].toString(),
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      excerpt: json['excerpt'] as String?,
      content: json['content'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      categoryId: json['category_id']?.toString(),
      categoryName: json['category_name'] as String?,
      categorySlug: json['category_slug'] as String?,
      categoryColor: json['category_color'] as String?,
      categoryIcon: json['category_icon'] as String?,
      readTimeMin: parseInt(json['read_time_min']),
      authorName: json['author_name'] as String?,
      isFeatured: json['is_featured'] == true || json['is_featured'] == 1,
      publishedAt: parseDate(json['published_at']),
      viewCount: parseInt(json['view_count']) ?? 0,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => BlogTag.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
