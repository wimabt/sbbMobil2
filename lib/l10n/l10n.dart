// AppLocalizations extension for cleaner access in widgets
// 
// Usage:
// ```dart
// import 'package:sbb_mobile/l10n/l10n.dart';
// 
// // In a widget:
// Text(context.l10n.btnGetDirections)
// ```

import 'package:flutter/widgets.dart';
import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

/// Extension on BuildContext for easy access to localized strings
extension AppLocalizationsX on BuildContext {
  /// Shorthand for `AppLocalizations.of(context)!`
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
