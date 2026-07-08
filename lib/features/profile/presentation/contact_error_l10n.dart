import 'package:flutter/foundation.dart';

import '../../../l10n/l10n.dart';
import 'providers/account_contact_provider.dart';

/// Backend hata kodunu lokalize mesaja çevirir.
///
/// Bilinen bir hata kodu varsa lokalize mesaj döner. Kod eşlenmemişse:
/// backend serbest-metin mesajı varsa onu (daha doğru/teşhis edici), yoksa
/// jenerik mesajı gösterir. Debug modda, tanıyı kolaylaştırmak için HTTP
/// status kodu da eklenir.
String contactErrorMessage(AppLocalizations l10n, ContactActionResult res) {
  switch (res.errorCode) {
    case ContactErrorCodes.emailRequiredFirst:
      return l10n.contactErrorEmailRequiredFirst;
    case ContactErrorCodes.changeAlreadyPending:
      return l10n.contactErrorChangePending;
    case ContactErrorCodes.invalidCode:
      return l10n.contactErrorInvalidCode;
    case ContactErrorCodes.codeExpired:
      return l10n.contactErrorCodeExpired;
    case ContactErrorCodes.tooManyAttempts:
      return l10n.contactErrorTooManyAttempts;
    case ContactErrorCodes.rateLimited:
      return l10n.contactErrorRateLimited;
    case ContactErrorCodes.valueAlreadyInUse:
      return l10n.contactErrorValueInUse;
    case ContactErrorCodes.sameValue:
      return l10n.contactErrorSameValue;
    default:
      final backendMsg = res.message?.trim();
      final base = (backendMsg != null && backendMsg.isNotEmpty)
          ? backendMsg
          : l10n.contactErrorGeneric;
      if (kDebugMode && res.statusCode != null) {
        return '$base (HTTP ${res.statusCode})';
      }
      return base;
  }
}
