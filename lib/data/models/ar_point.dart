import 'dart:convert';

/// Şartname §6.8.3.2 + backend_ar_todo.md AR1 — tek bir geospatial AR noktası.
///
/// `/api/v1/mobile/ar/points` endpoint'inden bir öğe.
class ArPoint {
  const ArPoint({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.radiusM,
    required this.bearingTolDeg,
    required this.minDistanceM,
    required this.priority,
    required this.contentType,
    required this.content,
    required this.actions,
    this.placeId,
    this.altitudeM,
    this.bearingDeg,
  });

  final String id;
  final String? placeId;
  final String name;
  final double lat;
  final double lng;
  final double? altitudeM;

  /// Etkinleşme yarıçapı, metre. Kullanıcı bu yarıçap içine girince eşleşmeye aday olur.
  final int radiusM;

  /// POI'nin "ön cephesinin" bearing'i (0–359°). `null` ise her açıdan görünür.
  final int? bearingDeg;

  /// Tolerans (±°). Kullanıcı cihazının heading'i bu aralık içindeyse içerik açılır.
  final int bearingTolDeg;

  /// Minimum yaklaşma mesafesi (metre). Çok yakındaysa içerik gizlenebilir.
  final int minDistanceM;

  /// Çakışma yönetimi (yüksek = öncelikli).
  final int priority;

  /// `info_card | image_2d | model_3d | audio | video | animation`
  final String contentType;

  /// İçerik türüne göre değişen serbest payload (model URL, başlık/desc, ses URL'i ...).
  final Map<String, dynamic> content;

  /// Etkileşim butonları. Örn. `[{label: "Detay gör", action: "open_place", params: {id: 42}}]`.
  final List<ArPointAction> actions;

  factory ArPoint.fromJson(Map<String, dynamic> json) {
    return ArPoint(
      id: json['id'].toString(),
      placeId: json['place_id']?.toString(),
      name: (json['name'] as String?) ?? '',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      altitudeM: (json['altitude_m'] as num?)?.toDouble(),
      radiusM: (json['radius_m'] as num?)?.toInt() ?? 25,
      bearingDeg: (json['bearing_deg'] as num?)?.toInt(),
      bearingTolDeg: (json['bearing_tol_deg'] as num?)?.toInt() ?? 45,
      minDistanceM: (json['min_distance_m'] as num?)?.toInt() ?? 0,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      contentType: (json['content_type'] as String?) ?? 'info_card',
      content: (json['content'] is Map<String, dynamic>)
          ? json['content'] as Map<String, dynamic>
          : const {},
      actions: (json['actions'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(ArPointAction.fromJson)
              .toList() ??
          const [],
    );
  }

  // ── Content tipine göre yardımcı erişimler ──────────────────────────

  String? get modelUrl =>
      contentType == 'model_3d' ? content['url'] as String? : null;

  String? get audioUrl =>
      contentType == 'audio' ? content['url'] as String? : null;

  String? get videoUrl =>
      contentType == 'video' ? content['url'] as String? : null;

  String? get imageUrl =>
      contentType == 'image_2d' ? content['url'] as String? : null;

  /// `info_card` ya da diğer karttan başlık (lang-aware backend göndermeli).
  String? get title =>
      (content['title_tr'] ?? content['title_en'] ?? content['title'])
          as String?;

  String? get description =>
      (content['desc_tr'] ?? content['desc_en'] ?? content['description'])
          as String?;

  // ── 3B model gösterimi için ek alanlar (§6.8.3.7) ────────────────────
  // Admin paneli `content` JSON'una bu anahtarları koyabilir; eski kayıtlar
  // için makul varsayılan değerler döner.

  /// `content_type == 'model_3d'` için ölçek çarpanı. Admin panelinden
  /// gönderilen .glb'lerin metrik birimi tutarsız olabildiği için override
  /// imkânı; varsayılan 1.0.
  double get modelScale {
    final v = content['scale'];
    if (v is num) return v.toDouble();
    return 1.0;
  }

  /// 3B modelin başlangıç Y-rotasyonu (derece). Modelin "ön cephesinin" hangi
  /// yöne baktığını ayarlamak için kullanılır. Varsayılan 0.
  double get modelRotationYDeg {
    final v = content['rotation_y_deg'];
    if (v is num) return v.toDouble();
    return 0.0;
  }

  /// `true` ise model her zaman kullanıcıya bakar (billboard davranışı).
  /// Bilgi tabelaları, sembolik ikonlar için kullanışlı. Varsayılan `false`.
  bool get modelAutoFaceUser {
    final v = content['auto_face_user'];
    if (v is bool) return v;
    return false;
  }
}

class ArPointAction {
  const ArPointAction({
    required this.label,
    required this.action,
    this.params = const {},
  });

  /// UI'da görünen buton etiketi.
  final String label;

  /// `open_place | add_to_itinerary | toggle_favorite | open_url | ...`
  final String action;

  /// Aksiyon parametreleri (örn `{id: 42}`).
  final Map<String, dynamic> params;

  factory ArPointAction.fromJson(Map<String, dynamic> json) {
    return ArPointAction(
      label: (json['label'] as String?) ?? '',
      action: (json['action'] as String?) ?? '',
      params: (json['params'] is Map<String, dynamic>)
          ? json['params'] as Map<String, dynamic>
          : const {},
    );
  }
}

/// İstemci tarafında sensör + konum verisi ile eşleştirilmiş bir AR noktası.
class ArMatchedPoint {
  const ArMatchedPoint({
    required this.point,
    required this.distanceM,
    required this.bearingFromUserDeg,
    required this.headingDeltaDeg,
    required this.inRadius,
    required this.inBearingTolerance,
    this.elevationAngleDeg = 0,
    this.hasElevationData = false,
  });

  final ArPoint point;

  /// Kullanıcı → POI mesafesi, metre.
  final double distanceM;

  /// Kullanıcı → POI yönü (true north'a göre, 0–360°). Bu kullanıcıya hangi
  /// yönü göstermesi gerektiğini söyler.
  final double bearingFromUserDeg;

  /// Cihaz heading'i ile `bearingFromUserDeg` arasındaki en kısa fark (°).
  /// 0 = tam karşı; ±180 = arkadakine.
  final double headingDeltaDeg;

  /// Yarıçap içinde mi?
  final bool inRadius;

  /// Cihaz heading'i POI'nin tolerans açısı içinde mi?
  final bool inBearingTolerance;

  /// §6.8.3.2 + §6.8.3.7 — Kullanıcının yatay düzlemine göre POI'ye olan dikey
  /// yükselme açısı (°). Pozitif = POI yukarıda (örn. tepe/kule), negatif =
  /// aşağıda. POI'nin `altitude_m` değeri ile kullanıcı GPS yüksekliği farkı
  /// ve mesafeden hesaplanır; kamera overlay'inde kartın dikey konumlanması
  /// için kullanılır. [hasElevationData] false ise 0'dır (kullanılmaz).
  final double elevationAngleDeg;

  /// Elevation açısı güvenilir veriden mi hesaplandı? (POI altitude_m mevcut +
  /// GPS yükseklik doğruluğu yeterli.) False ise kamera kartı mesafe-tabanlı
  /// dikey konuma düşer.
  final bool hasElevationData;

  /// Ekranda gösterilebilir mi (tüm kriterleri sağlıyor mu)?
  bool get isTriggered => inRadius && inBearingTolerance;

  ArMatchedPoint copyWith({
    double? distanceM,
    double? bearingFromUserDeg,
    double? headingDeltaDeg,
    bool? inRadius,
    bool? inBearingTolerance,
    double? elevationAngleDeg,
    bool? hasElevationData,
  }) {
    return ArMatchedPoint(
      point: point,
      distanceM: distanceM ?? this.distanceM,
      bearingFromUserDeg: bearingFromUserDeg ?? this.bearingFromUserDeg,
      headingDeltaDeg: headingDeltaDeg ?? this.headingDeltaDeg,
      inRadius: inRadius ?? this.inRadius,
      inBearingTolerance: inBearingTolerance ?? this.inBearingTolerance,
      elevationAngleDeg: elevationAngleDeg ?? this.elevationAngleDeg,
      hasElevationData: hasElevationData ?? this.hasElevationData,
    );
  }
}

/// Liste serileştirme yardımcısı (analytics / debug için).
String encodeArPoints(List<ArPoint> points) =>
    jsonEncode(points.map((p) => p.id).toList());
