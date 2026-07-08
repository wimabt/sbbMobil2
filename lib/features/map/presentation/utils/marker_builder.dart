import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Simple LRU cache with a maximum capacity.
///
/// When the cache exceeds [maxSize], the least-recently-used entries are evicted.
/// Uses a [LinkedHashMap] (insertion-ordered) with manual promotion on access.
class _LruCache<K, V> {
  final int maxSize;
  final Map<K, V> _map = {};

  _LruCache(this.maxSize);

  V? get(K key) {
    final value = _map.remove(key);
    if (value != null) {
      _map[key] = value; // re-insert to move to end (most-recent)
    }
    return value;
  }

  void put(K key, V value) {
    _map.remove(key); // remove first so re-insert goes to end
    _map[key] = value;
    while (_map.length > maxSize) {
      _map.remove(_map.keys.first); // evict oldest
    }
  }

  bool containsKey(K key) => _map.containsKey(key);
  void remove(K key) => _map.remove(key);
  void clear() => _map.clear();
  int get length => _map.length;
}

/// Pixel-perfect marker builder for Google Maps.
/// 
/// **Sharpness Rules:**
/// 1. Always use device pixel ratio for high-DPI rendering
/// 2. Use FIXED size containers to prevent layout squashing
/// 3. Pass actual pixel dimensions to BitmapDescriptor
/// 4. Cache aggressively to prevent regeneration
/// 
/// **Architecture:**
/// Widget -> RenderTree -> High-DPI Image -> PNG Bytes -> BitmapDescriptor
class MarkerBuilder {
  MarkerBuilder._();

  /// LRU cache for generated bitmaps (max 200 entries to prevent unbounded memory growth)
  static final _LruCache<String, BitmapDescriptor> _cache = _LruCache(200);

  /// Converts a Flutter Widget to a [BitmapDescriptor] for use as a map marker.
  /// 
  /// **PIXEL-PERFECT APPROACH:**
  /// 1. Render widget at FIXED logical size (widget determines its own constraints)
  /// 2. Capture at HIGH RESOLUTION using device pixel ratio
  /// 3. Pass LOGICAL size to BitmapDescriptor (Google Maps handles DPI scaling)
  /// 
  /// [widget] - The widget to render (should have fixed size internally)
  /// [logicalSize] - The capture area size in logical pixels
  /// [cacheKey] - Optional cache key to avoid regenerating
  static Future<BitmapDescriptor> widgetToBitmap({
    required Widget widget,
    required Size logicalSize,
    String? cacheKey,
  }) async {
    // Check cache first (LRU: promotes entry on hit)
    if (cacheKey != null) {
      final cached = _cache.get(cacheKey);
      if (cached != null) return cached;
    }

    // Get device pixel ratio for sharp rendering
    final double devicePixelRatio = _getDevicePixelRatio();
    
    // Create render pipeline with TIGHT constraints (no squashing possible)
    final renderRepaintBoundary = RenderRepaintBoundary();
    
    // Position the content at top-center for proper anchor point
    final positionedBox = RenderPositionedBox(
      alignment: Alignment.topCenter,
      child: renderRepaintBoundary,
    );

    final renderView = RenderView(
      view: ui.PlatformDispatcher.instance.views.first,
      child: positionedBox,
      configuration: ViewConfiguration(
        // TIGHT constraints ensure no resizing
        logicalConstraints: BoxConstraints.tight(logicalSize),
        devicePixelRatio: devicePixelRatio,
      ),
    );

    // Initialize pipeline
    final pipelineOwner = PipelineOwner();
    pipelineOwner.rootNode = renderView;
    renderView.prepareInitialFrame();

    // Build the widget tree with proper context
    final buildOwner = BuildOwner(focusManager: FocusManager());
    final element = RenderObjectToWidgetAdapter<RenderBox>(
      container: renderRepaintBoundary,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData(
            devicePixelRatio: devicePixelRatio,
            // Prevent text scaling from affecting marker size
            textScaler: TextScaler.noScaling,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: widget,
          ),
        ),
      ),
    ).attachToRenderTree(buildOwner);

    // Execute render pipeline
    buildOwner.buildScope(element);
    pipelineOwner.flushLayout();
    pipelineOwner.flushCompositingBits();
    pipelineOwner.flushPaint();

    // ===== HIGH-RES IMAGE CAPTURE =====
    // Capture at device pixel ratio for SHARP text and edges
    final ui.Image image = await renderRepaintBoundary.toImage(
      pixelRatio: devicePixelRatio,
    );
    
    // Convert to PNG bytes
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    
    // Release image memory
    image.dispose();

    // ===== CREATE BITMAP DESCRIPTOR =====
    // Use LOGICAL pixel dimensions - Google Maps handles DPI scaling internally
    final descriptor = BitmapDescriptor.bytes(
      bytes,
      width: logicalSize.width,
      height: logicalSize.height,
    );

    // Cache for reuse (LRU: evicts oldest when full)
    if (cacheKey != null) {
      _cache.put(cacheKey, descriptor);
    }

    return descriptor;
  }

  /// Alias for widgetToBitmap (backward compatibility)
  static Future<BitmapDescriptor> createMarkerBitmap({
    required Widget widget,
    required Size logicalSize,
    String? cacheKey,
  }) => widgetToBitmap(
    widget: widget, 
    logicalSize: logicalSize, 
    cacheKey: cacheKey,
  );

  /// Gets device pixel ratio safely
  static double _getDevicePixelRatio() {
    try {
      final views = ui.PlatformDispatcher.instance.views;
      if (views.isNotEmpty) {
        return views.first.devicePixelRatio;
      }
    } catch (_) {}
    return 3.0; // Default to 3.0 for high-DPI devices
  }

  /// Clears the entire marker cache
  static void clearCache() => _cache.clear();

  /// Removes a specific marker from cache
  static void removeFromCache(String cacheKey) => _cache.remove(cacheKey);
  
  /// Checks if a marker is cached
  static bool isCached(String cacheKey) => _cache.containsKey(cacheKey);
  
  /// Gets cache size for debugging
  static int get cacheSize => _cache.length;

  /// Pre-generates markers in batches for performance
  /// 
  /// Useful for pre-loading markers when data is received from API
  static Future<Map<String, BitmapDescriptor>> preGenerateMarkers({
    required List<MapEntry<String, Widget>> markers,
    required Size logicalSize,
  }) async {
    final results = <String, BitmapDescriptor>{};
    
    // Process in batches to avoid overwhelming the render pipeline
    const batchSize = 5;
    for (var i = 0; i < markers.length; i += batchSize) {
      final batch = markers.skip(i).take(batchSize);
      
      // Process batch in parallel
      final futures = batch.map((entry) async {
        final descriptor = await widgetToBitmap(
          widget: entry.value,
          logicalSize: logicalSize,
          cacheKey: entry.key,
        );
        return MapEntry(entry.key, descriptor);
      });
      
      final batchResults = await Future.wait(futures);
      results.addEntries(batchResults);
      
      // Small delay between batches to prevent frame drops
      if (i + batchSize < markers.length) {
        await Future.delayed(const Duration(milliseconds: 16)); // ~1 frame
      }
    }
    
    return results;
  }
}
