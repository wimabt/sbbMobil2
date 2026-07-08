import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/design/design_tokens.dart';
import '../../../../core/providers/connectivity_provider.dart';
import '../../../../core/security/secure_screen_mixin.dart';
import '../../../../core/services/qr_services.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../l10n/l10n.dart';

/// Theme-aware color provider for QR Modal
class _QrModalTheme {
  final bool isDark;
  
  _QrModalTheme(this.isDark);
  
  // Primary accent colors (same for both themes)
  static const Color primaryTeal = Color(0xFF26A69A);
  static const Color primaryBlue = Color(0xFF1976D2);
  static const Color successGreen = Color(0xFF4CAF50);
  
  // Theme-dependent colors
  Color get surface => isDark 
      ? const Color(0xFF1E1E1E) 
      : const Color(0xFFF8F9FA);
  
  Color get titleColor => isDark 
      ? Colors.white 
      : const Color(0xFF1E1E1E);
  
  Color get subtitleColor => isDark 
      ? Colors.white.withAlpha(150) 
      : const Color(0xFF757575);
  
  Color get handleBarColor => isDark 
      ? Colors.white.withAlpha(40) 
      : Colors.black.withAlpha(30);
  
  Color get timerBackgroundColor => isDark 
      ? Colors.white.withAlpha(20) 
      : Colors.black.withAlpha(15);
  
  Color get timerLabelColor => isDark 
      ? Colors.white.withAlpha(100) 
      : const Color(0xFF757575);
  
  // QR Card (always white for scannability)
  Color get qrCardBackground => Colors.white;
  Color get qrCodeColor => const Color(0xFF1E1E1E);
  Color get qrUserNameColor => const Color(0xFF1E1E1E);
  Color get qrUserIdColor => const Color(0xFF757575);
  
  // Dialog colors
  Color get dialogBackground => isDark 
      ? const Color(0xFF1E1E1E) 
      : Colors.white;
  
  Color get dialogTitleColor => isDark 
      ? Colors.white 
      : const Color(0xFF1E1E1E);
  
  Color get dialogMessageColor => isDark 
      ? Colors.white.withAlpha(150) 
      : const Color(0xFF757575);
  
  // Shadows
  List<BoxShadow> get qrCardShadow => isDark 
      ? [
          BoxShadow(
            color: primaryTeal.withAlpha(40),
            blurRadius: 30,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
        ]
      : [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ];
}

/// Digital ID QR Code Modal with backend-driven QR (Auth backend)
/// Supports both Light and Dark themes
class UserQrModal extends ConsumerStatefulWidget {
  /// User ID to embed in QR code
  final String userId;
  
  /// User's display name
  final String userName;
  
  const UserQrModal({
    super.key,
    required this.userId,
    required this.userName,
  });

  /// Shows the QR Modal as a bottom sheet
  static Future<void> show(BuildContext context, {
    required String userId,
    required String userName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UserQrModal(
            userId: userId,
            userName: userName,
          ),
    );
  }

  @override
  ConsumerState<UserQrModal> createState() => _UserQrModalState();
}

class _UserQrModalState extends ConsumerState<UserQrModal>
    with
        SingleTickerProviderStateMixin,
        SecureScreenMixin<UserQrModal>,
        WidgetsBindingObserver {
  GoRouter? _router;
  bool _routeListenerAttached = false;
  String? _locationWhenOpened;

  /// QR token string (base64url) — backend'in ürettiği, değişen token
  String? _qrData;
  /// "492-104" formatında sayısal kod
  String? _numericCode;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isOffline = false;
  bool _isRefreshing = false;
  
  /// Animation controller for progress bar
  late AnimationController _animationController;
  
  /// Token geçerlilik süresi — generate-qr'dan gelen expires_in (varsayılan 60s)
  int _expiresInSeconds = 60;
  QRSpendingService? _qrService;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _expiresInSeconds),
    )
      ..addStatusListener((status) {
        if (!mounted) return;
        if (status == AnimationStatus.completed && !_isOffline && _qrData != null) {
          // Token süresi doldu, yeni token bekleniyor — overlay göster
          setState(() => _isRefreshing = true);
        }
      })
      ..forward();

    _qrService = ref.read(qrSpendingServiceProvider);

    // Yeni token geldiğinde — qrData + numericCode + balance + expiresIn
    _qrService!.onQRUpdated = (qrData, numericCode, balance, expiresIn) {
      if (!mounted) return;
      setState(() {
        _qrData = qrData;
        _numericCode = _formatNumericCode(numericCode);
        _errorMessage = null;
        _isLoading = false;
        _isRefreshing = false;
        _expiresInSeconds = expiresIn;
        _animationController.duration = Duration(seconds: expiresIn);
        _animationController
          ..reset()
          ..forward();
      });
      Haptics.light();
    };

    // POS personeli ödemeyi tamamladığında
    _qrService!.onRedeemed = (amount, balanceAfter, message) {
      if (!mounted) return;
      _showRedeemedDialog(amount, message);
    };

    _qrService!.onError = (message) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = message;
      });
      Haptics.error();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    };

    _qrService!.startQRSession();

    WidgetsBinding.instance.addPostFrameCallback((_) => _attachRouteListener());
  }

  void _attachRouteListener() {
    if (!mounted) return;
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    _router = router;
    _locationWhenOpened = router.state.uri.toString();
    router.routerDelegate.addListener(_onGoRouterChanged);
    _routeListenerAttached = true;
  }

  void _onGoRouterChanged() {
    if (!mounted || _router == null || _locationWhenOpened == null) return;
    final now = _router!.state.uri.toString();
    if (now == _locationWhenOpened) return;
    unawaited(_expireAndPopDueToNavigation());
  }

  Future<void> _expireAndPopDueToNavigation() async {
    if (_routeListenerAttached) {
      _router?.routerDelegate.removeListener(_onGoRouterChanged);
      _routeListenerAttached = false;
    }
    final service = _qrService;
    if (service != null) {
      await service.stopQRSession();
    }
    if (!mounted) return;
    final nav = Navigator.maybeOf(context);
    if (nav != null && nav.canPop()) {
      nav.pop();
    }
  }

  /// "492104" → "492-104"
  String _formatNumericCode(String raw) {
    final digits = raw.replaceAll('-', '').replaceAll(' ', '');
    if (digits.length == 6) return '${digits.substring(0, 3)}-${digits.substring(3)}';
    return raw;
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_routeListenerAttached) {
      _router?.routerDelegate.removeListener(_onGoRouterChanged);
      _routeListenerAttached = false;
    }
    final service = _qrService;
    if (service != null) {
      unawaited(service.stopQRSession());
    }
    _animationController.dispose();
    super.dispose();
  }

  /// Arka plan / görünmezlik: sunucudaki QR oturumunu kapat (çağrı, başka uygulama vb.).
  /// `inactive` bilinçli olarak yok — kısa sistem UI’ları (bildirim çekmecesi) oturumu düşürmez.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _onAppBackgrounded();
        break;
      case AppLifecycleState.resumed:
        _onAppForegrounded();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _onAppBackgrounded() {
    final service = _qrService;
    if (service == null) return;
    unawaited(service.stopQRSession());
    if (!mounted) return;
    setState(() {
      _qrData = null;
      _numericCode = null;
      _isLoading = true;
      _isRefreshing = false;
      _errorMessage = null;
    });
    _animationController.stop();
  }

  void _onAppForegrounded() {
    if (!mounted || _qrService == null) return;
    unawaited(_restartQrAfterResume());
  }

  Future<void> _restartQrAfterResume() async {
    if (!mounted || _qrService == null) return;
    if (_isOffline) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = context.l10n.qrWaitingConnection;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    await _qrService!.startQRSession();
  }

  /// POS personeli ödemeyi tamamladığında gösterilir
  void _showRedeemedDialog(int amount, String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _QrResultDialog(
        isDark: isDark,
        title: context.l10n.qrPaymentComplete,
        message: message,
        icon: Icons.check_circle_rounded,
        color: _QrModalTheme.successGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = _QrModalTheme(isDark);

    // Connectivity: offline → stop session + show overlay, online → restart.
    ref.listen(connectivityProvider, (prev, next) {
      final offline = next.maybeWhen(
        data: (s) => s == AppConnectivity.offline,
        orElse: () => false,
      );
      if (offline == _isOffline) return;

      if (!mounted) return;
      setState(() {
        _isOffline = offline;
        if (offline) {
          _isRefreshing = false;
          _isLoading = false;
          _errorMessage = context.l10n.qrWaitingConnection;
        } else {
          _isLoading = true;
          _errorMessage = null;
        }
      });

      final service = _qrService;
      if (service == null) return;

      if (offline) {
        unawaited(service.stopQRSession());
      } else {
        unawaited(service.startQRSession());
      }
    });
    
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  24,
                  8,
                  24,
                  24 + AppNavBar.bottomPadding,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    _buildHandleBar(theme),
                    const SizedBox(height: 20),
                    
                    // Header
                    _buildHeader(theme),
                    const SizedBox(height: 24),
                    
                    // QR Card
                    _buildQrCard(theme),
                    const SizedBox(height: 16),
                    
                    // Security Timer
                    _buildSecurityTimer(theme),
                    const SizedBox(height: 8),
                    
                    // Timer label
                    _buildTimerLabel(theme),
                  ],
                ),
              ),
            ),
            if (_isOffline || _isRefreshing)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: true,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: theme.isDark ? 0.55 : 0.35),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        decoration: BoxDecoration(
                          color: theme.dialogBackground,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: theme.handleBarColor,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.4),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _isOffline ? context.l10n.qrWaitingConnection : context.l10n.qrRefreshing,
                              style: TextStyle(
                                color: theme.dialogTitleColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHandleBar(_QrModalTheme theme) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: theme.handleBarColor,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
  
  Widget _buildHeader(_QrModalTheme theme) {
    return Column(
      children: [
        // Icon and title row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _QrModalTheme.primaryTeal.withAlpha(theme.isDark ? 30 : 20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                color: _QrModalTheme.primaryTeal,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Dijital Kimlik',
              style: TextStyle(
                color: theme.titleColor,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.qrSpendPrompt,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.subtitleColor,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
  
  Widget _buildQrCard(_QrModalTheme theme) {
    final qrData = _qrData;
    Widget qrWidget;

    if (_isLoading) {
      qrWidget = const SizedBox(
        height: 220,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    } else if (qrData != null) {
      qrWidget = QrImageView(
        data: qrData,
        version: QrVersions.auto,
        size: 220,
        backgroundColor: Colors.white,
        eyeStyle: QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: theme.qrCodeColor,
        ),
        dataModuleStyle: QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: theme.qrCodeColor,
        ),
        errorCorrectionLevel: QrErrorCorrectLevel.H,
      );
    } else {
      qrWidget = SizedBox(
        height: 220,
        child: Center(
          child: Text(
            _errorMessage ?? context.l10n.qrNoCode,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.qrUserIdColor,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: theme.qrCardBackground,
        borderRadius: BorderRadius.circular(24),
        boxShadow: theme.qrCardShadow,
      ),
      child: Column(
        children: [
          // QR Code — backend'den gelen qr_data token'ı
          qrWidget,
          const SizedBox(height: 16),
          
          // User name
          Text(
            widget.userName,
            style: TextStyle(
              color: theme.qrUserNameColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          // Sayısal kod — personele sözel iletmek için
          if (_numericCode != null && _numericCode!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _QrModalTheme.primaryTeal.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _numericCode!,
                style: TextStyle(
                  color: theme.qrCodeColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildSecurityTimer(_QrModalTheme theme) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        // Progress goes from 1.0 to 0.0
        final progress = 1.0 - _animationController.value;
        
        return Container(
          height: 6,
          decoration: BoxDecoration(
            color: theme.timerBackgroundColor,
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    _QrModalTheme.primaryTeal,
                    _QrModalTheme.primaryBlue,
                  ],
                ),
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(
                    color: _QrModalTheme.primaryTeal.withAlpha(theme.isDark ? 100 : 60),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildTimerLabel(_QrModalTheme theme) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final remainingSeconds =
            (_expiresInSeconds * (1.0 - _animationController.value)).ceil();
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.security_rounded,
              size: 14,
              color: theme.timerLabelColor,
            ),
            const SizedBox(width: 6),
            Text(
              'Kod yenileniyor: ${remainingSeconds}s',
              style: TextStyle(
                color: theme.timerLabelColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }
  
}

/// Ödeme tamamlandığında gösterilen bilgi diyaloğu
class _QrResultDialog extends StatelessWidget {
  final bool isDark;
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  
  const _QrResultDialog({
    required this.isDark,
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = _QrModalTheme(isDark);
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: theme.dialogBackground,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: color.withAlpha(isDark ? 50 : 30),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(isDark ? 40 : 25),
              blurRadius: 40,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated icon container
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 400),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: child,
                );
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: color.withAlpha(isDark ? 30 : 20),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withAlpha(isDark ? 50 : 30),
                      blurRadius: 20,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: 64,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Title
            Text(
              title,
              style: TextStyle(
                color: theme.dialogTitleColor,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            
            // Message
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.dialogMessageColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            
            // Close button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Tamam',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
