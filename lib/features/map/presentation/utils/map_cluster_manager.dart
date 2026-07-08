import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// A cluster of map places grouped by proximity.
class MapCluster<T> {
  MapCluster({
    required this.items,
    required this.location,
  });

  /// Items in this cluster
  final List<T> items;

  /// Center location of the cluster
  final LatLng location;

  /// Number of items in the cluster
  int get count => items.length;

  /// Whether this cluster contains multiple items
  bool get isMultiple => items.length > 1;

  /// Get the first (or only) item
  T get first => items.first;

  /// Generate a unique ID for this cluster
  String getId() => '${location.latitude.toStringAsFixed(5)}_${location.longitude.toStringAsFixed(5)}_$count';
}

/// Simple and efficient grid-based clustering for map markers.
/// 
/// Groups nearby points into clusters based on the current zoom level.
/// At higher zoom levels, points spread out into individual markers.
class MapClusterManager<T> {
  MapClusterManager({
    required this.items,
    required this.getLocation,
    this.stopClusteringZoom = 16.0,
  });

  /// All items to be clustered
  List<T> items;

  /// Function to get LatLng from an item
  final LatLng Function(T item) getLocation;

  /// Zoom level at which clustering stops
  final double stopClusteringZoom;

  /// Current map bounds
  LatLngBounds? _visibleBounds;

  /// Current zoom level
  double _currentZoom = 10.0;

  /// Update items list
  void setItems(List<T> newItems) {
    items = newItems;
  }

  /// Update items without recreating the manager.
  /// Alias for [setItems] — preserves existing state (zoom, bounds)
  /// while only swapping the data, keeping cluster IDs more stable.
  void updateItems(List<T> newItems) {
    items = newItems;
  }

  /// Update current camera position
  void onCameraMove(CameraPosition position) {
    _currentZoom = position.zoom;
  }

  /// Set visible bounds (called when camera idle)
  void setVisibleBounds(LatLngBounds bounds) {
    _visibleBounds = bounds;
  }

  /// Get clusters for the current viewport and zoom level.
  List<MapCluster<T>> getClusters() {
    if (items.isEmpty) return [];

    // Filter to visible items only (with some padding)
    final visibleItems = _visibleBounds != null
        ? items.where((item) => _isInBounds(getLocation(item), _visibleBounds!)).toList()
        : items;

    if (visibleItems.isEmpty) return [];

    // At high zoom, don't cluster
    if (_currentZoom >= stopClusteringZoom) {
      return visibleItems
          .map((item) => MapCluster<T>(
                items: [item],
                location: getLocation(item),
              ))
          .toList();
    }

    // Grid-based clustering
    return _gridCluster(visibleItems);
  }

  /// Check if a point is within bounds (with padding)
  bool _isInBounds(LatLng point, LatLngBounds bounds) {
    final latPadding = (bounds.northeast.latitude - bounds.southwest.latitude) * 0.2;
    final lngPadding = (bounds.northeast.longitude - bounds.southwest.longitude) * 0.2;

    return point.latitude >= bounds.southwest.latitude - latPadding &&
        point.latitude <= bounds.northeast.latitude + latPadding &&
        point.longitude >= bounds.southwest.longitude - lngPadding &&
        point.longitude <= bounds.northeast.longitude + lngPadding;
  }

  /// Grid-based clustering algorithm.
  /// Divides the map into a grid and groups items in the same cell.
  List<MapCluster<T>> _gridCluster(List<T> visibleItems) {
    // Calculate grid cell size based on zoom level
    // Higher zoom = smaller cells = more individual markers
    final cellSize = _getCellSize(_currentZoom);

    // Group items by grid cell
    final Map<String, List<T>> grid = {};

    for (final item in visibleItems) {
      final location = getLocation(item);
      final cellKey = _getCellKey(location, cellSize);

      grid.putIfAbsent(cellKey, () => []);
      grid[cellKey]!.add(item);
    }

    // Convert grid cells to clusters
    return grid.values.map((cellItems) {
      final center = _calculateCenter(cellItems);
      return MapCluster<T>(
        items: cellItems,
        location: center,
      );
    }).toList();
  }

  /// Get grid cell size based on zoom level.
  /// Smaller values = larger clusters.
  /// Made more aggressive to cluster sooner.
  double _getCellSize(double zoom) {
    // More aggressive clustering - larger cells at lower zoom
    // At zoom 10: ~0.15 degrees (was 0.1)
    // At zoom 15: ~0.004 degrees (was 0.003)
    return 0.6 / math.pow(2, zoom - 8);
  }

  /// Get grid cell key for a location.
  String _getCellKey(LatLng location, double cellSize) {
    final latCell = (location.latitude / cellSize).floor();
    final lngCell = (location.longitude / cellSize).floor();
    return '${latCell}_$lngCell';
  }

  /// Calculate the center point of a list of items.
  LatLng _calculateCenter(List<T> clusterItems) {
    if (clusterItems.length == 1) {
      return getLocation(clusterItems.first);
    }

    double totalLat = 0;
    double totalLng = 0;

    for (final item in clusterItems) {
      final location = getLocation(item);
      totalLat += location.latitude;
      totalLng += location.longitude;
    }

    return LatLng(
      totalLat / clusterItems.length,
      totalLng / clusterItems.length,
    );
  }
}

/// Extension for easier usage with any ClusterItem-like objects.
extension ClusterItemExt on LatLng {
  /// Distance to another point in meters (Haversine formula)
  double distanceTo(LatLng other) {
    const earthRadius = 6371000.0; // meters

    final lat1 = latitude * math.pi / 180;
    final lat2 = other.latitude * math.pi / 180;
    final dLat = (other.latitude - latitude) * math.pi / 180;
    final dLng = (other.longitude - longitude) * math.pi / 180;

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }
}
