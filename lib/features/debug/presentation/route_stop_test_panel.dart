import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/services/discovery_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/point_collection_service.dart';
import '../../../core/utils/distance_helper.dart';
import '../../auth/providers/auth_provider.dart';

/// Mobile routes endpoint'inden rota ve durakları çeker.
/// Sadece `id`, `name` alanlarını kullanıyoruz.
final _mobileRoutesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final discovery = ref.watch(discoveryServiceProvider);
  final raw = await discovery.getRoutes();
  return raw.whereType<Map<String, dynamic>>().toList();
});

class RouteStopTestPanel extends ConsumerStatefulWidget {
  const RouteStopTestPanel({super.key});

  @override
  ConsumerState<RouteStopTestPanel> createState() => _RouteStopTestPanelState();
}

class _RouteStopTestPanelState extends ConsumerState<RouteStopTestPanel> {
  _RouteSimDistance _selectedDistance = _RouteSimDistance.onTop;
  Map<String, dynamic>? _selectedRoute;
  _RouteStopDebug? _selectedStop;
  List<_RouteStopDebug> _stops = const [];
  String? _statusMessage;

  bool get _hasSelection => _selectedRoute != null && _selectedStop != null;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final isLoggedIn = authState.status == AuthStatus.authenticated;
    final routesAsync = ref.watch(_mobileRoutesProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Rota Durak Test Paneli'),
      ),
      body: !isLoggedIn
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Bu paneli kullanmak için giriş yapmalısınız.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : routesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Rota listesi alınamadı:\n$err',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (routes) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildRouteSelector(context, isDark, routes),
                  const SizedBox(height: 16),
                  _buildDistanceSelector(context),
                  const SizedBox(height: 16),
                  if (_statusMessage != null) ...[
                    _buildMessageCard(context, isDark),
                    const SizedBox(height: 16),
                  ],
                  if (_selectedRoute != null)
                    _buildStopsList(context, isDark)
                  else
                    Text(
                      'Bir rota seçerek durakları listeleyin.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).hintColor,
                          ),
                    ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _buildRouteSelector(
    BuildContext context,
    bool isDark,
    List<Map<String, dynamic>> routes,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rota Seç',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<Map<String, dynamic>>(
          key: ValueKey(_selectedRoute?['id'] ?? 'none'),
          initialValue: _selectedRoute,
          isExpanded: true,
          items: routes
              .map(
                (r) => DropdownMenuItem(
                  value: r,
                  child: Text(
                    r['name']?.toString() ?? 'Rota ${r['id']}',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedRoute = value;
              _selectedStop = null;
              _stops = const [];
              _statusMessage = null;
            });
            if (value != null) {
              _loadStopsForRoute(value);
            }
          },
          decoration: InputDecoration(
            filled: true,
            fillColor:
                isDark ? AppColors.darkSurface : AppColors.lightSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }

  Future<void> _loadStopsForRoute(Map<String, dynamic> route) async {
    final discovery = ref.read(discoveryServiceProvider);
    final id = route['id'];
    final routeId = id is int ? id : int.tryParse(id.toString());
    if (routeId == null) return;

    try {
      final data = await discovery.getRouteDetail(routeId);
      final rawStops =
          (data['stops'] as List?) ?? (data['route_places'] as List?) ?? [];

      final parsed = rawStops
          .whereType<Map<String, dynamic>>()
          .map(
            (s) => _RouteStopDebug(
              routeId: routeId,
              placeId: s['id']?.toString() ?? '',
              name: s['name']?.toString() ?? 'Durak',
              lat: (s['lat'] as num?)?.toDouble(),
              lng: (s['lng'] as num?)?.toDouble(),
              stopPoints: (s['stop_points'] as num?)?.toInt() ?? 0,
              visited: s['visited'] == true,
            ),
          )
          .where((s) => s.lat != null && s.lng != null && s.stopPoints > 0)
          .toList();

      setState(() {
        _stops = parsed;
      });
    } catch (e) {
      setState(() {
        _stops = const [];
        _statusMessage = 'Duraklar alınamadı: $e';
      });
    }
  }

  Widget _buildDistanceSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Simülasyon Mesafesi',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _RouteSimDistance.values.map((d) {
            final selected = d == _selectedDistance;
            return ChoiceChip(
              label: Text(d.label),
              selected: selected,
              onSelected: (_) => setState(() => _selectedDistance = d),
              avatar: Icon(d.icon, size: 16),
              selectedColor: d.color.withAlpha(40),
              labelStyle: TextStyle(
                color: selected ? d.color : null,
                fontWeight: selected ? FontWeight.w600 : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMessageCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            isDark ? AppColors.neonBlue.withAlpha(15) : Colors.blue.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? AppColors.neonBlue.withAlpha(40)
              : Colors.blue.withAlpha(30),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: isDark ? AppColors.neonBlue : Colors.blue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _statusMessage ?? '',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStopsList(BuildContext context, bool isDark) {
    if (_stops.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'Bu rota için puanlı durak bulunamadı.\nAuth backend `/mobile/routes/:id` cevabını kontrol edin.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).hintColor,
              ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Duraklar (${_stops.length})',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        ..._stops.map(
          (s) => _buildStopCard(context, isDark, s),
        ),
      ],
    );
  }

  Widget _buildStopCard(
    BuildContext context,
    bool isDark,
    _RouteStopDebug stop,
  ) {
    final isSelected = _hasSelection && _selectedStop?.placeId == stop.placeId;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: Colors.orange, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _onStopTap(stop),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '+${stop.stopPoints}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.blue,
                          ),
                        ),
                        const Text(
                          'P',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stop.name,
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${stop.lat?.toStringAsFixed(4)}, ${stop.lng?.toStringAsFixed(4)}',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: Theme.of(context).hintColor,
                                ),
                      ),
                      if (stop.visited) ...[
                        const SizedBox(height: 2),
                        const Text(
                          'Zaten ziyaret edildi',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _buildSimButton(
                  context,
                  icon: Icons.my_location,
                  label: 'Sim',
                  color: Colors.orange,
                  onTap: () => _simulateLocation(stop),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 56,
      child: Material(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                Icon(icon, size: 16, color: color),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onStopTap(_RouteStopDebug stop) {
    setState(() => _selectedStop = stop);
    _simulateLocation(stop);
  }

  void _simulateLocation(_RouteStopDebug stop) {
    if (stop.lat == null || stop.lng == null) return;

    final target = LatLng(stop.lat!, stop.lng!);
    final simulated = _selectedDistance.offsetFrom(target);

    LocationService.setMockLocation(simulated);

    final distance =
        DistanceHelper.calculateHaversineDistance(simulated, target);
    final status = PointCollectionService.statusFromDistance(distance);

    setState(() {
      _selectedStop = stop;
      _statusMessage =
          '${stop.name} için konum simüle edildi:\n${_selectedDistance.label} → '
          '${DistanceHelper.formatDistance(distance)} uzakta → $status';
    });
  }
}

/// Debug panel için basit rota durağı modeli.
class _RouteStopDebug {
  const _RouteStopDebug({
    required this.routeId,
    required this.placeId,
    required this.name,
    required this.lat,
    required this.lng,
    required this.stopPoints,
    required this.visited,
  });

  final int routeId;
  final String placeId;
  final String name;
  final double? lat;
  final double? lng;
  final int stopPoints;
  final bool visited;
}

/// Rota durakları için simülasyon mesafesi seçenekleri.
enum _RouteSimDistance {
  onTop(
    label: 'Tam üzerinde (0m)',
    icon: Icons.gps_fixed,
    color: Colors.green,
    offsetMeters: 0,
  ),
  within50(
    label: '50m içinde',
    icon: Icons.near_me,
    color: Colors.green,
    offsetMeters: 50,
  ),
  within150(
    label: '~150m (yakın)',
    icon: Icons.radar,
    color: Colors.blue,
    offsetMeters: 150,
  ),
  at500(
    label: '~500m (uzak)',
    icon: Icons.location_off,
    color: Colors.orange,
    offsetMeters: 500,
  ),
  at2km(
    label: '~2km (çok uzak)',
    icon: Icons.wrong_location,
    color: Colors.red,
    offsetMeters: 2000,
  );

  const _RouteSimDistance({
    required this.label,
    required this.icon,
    required this.color,
    required this.offsetMeters,
  });

  final String label;
  final IconData icon;
  final Color color;
  final double offsetMeters;

  /// Hedef koordinattan [offsetMeters] metre kuzeye kaydır.
  /// 1 derece enlem ~ 111,320 metre
  LatLng offsetFrom(LatLng target) {
    if (offsetMeters == 0) return target;
    final latOffset = offsetMeters / 111320.0;
    return LatLng(target.latitude + latOffset, target.longitude);
  }
}

