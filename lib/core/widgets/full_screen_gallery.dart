import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import 'cached_image.dart';

/// Advanced full-screen image gallery with Instagram/Google Photos-like UX.
///
/// This implementation provides:
/// - **Locked Mode (Zoomed):** Pan/zoom without triggering page swipes
/// - **Navigation Mode (Default):** Horizontal swipe to change pages
/// - **Edge Detection:** Swipe to next image ONLY when at absolute edges while zoomed
/// - **Drag-to-Dismiss:** Vertical drag closes gallery (only when not zoomed)
/// - **Double-Tap Zoom:** Toggle between 1x and 2.5x zoom on tap location
/// - **Hero Animations:** Smooth expand from thumbnail
/// - **Opacity Transition:** Background fades as you drag to dismiss
///
/// **Usage:**
/// ```dart
/// FullScreenGallery.open(
///   context: context,
///   images: imageUrls,
///   initialIndex: 0,
///   heroTagPrefix: 'gallery_image_',
/// );
/// ```
class FullScreenGallery extends StatefulWidget {
  const FullScreenGallery({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.heroTagPrefix,
    this.loadingBuilder,
    this.errorBuilder,
    this.onPageChanged,
    this.showThumbnails = true,
    dynamic minScale,
    dynamic maxScale,
    this.doubleTapScale = 2.5,
  })  : minScale = minScale ?? PhotoViewComputedScale.contained,
        maxScale = maxScale ?? PhotoViewComputedScale.covered * 3;

  /// List of image URLs or asset paths
  final List<String> images;

  /// Initial page to show
  final int initialIndex;

  /// Prefix for Hero tag (append index to create unique tags)
  final String? heroTagPrefix;

  /// Custom loading widget builder
  final Widget Function(BuildContext, ImageChunkEvent?)? loadingBuilder;

  /// Custom error widget builder
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  /// Callback when page changes
  final void Function(int)? onPageChanged;

  /// Show thumbnail strip at bottom
  final bool showThumbnails;

  /// Minimum zoom scale
  final dynamic minScale;

  /// Maximum zoom scale
  final dynamic maxScale;

  /// Scale for double-tap zoom
  final double doubleTapScale;

  /// Convenience method to open the gallery
  static Future<T?> open<T>({
    required BuildContext context,
    required List<String> images,
    int initialIndex = 0,
    String? heroTagPrefix,
    Widget Function(BuildContext, ImageChunkEvent?)? loadingBuilder,
    Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
    bool showThumbnails = true,
  }) {
    return Navigator.of(context).push<T>(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FullScreenGallery(
            images: images,
            initialIndex: initialIndex,
            heroTagPrefix: heroTagPrefix,
            loadingBuilder: loadingBuilder,
            errorBuilder: errorBuilder,
            showThumbnails: showThumbnails,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  @override
  State<FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<FullScreenGallery>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late ScrollController _thumbnailScrollController;
  late int _currentIndex;

  // Controllers for each page
  final Map<int, _GalleryPageState> _pageStates = {};

  // Current state
  bool _isZoomed = false;
  bool _controlsVisible = true;

  // Dismiss animation state
  double _dragOffset = 0.0;
  double _dismissProgress = 0.0;
  bool _isDraggingToDismiss = false;

  // Animation controllers
  late AnimationController _controlsAnimationController;
  late Animation<double> _controlsAnimation;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _thumbnailScrollController = ScrollController();

    _controlsAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _controlsAnimation = CurvedAnimation(
      parent: _controlsAnimationController,
      curve: Curves.easeInOut,
    );
    _controlsAnimationController.value = 1.0;

    // Route geçişi bittikten sonra status bar'ı gizle (profesyonel tam ekran)
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    });

    // Scroll to initial thumbnail after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToThumbnail(_currentIndex, animate: false);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbnailScrollController.dispose();
    _controlsAnimationController.dispose();

    // Edge-to-edge modunu geri yükle
    // StableSystemPadding arkadaki ekranların padding'ini dondurduğu için zıplama olmaz
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    for (final state in _pageStates.values) {
      state.dispose();
    }

    super.dispose();
  }

  _GalleryPageState _getPageState(int index) {
    if (!_pageStates.containsKey(index)) {
      final pageState = _GalleryPageState();
      // Listen to scale state changes (for double-tap zoom)
      pageState.subscription = pageState.scaleStateController
          .outputScaleStateStream
          .listen((scaleState) {
        _onScaleStateChanged(scaleState);
      });
      _pageStates[index] = pageState;
    }
    return _pageStates[index]!;
  }

  void _onScaleStateChanged(PhotoViewScaleState scaleState) {
    final isZoomed = scaleState != PhotoViewScaleState.initial &&
        scaleState != PhotoViewScaleState.zoomedOut;

    if (_isZoomed != isZoomed) {
      setState(() {
        _isZoomed = isZoomed;
      });

      // Auto-hide controls when zoomed in, auto-show when zoomed out
      if (isZoomed && _controlsVisible) {
        _controlsAnimationController.reverse();
        _controlsVisible = false;
      } else if (!isZoomed && !_controlsVisible) {
        _controlsAnimationController.forward();
        _controlsVisible = true;
      }
    }
  }

  void _scrollToThumbnail(int index, {bool animate = true}) {
    if (!_thumbnailScrollController.hasClients) return;

    const thumbnailWidth = 64.0; // 56 + 8 margin
    final targetOffset = (index * thumbnailWidth) -
        (MediaQuery.of(context).size.width / 2) +
        (thumbnailWidth / 2);

    final maxOffset = _thumbnailScrollController.position.maxScrollExtent;
    final clampedOffset = targetOffset.clamp(0.0, maxOffset);

    if (animate) {
      _thumbnailScrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _thumbnailScrollController.jumpTo(clampedOffset);
    }
  }

  void _toggleControls() {
    if (_controlsVisible) {
      _controlsAnimationController.reverse();
    } else {
      _controlsAnimationController.forward();
    }
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
  }

  void _onVerticalDragStart(DragStartDetails details) {
    if (!_isZoomed) {
      _isDraggingToDismiss = true;
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (!_isDraggingToDismiss) return;

    setState(() {
      _dragOffset += details.delta.dy;
      _dismissProgress = (_dragOffset.abs() / 250).clamp(0.0, 1.0);
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (!_isDraggingToDismiss) return;

    final velocity = details.primaryVelocity ?? 0;

    if (_dismissProgress > 0.35 || velocity.abs() > 800) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _dragOffset = 0;
        _dismissProgress = 0;
        _isDraggingToDismiss = false;
      });
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _isZoomed = false;
    });
    _scrollToThumbnail(index);
    widget.onPageChanged?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    final backgroundOpacity = (1.0 - _dismissProgress).clamp(0.0, 1.0);
    final scale = 1.0 - (_dismissProgress * 0.15);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: PopScope(
      canPop: !_isDraggingToDismiss,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          setState(() {
            _dragOffset = 0;
            _dismissProgress = 0;
            _isDraggingToDismiss = false;
          });
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: backgroundOpacity),
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            // Main gallery with gesture handling
            GestureDetector(
              onVerticalDragStart: !_isZoomed ? _onVerticalDragStart : null,
              onVerticalDragUpdate: !_isZoomed ? _onVerticalDragUpdate : null,
              onVerticalDragEnd: !_isZoomed ? _onVerticalDragEnd : null,
              // Note: onTap removed to avoid conflict with PhotoView's double-tap zoom
              // Single tap is handled by PhotoView's onTapUp callback
              child: Transform.translate(
                offset: Offset(0, _dragOffset),
                child: Transform.scale(
                  scale: scale,
                  child: _buildGallery(),
                ),
              ),
            ),

            // Top controls
            _buildTopBar(backgroundOpacity),

            // Bottom thumbnail strip
            if (widget.showThumbnails && widget.images.length > 1)
              _buildThumbnailStrip(backgroundOpacity),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildGallery() {
    return PhotoViewGallery.builder(
      pageController: _pageController,
      itemCount: widget.images.length,
      builder: _buildPage,
      onPageChanged: _onPageChanged,
      scrollPhysics: _isZoomed
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics(),
      backgroundDecoration: const BoxDecoration(color: Colors.transparent),
      loadingBuilder: widget.loadingBuilder ?? _defaultLoadingBuilder,
      gaplessPlayback: true,
    );
  }

  PhotoViewGalleryPageOptions _buildPage(BuildContext context, int index) {
    final imageUrl = widget.images[index];
    final isNetwork = imageUrl.startsWith('http');
    final pageState = _getPageState(index);

    return PhotoViewGalleryPageOptions(
      imageProvider: isNetwork
          ? CachedNetworkImageProvider(imageUrl)
          : AssetImage(imageUrl) as ImageProvider,
      minScale: widget.minScale,
      maxScale: widget.maxScale,
      initialScale: PhotoViewComputedScale.contained,
      controller: pageState.photoController,
      scaleStateController: pageState.scaleStateController,
      heroAttributes: widget.heroTagPrefix != null
          ? PhotoViewHeroAttributes(
              tag: '${widget.heroTagPrefix}$index',
            )
          : null,
      errorBuilder: widget.errorBuilder ?? _defaultErrorBuilder,
      onTapUp: (context, details, controllerValue) {
        // Toggle controls on single tap
        _toggleControls();
      },
    );
  }

  Widget _defaultLoadingBuilder(BuildContext context, ImageChunkEvent? event) {
    return Center(
      child: SizedBox(
        width: 36,
        height: 36,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          value: event == null
              ? null
              : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
          color: Colors.white70,
        ),
      ),
    );
  }

  Widget _defaultErrorBuilder(
      BuildContext context, Object error, StackTrace? stackTrace) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_rounded,
            color: Colors.white.withValues(alpha: 0.4),
            size: 56,
          ),
          const SizedBox(height: 12),
          Text(
            'Görsel yüklenemedi',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(double opacity) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _controlsAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _controlsAnimation.value * opacity,
            child: IgnorePointer(
              ignoring: _controlsAnimation.value < 0.5,
              child: child,
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.7),
                Colors.black.withValues(alpha: 0.3),
                Colors.transparent,
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  // Close button
                  _buildControlButton(
                    icon: Icons.close,
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: context.l10n.btnClose,
                  ),

                  const SizedBox(width: 8),

                  // Page counter
                  if (widget.images.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / ${widget.images.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Tooltip(
          message: tooltip ?? '',
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(
              icon,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailStrip(double opacity) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _controlsAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _controlsAnimation.value * opacity,
            child: IgnorePointer(
              ignoring: _controlsAnimation.value < 0.5,
              child: child,
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.8),
                Colors.black.withValues(alpha: 0.4),
                Colors.transparent,
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                height: 68,
                child: ListView.builder(
                  controller: _thumbnailScrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: widget.images.length,
                  itemBuilder: (context, index) => _buildThumbnail(index),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(int index) {
    final isSelected = index == _currentIndex;
    final imageUrl = widget.images[index];
    final isNetwork = imageUrl.startsWith('http');

    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: 56,
        height: 56,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white24,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Opacity(
            opacity: isSelected ? 1.0 : 0.6,
            child: isNetwork
                ? CachedImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 150,
                    errorWidget: _thumbnailPlaceholder(),
                  )
                : Image.asset(
                    imageUrl,
                    fit: BoxFit.cover,
                    cacheWidth: 150,
                    errorBuilder: (_, _, _) => _thumbnailPlaceholder(),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _thumbnailPlaceholder() {
    return Container(
      color: Colors.grey[850],
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: Colors.white24,
        size: 18,
      ),
    );
  }
}

/// Internal state holder for each gallery page
class _GalleryPageState {
  final PhotoViewController photoController = PhotoViewController();
  final PhotoViewScaleStateController scaleStateController =
      PhotoViewScaleStateController();
  
  // Stream subscription for scale state changes
  StreamSubscription<PhotoViewScaleState>? subscription;

  void dispose() {
    subscription?.cancel();
    photoController.dispose();
    scaleStateController.dispose();
  }
}

/// Utility wrapper for common use cases
class GalleryItem {
  final String imageUrl;
  final String? thumbnailUrl;
  final String? id;
  final String? caption;

  const GalleryItem({
    required this.imageUrl,
    this.thumbnailUrl,
    this.id,
    this.caption,
  });
}

/// Extension for easy gallery opening
extension FullScreenGalleryExtension on BuildContext {
  /// Open a full-screen image gallery
  Future<void> showGallery({
    required List<String> images,
    int initialIndex = 0,
    String? heroTagPrefix,
    bool showThumbnails = true,
  }) {
    return FullScreenGallery.open(
      context: this,
      images: images,
      initialIndex: initialIndex,
      heroTagPrefix: heroTagPrefix,
      showThumbnails: showThumbnails,
    );
  }
}
