import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/design/design_tokens.dart';
import '../../../l10n/l10n.dart';
import '../../../core/services/analytics_events.dart';
import '../../../core/services/analytics_service.dart';
import 'providers/onboarding_provider.dart';

// ═══════════════════════════════════════════════════════════════════════
// Onboarding paleti — uygulamanın açık yeşil marka tonlarıyla uyumlu.
// Tüm slaytlarda mavi/mor neon yerine bu yeşil aksan kullanılır.
// ═══════════════════════════════════════════════════════════════════════

/// Ana yeşil aksan (ikon, halka, chip, indikatör) — her iki temada da aynı.
const Color _onbGreen = AppColors.brandGreenBright; // 0xFF2E8B57 (deniz yeşili)

/// İkincil yeşil — degrade ve ufak vurgular için.
const Color _onbGreenDeep = AppColors.brandGreenMid; // 0xFF0D6E3F

/// Hero daire / kart görseli için yumuşak yeşil degrade.
List<Color> _onbCircleGradient(bool isDark) => isDark
    ? [_onbGreen.withAlpha(64), _onbGreenDeep.withAlpha(64)]
    : [_onbGreen.withAlpha(46), AppColors.brandGreenTint];

/// Şartname §6.3.5 — İlk açılış / onboarding ekranı.
///
/// 7 slayt ile uygulamanın tüm temel yetenekleri tanıtılır:
///   1. Hoş geldiniz
///   2. Gezinme & menü (alt çubuk + harita + sol ☰ menü/tema + asistan)
///   3. Keşfet & ara (yakındakiler, öneriler, arama, gezi planı)
///   4. Kaydet, topla & tamamla (favori, yer/rota tamamlama, puan)
///   5. Harita & yol tarifi (noktalar, ısı haritası, navigasyon)
///   6. QR, AR & asistan
///   7. İsteğe bağlı ilgi alanı seçimi
///
/// Görsel slaytlarda gerçek UI öğelerinin **stilize replikaları** (alt
/// navigasyon, içerik kartı, QR/AR butonları) pulse'lı highlight ring ile
/// vurgulanır; her slaytta somut özellik maddeleri ([_Bullet]) listelenir.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  static const _totalPages = 7; // welcome + 5 feature + interests

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _index == _totalPages - 1;

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _skip() {
    _controller.animateToPage(
      _totalPages - 1,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    final notifier = ref.read(onboardingProvider.notifier);
    final interests = ref.read(onboardingProvider).interests;
    await notifier.complete();
    ref.read(analyticsServiceProvider).track(
      AnalyticsEvents.onboardingCompleted,
      properties: {
        'interests': interests.toList(),
        'interests_count': interests.length,
      },
    );
    if (!mounted) return;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!_isLast)
                    TextButton(
                      onPressed: _skip,
                      child: Text(
                        context.l10n.onbSkip,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.hintColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                children: const [
                  _WelcomePage(),
                  _NavigationPage(),
                  _DiscoverPage(),
                  _CollectPage(),
                  _MapPage(),
                  _ScanArPage(),
                  _InterestsPage(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PageIndicator(count: _totalPages, activeIndex: _index),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _isLast ? context.l10n.onboardingStart : context.l10n.onbContinue,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
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

// ═══════════════════════════════════════════════════════════════════════
// Slayt 1 — Welcome
// ═══════════════════════════════════════════════════════════════════════

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _onbCircleGradient(isDark),
              ),
              border: isDark
                  ? Border.all(color: _onbGreen.withAlpha(90))
                  : null,
            ),
            child: const Icon(
              Icons.location_city_rounded,
              size: 64,
              color: _onbGreen,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            context.l10n.onbWelcomeTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.4,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.onbWelcomeDesc,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.hintColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Slayt 2 — Gezinme: alt çubuk + harita FAB + sol menü + asistan
// ═══════════════════════════════════════════════════════════════════════

class _NavigationPage extends StatelessWidget {
  const _NavigationPage();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _FeaturePage(
      title: l.onbNavTitle,
      description: l.onbNavDesc,
      mockup: const _MockNavBar(),
      bullets: [
        _Bullet(Icons.home_rounded, l.onbNavBullet1Title, l.onbNavBullet1Desc),
        _Bullet(Icons.map_rounded, l.onbNavBullet2Title, l.onbNavBullet2Desc),
        _Bullet(Icons.menu_rounded, l.onbNavBullet3Title, l.onbNavBullet3Desc),
        _Bullet(Icons.smart_toy_rounded, l.onbNavBullet4Title, l.onbNavBullet4Desc),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Slayt 3 — Keşfet, ara ve planla
// ═══════════════════════════════════════════════════════════════════════

class _DiscoverPage extends StatelessWidget {
  const _DiscoverPage();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _FeaturePage(
      title: l.onbDiscoverTitle,
      description: l.onbDiscoverDesc,
      heroIcon: Icons.explore_rounded,
      bullets: [
        _Bullet(Icons.near_me_rounded, l.onbDiscoverBullet1Title, l.onbDiscoverBullet1Desc),
        _Bullet(Icons.auto_awesome_rounded, l.onbDiscoverBullet2Title, l.onbDiscoverBullet2Desc),
        _Bullet(Icons.search_rounded, l.onbDiscoverBullet3Title, l.onbDiscoverBullet3Desc),
        _Bullet(Icons.route_rounded, l.onbDiscoverBullet4Title, l.onbDiscoverBullet4Desc),
      ],
    );
  }
}

class _MockNavBar extends StatelessWidget {
  const _MockNavBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;

    return SizedBox(
      height: 110,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            height: 76,
            decoration: BoxDecoration(
              color: isDark ? cs.surfaceContainer : cs.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppElevation.level2,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MockNavIcon(icon: Icons.home, label: context.l10n.navHome, active: true),
                _MockNavIcon(icon: Icons.place_outlined, label: context.l10n.navPlaces),
                const SizedBox(width: 64),
                _MockNavIcon(
                    icon: Icons.notifications_outlined, label: context.l10n.navAnnouncements),
                _MockNavIcon(icon: Icons.person_outline, label: context.l10n.navProfile),
              ],
            ),
          ),
          // Highlighted FAB
          Positioned(
            bottom: 38,
            child: _PulseRing(
              color: _onbGreen,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_onbGreen, _onbGreenDeep],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _onbGreen.withAlpha(90),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.map, color: Colors.white, size: 30),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MockNavIcon extends StatelessWidget {
  const _MockNavIcon({
    required this.icon,
    required this.label,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = active ? _onbGreen : theme.hintColor;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Slayt 4 — Yer kartı mockup'ı + favori & puan rozet highlight
// ═══════════════════════════════════════════════════════════════════════

class _CollectPage extends StatelessWidget {
  const _CollectPage();

  @override
  Widget build(BuildContext context) {
    // Puan / gamification açıkken topla & tamamla anlatılır.
    final l = context.l10n;
    if (FeatureFlags.pointsEnabled) {
      return _FeaturePage(
        title: l.onbRewardsTitle,
        description: l.onbRewardsDesc,
        mockup: const _MockPlaceCard(),
        bullets: [
          _Bullet(Icons.favorite_rounded, l.onbRewardsBullet1Title, l.onbRewardsBullet1Desc),
          _Bullet(Icons.check_circle_rounded, l.onbRewardsBullet2Title, l.onbRewardsBullet2Desc),
          _Bullet(Icons.stars_rounded, l.onbRewardsBullet3Title, l.onbRewardsBullet3Desc),
          _Bullet(Icons.calendar_today_rounded, l.onbRewardsBullet4Title, l.onbRewardsBullet4Desc),
        ],
      );
    }
    // Puanlar kapalı — favori odaklı sürüm (puan/günlük giriş gösterilmez).
    return _FeaturePage(
      title: l.onbSaveTitle,
      description: l.onbSaveDesc,
      mockup: const _MockPlaceCard(),
      bullets: [
        _Bullet(Icons.favorite_rounded, l.onbSaveBullet1Title, l.onbSaveBullet1Desc),
        _Bullet(Icons.collections_bookmark_rounded, l.onbSaveBullet2Title, l.onbSaveBullet2Desc),
        _Bullet(Icons.bolt_rounded, l.onbSaveBullet3Title, l.onbSaveBullet3Desc),
      ],
    );
  }
}

class _MockPlaceCard extends StatelessWidget {
  const _MockPlaceCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      height: 130,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: Colors.white.withAlpha(15)) : null,
        boxShadow: isDark ? null : AppElevation.level2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Görsel placeholder + favori vurgusu
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _onbCircleGradient(isDark),
                    ),
                  ),
                  child: const Icon(
                    Icons.place_rounded,
                    size: 36,
                    color: _onbGreen,
                  ),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: _PulseRing(
                  color: isDark ? AppColors.neonPink : cs.error,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? AppColors.darkSurface.withAlpha(230)
                          : Colors.white.withAlpha(230),
                    ),
                    child: Icon(
                      Icons.favorite,
                      size: 18,
                      color: isDark ? AppColors.neonPink : cs.error,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amisos Tepesi',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : null,
                    ),
                  ),
                  Text(
                    'Şehir manzaralı tarihi gözetleme noktası.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          isDark ? Colors.white.withAlpha(180) : theme.hintColor,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.near_me_outlined,
                              size: 14, color: _onbGreen),
                          const SizedBox(width: 4),
                          Text('1.2 km',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? Colors.white.withAlpha(150)
                                    : null,
                              )),
                        ],
                      ),
                      // Puan rozeti yalnızca gamification açıkken gösterilir.
                      if (FeatureFlags.pointsEnabled)
                        _PulseRing(
                          color: isDark
                              ? AppColors.neonOrange
                              : AppColors.warningDark,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (isDark
                                      ? AppColors.neonOrange
                                      : AppColors.warningDark)
                                  .withAlpha(isDark ? 30 : 20),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                              border: Border.all(
                                color: (isDark
                                        ? AppColors.neonOrange
                                        : AppColors.warningDark)
                                    .withAlpha(isDark ? 60 : 50),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.stars_rounded,
                                    size: 13,
                                    color: isDark
                                        ? AppColors.neonOrange
                                        : AppColors.warningDark),
                                const SizedBox(width: 4),
                                Text(
                                  '+25',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppColors.neonOrange
                                        : AppColors.warningDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Slayt 5 — Harita & Yol Tarifi
// ═══════════════════════════════════════════════════════════════════════

class _MapPage extends StatelessWidget {
  const _MapPage();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _FeaturePage(
      title: l.onbMapTitle,
      description: l.onbMapDesc,
      heroIcon: Icons.map_rounded,
      bullets: [
        _Bullet(Icons.place_rounded, l.onbMapBullet1Title, l.onbMapBullet1Desc),
        _Bullet(Icons.local_fire_department_rounded, l.onbMapBullet2Title, l.onbMapBullet2Desc),
        _Bullet(Icons.directions_rounded, l.onbMapBullet3Title, l.onbMapBullet3Desc),
        _Bullet(Icons.my_location_rounded, l.onbMapBullet4Title, l.onbMapBullet4Desc),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Slayt 6 — QR, AR ve Asistan
// ═══════════════════════════════════════════════════════════════════════

class _ScanArPage extends StatelessWidget {
  const _ScanArPage();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _FeaturePage(
      title: l.onbScanTitle,
      description: l.onbScanDesc,
      mockup: const _MockScannerCard(),
      bullets: [
        _Bullet(Icons.qr_code_scanner_rounded, l.onbScanBullet1Title, l.onbScanBullet1Desc),
        _Bullet(Icons.view_in_ar_rounded, l.onbScanBullet2Title, l.onbScanBullet2Desc),
        _Bullet(Icons.smart_toy_rounded, l.onbScanBullet3Title, l.onbScanBullet3Desc),
      ],
    );
  }
}

class _MockScannerCard extends StatelessWidget {
  const _MockScannerCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            isDark ? Border.all(color: Colors.white.withAlpha(15)) : null,
        boxShadow: isDark ? null : AppElevation.level2,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Hızlı Tara',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : null,
              ),
            ),
          ),
          _PulseRing(
            color: _onbGreen,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _onbGreen.withAlpha(isDark ? 36 : 28),
              ),
              child: const Icon(
                Icons.qr_code_scanner_rounded,
                color: _onbGreen,
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _onbGreenDeep.withAlpha(isDark ? 36 : 28),
            ),
            child: const Icon(
              Icons.view_in_ar_rounded,
              color: _onbGreenDeep,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Slayt 5 — İlgi alanları
// ═══════════════════════════════════════════════════════════════════════

const List<_Interest> _kInterests = [
  _Interest('historic', Icons.account_balance_rounded),
  _Interest('culture', Icons.theater_comedy_rounded),
  _Interest('nature', Icons.park_rounded),
  _Interest('food', Icons.restaurant_rounded),
  _Interest('events', Icons.event_rounded),
  _Interest('routes', Icons.alt_route_rounded),
  _Interest('ar_qr', Icons.qr_code_scanner_rounded),
  _Interest('recipes', Icons.menu_book_rounded),
];

/// İlgi alanı etiketini aktif dile göre çözer (slug → ARB).
String _interestLabel(AppLocalizations l10n, String slug) {
  switch (slug) {
    case 'historic':
      return l10n.onbInterestHistoric;
    case 'culture':
      return l10n.onbInterestCulture;
    case 'nature':
      return l10n.onbInterestNature;
    case 'food':
      return l10n.onbInterestFood;
    case 'events':
      return l10n.onbInterestEvents;
    case 'routes':
      return l10n.onbInterestRoutes;
    case 'ar_qr':
      return l10n.onbInterestArQr;
    case 'recipes':
      return l10n.onbInterestRecipes;
    default:
      return slug;
  }
}

class _Interest {
  const _Interest(this.slug, this.icon);
  final String slug;
  final IconData icon;
}

class _InterestsPage extends ConsumerWidget {
  const _InterestsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selected =
        ref.watch(onboardingProvider.select((s) => s.interests));
    final notifier = ref.read(onboardingProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.onbInterestsTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.onbInterestsDesc,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.hintColor,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final interest in _kInterests)
                _InterestChip(
                  interest: interest,
                  isSelected: selected.contains(interest.slug),
                  isDark: isDark,
                  onTap: () => notifier.toggleInterest(interest.slug),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InterestChip extends StatelessWidget {
  const _InterestChip({
    required this.interest,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final _Interest interest;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const activeColor = _onbGreen;
    final bg = isSelected
        ? activeColor.withAlpha(isDark ? 40 : 25)
        : (isDark
            ? AppColors.darkSurface
            : theme.colorScheme.surfaceContainerHighest.withAlpha(120));
    final borderColor = isSelected
        ? activeColor.withAlpha(isDark ? 120 : 100)
        : (isDark
            ? Colors.white.withAlpha(15)
            : Colors.black.withAlpha(15));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                interest.icon,
                size: 18,
                color: isSelected ? activeColor : theme.hintColor,
              ),
              const SizedBox(width: 8),
              Text(
                _interestLabel(context.l10n, interest.slug),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? activeColor
                      : (isDark
                          ? Colors.white.withAlpha(220)
                          : theme.colorScheme.onSurface),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Yardımcı bileşenler — mockup düzeni, callout balonu, pulse ring, indicator
// ═══════════════════════════════════════════════════════════════════════

/// Özellik slaytı için ortak iskelet: üstte bir mockup **veya** marka renkli
/// hero ikon, altında başlık + açıklama, ardından somut özellik maddeleri.
///
/// Detaylı tanıtım [bullets] ile sağlanır — her madde ikon + kısa başlık +
/// tek satırlık açıklama içerir. Böylece tek slaytta hem görsel hem de
/// işlevsel ayrıntı verilir, "acemi" hissi yaratmadan kapsamlı tanıtım yapılır.
class _FeaturePage extends StatelessWidget {
  const _FeaturePage({
    required this.title,
    required this.description,
    this.mockup,
    this.heroIcon,
    this.bullets = const [],
  }) : assert(mockup != null || heroIcon != null,
            'Bir mockup veya heroIcon verilmeli');

  final String title;
  final String description;
  final Widget? mockup;
  final IconData? heroIcon;
  final List<_Bullet> bullets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Column(
        children: [
          if (mockup != null)
            mockup!
          else
            _HeroIcon(icon: heroIcon!, isDark: isDark),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.hintColor,
              height: 1.5,
            ),
          ),
          if (bullets.isNotEmpty) ...[
            const SizedBox(height: 24),
            for (final b in bullets)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _FeatureBullet(bullet: b, isDark: isDark),
              ),
          ],
        ],
      ),
    );
  }
}

/// Marka renkli, yuvarlak hero ikon — mockup'ı olmayan slaytlar için.
class _HeroIcon extends StatelessWidget {
  const _HeroIcon({required this.icon, required this.isDark});

  final IconData icon;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _onbCircleGradient(isDark),
        ),
        border: isDark
            ? Border.all(color: _onbGreen.withAlpha(90))
            : null,
      ),
      child: Icon(
        icon,
        size: 48,
        color: _onbGreen,
      ),
    );
  }
}

/// Onboarding özellik maddesi modeli.
class _Bullet {
  const _Bullet(this.icon, this.title, this.subtitle);
  final IconData icon;
  final String title;
  final String subtitle;
}

/// İkon + başlık + açıklama satırı — sola hizalı, kart içermeyen sade düzen.
class _FeatureBullet extends StatelessWidget {
  const _FeatureBullet({required this.bullet, required this.isDark});

  final _Bullet bullet;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const accent = _onbGreen;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: accent.withAlpha(isDark ? 32 : 22),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(bullet.icon, size: 20, color: accent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bullet.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                bullet.subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Vurgulanan UI öğesi etrafına yumuşakça nabız atan halka.
class _PulseRing extends StatefulWidget {
  const _PulseRing({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final scale = 1.0 + 0.35 * t;
        final opacity = (1.0 - t).clamp(0.0, 1.0);
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            IgnorePointer(
              child: Transform.scale(
                scale: scale,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.color.withValues(alpha: opacity * 0.55),
                      width: 3,
                    ),
                  ),
                  width: 56,
                  height: 56,
                ),
              ),
            ),
            child!,
          ],
        );
      },
      child: widget.child,
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.count, required this.activeIndex});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const activeColor = _onbGreen;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == activeIndex ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == activeIndex
                  ? activeColor
                  : theme.hintColor.withAlpha(60),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
      ],
    );
  }
}
