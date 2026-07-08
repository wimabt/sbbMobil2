import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/providers/point_collection_provider.dart';
import '../config/feature_flags.dart';
import '../routing/deep_link_validator.dart';
import '../services/analytics_events.dart';
import '../services/analytics_service.dart';
import '../services/notification_service.dart';
import '../services/log_service.dart';

// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  NOTIFICATION HANDLER WIDGET                                            ║
// ╠══════════════════════════════════════════════════════════════════════════╣
// ║  Handles:                                                                ║
// ║  1. Foreground remote push → Custom SnackBar                             ║
// ║  2. Notification clicks → Deep linking via GoRouter                      ║
// ║  3. Points proximity notification taps → Place detail navigation         ║
// ║                                                                          ║
// ║  NOTE: Geofence notifications are handled by GeofenceHandler widget.     ║
// ╚══════════════════════════════════════════════════════════════════════════╝

/// Widget that handles notification events and deep linking.
class NotificationHandler extends ConsumerStatefulWidget {
  final Widget child;

  const NotificationHandler({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<NotificationHandler> createState() => _NotificationHandlerState();
}

class _NotificationHandlerState extends ConsumerState<NotificationHandler> {
  StreamSubscription<NotificationPayload>? _subscription;
  StreamSubscription<String>? _pointsNavSubscription;

  @override
  void initState() {
    super.initState();
    _setupNotificationHandlers();
    // Points/gamification feature flag — proximity notification stream'i
    // kapalıyken hiç abone olunmaz (yine de notifier safe çağrılır).
    if (FeatureFlags.pointsEnabled) {
      _setupPointsNavigationListener();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _pointsNavSubscription?.cancel();
    super.dispose();
  }

  /// Puan proximity bildirim tıklamalarını dinle.
  void _setupPointsNavigationListener() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(pointCollectionProvider.notifier);
      _pointsNavSubscription = notifier.navigationStream.listen((placeId) {
        if (!mounted) return;
        if (!DeepLinkValidator.isValidRouteSegmentId(placeId)) {
          DeepLinkValidator.logBlockedNotificationPayload(
            'Blocked proximity notification place id',
          );
          return;
        }
        final router = GoRouter.maybeOf(context);
        if (router != null) {
          router.push('/places/$placeId');
        }
      });
    });
  }

  void _setupNotificationHandlers() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(notificationProvider.notifier);

      notifier.setOnForegroundNotification((title, body, data) {
        // mobile_analytics_todo.md §2.11 — notification_received
        // Foreground'da bildirim geldi (OneSignal). PII güvenliği için sadece
        // tip + notification_id; başlık/içerik gönderilmiyor.
        // NotificationPayload = Map<String, dynamic>.
        ref.read(analyticsServiceProvider).track(
          AnalyticsEvents.notificationReceived,
          properties: {
            'type': (data['type'] ?? data['target'] ?? 'unknown').toString(),
            'notification_id': (data['id'] ?? '').toString(),
          },
        );
        _showForegroundNotification(title, body, data);
      });

      notifier.setOnNotificationClick((target, id) {
        // mobile_analytics_todo.md §2.11 — notification_opened
        ref.read(analyticsServiceProvider).track(
          AnalyticsEvents.notificationOpened,
          properties: {
            'type': target,
            'notification_id': id,
          },
        );
        _handleDeepLink(target, id);
      });

      _subscription = notifier.notificationEvents.listen((payload) {
        LogService.d('Notification event stream: $payload', tag: 'NotificationHandler');
      });
    });
  }

  /// Show in-app notification when app is in foreground (remote push)
  void _showForegroundNotification(
    String title,
    String body,
    NotificationPayload data,
  ) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final target = data['target']?.toString().trim();
    final idRaw = data['id'];
    final id = idRaw == null ? '' : idRaw.toString().trim();
    final canDeepLink = target != null &&
        target.isNotEmpty &&
        DeepLinkValidator.isNotificationTargetAllowed(target) &&
        (!DeepLinkValidator.notificationTargetRequiresId(target) ||
            DeepLinkValidator.isValidRouteSegmentId(id));
    final String? snackActionTarget = canDeepLink ? target : null;

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications_active, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (body.isNotEmpty)
                    Text(
                      body,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 5),
        action: snackActionTarget != null
            ? SnackBarAction(
                label: context.l10n.btnView,
                textColor: Colors.amber,
                onPressed: () => _handleDeepLink(snackActionTarget, id),
              )
            : null,
      ),
    );
  }

  /// Handle deep linking to specific app routes
  void _handleDeepLink(String target, String id) {
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      LogService.w('GoRouter not found in context', tag: 'NotificationHandler');
      return;
    }

    if (!DeepLinkValidator.isNotificationTargetAllowed(target)) {
      DeepLinkValidator.logBlockedNotificationPayload(
        'Unknown deep link target (handler guard)',
      );
      router.go('/');
      return;
    }

    if (DeepLinkValidator.notificationTargetRequiresId(target) &&
        !DeepLinkValidator.isValidRouteSegmentId(id)) {
      DeepLinkValidator.logBlockedNotificationPayload(
        'Malformed deep link id (handler guard)',
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
      case 'announcement_detail':
      case 'announcement':
        router.go('/announcements/$id');
        break;
      case 'campaign_detail':
      case 'campaign':
        router.go('/campaigns/$id');
        break;
      case 'gastronomy_detail':
      case 'gastronomy':
        router.go('/gastronomy/$id');
        break;
      case 'recipe_detail':
      case 'recipe':
        router.go('/recipes/$id');
        break;
      case 'map':
        router.go('/map');
        break;
      default:
        LogService.w('Unknown deep link target: $target', tag: 'NotificationHandler');
        router.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
