import 'package:flutter/material.dart';
import '../../../../core/design/design_tokens.dart';

/// Pixel-perfect cluster marker widget that displays a count of grouped locations.
/// 
/// **Specifications:**
/// - Shape: Perfect Circle
/// - Size: EXACTLY 40 logical pixels (dp)
/// - Background: Smart Ocean Blue (#00B0FF) or Blue 500 in light mode
/// - Border: 3px solid White or dark grey in dark mode
/// - Shadow: Soft BoxShadow for depth
/// - Text: Contrasting color, Font Size 13.0, FontWeight.w700
class ClusterMarker extends StatelessWidget {
  const ClusterMarker({
    super.key,
    required this.count,
    this.isDark = false,
  });

  /// Number of items in the cluster
  final int count;

  /// Whether dark mode is enabled
  final bool isDark;

  // ===== FIXED SIZE CONSTANTS =====
  /// Circle diameter (logical pixels)
  static const double circleSize = 40.0;
  
  /// Border width
  static const double borderWidth = 3.0;
  
  /// Bitmap capture size (circle + shadow padding)
  static const double bitmapSize = 48.0;

  @override
  Widget build(BuildContext context) {
    // Determine the display text (show "99+" for large clusters)
    final displayText = count > 99 ? '99+' : count.toString();
    
    // Marka yeşili — light ve dark her ikisinde tutarlı.
    // Eski mavi (#2196F3 / neonBlue) marka rengiyle uyumsuzdu.
    final backgroundColor = isDark
        ? AppColors.brandGreenBright
        : AppColors.brandGreen;
    final borderColor = isDark ? const Color(0xFF3A3A3A) : Colors.white;
    final textColor = Colors.white;
    
    // Fixed size container prevents squashing
    return SizedBox(
      width: bitmapSize,
      height: bitmapSize,
      child: Center(
        child: Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: backgroundColor,
            border: Border.all(
              color: borderColor,
              width: borderWidth,
            ),
            boxShadow: [
              // Main shadow
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 127 : 51), // 0.5 / 0.2
                blurRadius: 8.0,
                offset: const Offset(0, 3),
                spreadRadius: 0,
              ),
              // Subtle glow
              if (isDark)
                BoxShadow(
                  color: AppColors.neonBlue.withAlpha(76), // 0.3
                  blurRadius: 6.0,
                  offset: Offset.zero,
                  spreadRadius: 0,
                ),
            ],
          ),
          child: Center(
            child: Text(
              displayText,
              style: TextStyle(
                color: textColor,
                fontSize: 13.0,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
