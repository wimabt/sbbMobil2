import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/services/analytics_events.dart';
import '../../../../core/services/analytics_service.dart';

/// Full-screen video player viewer
class VideoPlayerViewer extends ConsumerStatefulWidget {
  const VideoPlayerViewer({
    super.key,
    required this.videoUrl,
    this.analyticsEntityType,
    this.analyticsEntityId,
  });

  final String videoUrl;

  /// `mobile_analytics_todo.md` §2.3 — video_play_completed event'i için
  /// opsiyonel entity bağlamı. Verilirse dispose'ta watched_s + duration_s
  /// ile birlikte event gönderilir.
  final String? analyticsEntityType;
  final String? analyticsEntityId;

  @override
  ConsumerState<VideoPlayerViewer> createState() => _VideoPlayerViewerState();
}

class _VideoPlayerViewerState extends ConsumerState<VideoPlayerViewer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _showControls = true;
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    _initializeVideo();

    // Route geçişi bittikten sonra status bar'ı gizle (profesyonel tam ekran)
    // İlk an AnnotatedRegion ile transparent çiziliyor → geçiş sırasında zıplama yok
    // 500ms sonra immersiveSticky devreye giriyor → saat/ikon tamamen kaybolur
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    });
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _controller.initialize();
      _controller.addListener(_videoListener);
      setState(() {
        _isInitialized = true;
      });
      // Otomatik başlat
      _controller.play();
      // Video başladıktan sonra kontrolleri gizle
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _controller.value.isPlaying) {
          setState(() {
            _showControls = false;
          });
        }
      });
    } catch (e) {
      debugPrint('Video initialization error: $e');
      setState(() {
        _hasError = true;
      });
    }
  }

  void _videoListener() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    // mobile_analytics_todo.md §2.3 — video_play_completed (min 3sn izlendiyse).
    if (_isInitialized &&
        widget.analyticsEntityType != null &&
        widget.analyticsEntityId != null) {
      final watched = _controller.value.position.inSeconds;
      final duration = _controller.value.duration.inSeconds;
      if (watched >= 3) {
        ref.read(analyticsServiceProvider).track(
          AnalyticsEvents.videoPlayCompleted,
          properties: {
            'entity_type': widget.analyticsEntityType!,
            'entity_id': widget.analyticsEntityId!,
            'watched_s': watched,
            'duration_s': duration,
          },
        );
      }
    }
    // Edge-to-edge modunu geri yükle
    // StableSystemPadding arkadaki ekranların padding'ini dondurduğu için zıplama olmaz
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller.removeListener(_videoListener);
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller.value.isPlaying) {
      _controller.pause();
      // Pause durumunda kontrolleri göster
      setState(() {
        _showControls = true;
      });
    } else {
      _controller.play();
      // Play durumunda kontrolleri 2 saniye sonra gizle
      setState(() {
        _showControls = true;
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _controller.value.isPlaying) {
          setState(() {
            _showControls = false;
          });
        }
      });
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '${twoDigits(duration.inHours)}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: GestureDetector(
      onVerticalDragUpdate: (details) {
        _dragOffset += details.primaryDelta ?? 0;
        if (_dragOffset > 80) {
          Navigator.of(context).pop();
          _dragOffset = 0;
        }
      },
      onVerticalDragEnd: (_) => _dragOffset = 0,
      onVerticalDragCancel: () => _dragOffset = 0,
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Video content
            if (_hasError)
              _buildErrorState()
            else if (!_isInitialized)
              _buildLoadingState()
            else
              GestureDetector(
                onTap: _toggleControls,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  ),
                ),
              ),

            // Controls overlay
            if (_isInitialized && _showControls) ...[
              // Top bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 28),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),

              // Center play/pause button - sadece pause durumunda veya kontroller gösteriliyorsa göster
              if (!_controller.value.isPlaying || _showControls)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () {
                      // Eğer kontroller gösteriliyorsa sadece toggle yap, değilse play/pause
                      if (_showControls) {
                        _toggleControls();
                      } else {
                        _togglePlayPause();
                      }
                    },
                    child: Center(
                      child: GestureDetector(
                        onTap: _togglePlayPause,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _controller.value.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Bottom controls
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Progress bar
                      VideoProgressIndicator(
                        _controller,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: Colors.white,
                          bufferedColor: Colors.white38,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Time display
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(_controller.value.position),
                            style: const TextStyle(color: Colors.white),
                          ),
                          Text(
                            _formatDuration(_controller.value.duration),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Loading indicator when buffering
            if (_isInitialized && _controller.value.isBuffering)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Video yükleniyor...',
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.white54,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'Video yüklenemedi',
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                  });
                  _initializeVideo();
                },
                child: Text(context.l10n.btnRetry),
              ),
            ],
          ),
          const SizedBox(height: 48),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54, size: 32),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
