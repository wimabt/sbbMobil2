import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/widgets/phone_number_field.dart';
import '../../../l10n/l10n.dart';
import 'contact_error_l10n.dart';
import 'dev_code_banner.dart'; // GEÇİCİ — dev_code gösterimi, yayından önce kaldır
import 'providers/account_contact_provider.dart';

// ═══════════════════════════════════════════════════════════════════════
// FAZ 2 — E-posta değiştirme / ekleme (4 adım)
//   0: telefona step-up kodu gönder
//   1: telefon OTP'sini doğrula → sensitive token
//   2: yeni e-postayı gir → yeni adrese kod
//   3: yeni e-posta kodunu doğrula → güncelle
// ═══════════════════════════════════════════════════════════════════════

class ChangeEmailScreen extends ConsumerStatefulWidget {
  const ChangeEmailScreen({super.key, this.isAdd = false});

  /// E-postası olmayan kullanıcı için "ekleme" modu (başlık/başarı metni değişir).
  final bool isAdd;

  @override
  ConsumerState<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends ConsumerState<ChangeEmailScreen> {
  int _step = 0;
  bool _busy = false;
  String? _error;
  String? _devCode; // GEÇİCİ — backend dev_code, yayından önce kaldır

  final _otpCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  static final _emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');

  AccountContactNotifier get _n =>
      ref.read(accountContactProvider.notifier);

  @override
  void dispose() {
    // Akış yarıda bırakıldıysa step-up token'ını temizle.
    _n.resetSensitive();
    _otpCtrl.dispose();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(
    Future<ContactActionResult> Function() action, {
    required VoidCallback onOk,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await action();
    if (!mounted) return;
    if (res.success) {
      setState(() {
        _busy = false;
        _devCode = res.data?['dev_code'] as String?; // GEÇİCİ
      });
      onOk();
    } else {
      setState(() {
        _busy = false;
        _error = contactErrorMessage(context.l10n, res);
      });
    }
  }

  Future<void> _setNewEmail({bool confirmClaim = false}) async {
    final email = _emailCtrl.text.trim();
    if (!_emailRegex.hasMatch(email)) {
      setState(() => _error = context.l10n.valEmailInvalid);
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await _n.setNewEmail(email, confirmClaim: confirmClaim);
    if (!mounted) return;
    if (res.success) {
      setState(() {
        _busy = false;
        _devCode = res.data?['dev_code'] as String?; // GEÇİCİ
        _step = 3;
      });
    } else if (res.errorCode == ContactErrorCodes.emailClaimConfirm) {
      // E-posta başka bir numaraya doğrulanmamış olarak kayıtlı → kullanıcıya
      // "doğrulayarak bağla" onayı sor; onaylarsa confirm_claim ile tekrar dene.
      setState(() => _busy = false);
      final ok = await _confirmClaimDialog();
      if (ok == true && mounted) {
        await _setNewEmail(confirmClaim: true);
      }
    } else {
      setState(() {
        _busy = false;
        _error = contactErrorMessage(context.l10n, res);
      });
    }
  }

  Future<bool?> _confirmClaimDialog() {
    final l10n = context.l10n;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.emailClaimConfirmTitle),
        content: Text(l10n.emailClaimConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.btnGiveUp),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.btnContinue),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ContactFlowScaffold(
      title: widget.isAdd ? l10n.addEmailTitle : l10n.changeEmailTitle,
      step: _step,
      totalSteps: 4,
      child: switch (_step) {
        0 => _IntroStep(
            description: l10n.changeEmailIntro,
            buttonLabel: l10n.changeContactSendCode,
            busy: _busy,
            error: _error,
            onPressed: () =>
                _run(_n.startEmailChange, onOk: () => setState(() => _step = 1)),
          ),
        1 => _CodeStep(
            label: l10n.changeStepPhoneOtpLabel,
            devCode: _devCode, // GEÇİCİ
            controller: _otpCtrl,
            buttonLabel: l10n.btnNext,
            busy: _busy,
            error: _error,
            onPressed: () => _run(
              () => _n.verifyEmailChangeStepup(_otpCtrl.text.trim()),
              onOk: () => setState(() => _step = 2),
            ),
          ),
        2 => _EmailInputStep(
            controller: _emailCtrl,
            busy: _busy,
            error: _error,
            onPressed: () => _setNewEmail(),
          ),
        _ => _CodeStep(
            label: l10n.changeNewEmailCodeLabel,
            devCode: _devCode, // GEÇİCİ
            controller: _codeCtrl,
            buttonLabel: l10n.emailVerifyConfirm,
            busy: _busy,
            error: _error,
            onPressed: () => _run(
              () => _n.confirmEmailChange(_codeCtrl.text.trim()),
              onOk: () => Navigator.of(context).pop(true),
            ),
          ),
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// FAZ 3 — Telefon değiştirme (4 adım, doğrulanmış e-posta gerekir)
//   0: doğrulanmış e-postaya step-up kodu (yoksa EMAIL_REQUIRED_FIRST kapısı)
//   1: e-posta kodunu doğrula → sensitive token
//   2: yeni telefonu gir → yeni numaraya OTP
//   3: yeni telefon OTP'sini doğrula → güncelle (+ diğer cihazlar logout)
// ═══════════════════════════════════════════════════════════════════════

class ChangePhoneScreen extends ConsumerStatefulWidget {
  const ChangePhoneScreen({super.key});

  @override
  ConsumerState<ChangePhoneScreen> createState() => _ChangePhoneScreenState();
}

class _ChangePhoneScreenState extends ConsumerState<ChangePhoneScreen> {
  int _step = 0;
  bool _busy = false;
  bool _emailGate = false;
  String? _error;
  String? _devCode; // GEÇİCİ — backend dev_code, yayından önce kaldır

  final _emailCodeCtrl = TextEditingController();
  // Varsayılan +90; `+` sabit, ülke kodu dahil sonrası düzenlenebilir.
  final _phoneCtrl = TextEditingController(text: kDefaultPhonePrefix);
  final _otpCtrl = TextEditingController();

  AccountContactNotifier get _n =>
      ref.read(accountContactProvider.notifier);

  @override
  void dispose() {
    _n.resetSensitive();
    _emailCodeCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(
    Future<ContactActionResult> Function() action, {
    required VoidCallback onOk,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await action();
    if (!mounted) return;
    if (res.success) {
      setState(() {
        _busy = false;
        _devCode = res.data?['dev_code'] as String?; // GEÇİCİ
      });
      onOk();
    } else {
      setState(() {
        _busy = false;
        _error = contactErrorMessage(context.l10n, res);
      });
    }
  }

  // Step 0: EMAIL_REQUIRED_FIRST'i kapı olarak ele al.
  Future<void> _startStepup() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await _n.startPhoneChange();
    if (!mounted) return;
    if (res.success) {
      setState(() {
        _busy = false;
        _step = 1;
        _devCode = res.data?['dev_code'] as String?; // GEÇİCİ
      });
    } else if (res.errorCode == ContactErrorCodes.emailRequiredFirst) {
      setState(() {
        _busy = false;
        _emailGate = true;
      });
    } else {
      setState(() {
        _busy = false;
        _error = contactErrorMessage(context.l10n, res);
      });
    }
  }

  void _setNewPhone() {
    final phone = normalizePhone(_phoneCtrl.text);
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 8 || digits.length > 15) {
      setState(() => _error = context.l10n.changeNewPhoneInvalid);
      return;
    }
    _run(() => _n.setNewPhone(phone), onOk: () => setState(() => _step = 3));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (_emailGate) {
      return ContactFlowScaffold(
        title: l10n.changePhoneTitle,
        step: 0,
        totalSteps: 4,
        showStepLabel: false,
        child: _EmailRequiredGate(
          // Hesap ekranına dön → kullanıcı e-postasını doğrulasın.
          onAction: () => Navigator.of(context).pop(),
        ),
      );
    }

    return ContactFlowScaffold(
      title: l10n.changePhoneTitle,
      step: _step,
      totalSteps: 4,
      child: switch (_step) {
        0 => _IntroStep(
            description: l10n.changePhoneIntro,
            buttonLabel: l10n.changeContactSendCode,
            busy: _busy,
            error: _error,
            onPressed: _startStepup,
          ),
        1 => _CodeStep(
            label: l10n.changeStepEmailCodeLabel,
            devCode: _devCode, // GEÇİCİ
            controller: _emailCodeCtrl,
            buttonLabel: l10n.btnNext,
            busy: _busy,
            error: _error,
            onPressed: () => _run(
              () => _n.verifyPhoneChangeStepup(_emailCodeCtrl.text.trim()),
              onOk: () => setState(() => _step = 2),
            ),
          ),
        2 => _PhoneInputStep(
            controller: _phoneCtrl,
            busy: _busy,
            error: _error,
            onPressed: _setNewPhone,
          ),
        _ => _CodeStep(
            label: l10n.changeNewPhoneOtpLabel,
            devCode: _devCode, // GEÇİCİ
            controller: _otpCtrl,
            buttonLabel: l10n.emailVerifyConfirm,
            busy: _busy,
            error: _error,
            footnote: l10n.changePhoneOtherDevicesNote,
            onPressed: () => _run(
              () => _n.confirmPhoneChange(_otpCtrl.text.trim()),
              onOk: () => Navigator.of(context).pop(true),
            ),
          ),
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Paylaşılan görünüm parçaları
// ═══════════════════════════════════════════════════════════════════════

class ContactFlowScaffold extends StatelessWidget {
  const ContactFlowScaffold({
    super.key,
    required this.title,
    required this.step,
    required this.totalSteps,
    required this.child,
    this.showStepLabel = true,
  });

  final String title;
  final int step;
  final int totalSteps;
  final Widget child;
  final bool showStepLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title:
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
        backgroundColor: bg,
        bottom: showStepLabel
            ? PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Text(
                      l10n.changeContactStepLabel(step + 1, totalSteps),
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: theme.hintColor),
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [child],
        ),
      ),
    );
  }
}

class _IntroStep extends StatelessWidget {
  const _IntroStep({
    required this.description,
    required this.buttonLabel,
    required this.busy,
    required this.error,
    required this.onPressed,
  });

  final String description;
  final String buttonLabel;
  final bool busy;
  final String? error;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(description,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
        if (error != null) ...[
          const SizedBox(height: 16),
          _ErrorText(error!),
        ],
        const SizedBox(height: 24),
        _PrimaryButton(label: buttonLabel, busy: busy, onPressed: onPressed),
      ],
    );
  }
}

class _CodeStep extends StatelessWidget {
  const _CodeStep({
    required this.label,
    required this.controller,
    required this.buttonLabel,
    required this.busy,
    required this.error,
    required this.onPressed,
    this.footnote,
    this.devCode,
  });

  final String label;
  final TextEditingController controller;
  final String buttonLabel;
  final bool busy;
  final String? error;
  final VoidCallback onPressed;
  final String? footnote;

  /// GEÇİCİ — backend dev_code; yayından önce kaldır.
  final String? devCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DevCodeBanner(code: devCode), // GEÇİCİ
        TextField(
          controller: controller,
          autofocus: true,
          enabled: !busy,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: label,
            counterText: '',
            errorText: error,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => onPressed(),
        ),
        if (footnote != null) ...[
          const SizedBox(height: 8),
          Text(footnote!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.hintColor, height: 1.4)),
        ],
        const SizedBox(height: 20),
        _PrimaryButton(label: buttonLabel, busy: busy, onPressed: onPressed),
      ],
    );
  }
}

class _EmailInputStep extends StatelessWidget {
  const _EmailInputStep({
    required this.controller,
    required this.busy,
    required this.error,
    required this.onPressed,
  });

  final TextEditingController controller;
  final bool busy;
  final String? error;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          autofocus: true,
          enabled: !busy,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: l10n.changeNewEmailLabel,
            hintText: 'ornek@mail.com',
            errorText: error,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => onPressed(),
        ),
        const SizedBox(height: 20),
        _PrimaryButton(label: l10n.changeContactSendCode, busy: busy, onPressed: onPressed),
      ],
    );
  }
}

class _PhoneInputStep extends StatelessWidget {
  const _PhoneInputStep({
    required this.controller,
    required this.busy,
    required this.error,
    required this.onPressed,
  });

  final TextEditingController controller;
  final bool busy;
  final String? error;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PhoneNumberField(
          controller: controller,
          autofocus: true,
          enabled: !busy,
          labelText: l10n.changeNewPhoneLabel,
          hintText: l10n.changeNewPhoneHint,
          errorText: error,
          borderRadius: 4,
          onFieldSubmitted: (_) => onPressed(),
        ),
        const SizedBox(height: 20),
        _PrimaryButton(label: l10n.changeContactSendCode, busy: busy, onPressed: onPressed),
      ],
    );
  }
}

class _EmailRequiredGate extends StatelessWidget {
  const _EmailRequiredGate({required this.onAction});

  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Icon(Icons.mark_email_unread_outlined,
            size: 56, color: theme.colorScheme.primary),
        const SizedBox(height: 20),
        Text(l10n.emailRequiredGateTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Text(l10n.emailRequiredGateBody,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.hintColor, height: 1.5)),
        const SizedBox(height: 28),
        _PrimaryButton(
          label: l10n.emailRequiredGateButton,
          busy: false,
          onPressed: onAction,
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline_rounded,
            size: 18, color: theme.colorScheme.error),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error, height: 1.4)),
        ),
      ],
    );
  }
}
