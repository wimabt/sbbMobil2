import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/phone_number_field.dart';
import '../../../l10n/l10n.dart';
import '../../legal/data/legal_documents.dart';
import '../../legal/providers/consent_provider.dart';
import '../providers/auth_provider.dart';

class AuthRegisterScreen extends ConsumerStatefulWidget {
  const AuthRegisterScreen({super.key, this.initialPhone});

  /// Giriş ekranından `?phone=` ile (E.164) önceden doldurma.
  final String? initialPhone;

  @override
  ConsumerState<AuthRegisterScreen> createState() => _AuthRegisterScreenState();
}

class _AuthRegisterScreenState extends ConsumerState<AuthRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  /// §10.6.2 / §14.2.2 — üyelik için açık rıza zorunlu.
  bool _consentAccepted = false;
  late final TapGestureRecognizer _aydinlatmaTap;
  late final TapGestureRecognizer _kosullarTap;

  @override
  void initState() {
    super.initState();
    _aydinlatmaTap = TapGestureRecognizer()
      ..onTap = () => context.push('/legal/${LegalDocIds.aydinlatma}');
    _kosullarTap = TapGestureRecognizer()
      ..onTap = () => context.push('/legal/${LegalDocIds.kullanim}');
    // Telefon alanını tohumla: ?phone= geldiyse onu (ülke kodu dahil),
    // yoksa varsayılan +90. `+` sabit, sonrası düzenlenebilir.
    seedPhoneController(_phoneController, initial: widget.initialPhone);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _aydinlatmaTap.dispose();
    _kosullarTap.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen(authProvider, (previous, next) {
      if (next.status == AuthStatus.otpSent) {
        context.push('/otp');
      }
    });

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.primary.withValues(alpha: 0.08),
              colorScheme.surface,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.btnRegister,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.registerSubtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      context.l10n.lblFirstName,
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _firstNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: context.l10n.lblFirstName,
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return context.l10n.valFirstNameRequired;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.lblLastName,
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _lastNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: context.l10n.lblLastName,
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return context.l10n.valLastNameRequired;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.lblEmail,
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'ornek@mail.com',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                      ),
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty) {
                          return context.l10n.valEmailRequired;
                        }
                        final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                        if (!emailRegex.hasMatch(v)) {
                          return context.l10n.valEmailInvalid;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.lblPhoneNumber,
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    PhoneNumberField(
                      controller: _phoneController,
                      hintText: '+90 5XX XXX XX XX',
                      validator: (value) => validatePhoneNumber(context, value),
                    ),
                    const SizedBox(height: 20),
                    // ── Açık rıza (§10.6.2 / §14.2.2) ──────────────────────
                    _ConsentCheckbox(
                      value: _consentAccepted,
                      onChanged: (v) =>
                          setState(() => _consentAccepted = v ?? false),
                      aydinlatmaTap: _aydinlatmaTap,
                      kosullarTap: _kosullarTap,
                    ),
                    const SizedBox(height: 20),
                    if (authState.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Text(
                          authState.errorMessage!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.error,
                          ),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: (authState.isLoading || !_consentAccepted)
                            ? null
                            : () async {
                                if (!_formKey.currentState!.validate()) return;
                                // Açık rızayı kalıcı kaydet (denetim izi için).
                                await ref
                                    .read(consentProvider.notifier)
                                    .accept();
                                final normalized =
                                    normalizePhone(_phoneController.text);
                                await ref
                                    .read(authProvider.notifier)
                                    .sendOtp(
                                      normalized,
                                      firstName:
                                          _firstNameController.text.trim(),
                                      lastName: _lastNameController.text.trim(),
                                      email: _emailController.text.trim(),
                                      type: 'register',
                                    );
                              },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: authState.isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                context.l10n.btnContinue,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.authOtpSendInfo,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kayıt için açık rıza onay kutusu — Aydınlatma Metni ve Kullanım Koşulları'na
/// tıklanabilir bağlantı içerir (§10.6.3).
class _ConsentCheckbox extends StatelessWidget {
  const _ConsentCheckbox({
    required this.value,
    required this.onChanged,
    required this.aydinlatmaTap,
    required this.kosullarTap,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;
  final TapGestureRecognizer aydinlatmaTap;
  final TapGestureRecognizer kosullarTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final linkStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    );
    final baseStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.hintColor,
      height: 1.45,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!value),
            child: Text.rich(
              TextSpan(
                style: baseStyle,
                children: [
                  if (context.l10n.registerConsentPrefix.isNotEmpty)
                    TextSpan(text: context.l10n.registerConsentPrefix),
                  TextSpan(
                    text: context.l10n.legalClarificationText,
                    style: linkStyle,
                    recognizer: aydinlatmaTap,
                  ),
                  TextSpan(text: context.l10n.registerConsentMid),
                  TextSpan(
                    text: context.l10n.legalTermsOfUse,
                    style: linkStyle,
                    recognizer: kosullarTap,
                  ),
                  TextSpan(text: context.l10n.registerConsentSuffix),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

