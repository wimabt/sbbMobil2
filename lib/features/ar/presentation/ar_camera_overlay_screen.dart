import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/log_service.dart';
import '../../../core/utils/external_ar_launcher.dart';
import '../../../data/models/ar_point.dart';
import '../../../l10n/l10n.dart';
import 'providers/ar_geo_provider.dart';
import 'widgets/ar_model_scene.dart';
import 'widgets/ar_overlay_layer.dart';

/// §6.8.3.3 + §6.8.3.7 — **Birleşik AR sahnesi.**
///
/// Tek ekranda iki iç mod:
///   1. **Birincil (ARCore/ARKit):** [ArModelScene] canlı kamerayı native/GPU
///      ile render eder (Flutter `camera` Texture'ı gibi donmaz). 3B karta
///      dokununca model **aynı sahneye** yerleşir (sayfa değişmez) ve
///      sürüklenip ölçeklenebilir/döndürülebilir.
///   2. **Fallback (ARCore yok):** klasik `camera` eklentili arka plan
///      ([_CameraFallbackBackground]) + aynı [ArOverlayLayer]. 3B model bu
///      cihazlarda cihazın native AR uygulamasında (Scene Viewer / Quick Look)
///      açılır.
///
/// POI kartlarının yatay/dikey konumlama, çakışma ve banner mantığı her iki
/// modda da paylaşılan [ArOverlayLayer]'dadır. Eşleştirme motoru
/// [arGeoControllerProvider]'dan beslenir; bu ekran yalnızca görselleştirmedir.
class ArCameraOverlayScreen extends ConsumerStatefulWidget {
  const ArCameraOverlayScreen({super.key});

  @override
  ConsumerState<ArCameraOverlayScreen> createState() =>
      _ArCameraOverlayScreenState();
}

class _ArCameraOverlayScreenState extends ConsumerState<ArCameraOverlayScreen> {
  /// ARCore/ARKit oturumu başlatılamadıysa kamera-overlay fallback'ine düşeriz.
  bool _arUnavailable = false;

  /// Yalnızca **fallback** modda 3B kart'a dokununca çağrılır → cihazın native
  /// AR uygulamasında aç. (Birincil modda model zaten sahneye yerleşir.)
  void _onTapModel(ArMatchedPoint match) {
    final url = match.point.modelUrl;
    if (url == null || url.isEmpty) return;
    launchExternalArViewer(url, title: match.point.name);
  }

  void _onArUnavailable() {
    if (!mounted || _arUnavailable) return;
    LogService.i('AR scene falling back to camera overlay',
        tag: 'ArCameraOverlay');
    setState(() => _arUnavailable = true);
  }

  @override
  Widget build(BuildContext context) {
    // NOT: Geo state'i artık ArOverlayLayer kendi içinde izliyor → bu ekran
    // (Scaffold/AppBar) ve native ArModelScene ~20Hz geo update'lerinde
    // rebuild OLMAZ. Sadece _arUnavailable setState'inde rebuild olur.
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          context.l10n.arSceneTitle,
          style: const TextStyle(
              fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Kamera + (birincilde) 3B modeller doğrudan sahnede ───
          if (!_arUnavailable)
            ArModelScene(onUnavailable: _onArUnavailable)
          else
            const _CameraFallbackBackground(),

          // ── 2. Paylaşılan POI overlay'i ─────────────────────────────
          // 3B model kartları yalnızca fallback'te (ARCore yoksa) gösterilir;
          // birincil modda modeller zaten sahneye doğrudan yerleştirilir.
          ArOverlayLayer(
            onTapModel: _onTapModel,
            includeModelCards: _arUnavailable,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Fallback kamera arka planı — ARCore/ARKit olmayan cihazlar için
// ═══════════════════════════════════════════════════════════════════════

/// `camera` eklentili tam-ekran önizleme. **İzole** bir StatefulWidget'tır:
/// [arGeoControllerProvider]'ı izlemez → ~20Hz geo rebuild'lerinden etkilenmez
/// (preview Texture'ı ayrı [RepaintBoundary]'de, donma önlenir).
class _CameraFallbackBackground extends StatefulWidget {
  const _CameraFallbackBackground();

  @override
  State<_CameraFallbackBackground> createState() =>
      _CameraFallbackBackgroundState();
}

class _CameraFallbackBackgroundState extends State<_CameraFallbackBackground>
    with WidgetsBindingObserver {
  CameraController? _camera;
  Future<void>? _initFuture;
  bool _initFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initFuture = _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _initFailed = true);
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      // NOT: `imageFormatGroup` BİLEREK verilmez. Önizleme-only bir
      // controller'a `yuv420` (stream formatı) vermek, image-stream tüketicisi
      // olmadan bazı Android cihazlarında preview'i ilk karenin ardından
      // dondurur. Varsayılan format preview için doğrudur.
      final ctl = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await ctl.initialize();
      if (!mounted) {
        await ctl.dispose();
        return;
      }
      setState(() => _camera = ctl);
    } catch (e, st) {
      LogService.w('AR camera init failed: $e', tag: 'ArCameraOverlay');
      if (kDebugMode) debugPrint('$st');
      if (mounted) setState(() => _initFailed = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      final ctl = _camera;
      if (ctl == null) return;
      ctl.dispose();
      if (mounted) setState(() => _camera = null);
    } else if (state == AppLifecycleState.resumed && _camera == null) {
      if (mounted) setState(() => _initFuture = _initCamera());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initFailed) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            context.l10n.arCameraInitFailed,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
    final ctl = _camera;
    if (ctl == null || !ctl.value.isInitialized) {
      return FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
            );
          }
          return const SizedBox.shrink();
        },
      );
    }
    // §6.8.3.3 — kamera görüntüsü tam ekranı kaplamalı (BoxFit.cover davranışı).
    final mq = MediaQuery.sizeOf(context);
    var scale = mq.aspectRatio * ctl.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;
    return RepaintBoundary(
      child: ClipRect(
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.center,
          child: Center(child: CameraPreview(ctl)),
        ),
      ),
    );
  }
}
