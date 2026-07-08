import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// LogService - Production-ready logging utility
///
/// Wraps all logging so that verbose logs only appear in debug mode.
/// In release mode, logs are silenced for performance and security.
///
/// Call [LogService.enableFileLogging] once in main() to persist all
/// debugPrint output to a timestamped log file.
///
/// **Where the file goes**
/// - **Desktop** (Windows / macOS / Linux): `[project]/logs/flutter_*.log`
///   when you run `flutter run -d windows` (etc.) from the project root —
///   logs appear **inside this repo** under `logs/`.
/// - **Android / iOS**: app sandbox on the device only. Copy to the PC with
///   `scripts/pull_device_logs.ps1` (see [logs/README.md]).
class LogService {
  LogService._();

  /// Must match `android { defaultConfig { applicationId } }` in Gradle.
  static const String androidApplicationId = 'com.smartsamsun.mobil';

  static IOSink? _sink;
  static DebugPrintCallback? _originalDebugPrint;

  /// Starts writing ALL debugPrint output to a log file.
  /// Returns the file path for reference.
  static Future<String> enableFileLogging() async {
    // Capture the original debugPrint BEFORE overriding it.
    final originalPrint = debugPrint;
    _originalDebugPrint = originalPrint;

    final Directory logDir;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Desktop: write under project root (cwd is usually the repo when you
      // `flutter run -d windows` from the IDE / terminal).
      logDir = Directory('${Directory.current.path}/logs');
      if (!logDir.existsSync()) logDir.createSync(recursive: true);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      logDir = Directory('${dir.path}/logs');
      if (!logDir.existsSync()) logDir.createSync(recursive: true);
    }

    // Rotate: keep last 5 files
    final existing = logDir.listSync().whereType<File>().toList()
      ..sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
    while (existing.length >= 5) {
      existing.removeAt(0).deleteSync();
    }

    final ts = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final file = File('${logDir.path}/flutter_$ts.log');
    _sink = file.openWrite(mode: FileMode.append);

    _sink!.writeln('=== SBB Mobile Log — $ts ===\n');

    // Override global debugPrint to tee into file.
    // Use the captured local variable to avoid infinite recursion.
    debugPrint = (String? message, {int? wrapWidth}) {
      originalPrint(message, wrapWidth: wrapWidth);
      if (message != null && _sink != null) {
        _sink!.writeln(message);
      }
    };

    originalPrint('📝 [LogService] File logging enabled: ${file.path}');
    if (Platform.isAndroid) {
      originalPrint(
        '📝 [LogService] Bu dosya cihazda. PC\'de projeye almak için: '
        'PowerShell: .\\scripts\\pull_device_logs.ps1  (veya logs/README.md)',
      );
    } else if (Platform.isIOS) {
      originalPrint(
        '📝 [LogService] iOS: dosya simülatör/cihazda. PC\'ye almak için logs/README.md',
      );
    } else {
      originalPrint(
        '📝 [LogService] Masaüstü modu: log bu repodaki logs/ klasöründe.',
      );
    }
    return file.path;
  }

  /// Flush and close the log file (call on app exit if needed).
  static Future<void> dispose() async {
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
    if (_originalDebugPrint != null) {
      debugPrint = _originalDebugPrint!;
      _originalDebugPrint = null;
    }
  }

  /// Debug log - Only shows in debug mode
  /// Use for verbose development logs
  static void d(String message, {String? tag}) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag]' : '';
      debugPrint('🐛 $prefix $message');
    }
  }

  /// Info log - Only shows in debug mode
  /// Use for informational messages
  static void i(String message, {String? tag}) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag]' : '';
      debugPrint('ℹ️ $prefix $message');
    }
  }

  /// Warning log - Only shows in debug mode
  /// Use for non-critical issues
  static void w(String message, {String? tag}) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag]' : '';
      debugPrint('⚠️ $prefix $message');
    }
  }

  /// Error log - Only shows in debug mode
  /// Use for errors and exceptions
  static void e(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag]' : '';
      debugPrint('🔥 $prefix $message');
      if (error != null) {
        debugPrint('🔥 $prefix Error: $error');
      }
      if (stackTrace != null) {
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  /// Success log - Only shows in debug mode
  /// Use for successful operations
  static void s(String message, {String? tag}) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag]' : '';
      debugPrint('✅ $prefix $message');
    }
  }

  /// API log - Only shows in debug mode
  /// Use for API-related logs
  static void api(String message, {String? tag, bool isRequest = false, bool isResponse = false}) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag]' : '';
      final icon = isRequest ? '📡' : isResponse ? '✅' : '🌐';
      debugPrint('$icon $prefix $message');
    }
  }

  /// Network log - Only shows in debug mode
  /// Use for network-related logs (distances, location, etc.)
  static void network(String message, {String? tag}) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag]' : '';
      debugPrint('📍 $prefix $message');
    }
  }

  /// Performance log - Only shows in debug mode
  /// Use for performance-related logs
  static void perf(String message, {String? tag}) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag]' : '';
      debugPrint('⚡ $prefix $message');
    }
  }
}
