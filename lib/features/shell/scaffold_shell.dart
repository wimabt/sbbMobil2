import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/design/design_tokens.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/offline_banner.dart';
import '../../l10n/l10n.dart';

class ScaffoldShell extends StatelessWidget {
  const ScaffoldShell({super.key, required this.child});

  final Widget child;

  // Left side nav items - now uses BuildContext for localization
  static List<_NavItem> _getLeftTabs(BuildContext context) => [
    _NavItem(
      label: context.l10n.navHome,
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      route: '/',
    ),
    _NavItem(
      label: context.l10n.navPlaces,
      icon: Icons.place_outlined,
      activeIcon: Icons.place,
      route: '/places',
    ),
  ];

  // Right side nav items
  static List<_NavItem> _getRightTabs(BuildContext context) => [
    _NavItem(
      label: context.l10n.navAnnouncements,
      icon: Icons.notifications_outlined,
      activeIcon: Icons.notifications,
      route: '/announcements',
    ),
    _NavItem(
      label: context.l10n.navProfile,
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      route: '/profile',
    ),
  ];

  // Map route (center FAB)
  static const _mapRoute = '/map';

  // All valid routes for navigation
  static const _validRoutes = [
    '/',
    '/places',
    '/announcements',
    '/profile',
    '/map',
  ];

  String? _activeRoute(String location) {
    // Check each valid route
    for (final route in _validRoutes) {
      if (route == '/' && location == '/') {
        return route;
      } else if (route != '/' &&
          (location == route || location.startsWith('$route/'))) {
        return route;
      }
    }
    // Default to home for root path
    if (location == '/') return '/';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Sorgu dizesi (?category=...) sekmeyi bozmasın diye path kullan
    final location = GoRouterState.of(context).uri.path;
    final activeRoute = _activeRoute(location);
    final isMapActive = activeRoute == _mapRoute;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Get localized nav items
    final leftTabs = _getLeftTabs(context);
    final rightTabs = _getRightTabs(context);

    // Compact mode for map screen
    final fabSize = isMapActive ? AppNavBar.compactFabSize : AppNavBar.fabSize;
    final navBarHeight = isMapActive
        ? AppNavBar.compactHeight
        : AppNavBar.height;
    final iconSize = isMapActive ? 20.0 : 28.0;
    final notchMargin = isMapActive ? 6.0 : 10.0;

    // NOT: Sistem geri politikası (sekmede geri → ana sayfa) burada DEĞİL,
    // app_router'daki PopOrHomeScope sarmalayıcılarında uygulanır. Shell
    // seviyesindeki PopScope, Android predictive back'in "framework geri
    // işleyebilir mi?" kararına katılamadığı için çalışmaz.
    return Scaffold(
      resizeToAvoidBottomInset:
          false, // Klavye açıldığında harita butonunun sabit kalması için
      extendBodyBehindAppBar:
          true, // Body'yi AppBar arkasına uzat (OS bar değişimleri top padding'i etkilemesin)
      body: Column(
        children: [
          // Çevrimdışı uyarı bandı — bağlantı kesilince animasyonlu kayar
          const OfflineBanner(),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: child,
              ),
            ),
          ),
        ],
      ),
      extendBody: true,
      floatingActionButton: Container(
        height: fabSize,
        width: fabSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isMapActive
                ? [colorScheme.primary, colorScheme.primaryContainer]
                : [
                    colorScheme.primary.withValues(alpha: 0.9),
                    colorScheme.secondary.withValues(alpha: 0.9),
                  ],
          ),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: FloatingActionButton(
          onPressed: () => context.go(_mapRoute),
          elevation: 0,
          backgroundColor: Colors.transparent,
          shape: const CircleBorder(),
          child: Icon(
            isMapActive ? Icons.map : Icons.map_outlined,
            color: Colors.white,
            size: iconSize,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: notchMargin,
        elevation: 8,
        color: isDark ? colorScheme.surfaceContainer : colorScheme.surface,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        padding: EdgeInsets.zero,
        height: navBarHeight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Left side icons
            ...leftTabs.map(
              (item) => _NavButton(
                item: item,
                isActive: activeRoute == item.route,
                isCompact: isMapActive,
                onTap: () {
                  Haptics.light();
                  context.go(item.route);
                },
              ),
            ),

            // Spacing for the FAB
            SizedBox(width: fabSize),

            // Right side icons
            ...rightTabs.map(
              (item) => _NavButton(
                item: item,
                isActive: activeRoute == item.route,
                isCompact: isMapActive,
                onTap: () {
                  Haptics.light();
                  context.go(item.route);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.isActive,
    required this.onTap,
    this.isCompact = false,
  });

  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = colorScheme.primary;
    final inactiveColor = Theme.of(context).hintColor;

    final height = isCompact ? AppNavBar.compactHeight : AppNavBar.height;
    final iconSize = isCompact ? 20.0 : 24.0;
    final padding = isCompact
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 2)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 4);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: SizedBox(
          height: height,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: padding,
                decoration: BoxDecoration(
                  color: isActive
                      ? activeColor.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isActive ? item.activeIcon : item.icon,
                  color: isActive ? activeColor : inactiveColor,
                  size: iconSize,
                ),
              ),
              // Hide labels in compact mode
              if (!isCompact) ...[
                const SizedBox(height: 2),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    color: isActive ? activeColor : inactiveColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;
}
