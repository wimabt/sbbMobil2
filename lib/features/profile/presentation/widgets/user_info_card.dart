import 'package:flutter/material.dart';
import '../../../../core/design/design_tokens.dart';
import '../../../../l10n/l10n.dart';

/// Premium Digital Loyalty Card — replaces old UserInfoCard.
///
/// Merges user info + QR trigger into a single credit-card style widget
/// with an elegant gradient background, rounded corners, and a sleek
/// integrated QR icon button on the right side.
class UserInfoCard extends StatelessWidget {
  const UserInfoCard({
    super.key,
    required this.name,
    required this.subtitle,
    required this.memberSince,
    this.avatarInitials,
    this.onQrPressed,
    this.emailVerified,
    this.onVerifyEmailPressed,
  });

  final String name;

  /// Masked phone number
  final String subtitle;
  final String memberSince;
  final String? avatarInitials;

  /// Callback when the integrated QR trigger button is tapped.
  final VoidCallback? onQrPressed;

  /// E-posta doğrulama durumu çipi:
  ///   null  → e-posta yok, çip gösterilmez
  ///   true  → "Doğrulandı" (yeşil)
  ///   false → "E-posta doğrulanmadı" (turuncu)
  final bool? emailVerified;

  /// Çipe dokununca (genelde Hesap Bilgileri'ne yönlendirme).
  final VoidCallback? onVerifyEmailPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;
    final initials = avatarInitials ??
        name
            .split(' ')
            .map((n) => n.isNotEmpty ? n[0] : '')
            .take(2)
            .join()
            .toUpperCase();

    // ── Kart yüzeyi: koyu temada app genel gri yüzeyleri (lacivert gradient yok) ──
    final gradientColors = isDark
        ? const [AppColors.darkSurfaceElevated, AppColors.darkSurface]
        : const [Color(0xFFFFFFFF), Color(0xFFF2F5F9)];

    // ── Dekoratif daireler (koyu: hafif primary parıltı; açık: primary) ──
    final shimmerColor = isDark
        ? cs.primary.withAlpha(18)
        : cs.primary.withAlpha(22);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(20),
          border: isDark
              ? AppDarkEffects.subtleBorder(context)
              : Border.all(
                  color: cs.outline.withAlpha(35),
                  width: 1,
                ),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha(110),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ]
              : AppElevation.level2,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // ── Decorative background circles ──
              Positioned(
                top: -30,
                right: -20,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: shimmerColor,
                  ),
                ),
              ),
              Positioned(
                bottom: -40,
                left: -30,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: shimmerColor,
                  ),
                ),
              ),
              // ── Subtle top-left accent line ──
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        cs.primary.withAlpha(0),
                        cs.primary.withAlpha(isDark ? 28 : 40),
                        cs.primary.withAlpha(0),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Main content ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 16, 22),
                child: Row(
                  children: [
                    // ── Avatar ──
                    _buildAvatar(context, initials, isDark),
                    const SizedBox(width: 16),

                    // ── Info column ──
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: isDark
                                    ? cs.onSurfaceVariant
                                    : theme.hintColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 11,
                                color: isDark
                                    ? cs.onSurfaceVariant
                                    : theme.hintColor.withAlpha(200),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                context.l10n.lblMemberSince(memberSince),
                                style: TextStyle(
                                  color: isDark
                                      ? cs.onSurfaceVariant
                                      : theme.hintColor.withAlpha(220),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                          if (emailVerified != null) ...[
                            const SizedBox(height: 8),
                            _EmailStatusChip(
                              verified: emailVerified!,
                              onTap: onVerifyEmailPressed,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // ── QR Trigger Button ──
                    if (onQrPressed != null) ...[
                      const SizedBox(width: 8),
                      _buildQrButton(context, isDark),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Avatar — koyu temada beyaz tonları; açık temada yüzey rengi + koyu yazı.
  Widget _buildAvatar(BuildContext context, String initials, bool isDark) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark
            ? AppColors.darkBackground.withAlpha(220)
            : cs.surfaceContainerHighest.withAlpha(220),
        border: Border.all(
          color: isDark
              ? Colors.white.withAlpha(22)
              : cs.outline.withAlpha(60),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: isDark ? cs.onSurface : cs.primary,
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  /// QR — koyu temada cam efekti; açık temada hafif yüzey + primary ikon.
  Widget _buildQrButton(BuildContext context, bool isDark) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onQrPressed,
        borderRadius: BorderRadius.circular(14),
        splashColor:
            isDark ? Colors.white.withAlpha(24) : cs.primary.withAlpha(40),
        highlightColor:
            isDark ? Colors.white.withAlpha(12) : cs.primary.withAlpha(18),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkBackground.withAlpha(200)
                : cs.surfaceContainerHigh.withAlpha(230),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withAlpha(18)
                  : cs.outline.withAlpha(70),
              width: 1,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.qr_code_2_rounded,
              color: cs.primary,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}

/// Profil kartında e-posta doğrulama durumunu gösteren küçük çip.
///   verified=true  → yeşil "Doğrulandı" (bilgi)
///   verified=false → turuncu "E-posta doğrulanmadı" (eylem gerektirir, chevron'lu)
/// Dokununca [onTap] (genelde Hesap Bilgileri ekranına yönlendirir).
class _EmailStatusChip extends StatelessWidget {
  const _EmailStatusChip({required this.verified, this.onTap});

  final bool verified;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = verified
        ? (isDark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32)) // yeşil
        : (isDark ? const Color(0xFFFFB74D) : const Color(0xFFE08600)); // turuncu
    final label = verified
        ? context.l10n.accountEmailVerified
        : context.l10n.profileEmailNotVerified;
    final icon = verified
        ? Icons.verified_rounded
        : Icons.error_outline_rounded;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withAlpha(isDark ? 36 : 28),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: color.withAlpha(110), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              // Doğrulanmamışta eyleme yönlendiren chevron; doğrulanmışta gizli.
              if (!verified && onTap != null) ...[
                const SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded, size: 14, color: color),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
