import 'dart:math' as math;

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

  /// `_controller` gerçekten oluşturuldu mu? `Uri.parse` / `networkUrl` bozuk
  /// URL'de fırlatırsa `late` alan atanmadan kalır; dispose'ta ona dokunmak
  /// `LateInitializationError` ile çöktürürdü. Bu bayrak dispose'u güvene alır.
  bool _controllerCreated = false;

  /// Çift kapatmayı (çarpı + kaydırma aynı anda / kaydırma sırasında tekrar
  /// tetiklenme) engeller — tek `pop`.
  bool _closing = false;

  /// Oynatma teardown'u (durdur + sıfırla + sistem UI geri yükle) bir kez
  /// yapılsın; hem kapatma anında hem dispose'ta çağrıldığında tekrar etmesin.
  bool _torndown = false;

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
      _controllerCreated = true;
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
    // Kapatma anında zaten yapılmadıysa oynatmayı durdur + sistem UI'yı geri
    // yükle (dispose'un ne zaman/çalışıp çalışmadığına GÜVENMEDEN — kök sorun:
    // bazı durumlarda dispose gecikince ses arkada çalmaya ve immersive üst bar
    // gizli kalmaya devam ediyordu).
    _teardownPlayback();
    if (_controllerCreated) {
      _controller.removeListener(_videoListener);
      _controller.dispose();
    }
    super.dispose();
  }

  /// Oynatmayı **anında** durdurup başa sarar ve tam-ekran sistem UI modunu
  /// (immersive → edgeToEdge) geri yükler. Kapatma niyeti oluştuğu an çağrılır;
  /// dispose'a bel bağlamaz. İdempotent (birden çok çağrı zararsız).
  void _teardownPlayback() {
    if (_torndown) return;
    _torndown = true;
    // iOS (AVFoundation): sadece dispose oynatmayı durdurmuyor; ses arka planda
    // devam ediyordu. Sesi kıs + duraklat + başa sar → AVPlayer anında susar,
    // ekrandan çıkıldığı an video sıfırlanır (kullanıcı isteği).
    // NOT: Yalnızca `initialize()` tamamlandıysa oynatıcıya dokun — hazır
    // olmayan controller'da `seekTo`/`pause` iOS'ta HATA fırlatabiliyor. Ayrıca
    // try/catch: teardown'daki hiçbir hata kapatmayı (pop) ASLA engellemesin.
    if (_controllerCreated && _isInitialized) {
      try {
        _controller.setVolume(0);
        _controller.pause();
        _controller.seekTo(Duration.zero);
      } catch (_) {/* kapatmayı bloklama */}
    }
    // Üst bar / sistem çubuklarını geri getir — video sayfasından çıkıldığı an.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  /// Tek kapatma yolu — çarpı, kaydırma ve hata ekranı hepsi buradan geçer.
  /// Önce oynatmayı durdurur (pop gecikse/başarısız olsa bile ses susar),
  /// sonra route'u kapatır. `_closing` bayrağı çift pop'u engeller.
  void _dismiss() {
    if (_closing) return;
    _closing = true;
    // Teardown pop'u ASLA engellememeli (yukarıda zaten try/catch'li; burada da
    // ayrıca korunuyoruz). Kapatma her koşulda gerçekleşsin.
    try {
      _teardownPlayback();
    } catch (_) {}
    // Orijinal, iOS+Android'de çalışan kapatma yolu: en yakın Navigator (bu
    // route root'a push edildiği için zaten root Navigator'dır). `rootNavigator:
    // true` + `canPop()` guard'ı iOS'ta kapatmayı bozuyordu → sade `pop`.
    if (mounted) {
      Navigator.of(context).pop();
    }
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
      child: PopScope(
        // Route HANGI yolla kapatılırsa kapatılsın (çarpı, kaydırma, Android
        // geri tuşu, iOS kenar-geri jesti) oynatma teardown'u GARANTİ çalışsın
        // — dispose gecikse bile ses susar, üst bar geri gelir.
        canPop: true,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) _teardownPlayback();
        },
        child: GestureDetector(
        onVerticalDragUpdate: (details) {
          _dragOffset += details.primaryDelta ?? 0;
          // Eşik aşılınca TEK kapatma (`_dismiss` `_closing` ile korumalı) —
          // eskiden `pop`'u drag-update içinde çağırıp `_dragOffset`'i sıfırlamak
          // hızlı kaydırmada çift pop'a yol açabiliyordu.
          if (_dragOffset > 80) _dismiss();
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
                  // iOS FIX: Çarpı, çentik/Dynamic Island bölgesinin İÇİNE
                  // çiziliyordu (top: 0 + SafeArea yok) — o bölgede dokunuşları
                  // iOS sistemi yutar, onPressed HİÇ tetiklenmez ("çarpı
                  // kapatmıyor"un gerçek nedeni). `viewPadding` kullanıyoruz
                  // çünkü immersive modda `padding` sıfırlanabilir ama fiziksel
                  // çentik inseti `viewPadding`'te her zaman durur.
                  padding: EdgeInsets.only(
                    top: math.max(
                        MediaQuery.viewPaddingOf(context).top, 8),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 28),
                        onPressed: _dismiss,
                        // Dokunma alanını büyüt — kenara yakın küçük hedefte
                        // ıskalamayı azaltır.
                        padding: const EdgeInsets.all(12),
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
                  // Alt inset: iOS home-indicator / Android jest çubuğu ile
                  // çakışmasın (üst bardaki çentik düzeltmesiyle aynı mantık).
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    math.max(MediaQuery.viewPaddingOf(context).bottom, 16),
                  ),
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
            onPressed: _dismiss,
          ),
        ],
      ),
    );
  }
}
