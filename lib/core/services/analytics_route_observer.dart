import 'package:flutter/widgets.dart';

import 'analytics_service.dart';

/// GoRouter `observers` listesine bağlanır; sayfa push/replace olduğunda
/// `screen_view` olayını [AnalyticsService] üzerinden raporlar.
///
/// Route'un `name` alanı `screen_name` olarak gönderilir. İsmi olmayan
/// (anonim modal vb.) route'lar atlanır.
class AnalyticsRouteObserver extends NavigatorObserver {
  AnalyticsRouteObserver(this._analytics);

  final AnalyticsService _analytics;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _record(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) _record(newRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  void _record(Route<dynamic> route) {
    final name = route.settings.name;
    if (name == null || name.isEmpty) return;
    _analytics.screenView(name);
  }
}
