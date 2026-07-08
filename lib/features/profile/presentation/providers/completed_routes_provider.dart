import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/discovery_service.dart';
import '../../../../core/services/route_id_resolver.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../routes/presentation/providers/routes_provider.dart';
import '../../../routes/presentation/models/route_data.dart';
import '../models/completed_route.dart';

/// Profil ekranı için tamamlanan rotalar provider'ı.
///
/// Backend:
///   - `GET /api/v1/mobile/routes/progress` (DiscoveryService.getRouteProgress)
///   - City CMS rota listesi: RoutesProvider.routes (TourRoute)
final completedRoutesProvider =
    FutureProvider.autoDispose<List<CompletedRoute>>((ref) async {
  final authState = ref.watch(authProvider);
  if (authState.status != AuthStatus.authenticated) {
    return const [];
  }

  final discovery = ref.watch(discoveryServiceProvider);
  final routesState = ref.watch(routesProvider);
  final resolver = ref.watch(routeIdResolverProvider);

  final progressList = await discovery.getRouteProgress();

  if (progressList.isEmpty) return const [];

  final tourRoutes = routesState.routes;

  return progressList
      .where((p) => p.isCompleted)
      .map((p) {
        final cmsId = resolver.mobileToExternal[p.routeId.toString()];

        final matched = tourRoutes.firstWhere(
          (r) =>
              r.id == p.routeId.toString() ||
              r.id == cmsId,
          orElse: () => TourRoute(
            id: p.routeId.toString(),
            image: '',
            title: p.routeName,
            description: '',
            category: '',
            duration: '-',
            distance: '-',
            difficulty: '',
            stops: p.totalPlaces,
            points: 0,
          ),
        );

        final startedAt = p.startedAt;
        final dateLabel = startedAt != null
            ? '${startedAt.day}.${startedAt.month}.${startedAt.year}'
            : '';

        return CompletedRoute(
          id: p.routeId,
          cmsId: cmsId,
          name: matched.title,
          places: p.totalPlaces,
          distance: matched.distance,
          date: dateLabel,
        );
      })
      .toList();
});

