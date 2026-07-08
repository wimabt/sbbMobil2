import 'package:flutter/material.dart';
import '../../../../core/design/design_tokens.dart';

/// Gamification card widget for home screen
/// Light Theme: Soft blue gradient banner showing user points
/// Dark Theme: Glowing, vibrant neon-blue card with glow effects
class PointsCard extends StatelessWidget {
  const PointsCard({
    super.key,
    required this.points,
    this.myQrLabel,
    this.onMyQrPressed,
  });

  final String points;

  /// Sağ üst rozet metni (ör. l10n.titleQrCode). [onMyQrPressed] ile birlikte verilirse gösterilir.
  final String? myQrLabel;
  final VoidCallback? onMyQrPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        gradient: isDark ? AppGradients.darkNeonGradient : AppGradients.lightBlueGradient,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: isDark
            ? AppDarkEffects.neonGlow(AppColors.brandGreenBright)
            : AppElevation.level3,
      ),
      child: Stack(
        children: [
          // Decorative background elements
          _buildBackgroundDecoration(isDark),
          
          // Main content
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                _buildIconContainer(context, isDark),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _buildPointsInfo(context, isDark)),
                if (onMyQrPressed != null &&
                    myQrLabel != null &&
                    myQrLabel!.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.sm),
                  _buildMyQrChip(context, isDark),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundDecoration(bool isDark) {
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Stack(
          children: [
            // Top-right decorative circle
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(isDark ? 15 : 20),
                ),
              ),
            ),
            // Bottom-left decorative circle
            Positioned(
              bottom: -40,
              left: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(isDark ? 10 : 15),
                ),
              ),
            ),
            // Subtle grid pattern overlay
            if (isDark)
              Positioned.fill(
                child: CustomPaint(
                  painter: _gridPatternPainter,
                  isComplex: true,
                  willChange: false,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconContainer(BuildContext context, bool isDark) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(isDark ? 25 : 40),
        shape: BoxShape.circle,
        border: isDark
            ? Border.all(
                color: Colors.white.withAlpha(30),
                width: 1,
              )
            : null,
      ),
      child: Center(
        child: Icon(
          Icons.emoji_events_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }

  Widget _buildPointsInfo(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Toplam Puanınız',
          style: TextStyle(
            color: Colors.white.withAlpha(200),
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              points,
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                height: 1,
                shadows: isDark
                    ? [
                        Shadow(
                          color: AppColors.brandGreenBright.withAlpha(30),
                          blurRadius: 4,
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'puan',
              style: TextStyle(
                color: Colors.white.withAlpha(180),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Eski «Seviye» rozetinin cam/flu şeffaf stiliyle uyumlu, kompakt QR tetikleyici.
  Widget _buildMyQrChip(BuildContext context, bool isDark) {
    final onTap = onMyQrPressed!;
    final label = myQrLabel!;

    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(isDark ? 20 : 35),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: Colors.white.withAlpha(isDark ? 30 : 50),
              width: 1,
            ),
            boxShadow: isDark
                ? [
                    BoxShadow(
                      color: AppColors.brandGreenBright.withAlpha(15),
                      blurRadius: 4,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.qr_code_2_rounded,
                color: isDark ? const Color(0xFFA5D6A7) : Colors.white,
                size: 16,
              ),
              const SizedBox(width: AppSpacing.xs),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 88),
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 0.15,
                    height: 1.15,
                    shadows: isDark
                        ? [
                            Shadow(
                              color: const Color(0xFFA5D6A7).withAlpha(25),
                              blurRadius: 3,
                            ),
                          ]
                        : null,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Singleton instance — her build'de yeni nesne oluşturmayı engeller
const _gridPatternPainter = _GridPatternPainter();

/// Custom painter for subtle grid pattern in dark mode
class _GridPatternPainter extends CustomPainter {
  const _GridPatternPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(5)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const spacing = 20.0;
    
    // Horizontal lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    
    // Vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
