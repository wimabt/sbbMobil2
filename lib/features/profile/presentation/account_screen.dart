import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_tokens.dart';
import '../../../l10n/l10n.dart';
import '../../auth/providers/auth_provider.dart';
import 'change_contact_flows.dart';
import 'contact_error_l10n.dart';
import 'dev_code_banner.dart'; // GEÇİCİ — dev_code gösterimi, yayından önce kaldır
import 'providers/account_contact_provider.dart';

/// Hesap Bilgileri ekranı — ad, telefon ve e-posta (doğrulama durumu ile).
///
/// FAZ 1 kapsamı: e-posta doğrulama akışı + "doğrulanmamış" rozeti.
/// E-posta/telefon değiştirme aksiyonları sonraki fazlarda eklenecek.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(authProvider.select((s) => s.user));
    final l10n = context.l10n;

    // Yerel ScaffoldMessenger: snackbar'lar bu ekranın Scaffold'una bağlanır,
    // shell'in (alttaki harita FAB'ı olan) Scaffold'unu ittirmez.
    return ScaffoldMessenger(
      child: Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(l10n.accountTitle,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _SectionLabel(label: l10n.accountContactSection),
                const SizedBox(height: 10),
                _InfoCard(
                  isDark: isDark,
                  children: [
                    _InfoRow(
                      icon: Icons.person_outline_rounded,
                      label: l10n.accountNameLabel,
                      value: _displayName(user, l10n),
                      isDark: isDark,
                    ),
                    _divider(isDark),
                    _InfoRow(
                      icon: Icons.phone_outlined,
                      label: l10n.accountPhoneLabel,
                      value: user.maskedPhone.isNotEmpty
                          ? user.maskedPhone
                          : '—',
                      isDark: isDark,
                      trailing: const _ChangePhoneButton(),
                    ),
                    _divider(isDark),
                    _EmailRow(user: user, isDark: isDark),
                  ],
                ),
              ],
            ),
      ),
    );
  }

  static String _displayName(AuthUser user, AppLocalizations l10n) {
    final name = [user.firstName, user.lastName]
        .where((p) => p != null && p.trim().isNotEmpty)
        .join(' ')
        .trim();
    return name.isNotEmpty ? name : '—';
  }

  static Widget _divider(bool isDark) => Padding(
        padding: const EdgeInsets.only(left: 52),
        child: Divider(
          height: 1,
          thickness: 0.5,
          color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(12),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════
// E-posta satırı — doğrulama rozeti + "Doğrula" aksiyonu (FAZ 1)
// ═══════════════════════════════════════════════════════════════════════

class _EmailRow extends ConsumerWidget {
  const _EmailRow({required this.user, required this.isDark});

  final AuthUser user;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final hasEmail = (user.email ?? '').trim().isNotEmpty;
    final verified = user.emailVerified;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withAlpha(10)
                  : theme.colorScheme.surfaceContainerHighest.withAlpha(180),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.alternate_email_rounded,
                size: 20,
                color: isDark
                    ? Colors.white.withAlpha(210)
                    : theme.colorScheme.onSurface),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.accountEmailLabel,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor)),
                const SizedBox(height: 2),
                Text(
                  hasEmail ? user.email!.trim() : l10n.accountNoEmail,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: hasEmail ? null : theme.hintColor,
                  ),
                ),
                // Sadece doğrulanmamışsa uyar; doğruysa rozet gösterme (gürültü).
                if (hasEmail && !verified) ...[
                  const SizedBox(height: 6),
                  const _UnverifiedBadge(),
                ],
                const SizedBox(height: 2),
                Wrap(
                  spacing: 4,
                  children: [
                    if (hasEmail && !verified)
                      TextButton(
                        onPressed: () => _openVerifySheet(context),
                        child: Text(l10n.accountVerifyEmail),
                      ),
                    TextButton(
                      onPressed: () =>
                          _openChangeEmail(context, isAdd: !hasEmail),
                      child: Text(
                          hasEmail ? l10n.btnChange : l10n.accountAddEmail),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openChangeEmail(BuildContext context,
      {required bool isAdd}) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ChangeEmailScreen(isAdd: isAdd)),
    );
    if (ok == true && context.mounted) {
      messenger.showSnackBar(
        SnackBar(
            content:
                Text(isAdd ? l10n.addEmailSuccess : l10n.changeEmailSuccess)),
      );
    }
  }

  /// Doğrulama sheet'ini açar. Kodu gönderme (start) sheet'in KENDİ içinde
  /// yapılır → hata/dev_code sheet içinde gösterilir, snackbar ile shell FAB'ı
  /// ittirilmez. Başarıda profil yenilenir, rozet otomatik "Doğrulandı" olur.
  void _openVerifySheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      // Sheet'i KÖK navigator'da aç: aksi halde sheet shell'in branch
      // navigator'ında (Scaffold body'si içinde) çizilir ve shell'in ortadaki
      // harita FAB'ı + alt bar'ı sheet'in üstünde kalır — kod girişi/hata
      // mesajı butonun arkasında gizleniyordu.
      useRootNavigator: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EmailVerifySheet(email: user.email!.trim()),
    );
  }
}

/// Telefon satırının sağındaki "Değiştir" aksiyonu → FAZ 3 sihirbazı.
class _ChangePhoneButton extends StatelessWidget {
  const _ChangePhoneButton();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TextButton(
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        final ok = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const ChangePhoneScreen()),
        );
        if (ok == true && context.mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.changePhoneSuccess)),
          );
        }
      },
      child: Text(l10n.btnChange),
    );
  }
}

/// Hesap Bilgileri'nde e-posta doğrulanmamışsa gösterilen rozet.
/// (Doğruysa rozet gösterilmez — ana profil kartı zaten "Doğrulandı" gösteriyor.)
class _UnverifiedBadge extends StatelessWidget {
  const _UnverifiedBadge();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? AppColors.neonPink : AppColors.error;
    final bg = color.withAlpha(isDark ? 28 : 22);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            l10n.accountEmailUnverified,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// E-posta doğrulama kod giriş sheet'i
// ═══════════════════════════════════════════════════════════════════════

class _EmailVerifySheet extends ConsumerStatefulWidget {
  const _EmailVerifySheet({required this.email});

  final String email;

  @override
  ConsumerState<_EmailVerifySheet> createState() => _EmailVerifySheetState();
}

class _EmailVerifySheetState extends ConsumerState<_EmailVerifySheet> {
  final _codeCtrl = TextEditingController();

  bool _starting = true; // start (kod gönderme) sürüyor
  String? _startError; // start başarısızsa mesaj
  bool _busy = false; // confirm sürüyor
  String? _error; // confirm hatası (kısa — field errorText)
  String? _blockingError; // bloklayan/bilgilendirici hata (uzun — kutu)
  String? _devCode; // GEÇİCİ — backend dev_code, yayından önce kaldır

  @override
  void initState() {
    super.initState();
    // `_start()` içinde context.l10n (Localizations.of) kullanılıyor; bu
    // initState tamamlanmadan çağrılamaz. İlk frame sonrasına erteliyoruz.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _start();
    });
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  /// Kodu gönder (start). Hata da dev_code da sheet içinde gösterilir.
  Future<void> _start() async {
    setState(() {
      _starting = true;
      _startError = null;
    });
    final l10n = context.l10n;
    final res =
        await ref.read(accountContactProvider.notifier).startEmailVerification();
    if (!mounted) return;
    setState(() {
      _starting = false;
      if (res.success) {
        _devCode = res.data?['dev_code'] as String?; // GEÇİCİ
        _startError = null;
      } else {
        _startError = contactErrorMessage(l10n, res);
      }
    });
  }

  Future<void> _confirm() async {
    final code = _codeCtrl.text.trim();
    if (code.length < 4) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final l10n = context.l10n;
    final res = await ref
        .read(accountContactProvider.notifier)
        .confirmEmailVerification(code);
    if (!mounted) return;
    if (res.success) {
      Navigator.of(context).pop(true);
    } else if (res.errorCode == ContactErrorCodes.valueAlreadyInUse) {
      // E-posta başka bir hesapta doğrulanmış → tekrar denemek çözmez. Küçük
      // errorText yerine bilgilendirici, eyleme dönük bir kutu göster.
      setState(() {
        _busy = false;
        _error = null;
        _blockingError = l10n.emailVerifyErrorInUseElsewhere;
      });
    } else {
      setState(() {
        _busy = false;
        _blockingError = null;
        _error = contactErrorMessage(l10n, res);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.hintColor.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(l10n.emailVerifyTitle,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(l10n.emailVerifySentTo(widget.email),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.hintColor, height: 1.4)),
          const SizedBox(height: 20),
          if (_starting)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_startError != null)
            _StartErrorView(message: _startError!, onRetry: _start)
          else
            ..._buildCodeEntry(theme, l10n),
        ],
      ),
    );
  }

  /// Bloklayan/bilgilendirici hata (ör. e-posta başka hesapta doğrulanmış):
  /// küçük field errorText'i yerine okunur, eyleme dönük bir kutu.
  Widget _buildBlockingBox(ThemeData theme, String message) {
    final color = theme.colorScheme.error;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCodeEntry(ThemeData theme, AppLocalizations l10n) {
    return [
      DevCodeBanner(code: _devCode), // GEÇİCİ
      if (_blockingError != null) ...[
        _buildBlockingBox(theme, _blockingError!),
        const SizedBox(height: 12),
      ],
      TextField(
        controller: _codeCtrl,
        autofocus: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        enabled: !_busy,
        decoration: InputDecoration(
          labelText: l10n.emailVerifyCodeLabel,
          counterText: '',
          errorText: _error,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) {
          if (_error != null || _blockingError != null) {
            setState(() {
              _error = null;
              _blockingError = null;
            });
          }
        },
        onSubmitted: (_) => _confirm(),
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        height: 50,
        child: FilledButton(
          onPressed: _busy ? null : _confirm,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.emailVerifyConfirm),
        ),
      ),
      const SizedBox(height: 4),
      Center(
        child: TextButton(
          onPressed: _busy ? null : _start,
          child: Text(l10n.emailVerifyResend),
        ),
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withAlpha(90),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 16, color: theme.hintColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.emailVerifyWhyBody,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.hintColor, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    ];
  }
}

/// Start (kod gönderme) başarısız olduğunda sheet içinde gösterilen hata + tekrar.
class _StartErrorView extends StatelessWidget {
  const _StartErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 20, color: theme.colorScheme.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.error, height: 1.4)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 50,
          child: FilledButton(
            onPressed: onRetry,
            child: Text(context.l10n.emailVerifyResend),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Ortak görünüm parçaları
// ═══════════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: isDark
              ? AppColors.textSecondaryDark.withAlpha(180)
              : AppColors.textSecondaryLight,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children, required this.isDark});

  final List<Widget> children;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: isDark
            ? Border.all(color: Colors.white.withAlpha(10), width: 1)
            : null,
        boxShadow: isDark ? null : AppElevation.level1,
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withAlpha(10)
                  : theme.colorScheme.surfaceContainerHighest.withAlpha(180),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                size: 20,
                color: isDark
                    ? Colors.white.withAlpha(210)
                    : theme.colorScheme.onSurface),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor)),
                const SizedBox(height: 2),
                Text(value,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
