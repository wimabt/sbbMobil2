import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/routing/sbb_deep_link_resolver.dart';
import '../../../core/utils/external_ar_launcher.dart';
import '../../../core/services/analytics_events.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/ar_service.dart';
import '../../../core/services/log_service.dart';
import '../../../core/services/qr_resolve_service.dart';

const _tag = 'QrArScanner';

/// QR Scanner for marker-based AR triggers.
///
/// Scan flow (per ar_bcknd.md §3):
/// 1. Parse QR content as JSON → check for `type: "ar_model"` with `modelId`/`modelUrl`
/// 2. If `modelId` present → call `GET /mobile/ar/place/{id}` to get full place + model
/// 3. If only URL → call `GET /mobile/ar/resolve?url=...` to find associated place
/// 4. Navigate to AR Viewer with the resolved HTTPS model URL
class QrArScannerScreen extends ConsumerStatefulWidget {
  const QrArScannerScreen({super.key});

  @override
  ConsumerState<QrArScannerScreen> createState() => _QrArScannerScreenState();
}

class _QrArScannerScreenState extends ConsumerState<QrArScannerScreen> {
  late final MobileScannerController _scannerController;
  bool _isProcessing = false;
  bool _torchEnabled = false;

  @override
  void initState() {
    super.initState();
    // PERFORMANS: varsayılan ayarlarda mobile_scanner her kareyi TÜM barkod
    // formatları için analiz eder → CPU dolar, kamera preview'i kekeler/donar.
    //   • formats: yalnızca QR (AR tetikleyicileri QR) → analiz maliyeti düşer
    //   • detectionTimeoutMs: analizler arası min ~300ms throttle → kalan süre
    //     preview'e kalır, akıcılaşır. NOT: paket bu throttle'ı yalnızca
    //     DetectionSpeed.normal ile uyguluyor (noDuplicates'te 0'a düşüyor).
    //     Tekrar işleme `_isProcessing` + `stop()` ile zaten engelleniyor.
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      // Zayıf cihazlarda kare analizi yetişemeyince kareler birikir ve preview
      // ~saniyelerce donar. Throttle'ı artırıp (500ms) analiz çözünürlüğünü
      // düşürmek (720p) hem analiz maliyetini hem preview texture yükünü azaltır
      // → kamera akıcı kalır. QR için 720p fazlasıyla yeterli.
      detectionTimeoutMs: 500,
      cameraResolution: const Size(1280, 720),
      formats: const [BarcodeFormat.qrCode],
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_isProcessing) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final rawValue = barcode.rawValue!;
    LogService.d('QR detected: $rawValue', tag: _tag);

    _isProcessing = true;
    _scannerController.stop();
    _handleArQr(rawValue);
  }

  /// QR çözümleme akışı:
  ///   0) Kısa ([PersistentQrCode.isLikely]) bir kodsa →
  ///      `mobile_pending_changes.md` B8 — `/api/v1/qr/resolve` → deep link.
  ///   1) JSON `{ type: "ar_model", ... }` → AR modeli (ar_bcknd.md §3.2).
  ///   2) `https?://...` URL → AR resolve endpoint'i.
  ///   3) Aksi halde → "AR modeli içermiyor" uyarısı.
  ///
  /// POS QR (uzun, HMAC imzalı `qr_data` payload) bu ekrandan tetiklenmez
  /// — staff_pos akışı kendi tarayıcısını kullanır.
  Future<void> _handleArQr(String scannedText) async {
    final trimmed = scannedText.trim();

    // 0) Persistent (kısa, kalıcı) QR → /qr/resolve
    if (PersistentQrCode.isLikely(trimmed)) {
      final handled = await _handlePersistentQr(trimmed);
      if (handled) return;
      // handle başarısız ise scanner'ı zaten resume ettik; düşüş yok.
      return;
    }

    final arService = ref.read(arServiceProvider);

    // 1) Try JSON format: { "type": "ar_model", "modelId": "...", "modelUrl": "..." }
    try {
      final decoded = jsonDecode(scannedText);
      if (decoded is Map<String, dynamic> && decoded['type'] == 'ar_model') {
        final modelId = decoded['modelId'] as String?;
        final modelUrl = decoded['modelUrl'] as String?;
        final modelName = decoded['modelName'] as String?;

        if (modelId != null) {
          final result = await arService.fetchArPlace(modelId);
          if (result.hasModel && mounted) {
            await _openInAr(
              modelUrl: result.modelUrl!,
              modelName: result.modelName ?? result.place?.name ?? modelName,
            );
            return;
          }
        }

        if (modelUrl != null && mounted) {
          await _openInAr(modelUrl: modelUrl, modelName: modelName);
          return;
        }

        _showError('QR kodunda AR model bilgisi bulunamadı');
        _resumeScanner();
        return;
      }
    } catch (_) {
      // JSON değilse devam et
    }

    // 2) Plain URL — resolve endpoint'i ile eşleştir
    final uri = Uri.tryParse(scannedText.trim());
    if (uri != null && uri.hasAbsolutePath && uri.scheme.startsWith('http')) {
      final resolveResult = await arService.resolveArUrl(scannedText.trim());

      if (resolveResult.hasModel && mounted) {
        await _openInAr(
          modelUrl: resolveResult.modelUrl!,
          modelName: resolveResult.modelName ?? resolveResult.place?.name,
        );
        return;
      }
    }

    // 3) Geçersiz format
    _showError('Bu QR kod bir AR modeli içermiyor');
    _resumeScanner();
  }

  /// Persistent (B8) QR akışı.
  /// Dönen `bool` — true: ele aldık (success veya bilinçli hata mesajı);
  /// false: persistent değilmiş, çağıran AR akışına düşsün.
  Future<bool> _handlePersistentQr(String code) async {
    final resolver = ref.read(qrResolveServiceProvider);
    try {
      final resp = await resolver.resolve(code);

      ref.read(analyticsServiceProvider).track(
        AnalyticsEvents.qrScanned,
        properties: {
          'payload_kind': resp.targetType,
          'target_id': resp.targetId,
          'source': 'persistent',
        },
      );

      if (!mounted) return true;
      final navResult =
          await SbbDeepLinkResolver.open(context, resp.deepLink);

      if (navResult == SbbDeepLinkResult.invalid) {
        _showError('QR kod tanınmadı veya artık geçerli değil');
        _resumeScanner();
      } else {
        // Yönlendirme yapıldı — scanner ekranı arka planda kapanmadan önce
        // tek kullanımlık olarak isProcessing flag'i true kalır.
        // Geri dönüşte resume için kısa gecikme.
        Future.delayed(const Duration(milliseconds: 600), _resumeScanner);
      }
      return true;
    } on QrResolveException catch (e) {
      // 404 → "tanınmadı" toast'ı; ağ → "bağlantı" toast'ı.
      switch (e.kind) {
        case QrResolveErrorKind.notFound:
          _showError('QR kod tanınmadı veya artık geçerli değil');
          break;
        case QrResolveErrorKind.network:
          _showError('Bağlantı hatası. Lütfen tekrar deneyin');
          break;
        case QrResolveErrorKind.unknown:
          _showError('QR çözümlenemedi');
          break;
      }
      _resumeScanner();
      return true;
    }
  }

  /// Çözülen modeli **cihazın native AR'ında** açar (Android: Scene Viewer,
  /// iOS: AR Quick Look). Uygulama-içi SceneView render'ı orta-segment
  /// cihazlarda donduğu için (bkz. pubspec AR notu) ana yol native AR.
  Future<void> _openInAr({
    required String modelUrl,
    String? modelName,
  }) async {
    if (!mounted) return;
    final ok = await launchExternalArViewer(modelUrl, title: modelName);
    if (!ok && mounted) {
      _showError('AR görüntüleyici açılamadı');
    }
    // Native AR ekranı kapanıp tarayıcıya dönülünce yeniden taramaya hazır ol.
    Future.delayed(const Duration(milliseconds: 800), _resumeScanner);
  }

  void _resumeScanner() {
    if (mounted) {
      _isProcessing = false;
      _scannerController.start();
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _toggleTorch() {
    _scannerController.toggleTorch();
    if (mounted) {
      setState(() => _torchEnabled = !_torchEnabled);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'AR QR Tarayıcı',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _toggleTorch,
            icon: Icon(
              _torchEnabled ? Icons.flash_on : Icons.flash_off,
              color: _torchEnabled ? AppColors.neonOrange : Colors.white70,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onBarcodeDetected,
            errorBuilder: (context, error) =>
                _ScannerErrorFallback(error: error),
          ),
          _buildScanOverlay(),
          if (_isProcessing) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildScanOverlay() {
    return Positioned.fill(
      child: Column(
        children: [
          const Spacer(flex: 3),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 48),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(180),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.view_in_ar,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  'AR QR Kodunu Tarayın',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '3D modeli görüntülemek için QR kodu kameraya gösterin',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
          const Spacer(flex: 1),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withAlpha(150),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'AR modeli çözümleniyor...',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Şartname §6.8.3.10 — Kamera izni reddi / desteklenmeyen cihaz / başka
/// bir hata için kullanıcıya anlamlı yönlendirme. `mobile_scanner` paketi
/// `errorBuilder` ile bu widget'ı kamera başlatılamadığında render eder.
class _ScannerErrorFallback extends StatelessWidget {
  const _ScannerErrorFallback({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (icon, title, message, actionLabel, action) =
        _resolveError(context, error);

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 56, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            if (action != null)
              FilledButton.icon(
                onPressed: action,
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: Text(actionLabel),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(context.l10n.btnGoBack,
                  style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, String, String, String, VoidCallback?) _resolveError(
    BuildContext context,
    MobileScannerException error,
  ) {
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return (
          Icons.no_photography_outlined,
          'Kamera İzni Gerekli',
          'QR / AR kodlarını okuyabilmek için uygulama ayarlarından kamera '
              'iznini etkinleştirmeniz gerekiyor.',
          'Ayarlara Git',
          () => openAppSettings(),
        );
      case MobileScannerErrorCode.unsupported:
        return (
          Icons.phonelink_erase_rounded,
          'Bu Cihaz Desteklenmiyor',
          'Cihazınızda QR tarama özelliği etkin değil. AR içeriklerine '
              'mekan detay sayfasından da ulaşabilirsiniz.',
          '',
          null,
        );
      default:
        return (
          Icons.videocam_off_outlined,
          'Kamera Başlatılamadı',
          'Beklenmeyen bir hata oluştu. Cihazı yeniden başlatmayı veya '
              'birkaç saniye sonra tekrar denemeyi deneyebilirsiniz.',
          '',
          null,
        );
    }
  }
}
