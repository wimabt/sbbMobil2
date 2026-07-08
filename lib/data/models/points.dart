/// Puan Sistemi modelleri – flutter-integration.md §10
///
/// [PointsBalance] : GET /api/v1/mobile/points/balance
/// [PointTransaction] : GET /api/v1/mobile/points/history
/// [VisitResult] : POST /api/v1/mobile/places/:id/visit
/// [RouteVisitResult] : POST /api/v1/mobile/routes/:routeId/places/:placeId/visit
library;

// ─── Points Balance ─────────────────────────────────────────────────

class PointsBalance {
  const PointsBalance({
    required this.totalPoints,
    required this.totalEarned,
    required this.totalSpent,
    required this.placesVisited,
    required this.routesCompleted,
    required this.rank,
  });

  final int totalPoints;
  final int totalEarned;
  final int totalSpent;
  final int placesVisited;
  final int routesCompleted;
  final String rank;

  factory PointsBalance.fromJson(Map<String, dynamic> json) {
    return PointsBalance(
      totalPoints: json['total_points'] as int? ?? 0,
      totalEarned: json['total_earned'] as int? ?? 0,
      totalSpent: json['total_spent'] as int? ?? 0,
      placesVisited: json['places_visited'] as int? ?? 0,
      routesCompleted: json['routes_completed'] as int? ?? 0,
      rank: json['rank'] as String? ?? 'Yeni Başlayan',
    );
  }

  /// Varsayılan boş bakiye
  factory PointsBalance.empty() {
    return const PointsBalance(
      totalPoints: 0,
      totalEarned: 0,
      totalSpent: 0,
      placesVisited: 0,
      routesCompleted: 0,
      rank: 'Yeni Başlayan',
    );
  }
}

// ─── Point Transaction (History) ────────────────────────────────────

class PointTransaction {
  const PointTransaction({
    required this.type,
    required this.points,
    required this.description,
    this.targetType,
    this.targetId,
    this.createdAt,
  });

  /// `EARN`, `BONUS`, `SPEND` etc.
  final String type;
  final int points;
  final String description;

  /// `PLACE` or `ROUTE`
  final String? targetType;
  final String? targetId;
  final DateTime? createdAt;

  factory PointTransaction.fromJson(Map<String, dynamic> json) {
    return PointTransaction(
      type: json['type'] as String? ?? 'EARN',
      points: json['points'] as int? ?? 0,
      description: json['description'] as String? ?? '',
      targetType: json['target_type'] as String?,
      targetId: json['target_id']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

// ─── Place Visit Result ─────────────────────────────────────────────

class VisitResult {
  const VisitResult({
    required this.pointsEarned,
    required this.totalPoints,
    required this.placeName,
    required this.isFirstVisit,
    this.distance,
    this.message,
    this.campaignName,
  });

  final int pointsEarned;
  final int totalPoints;
  final String placeName;
  final bool isFirstVisit;
  final int? distance;
  final String? message;
  final String? campaignName;

  factory VisitResult.fromJson(Map<String, dynamic> json) {
    return VisitResult(
      pointsEarned: json['points_earned'] as int? ?? 0,
      totalPoints: json['total_points'] as int? ?? 0,
      placeName: json['place_name'] as String? ?? '',
      isFirstVisit: json['is_first_visit'] == true,
      distance: json['distance'] as int?,
      message: json['message'] as String?,
      campaignName: json['campaign_name'] as String?,
    );
  }
}

// ─── Route Stop Visit Result ────────────────────────────────────────

class RouteProgress {
  const RouteProgress({
    required this.visited,
    required this.total,
    required this.percentage,
    required this.isCompleted,
    this.completedAt,
  });

  final int visited;
  final int total;
  final int percentage;
  final bool isCompleted;
  final DateTime? completedAt;

  factory RouteProgress.fromJson(Map<String, dynamic> json) {
    return RouteProgress(
      visited: json['visited'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
      percentage: json['percentage'] as int? ?? 0,
      isCompleted: json['is_completed'] == true,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
    );
  }
}

class RouteVisitResult {
  const RouteVisitResult({
    required this.pointsEarned,
    required this.totalPoints,
    required this.placeName,
    this.distance,
    this.message,
    this.routeProgress,
    this.routeCompleted = false,
    this.routeName,
    this.completionBonus,
    this.allStopsBonus,
    this.totalEarnedThisVisit,
  });

  final int pointsEarned;
  final int totalPoints;
  final String placeName;
  final int? distance;
  final String? message;
  final RouteProgress? routeProgress;

  /// `true` when the last stop of the route is visited
  final bool routeCompleted;
  final String? routeName;
  final int? completionBonus;
  final int? allStopsBonus;
  final int? totalEarnedThisVisit;

  factory RouteVisitResult.fromJson(Map<String, dynamic> json) {
    return RouteVisitResult(
      pointsEarned: json['points_earned'] as int? ?? 0,
      totalPoints: json['total_points'] as int? ?? 0,
      placeName: json['place_name'] as String? ?? '',
      distance: json['distance'] as int?,
      message: json['message'] as String?,
      routeProgress: json['route_progress'] != null
          ? RouteProgress.fromJson(
              json['route_progress'] as Map<String, dynamic>)
          : null,
      routeCompleted: json['route_completed'] == true,
      routeName: json['route_name'] as String?,
      completionBonus: json['completion_bonus'] as int?,
      allStopsBonus: json['all_stops_bonus'] as int?,
      totalEarnedThisVisit: json['total_earned_this_visit'] as int?,
    );
  }
}

// ─── Route Progress Entry (GET /routes/progress) ────────────────────

class RouteProgressEntry {
  const RouteProgressEntry({
    required this.routeId,
    required this.routeName,
    this.color,
    required this.visitedPlaces,
    required this.totalPlaces,
    required this.isCompleted,
    required this.progressPercentage,
    this.startedAt,
  });

  final int routeId;
  final String routeName;
  final String? color;
  final List<String> visitedPlaces;
  final int totalPlaces;
  final bool isCompleted;
  final int progressPercentage;
  final DateTime? startedAt;

  factory RouteProgressEntry.fromJson(Map<String, dynamic> json) {
    return RouteProgressEntry(
      routeId: json['route_id'] as int? ?? 0,
      routeName: json['route_name'] as String? ?? '',
      color: json['color'] as String?,
      visitedPlaces: List<String>.from(
        (json['visited_places'] as List?)?.map((e) => e.toString()) ?? [],
      ),
      totalPlaces: json['total_places'] as int? ?? 0,
      isCompleted: json['is_completed'] == true,
      progressPercentage: json['progress_percentage'] as int? ?? 0,
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'] as String)
          : null,
    );
  }
}
