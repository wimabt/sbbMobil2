import '../services/log_service.dart';

/// Whitelist + strict ID checks for push / geofence payloads and public path segments (P3-1).
abstract final class DeepLinkValidator {
  DeepLinkValidator._();

  static const int maxRouteIdLength = 128;

  /// Safe for URL path segments and API id parameters: no slashes, query chars, or traversal.
  /// Allows CMS numeric ids, slugs, and hyphenated UUIDs.
  static final RegExp safeRouteId = RegExp(r'^[a-zA-Z0-9_-]+$');

  /// OneSignal / notification [target] values handled by [NotificationHandler].
  static const Set<String> notificationTargets = {
    'district_detail',
    'district',
    'place_detail',
    'place',
    'route_detail',
    'route',
    'event_detail',
    'event',
    'announcement_detail',
    'announcement',
    'campaign_detail',
    'campaign',
    'gastronomy_detail',
    'gastronomy',
    'recipe_detail',
    'recipe',
    'map',
  };

  /// Geofence dialog → navigation (subset).
  static const Set<String> geofenceTargets = {
    'district_detail',
    'district',
    'place_detail',
    'place',
    'route_detail',
    'route',
    'event_detail',
    'event',
  };

  static const Set<String> _shellRoutesWithDetailId = {
    'places',
    'routes',
    'events',
    'announcements',
    'campaigns',
    'recipes',
  };

  static bool isValidRouteSegmentId(String id) =>
      id.isNotEmpty && id.length <= maxRouteIdLength && safeRouteId.hasMatch(id);

  static bool isNotificationTargetAllowed(String target) =>
      notificationTargets.contains(target);

  static bool isGeofenceTargetAllowed(String target) =>
      geofenceTargets.contains(target);

  static bool notificationTargetRequiresId(String target) => target != 'map';

  /// If navigation should be aborted, returns `'/'`. Otherwise null.
  static String? redirectIfInvalidPublicDeepLink(Uri uri) {
    final segs = uri.pathSegments;
    if (segs.length == 2 && segs[0] == 'gastronomy') {
      if (!isValidRouteSegmentId(segs[1])) {
        LogService.w(
          'Blocked malformed deep link path: ${uri.path}',
          tag: 'DeepLink',
        );
        return '/';
      }
      return null;
    }
    if (segs.length == 2 && _shellRoutesWithDetailId.contains(segs[0])) {
      if (!isValidRouteSegmentId(segs[1])) {
        LogService.w(
          'Blocked malformed deep link path: ${uri.path}',
          tag: 'DeepLink',
        );
        return '/';
      }
    }
    return null;
  }

  static void logBlockedNotificationPayload(String reason) {
    LogService.w(reason, tag: 'DeepLink');
  }
}
