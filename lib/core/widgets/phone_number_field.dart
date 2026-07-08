import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';

/// Tüm telefon girişlerinde kullanılan ortak varsayılan ülke kodu.
/// Kullanıcı silip kendi ülke kodunu yazabilir; yalnız `+` sabittir.
const String kDefaultPhonePrefix = '+90';

/// Telefon alanı formatlayıcısı:
///   • Metin HER ZAMAN tek bir `+` ile başlar (silinemez/çoğaltılamaz).
///   • `+`'tan sonrası yalnız rakamdır; ülke kodu dahil tamamı düzenlenebilir
///     (kullanıcı `90`'ı silip `49` yazabilir).
///   • En fazla [maxDigits] rakam (E.164 üst sınırı 15).
///
/// Böylece "+90" varsayılanıyla gelir ama kullanıcı `+`'tan sonrasını
/// tamamen değiştirebilir; `+` her durumda kalır.
class LeadingPlusPhoneFormatter extends TextInputFormatter {
  const LeadingPlusPhoneFormatter({this.maxDigits = 15});

  final int maxDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > maxDigits) {
      digits = digits.substring(0, maxDigits);
    }
    final text = '+$digits';

    // İmleci sondan göreli koru → kullanıcı ortada düzenlerken sıçramaz.
    // En az 1 (yani `+`'tan sonra) — `+` asla seçili/silinebilir konuma düşmez.
    final fromEnd = newValue.text.length - newValue.selection.end;
    final offset = (text.length - fromEnd).clamp(1, text.length);

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

/// Bir telefon controller'ını güvenli şekilde "tohumlar":
///   • [initial] verilmişse onu normalize edip yazar (ör. login → register
///     geçişinde `?phone=`).
///   • Aksi halde alan boşsa varsayılan `+90` ile doldurur.
/// Zaten `+...` içeren doluysa dokunmaz.
void seedPhoneController(TextEditingController controller, {String? initial}) {
  final current = controller.text.trim();
  if (initial != null && initial.trim().isNotEmpty) {
    controller.text = normalizePhone(initial);
    return;
  }
  if (current.isEmpty || current == '+') {
    controller.text = kDefaultPhonePrefix;
  }
}

/// Girdiyi E.164 benzeri biçime indirger: `+` + yalnız rakamlar.
/// Boşsa boş string döner (çağıran doğrulamada yakalar).
String normalizePhone(String input) {
  final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.isEmpty ? '' : '+$digits';
}

/// Ortak telefon doğrulaması (ülke kodu dahil 8–15 rakam).
/// Belirli bir ülkeye kilitlemez — kullanıcı kendi ülke kodunu girebilir.
String? validatePhoneNumber(BuildContext context, String? value) {
  final l10n = context.l10n;
  final digits = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return l10n.valPhoneRequired;
  if (digits.length < 8 || digits.length > 15) return l10n.valPhoneInvalid;
  return null;
}

/// Uygulamadaki tüm telefon girişleri için ortak alan.
///
/// Sabit `+`, varsayılan `+90`, düzenlenebilir ülke kodu, telefon klavyesi ve
/// tutarlı doğrulama. Form içinde [validator] ile, form dışı (errorText) akışta
/// [errorText] ile kullanılabilir.
class PhoneNumberField extends StatelessWidget {
  const PhoneNumberField({
    super.key,
    required this.controller,
    this.labelText,
    this.hintText,
    this.validator,
    this.errorText,
    this.enabled = true,
    this.autofocus = false,
    this.onFieldSubmitted,
    this.borderRadius = 16,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final String? Function(String?)? validator;
  final String? errorText;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<String>? onFieldSubmitted;
  final double borderRadius;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: TextInputType.phone,
      textInputAction: textInputAction,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      inputFormatters: const [LeadingPlusPhoneFormatter()],
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText ?? '+90 5XX XXX XX XX',
        errorText: errorText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}
