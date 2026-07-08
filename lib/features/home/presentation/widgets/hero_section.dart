import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design_tokens.dart';
import '../../../../l10n/l10n.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../places/presentation/providers/places_provider.dart';

/// Hero section widget for home screen
/// Light Theme: Bright photo + gradient overlay + cam efektli arama çubuğu
/// Dark Theme: Cinematic overlay + aynı arama çubuğu (uyarlanmış opaklık)
class HeroSection extends ConsumerStatefulWidget {
  const HeroSection({
    super.key,
    this.title,
    this.subtitle,
    this.imagePath = 'assets/images/hero-city.jpg',
    this.imageUrl,
    this.imageAlignment = Alignment.center,
    this.imageFit = BoxFit.cover,
    this.topLeading,
    this.topTrailing,
  });

  /// null ise yerelleştirilmiş varsayılan kullanılır (build içinde çözülür).
  final String? title;
  final String? subtitle;

  /// Bundle'daki varsayılan/yedek görsel (network başarısız olursa veya
  /// [imageUrl] yoksa kullanılır).
  final String imagePath;

  /// Panelden yönetilen uzak hero görseli (mutlak URL). null/boş ise [imagePath]
  /// kullanılır. Hata durumunda da [imagePath]'e düşülür.
  final String? imageUrl;

  /// Odak noktasından türetilen hizalama — [imageFit] cover iken kırpmanın
  /// hangi bölgeyi koruyacağını belirler.
  final Alignment imageAlignment;

  /// cover (doldur+kırp) veya contain (sığdır). Varsayılan cover.
  final BoxFit imageFit;

  /// Hero görselinin sol üstüne bindirilen yüzen kontrol (örn. menü butonu).
  /// Eski opak üst bar kaldırıldı; menü/asistan artık görselin üzerinde yüzer.
  final Widget? topLeading;

  /// Hero görselinin sağ üstüne bindirilen yüzen kontrol (örn. asistan butonu).
  final Widget? topTrailing;

  @override
  ConsumerState<HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends ConsumerState<HeroSection> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocus;

  static const double _heroHeight = 302;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocus = FocusNode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _openPlacesWithSearch() {
    final q = _searchController.text.trim();
    ref.read(placesProvider.notifier).applyRouteCategorySlug(null);
    ref.read(placesProvider.notifier).setCategory('all');
    if (q.isEmpty) {
      context.go('/places');
    } else {
      context.go('/places?q=${Uri.encodeComponent(q)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    // Hero status bar'ın arkasına kadar uzar (edge-to-edge); top inset kadar
    // ekstra yükseklik vererek görselin "izlenebilir" alanı eskisiyle aynı kalır.
    final topInset = MediaQuery.of(context).padding.top;
    final l10n = context.l10n;

    final authState = ref.watch(authProvider);
    final isLoggedIn = authState.status == AuthStatus.authenticated;
    final user = authState.user;
    final firstName = user?.firstName?.trim();
    final badgeText = isLoggedIn && firstName != null && firstName.isNotEmpty
        ? 'Merhaba, $firstName!'
        : 'Merhaba!';

    return SizedBox(
      height: _heroHeight + topInset,
      width: screenWidth,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            child: _buildBackground(context, isDark, screenWidth),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: isDark
                  ? AppGradients.heroOverlayDark
                  : AppGradients.heroOverlayLight,
            ),
          ),
          // Üst scrim — status bar ikonları + yüzen butonlar her görselde
          // (parlak gökyüzü dahil) okunur kalsın diye hafif koyu geçiş.
          if (widget.topLeading != null || widget.topTrailing != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: topInset + 72,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withAlpha(70),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // Yüzen üst kontroller (menü solda, asistan sağda).
          if (widget.topLeading != null || widget.topTrailing != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      if (widget.topLeading != null) widget.topLeading!,
                      const Spacer(),
                      if (widget.topTrailing != null) widget.topTrailing!,
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: AppSpacing.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildWelcomeBadge(context, isDark, badgeText),
                const SizedBox(height: AppSpacing.md),
                Text(
                  widget.title ?? context.l10n.authWelcome,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        height: 1.1,
                        shadows: [
                          Shadow(
                            color: Colors.black.withAlpha(100),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  widget.subtitle ?? context.l10n.heroDiscoverSubtitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withAlpha(220),
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.2,
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm + 2),
                _HeroGlassSearchBar(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  hintText: l10n.heroSearchHint,
                  actionLabel: l10n.heroSearchAction,
                  isDark: isDark,
                  onSubmitted: (_) => _openPlacesWithSearch(),
                  onSearchTap: _openPlacesWithSearch,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Arka plan görseli: panelden gelen [imageUrl] varsa CachedNetworkImage,
  /// yoksa (veya network hatasında) bundle'daki asset. Odak noktası
  /// [imageAlignment] + [imageFit] ile uygulanır (panel önizlemesiyle birebir).
  Widget _buildBackground(BuildContext context, bool isDark, double screenWidth) {
    final fallback = _assetBackground(context, isDark, screenWidth);
    final url = widget.imageUrl;
    if (url == null || url.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: url,
      fit: widget.imageFit,
      alignment: widget.imageAlignment,
      width: screenWidth,
      memCacheWidth:
          (screenWidth * MediaQuery.of(context).devicePixelRatio).toInt(),
      fadeInDuration: const Duration(milliseconds: 250),
      placeholder: (context, url) => fallback,
      errorWidget: (context, url, error) => fallback,
    );
  }

  Widget _assetBackground(BuildContext context, bool isDark, double screenWidth) {
    return Image.asset(
      widget.imagePath,
      fit: widget.imageFit,
      alignment: widget.imageAlignment,
      width: screenWidth,
      cacheWidth: (screenWidth * MediaQuery.of(context).devicePixelRatio).toInt(),
      errorBuilder: (context, error, stackTrace) => Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1A1A2E),
                    Color(0xFF16213E),
                  ],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF667eea),
                    Color(0xFF764ba2),
                  ],
                ),
        ),
        child: Center(
          child: Icon(
            Icons.location_city_rounded,
            size: 64,
            color: Colors.white.withAlpha(80),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeBadge(BuildContext context, bool isDark, String badgeText) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.brandGreenBright.withAlpha(45)
                : Colors.white.withAlpha(40),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: isDark
                  ? AppColors.brandGreenBright.withAlpha(70)
                  : Colors.white.withAlpha(50),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.waving_hand_rounded,
                size: 14,
                // Fotoğraf üstünde her iki temada da beyaz + hafif gölge:
                // koyu modda yeşil yazı açık gökyüzü bölgesinde kayboluyordu.
                color: Colors.white,
                shadows: const [
                  Shadow(
                    color: Color(0x73000000), // siyah %45
                    blurRadius: 6,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                badgeText,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.3,
                  shadows: [
                    Shadow(
                      color: Color(0x73000000), // siyah %45
                      blurRadius: 6,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroGlassSearchBar extends StatelessWidget {
  const _HeroGlassSearchBar({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.actionLabel,
    required this.isDark,
    required this.onSubmitted,
    required this.onSearchTap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final String actionLabel;
  final bool isDark;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    const barHeight = 48.0;
    final radius = BorderRadius.circular(barHeight / 2);

    // Beyaz tabaka yerine koyu yarı saydam cam — arka plan rengi görünsün, halo olmasın
    final glassTint = isDark
        ? Colors.black.withValues(alpha: 0.28)
        : Colors.black.withValues(alpha: 0.2);
    final edgeLine = Colors.white.withValues(alpha: 0.14);

    const iconColor = Colors.white;
    final hintStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.92),
      fontSize: 15,
      fontWeight: FontWeight.w400,
    );
    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 15,
      fontWeight: FontWeight.w400,
    );

    return ClipRRect(
      borderRadius: radius,
      clipBehavior: Clip.hardEdge,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            color: glassTint,
            border: Border.all(color: edgeLine, width: 0.6),
          ),
          child: SizedBox(
            height: barHeight,
            child: Padding(
              // Sağ-sol simetrik iç boşluk → aksiyon butonu çubuğa "oturmuş"
              // görünür, üstüne yapışmış/iç içe bir daire gibi durmaz.
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  // Sol bölge (ikon + boşluklar) da tıklanabilir: kullanıcı
                  // çubuğun herhangi bir yerine dokununca alan odaklanır,
                  // sadece TextField'in dar alanında değil.
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: focusNode.requestFocus,
                    child: const Padding(
                      padding: EdgeInsets.only(left: 8, right: 10),
                      child: Icon(Icons.search_rounded,
                          color: iconColor, size: 22),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      cursorColor: Colors.white,
                      style: textStyle,
                      decoration: InputDecoration(
                        // Tüm border state'leri kapalı — aksi halde global
                        // tema'nın focusedBorder'ı (yeşil outline) odaklanınca
                        // sızıyor ve "kutu içinde kutu" görüntüsü veriyordu.
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        isDense: true,
                        filled: true,
                        fillColor: Colors.transparent,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                        hintText: hintText,
                        hintStyle: hintStyle,
                        isCollapsed: true,
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: onSubmitted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Aksiyon: daire yerine, çubuğun yuvarlaklığıyla uyumlu pill
                  // buton. Üst/alt 6px boşlukla içeri oturur; "Ara" yazısı
                  // sıkışmaz, tek bütünleşik arama çubuğu hissi verir.
                  _SearchActionButton(
                    label: actionLabel,
                    height: barHeight - 12,
                    onTap: onSearchTap,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hero arama çubuğunun aksiyon butonu — çubuğun pill formuyla uyumlu,
/// içeriye oturan, "Ara" etiketli tam yuvarlak buton.
class _SearchActionButton extends StatelessWidget {
  const _SearchActionButton({
    required this.label,
    required this.height,
    required this.onTap,
  });

  final String label;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(height / 2);

    return Material(
      color: scheme.primary,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: height + 12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: SizedBox(
              height: height,
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
