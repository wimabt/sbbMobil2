import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_tokens.dart';
import '../../../l10n/l10n.dart';
import '../../profile/presentation/widgets/settings_section.dart';

/// Premium Settings Screen — iOS 18 / Material Design 3 inspired.
///
/// Uygulamanın **tek** ayar yüzeyi. Gövde, paylaşılan [SettingsSection]
/// widget'ından gelir (tema seçici, hesap/dil/bildirim/yasal kartı, analitik
/// opt-out, çıkış ve hesap silme). Eskiden profilde inline + burada ayrı ayrı
/// kodlanan ayarlar tek kaynağa indirildi; profil ekranı artık sadece kimlik,
/// istatistik ve "içeriklerim" kısayollarını gösterir.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        title: Text(
          l10n.lblSettings,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          // SettingsSection kendi yatay padding'ini (16) yönettiği için burada
          // sadece üst/alt boşluk veriyoruz.
          padding: const EdgeInsets.only(
            top: 4,
            bottom: AppNavBar.bottomPadding + 16,
          ),
          child: const SettingsSection(),
        ),
      ),
    );
  }
}
