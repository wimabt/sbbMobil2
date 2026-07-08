import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';
import '../routing/deep_link_validator.dart';
import '../services/geofence_service.dart';
import '../services/log_service.dart';
import '../services/native_geofence_service.dart';

// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  GEOFENCE HANDLER WIDGET - Lifecycle-Based Geofencing                    ║
// ╠══════════════════════════════════════════════════════════════════════════╣
// ║  • WidgetsBindingObserver ile app lifecycle dinler                       ║
// ║  • App her resume olduğunda checkLocation() çağırır                     ║
// ║  • Foreground'da bölgeye girilince GeofenceWelcomeDialog gösterir       ║
// ║  • Deep linking: district_detail → go_router                            ║
// ╚══════════════════════════════════════════════════════════════════════════╝

/// Geofence olaylarını dinleyip bildirim gösteren widget
///
/// Bu widget:
/// 1. App ön plana geldiğinde konum kontrolü yapar (Lifecycle-Based)
/// 2. Bölge girişinde in-app dialog gösterir
/// 3. Notification tap'te deep link yapar
class GeofenceHandler extends ConsumerStatefulWidget {
  final Widget child;

  /// true ise widget mount olduğunda servisi otomatik etkinleştirir
  final bool autoStart;

  const GeofenceHandler({
    super.key,
    required this.child,
    this.autoStart = false,
  });

  @override
  ConsumerState<GeofenceHandler> createState() => _GeofenceHandlerState();
}

class _GeofenceHandlerState extends ConsumerState<GeofenceHandler>
    with WidgetsBindingObserver {
  /// Native geofence bildirimine dokunma akışı aboneliği.
  StreamSubscription<Map<String, dynamic>>? _nativeTapSub;

  @override
  void initState() {
    super.initState();

    // Lifecycle observer ekle (GEOFENCE_MASTER.md STEP 3)
    WidgetsBinding.instance.addObserver(this);

    // Post-frame callback ile servisi yapılandır
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupGeofenceHandler();
    });
  }

  @override
  void dispose() {
    _nativeTapSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LIFECYCLE OBSERVER - App resume olduğunda konum kontrolü
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      LogService.i(
        '📱 App resumed → checking geofence triggers...',
        tag: 'GeofenceHandler',
      );

      // Geofence servisi etkinse konum kontrolü yap + native bölgeleri tazele
      // (admin panelden eklenen/düzenlenen bölgeler yayılsın).
      final geofenceState = ref.read(geofenceProvider).value ?? const GeofenceState();
      if (geofenceState.isEnabled) {
        ref.read(geofenceProvider.notifier).checkLocation();
        ref.read(geofenceProvider.notifier).syncNativeGeofences();
      }
      // App kapalıyken native geofence bildirimine dokunulup açıldıysa,
      // bekleyen deep-link payload'unu çek ve yönlendir.
      NativeGeofenceService.instance.drainPendingTap();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SETUP
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _setupGeofenceHandler() async {
    LogService.d('Setting up geofence handler...', tag: 'GeofenceHandler');

    final notifier = ref.read(geofenceProvider.notifier);

    // Geofence triggered callback: Dialog göster (uyg. açıkken)
    notifier.setOnGeofenceTriggered((zone, payload) {
      LogService.i(
        '📢 Geofence triggered in foreground: ${zone.name}',
        tag: 'GeofenceHandler',
      );
      _showGeofenceDialog(zone, payload);
    });

    // Native (OS) geofence bildirimine dokunma → deep link. Hem app açıkken
    // gelen tap'ler hem de app kapalıyken dokunulup açılan (drainPendingTap)
    // payload'lar bu akıştan gelir.
    _nativeTapSub ??=
        NativeGeofenceService.instance.taps.listen((payload) {
      if (!mounted) return;
      LogService.i('📍 Native geofence notification tapped', tag: 'GeofenceHandler');
      _navigateToDeepLink(payload);
    });
    await NativeGeofenceService.instance.drainPendingTap();

    // AutoStart = true ise servisi etkinleştir
    if (widget.autoStart) {
      final started = await notifier.enable();
      if (started) {
        LogService.s('Geofence service auto-started', tag: 'GeofenceHandler');
      } else {
        LogService.w(
          'Geofence service auto-start failed (permission denied?)',
          tag: 'GeofenceHandler',
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // IN-APP DIALOG
  // ─────────────────────────────────────────────────────────────────────────

  /// Bölgeye girildiğinde hoş geldin dialog'u göster
  void _showGeofenceDialog(GeofenceZone zone, Map<String, dynamic> payload) {
    if (!mounted) {
      LogService.w('Widget not mounted, cannot show dialog', tag: 'GeofenceHandler');
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => GeofenceWelcomeDialog(
        title: '📍 ${zone.name}',
        body: zone.message,
        regionName: zone.name,
        onExplore: () {
          Navigator.of(dialogContext).pop();
          _navigateToDeepLink(payload);
        },
        onDismiss: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  /// Deep link navigasyonu
  void _navigateToDeepLink(Map<String, dynamic> payload) {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;

    final target = payload['target']?.toString().trim();
    final idRaw = payload['id'];
    final id = idRaw == null ? '' : idRaw.toString().trim();

    if (target == null || target.isEmpty) return;

    if (!DeepLinkValidator.isGeofenceTargetAllowed(target)) {
      DeepLinkValidator.logBlockedNotificationPayload(
        'Blocked unknown geofence deep link target',
      );
      router.go('/');
      return;
    }

    if (!DeepLinkValidator.isValidRouteSegmentId(id)) {
      DeepLinkValidator.logBlockedNotificationPayload(
        'Blocked malformed geofence deep link id',
      );
      router.go('/');
      return;
    }

    switch (target) {
      case 'district_detail':
      case 'district':
        router.go('/places/$id');
        break;
      case 'place_detail':
      case 'place':
        router.go('/places/$id');
        break;
      case 'route_detail':
      case 'route':
        router.go('/routes/$id');
        break;
      case 'event_detail':
      case 'event':
        router.go('/events/$id');
        break;
      default:
        router.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// GEOFENCE WELCOME DIALOG
// ═══════════════════════════════════════════════════════════════════════════════

/// Geofence girişinde gösterilen hoş geldin dialog'u
///
/// Premium, civic-grade tasarım. Neon/flashy değil, sakin ve güvenilir.
class GeofenceWelcomeDialog extends StatelessWidget {
  final String title;
  final String body;
  final String regionName;
  final VoidCallback onExplore;
  final VoidCallback onDismiss;

  const GeofenceWelcomeDialog({
    super.key,
    required this.title,
    required this.body,
    required this.regionName,
    required this.onExplore,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 16,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1A365D),
                    const Color(0xFF0F172A),
                  ]
                : [
                    const Color(0xFFF0F9FF),
                    const Color(0xFFE0F2FE),
                  ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Üst görsel bölümü
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.primaryColor.withValues(alpha: 0.8),
                    theme.primaryColor.withValues(alpha: 0.4),
                  ],
                ),
              ),
              child: Column(
                children: [
                  // Animasyonlu konum ikonu
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.location_on,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // Bölge etiketi
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      regionName.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // İçerik
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodySmall?.color,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Butonlar
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onDismiss,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(context.l10n.btnLater),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: onExplore,
                          icon: const Icon(Icons.explore, size: 20),
                          label: Text(context.l10n.btnExplore),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// GEOFENCE TOGGLE WIDGET (Ayarlar ekranı için)
// ═══════════════════════════════════════════════════════════════════════════════

/// Geofence servisini açıp kapatan toggle widget'ı
///
/// Profile veya Settings ekranında kullanılır.
class GeofenceToggle extends ConsumerWidget {
  final String? title;
  final String? subtitle;

  const GeofenceToggle({
    super.key,
    this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final geofenceState = ref.watch(geofenceProvider).value ?? const GeofenceState();
    final notifier = ref.read(geofenceProvider.notifier);

    return SwitchListTile(
      title: Text(title ?? context.l10n.geofenceToggleTitle),
      subtitle: Text(
        subtitle ?? context.l10n.geofenceToggleSubtitle,
      ),
      value: geofenceState.isEnabled,
      secondary: Icon(
        geofenceState.isEnabled ? Icons.location_on : Icons.location_off_outlined,
        color: geofenceState.isEnabled ? Theme.of(context).primaryColor : null,
      ),
      onChanged: (enabled) async {
        if (enabled) {
          await notifier.enable();
        } else {
          notifier.disable();
        }
      },
    );
  }
}
