/// Generic API Response wrapper
/// API kılavuzundaki standart response formatına uygun
class ApiResponse<T> {
  const ApiResponse({
    required this.status,
    required this.message,
    this.data,
    this.meta,
    this.code,
    this.errors,
  });

  final bool status;
  final String message;
  final T? data;
  final ApiMeta? meta;
  final String? code;
  final Map<String, List<String>>? errors;

  /// JSON'dan ApiResponse oluştur
  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) {
    // Backend'den "pagination" veya "meta" gelebilir
    final metaData = json['meta'] ?? json['pagination'];
    
    return ApiResponse<T>(
      status: json['status'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] != null ? fromJsonT(json['data']) : null,
      meta: metaData != null
          ? ApiMeta.fromJson(metaData as Map<String, dynamic>)
          : null,
      code: json['code'] as String?,
      errors: (json['errors'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, List<String>.from(v as List)),
      ),
    );
  }

  /// Başarılı response mi?
  bool get isSuccess => status && data != null;

  /// Hata response'u mu?
  bool get isError => !status;

  /// İlk hata mesajını al
  String? get firstError {
    if (errors == null || errors!.isEmpty) return null;
    final firstKey = errors!.keys.first;
    final firstErrors = errors![firstKey];
    return firstErrors?.isNotEmpty == true ? firstErrors!.first : null;
  }
}

/// API Pagination meta bilgisi
class ApiMeta {
  const ApiMeta({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrev,
  });

  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final bool hasNext;
  final bool hasPrev;

  factory ApiMeta.fromJson(Map<String, dynamic> json) {
    return ApiMeta(
      page: json['page'] as int? ?? 1,
      limit: json['limit'] as int? ?? 20,
      total: json['total'] as int? ?? 0,
      totalPages: json['total_pages'] as int? ?? 0,
      hasNext: json['has_next'] as bool? ?? false,
      hasPrev: json['has_prev'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'page': page,
      'limit': limit,
      'total': total,
      'total_pages': totalPages,
      'has_next': hasNext,
      'has_prev': hasPrev,
    };
  }
}

/// List response için helper typedef
typedef ApiListResponse<T> = ApiResponse<List<T>>;
