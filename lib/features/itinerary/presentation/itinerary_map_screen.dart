import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/services/osrm_service.dart';
import '../../../data/models/models.dart';
import '../../places/presentation/providers/places_provider.dart';
import 'providers/itineraries_provider.dart';

/// Şartname §6.5.2 son madde — Plan duraklarının harita üzerinde
/// görüntülenmesi ve aralarındaki **önerilen güzergahın** çizilmesi.
///
/// Tasarım:
/// • Item'ların lat/lng'si `placesProvider.allPlaces` cache'inden eşleşir
///   (entity_id ↔ Place.id). Cache yoksa kullanıcı önce Yerler sekmesine
///   yönlendirilir; kayıp koordinatlar atlanır, kalanlarla çizilir.
/// • OSRM `/route/v1/driving/{coords}` ile tek istekte çoklu durak.
/// • Üstte özet kartı: durak sayısı, toplam km, toplam süre.
class ItineraryMapScreen extends ConsumerStatefulWidget {
  const ItineraryMapScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<ItineraryMapScreen> createState() =>
      _ItineraryMapScreenState();
}

class _ItineraryMapScreenState extends ConsumerState<ItineraryMapScreen> {
  static const LatLng _defaultCenter = LatLng(41.2867, 36.3300); // Samsun
  GoogleMapController? _mapController;
  final OsrmService _osrm = OsrmService();
  RouteData? _route;
  bool _routeLoading = false;
  bool _routeFailed = false;

  /// Itinerary items'a karşılık gelen koordinatlar (sıralı).
  List<({String name, LatLng latLng})> _stops = const [];

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _resolveStops(Itinerary itinerary, List<Place> places) {
    final byId = {for (final p in places) p.id: p};
    final resolved = <({String name, LatLng latLng})>[];
    for (final item in itinerary.items) {
      final place = byId[item.entityId];
      if (place?.lat != null && place?.lng != null) {
        resolved.add((
          name: item.entityName,
          latLng: LatLng(place!.lat!, place.lng!),
        ));
      }
    }
    if (_stops.length != resolved.length ||
        !_listEquals(_stops, resolved)) {
      _stops = resolved;
      _route = null;
      _routeFailed = false;
      if (resolved.length >= 2) {
        _fetchRoute();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitCameraToStops();
      });
    }
  }

  bool _listEquals(
    List<({String name, LatLng latLng})> a,
    List<({String name, LatLng latLng})> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].latLng != b[i].latLng || a[i].name != b[i].name) return false;
    }
    return true;
  }

  Future<void> _fetchRoute() async {
    setState(() {
      _routeLoading = true;
      _routeFailed = false;
    });
    final result = await _osrm.getRouteMultiStop(
      _stops.map((s) => s.latLng).toList(),
    );
    if (!mounted) return;
    setState(() {
      _route = result;
      _routeLoading = false;
      _routeFailed = result == null;
    });
  }

  void _fitCameraToStops() {
    if (_mapController == null || _stops.isEmpty) return;
    if (_stops.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_stops.first.latLng, 14),
      );
      return;
    }
    double minLat = _stops.first.latLng.latitude;
    double maxLat = minLat;
    double minLng = _stops.first.latLng.longitude;
    double maxLng = minLng;
    for (final s in _stops) {
      minLat = s.latLng.latitude < minLat ? s.latLng.latitude : minLat;
      maxLat = s.latLng.latitude > maxLat ? s.latLng.latitude : maxLat;
      minLng = s.latLng.longitude < minLng ? s.latLng.longitude : minLng;
      maxLng = s.latLng.longitude > maxLng ? s.latLng.longitude : maxLng;
    }
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        64,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final itinerary = ref.watch(itineraryByIdProvider(widget.id));
    final places = ref.watch(placesProvider.select((s) => s.allPlaces));

    if (itinerary == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(context.l10n.itineraryNotFound)),
      );
    }

    _resolveStops(itinerary, places);

    final markers = <Marker>{
      for (var i = 0; i < _stops.length; i++)
        Marker(
          markerId: MarkerId('stop_$i'),
          position: _stops[i].latLng,
          infoWindow: InfoWindow(
            title: '${i + 1}. ${_stops[i].name}',
          ),
        ),
    };

    final polylines = <Polyline>{
      if (_route != null && _route!.points.isNotEmpty)
        Polyline(
          polylineId: const PolylineId('itinerary_route'),
          points: _route!.points,
          color: isDark ? AppColors.neonBlue : theme.colorScheme.primary,
          width: 4,
        ),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(itinerary.title,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _stops.isEmpty ? _defaultCenter : _stops.first.latLng,
              zoom: 12,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              _fitCameraToStops();
            },
            markers: markers,
            polylines: polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            compassEnabled: true,
            zoomControlsEnabled: false,
          ),
          // Üst özet kartı
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: SafeArea(
              child: _SummaryCard(
                stopCount: _stops.length,
                missingCount: itinerary.items.length - _stops.length,
                route: _route,
                isLoading: _routeLoading,
                isFailed: _routeFailed,
                onRetry: _stops.length >= 2 ? _fetchRoute : null,
              ),
            ),
          ),
          if (_stops.isEmpty) const _StopsMissingOverlay(),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.stopCount,
    required this.missingCount,
    required this.route,
    required this.isLoading,
    required this.isFailed,
    this.onRetry,
  });

  final int stopCount;
  final int missingCount;
  final RouteData? route;
  final bool isLoading;
  final bool isFailed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(14),
      color: isDark ? AppColors.darkSurface : Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Icon(Icons.alt_route_rounded,
                color: isDark
                    ? AppColors.neonBlue
                    : theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isLoading
                        ? 'Güzergah hesaplanıyor...'
                        : route != null
                            ? '${route!.distanceKm.toStringAsFixed(1)} km · ${route!.durationMinutes.toStringAsFixed(0)} dk'
                            : isFailed
                                ? 'Güzergah alınamadı'
                                : '$stopCount durak',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    missingCount > 0
                        ? '$stopCount durak haritada · $missingCount durağın konumu eksik'
                        : '$stopCount durak haritada',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor),
                  ),
                ],
              ),
            ),
            if (isFailed && onRetry != null)
              IconButton(
                tooltip: context.l10n.btnRetry,
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
              ),
          ],
        ),
      ),
    );
  }
}

class _StopsMissingOverlay extends StatelessWidget {
  const _StopsMissingOverlay();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(160),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Bu plandaki durakların konum bilgisi henüz yüklenmedi.\n'
            'Yerler sekmesini açıp tekrar deneyin.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
