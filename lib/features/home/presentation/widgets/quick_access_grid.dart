
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/scale_tap_wrapper.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/design/design_tokens.dart';
import '../../../../l10n/l10n.dart';

/// Ana sayfa ve çekmece menüde ortak: rota → ikon rengi (Hızlı Erişim görselleriyle uyumlu).
Color quickAccessIconColorForRoute(String route, BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  if (isDark) {
    switch (route) {
      case '/campaigns':
        return AppColors.neonPink;
      case '/places':
        return const Color(0xFF81C784);
      case '/routes':
        return const Color(0xFF69F0AE);
      case '/recipes':
        return AppColors.neonOrange;
      case '/events':
      case '/qr-ar-scanner':
        return const Color(0xFFA5D6A7);
      case '/culture':
        return AppColors.neonPurple;
      default:
        return const Color(0xFFA5D6A7);
    }
  }
  switch (route) {
    case '/campaigns':
      return Colors.pink.shade600;
    case '/places':
      return AppColors.accentMap;
    case '/routes':
    case '/events':
    case '/qr-ar-scanner':
      return AppColors.accentRoutes;
    case '/recipes':
      return AppColors.accentFood;
    case '/culture':
      return AppColors.accentCulture;
    default:
      return Theme.of(context).colorScheme.primary;
  }
}

/// Quick access grid widget for home screen
/// Light Theme: Circular floating white buttons with soft shadows and colorful icons
/// Dark Theme: Glassmorphism effect (semi-transparent dark blur) with bright neon icons
class QuickAccessGrid extends StatelessWidget {
  const QuickAccessGrid({
    super.key,
    required this.items,
  });

  final List<QuickAccessItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: context.l10n.sectionQuickAccess),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: items.map((item) {
            return Expanded(
              child: _QuickAccessButton(item: item),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _QuickAccessButton extends StatefulWidget {
  const _QuickAccessButton({required this.item});

  final QuickAccessItem item;

  @override
  State<_QuickAccessButton> createState() => _QuickAccessButtonState();
}

class _QuickAccessButtonState extends State<_QuickAccessButton> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final item = widget.item;

    final iconColor = quickAccessIconColorForRoute(item.route, context);
    
    return ScaleTapWrapper(
      onTap: () => context.push(item.route),
      scaleEnd: 0.92,
      child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Circular button
            Container(
              width: 64,
              height: 64,
              decoration: isDark
                  ? _buildDarkDecoration(iconColor)
                  : _buildLightDecoration(),
              child: _buildIcon(item.icon, iconColor, isDark),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Label
            Text(
              item.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? Colors.white.withAlpha(220)
                    : Theme.of(context).colorScheme.onSurface,
                letterSpacing: 0.1,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
    );
  }

  BoxDecoration _buildLightDecoration() {
    return BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      boxShadow: AppElevation.floatingButton,
    );
  }

  BoxDecoration _buildDarkDecoration(Color accentColor) {
    return BoxDecoration(
      shape: BoxShape.circle,
      // BackdropFilter yerine solid gradient — aynı glassmorphism hissi, sıfır GPU yükü
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withAlpha(20),
          Colors.white.withAlpha(8),
        ],
      ),
      border: Border.all(
        color: Colors.white.withAlpha(20),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: accentColor.withAlpha(15),
          blurRadius: 6,
          spreadRadius: 0,
        ),
      ],
    );
  }

  Widget _buildIcon(IconData icon, Color color, bool isDark) {
    return Center(
      child: Icon(
        icon,
        color: color,
        size: 28,
        shadows: isDark
            ? [
                Shadow(
                  color: color.withAlpha(40),
                  blurRadius: 4,
                ),
              ]
            : null,
      ),
    );
  }

}

/// Quick access item model
class QuickAccessItem {
  const QuickAccessItem({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;
}
