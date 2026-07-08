import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/design/design_tokens.dart';
import '../../../l10n/l10n.dart';
import 'providers/user_activity_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'widgets/completed_routes_section.dart';
import 'widgets/login_screen.dart';
import 'widgets/profile_header.dart';
import 'widgets/stats_row.dart';
import 'widgets/profile_quick_links.dart';
import 'widgets/profile_preferences.dart';
import 'widgets/user_info_card.dart';
import 'widgets/user_qr_modal.dart';
import '../../home/presentation/providers/points_provider.dart';
import 'providers/completed_routes_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _staffTapCount = 0;
  DateTime? _lastStaffTapAt;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoggedIn = authState.status == AuthStatus.authenticated;
    final user = authState.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Points/gamification feature flag — provider'a hiç bakma (HTTP atılmaz).
    final pointsAsync = FeatureFlags.pointsEnabled
        ? ref.watch(pointsBalanceProvider)
        : null;
    final completedRoutesAsync = ref.watch(completedRoutesProvider);
    
    if (!isLoggedIn) {
      // Profil sekmesine gelen ama giriş yapmamış kullanıcılar için
      // giriş / kayıt seçim ekranını göster.
      return const LoginScreen();
    }

    final displayName = _buildDisplayName(context, user);
    final userId = user?.id ?? 'USR';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileHeader(
                onSettingsPressed: () => context.push('/settings'),
              ),

              // ── Premium Digital Loyalty Card (User Info + QR Trigger) ──
              // QR ikonu sadece puan/ödeme sistemi açıkken görünür çünkü
              // bu QR satın alma sırasında okutulup puan biriktirmek/harcamak
              // için kullanılıyor. pointsEnabled=false iken kullanılamaz.
              UserInfoCard(
                name: displayName,
                subtitle: user?.maskedPhone ?? '',
                memberSince: user?.createdAt != null
                    ? '${user!.createdAt!.day}.${user.createdAt!.month}.${user.createdAt!.year}'
                    : '-',
                avatarInitials: _buildAvatarInitials(context, user),
                // E-posta varsa doğrulama durumunu kartta göster (doğrulandı /
                // doğrulanmadı). E-posta yoksa çip gizli. Dokununca Hesap
                // Bilgileri'ne (doğrulama/yönetim) götür.
                emailVerified:
                    (user != null && (user.email?.trim().isNotEmpty ?? false))
                        ? user.emailVerified
                        : null,
                onVerifyEmailPressed: () => context.push('/account'),
                onQrPressed: FeatureFlags.pointsEnabled
                    ? () {
                        UserQrModal.show(
                          context,
                          userId: userId,
                          userName: displayName,
                        );
                      }
                    : null,
              ),

              // ── Stats Grid (pulled up, standard spacing) ──
              const SizedBox(height: 24),
              // Points flag açıkken: backend balance'ından beslenir.
              // Kapalıyken: local activity tracker (cihazda) sayar.
              // Puan kartı zaten StatsRow içinde flag ile gizleniyor;
              // ziyaret/rota sayıları her durumda anlamlı kalsın.
              _buildStatsRow(ref, pointsAsync),

              // ── Completed Routes Section ──
              completedRoutesAsync.when(
                data: (routes) => routes.isNotEmpty
                    ? CompletedRoutesSection(
                        routes: routes,
                        onRouteTap: (route) {
                          context.push('/routes/${route.navigationId}');
                        },
                      )
                    : const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),

              // ── İçeriklerim kısayolları ──
              // Hesap yönetimi / dil / bildirim / yasal / hesap silme gibi
              // *seyrek* tercihler sağ üst dişli → /settings'te. Profilde
              // kullanıcıya ait içerik kısayolları + sık kullanılan tema/çıkış.
              const ProfileQuickLinks(),

              // ── Tema + Çıkış Yap (sık kullanılan tercihler) ──
              const ProfilePreferences(),
              if (kDebugMode && FeatureFlags.pointsEnabled) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/debug/points'),
                    icon: const Icon(Icons.science_outlined, size: 20),
                    label: const Text('Puan Test Paneli (Yerler)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: BorderSide(color: Colors.orange.withAlpha(60)),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 4.0,
                  ),
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/debug/route-stops'),
                    icon: const Icon(Icons.alt_route, size: 20),
                    label: const Text('Rota Durak Test Paneli'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: BorderSide(color: Colors.blue.withAlpha(60)),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],

              // Hidden staff entry point:
              // 7 quick taps on this invisible area opens staff login.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _handleStaffSecretTap(context),
                child: const SizedBox(height: 22),
              ),

              // Bottom padding for navbar
              SizedBox(height: AppNavBar.bottomPadding),
            ],
          ),
        ),
      ),
    );
  }

  String _buildDisplayName(BuildContext context, AuthUser? user) {
    if (user == null) return context.l10n.profileRegisteredUser;
    final parts = [
      user.firstName?.trim() ?? '',
      user.lastName?.trim() ?? '',
    ].where((e) => e.isNotEmpty).toList();
    if (parts.isNotEmpty) {
      return parts.join(' ');
    }
    return context.l10n.profileRegisteredUser;
  }

  /// Stats row builder — points flag durumuna göre veri kaynağı seçer.
  ///
  /// **Points OFF (default):** Local activity tracker'dan visited/completed
  /// sayıları gösterilir. Puan kartı StatsRow içinde zaten gizli.
  ///
  /// **Points ON:** Backend balance'ından beslenir. Local sayaç fallback
  /// olarak çalışmaya devam eder (kullanıcı offline iken yine de görür).
  Widget _buildStatsRow(WidgetRef ref, AsyncValue<dynamic>? pointsAsync) {
    // Ziyaret + Rota sayaçları artık backend kaynaklı, kullanıcıya bağlı
    // (userActivityProvider). Points flag'inden bağımsız çalışır → hesap
    // değiştiğinde doğru kullanıcının verisi gelir.
    final activity = ref.watch(userActivityProvider);
    final visits = activity.visitedCount.toString();
    final routes = activity.completedRoutesCount.toString();

    if (!FeatureFlags.pointsEnabled || pointsAsync == null) {
      return StatsRow(points: '0', visits: visits, routes: routes);
    }

    // Puan kartı backend balance'ından; ziyaret/rota userActivity'den.
    return pointsAsync.when(
      data: (balance) => StatsRow(
        points: (balance?.totalPoints ?? 0).toString(),
        visits: visits,
        routes: routes,
      ),
      loading: () => StatsRow(points: '0', visits: visits, routes: routes),
      error: (_, _) => StatsRow(points: '0', visits: visits, routes: routes),
    );
  }

  String _buildAvatarInitials(BuildContext context, AuthUser? user) {
    if (user == null) return 'K';
    final name = _buildDisplayName(context, user);
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return (words[0].characters.first + words[1].characters.first)
          .toUpperCase();
    }
    return name.characters.take(2).toString().toUpperCase();
  }

  Future<void> _handleStaffSecretTap(BuildContext context) async {
    final now = DateTime.now();
    final last = _lastStaffTapAt;
    _lastStaffTapAt = now;

    // Reset if taps are not within a short window
    if (last == null || now.difference(last) > const Duration(seconds: 2)) {
      _staffTapCount = 1;
    } else {
      _staffTapCount += 1;
    }

    if (_staffTapCount < 7) return;
    _staffTapCount = 0;

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ctx.l10n.staffPanelTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  ctx.l10n.staffLoginPrompt,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      context.push('/staff/login');
                    },
                    child: Text(ctx.l10n.staffLoginTitle),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(ctx.l10n.btnGiveUp),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

const StatsRow constStatsRowPlaceholder = StatsRow(
  points: '-',
  visits: '-',
  routes: '-',
);
