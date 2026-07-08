import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInput;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../../../core/security/secure_screen_mixin.dart';
import '../../../core/utils/haptics.dart';
import '../../../l10n/l10n.dart';
import '../providers/auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> with SecureScreenMixin<OtpScreen> {
  static const _initialSeconds = 180;

  late int _remainingSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = _initialSeconds;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _remainingSeconds = _initialSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        setState(() {
          _remainingSeconds = 0;
        });
        timer.cancel();
      } else {
        setState(() {
          _remainingSeconds--;
        });
      }
    });
  }

  String get _formattedTime {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _handleVerifyOutcome({
    required BuildContext context,
    required VerifyOtpOutcome outcome,
    required String phone,
    required String otp,
  }) async {
    switch (outcome) {
      case VerifyOtpSuccess():
        // Router auth state listener handles navigation
        break;
      case VerifyOtpDeletionPending(:final daysRemaining):
        await _showDeletionPendingDialog(
          context: context,
          phone: phone,
          otp: otp,
          daysRemaining: daysRemaining,
        );
      case VerifyOtpDeletionFinal(:final message):
        await _showDeletionFinalDialog(
          context: context,
          message: message,
        );
      case VerifyOtpFailure():
        // errorMessage banner displays the failure
        break;
    }
  }

  Future<void> _showDeletionPendingDialog({
    required BuildContext context,
    required String phone,
    required String otp,
    required int daysRemaining,
  }) async {
    final theme = Theme.of(context);
    final restore = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.otpPendingDeletionTitle),
          content: Text(
            context.l10n.otpPendingDeletionBody(daysRemaining),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.l10n.btnGiveUp),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(context.l10n.btnRestoreAccount),
            ),
          ],
        );
      },
    );

    if (!context.mounted) return;

    if (restore == true) {
      final messenger = ScaffoldMessenger.of(context);
      final restoredMsg = context.l10n.accountRestoredMsg;
      final notifier = ref.read(authProvider.notifier);
      final outcome = await notifier.verifyOtp(
        phoneNumber: phone,
        otp: otp,
        restore: true,
      );
      if (outcome is VerifyOtpSuccess) {
        await Haptics.success();
        messenger.showSnackBar(
          SnackBar(
            content: Text(restoredMsg),
          ),
        );
      } else if (outcome is VerifyOtpFailure) {
        await Haptics.error();
        messenger.showSnackBar(
          SnackBar(content: Text(outcome.message)),
        );
      }
    }
  }

  Future<void> _showDeletionFinalDialog({
    required BuildContext context,
    required String? message,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.otpAccountDeletedTitle),
          content: Text(
            message ?? context.l10n.otpAccountDeletedBody,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.l10n.btnCreateNewAccount),
            ),
          ],
        );
      },
    );

    if (!context.mounted) return;
    context.go('/register');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final phone = authState.phoneNumber ?? '';
    final fullName = [
      authState.firstName?.trim() ?? '',
      authState.lastName?.trim() ?? '',
    ].where((e) => e.isNotEmpty).join(' ');
    final email = authState.email ?? '';
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    ref.listen(authProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated) {
        // Başarılı doğrulama — dokunsal geri bildirim
        Haptics.success();
        // SMS autofill oturumunu temizle
        TextInput.finishAutofillContext(shouldSave: true);
        // Giriş / kayıt tamamlandığında kullanıcıyı ana sayfa yerine
        // doğrudan profil sekmesine yönlendir.
        context.go('/profile');
      } else if (next.errorMessage != null &&
          previous?.errorMessage != next.errorMessage) {
        // Hata durumu — ağır dokunsal geri bildirim
        Haptics.error();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.otpAppBarTitle),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.otpVerifyPhoneTitle,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.otpSentToLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.hintColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                phone.isNotEmpty ? phone : '-',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              // TODO(GEÇİCİ — KALDIRILACAK): OTP kodunu her build'de göster.
              // 2026-06-09 talebiyle eklendi. Yayına çıkmadan ÖNCE bu bloğu
              // `kDebugMode &&` koşuluna geri al veya tamamen kaldır.
              if (authState.otpCode != null && authState.otpCode!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Test OTP: ${authState.otpCode}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
              ],
              if (fullName.isNotEmpty || email.isNotEmpty) ...[
                const SizedBox(height: 4),
                if (fullName.isNotEmpty)
                  Text(
                    fullName,
                    style: theme.textTheme.bodyMedium,
                  ),
                if (email.isNotEmpty)
                  Text(
                    email,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
              ],
              const SizedBox(height: 24),
              Center(
                child: PinCodeTextField(
                  appContext: context,
                  length: 6,
                  autoFocus: true,
                  keyboardType: TextInputType.number,
                  animationType: AnimationType.fade,
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(12),
                    fieldHeight: 52,
                    fieldWidth: 44,
                    activeColor: colorScheme.primary,
                    selectedColor: colorScheme.primary,
                    inactiveColor: colorScheme.outlineVariant,
                    activeFillColor: Colors.transparent,
                    inactiveFillColor: Colors.transparent,
                    selectedFillColor: Colors.transparent,
                  ),
                  backgroundColor: Colors.transparent,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  cursorColor: colorScheme.primary,
                  animationDuration: const Duration(milliseconds: 200),
                  enableActiveFill: false,
                  onCompleted: (value) async {
                    if (value.length == 6 && phone.isNotEmpty) {
                      await Haptics.light();
                      final notifier = ref.read(authProvider.notifier);
                      if (authState.loginOtpFlow) {
                        final outcome = await notifier.verifyOtp(
                          phoneNumber: phone,
                          otp: value,
                        );
                        if (!context.mounted) return;
                        await _handleVerifyOutcome(
                          context: context,
                          outcome: outcome,
                          phone: phone,
                          otp: value,
                        );
                      } else {
                        await notifier.registerWithOtp(
                          phoneNumber: phone,
                          otp: value,
                          firstName: authState.firstName?.trim() ?? '',
                          lastName: authState.lastName?.trim() ?? '',
                          email: authState.email,
                        );
                      }
                    }
                  },
                  onChanged: (_) {},
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.l10n.lblRemainingTime,
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    _formattedTime,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _remainingSeconds > 0 || phone.isEmpty
                      ? null
                      : () async {
                          await ref.read(authProvider.notifier).sendOtp(
                                phone,
                                firstName: authState.firstName,
                                lastName: authState.lastName,
                                email: authState.email,
                                type: authState.loginOtpFlow ? 'login' : 'register',
                              );
                          _startTimer();
                        },
                  child: Text(
                    context.l10n.btnResendCode,
                    style: TextStyle(
                      color: _remainingSeconds > 0
                          ? theme.disabledColor
                          : colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (authState.errorMessage != null)
                Text(
                  authState.errorMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

