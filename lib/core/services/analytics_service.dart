import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/api_client.dart' show ApiException;
import '../../api/endpoints.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../network/api_service.dart';
import '../providers/locale_provider.dart';
import 'analytics_events.dart';
import 'log_service.dart';

/// Şartname §6.3.6 + mobile_integ.md §2 — Kullanıcı davranış izleme servisi.
///
/// Akış:
///   • `track()` event'i in-memory buffer'a yazar; her ekleme sonrası tek-yönlü
///     persist (SharedPreferences) yapılır, böylece app crash/kill durumunda
///     veri kaybedilmez.
///   • Buffer 30 event'e ulaşırsa veya 30 sn periyodik timer tetiklenirse
///     `flush()` çağrılır; app background'a girince de flush tetiklenir.
///   • `flush()` batch'i `POST /api/v1/analytics/events`'e gönderir
///     (maks 50 event/istek). 4xx → düş; 413/429/5xx → exponential backoff
///     ile en fazla 3 retry.
///   • Sunucu auth opsiyonel; anonim akış da çalışır.
class AnalyticsService with WidgetsBindingObserver {
  AnalyticsService(this._ref) : _sessionId = _newSessionId() {
    WidgetsBinding.instance.addObserver(this);
    _ref.onDispose(() {
      _periodicTimer?.cancel();
      _flushInFlight = null;
      WidgetsBinding.instance.removeObserver(this);
    });
    // Cold start'ta önceki kapanışın buffer'ını + opt-out flag'ini yükle ve
    // session açılışını yakala.
    unawaited(Future(() async {
      await _loadOptOutState();
      await _restoreBuffer();
      track(AnalyticsEvents.sessionStart);
      _periodicTimer = Timer.periodic(_flushInterval, (_) {
        unawaited(flush());
      });
      // Cold start sonrası persist edilmiş buffer'ı sunucuya teslim etmeyi dene.
      unawaited(flush());
    }));
  }

  final Ref _ref;
  final String _sessionId;
  final List<AnalyticsEvent> _buffer = [];

  Timer? _periodicTimer;
  Future<void>? _flushInFlight;
  DateTime? _lastFlushAt;

  /// `mobile_analytics_todo.md` §1.2 — kullanıcı opt-out toggle'ı. Default
  /// `true`. `false` iken hiçbir event üretilmez (sadece `auth_*` zorunlu).
  bool _enabled = true;

  static const int _maxBufferSize = 200;        // §1.2 LRU tavanı
  static const int _flushThreshold = 30;
  static const int _maxBatchSize = 50;
  static const int _maxRetries = 3;
  static const Duration _flushInterval = Duration(seconds: 30);
  static const Duration _cellularMinInterval = Duration(seconds: 60); // §1.2
  static const String _kBufferKey = 'analytics_pending_v1';
  static const String _kOptOutKey = 'analytics_enabled';
  static const String _kAppVersion = '1.0.0'; // pubspec.yaml `version`

  /// Auth ile bağımsız davranan, opt-out edilemeyen event'ler — §1.2 madde 6.
  /// Bu liste dışındaki event'ler `_enabled=false` iken üretilmez.
  static const Set<String> _alwaysOnEvents = {
    AnalyticsEvents.authLogin,
    AnalyticsEvents.authLogout,
    AnalyticsEvents.authRegister,
  };

  @visibleForTesting
  List<AnalyticsEvent> get pending => List.unmodifiable(_buffer);

  String get sessionId => _sessionId;

  /// Tek olay yakala. Çağıran taraf `await` etmek zorunda değildir.
  ///
  /// Opt-out kapalıyken (`_enabled=false`) sadece `_alwaysOnEvents`
  /// listesindeki event'ler (auth_*) üretilir; geri kalanı sessizce drop edilir.
  ///
  /// PII güvenliği için properties `_sanitize()` üzerinden geçer (§1.2):
  ///   * `query` ≤ 64 karakter
  ///   * `website_tapped.url` → host
  ///   * `error_occurred` → stack trace yok, message ≤ 80 karakter
  ///   * phone/email/password/token alanları her zaman silinir
  void track(String eventName, {Map<String, Object?>? properties}) {
    if (!_enabled && !_alwaysOnEvents.contains(eventName)) return;

    final auth = _ref.read(authProvider);
    final locale = _ref.read(localeProvider).locale.languageCode;
    final sanitized = _sanitize(eventName, properties ?? const {});
    final entry = AnalyticsEvent(
      name: eventName,
      properties: sanitized,
      occurredAt: DateTime.now().toUtc(),
      sessionId: _sessionId,
      userId: auth.user?.id,
      platform: _platformLabel(),
      locale: locale,
      appVersion: _kAppVersion,
    );
    _buffer.add(entry);
    // §1.2 LRU cap — bellek tavanını aştıysak en eskileri at; OOM > data loss.
    if (_buffer.length > _maxBufferSize) {
      _buffer.removeRange(0, _buffer.length - _maxBufferSize);
    }
    unawaited(_persistBuffer());
    if (kDebugMode) {
      debugPrint(
        '[Analytics] ${entry.name} '
        '${entry.properties.isEmpty ? '' : entry.properties}',
      );
    }
    if (_buffer.length >= _flushThreshold) {
      unawaited(flush());
    }
  }

  /// User opt-out toggle. `false` → buffer da temizlenir (gönderilmemiş
  /// event'ler de gitsin); SharedPreferences'a persist edilir.
  Future<void> setEnabled(bool value) async {
    _enabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kOptOutKey, value);
    } catch (e) {
      if (kDebugMode) debugPrint('[Analytics] opt-out persist failed: $e');
    }
    if (!value) {
      _buffer.clear();
      unawaited(_persistBuffer());
    }
  }

  /// Mevcut opt-out durumu (UI binding için).
  bool get isEnabled => _enabled;

  Future<void> _loadOptOutState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_kOptOutKey) ?? true;
    } catch (e) {
      if (kDebugMode) debugPrint('[Analytics] opt-out load failed: $e');
      _enabled = true;
    }
  }

  /// Sayfa/ekran görüntüleme. NavigatorObserver tarafından otomatik çağrılır.
  void screenView(String screenName, {Map<String, Object?>? extra}) {
    track(
      AnalyticsEvents.screenView,
      properties: {
        'screen_name': screenName,
        if (extra != null) ...extra,
      },
    );
  }

  /// Buffer'ı sunucuya gönderir. Aynı anda yalnızca tek flush çalışır;
  /// çağıran taraflar `await` edebilir (logout pre-flush gibi).
  Future<void> flush() {
    final inFlight = _flushInFlight;
    if (inFlight != null) return inFlight;
    if (_buffer.isEmpty) return Future.value();
    final fut = _doFlush();
    _flushInFlight = fut;
    fut.whenComplete(() {
      if (identical(_flushInFlight, fut)) _flushInFlight = null;
    });
    return fut;
  }

  Future<void> _doFlush() async {
    // §1.2 — cellular tasarrufu: hücresel ağdaysak son flush üstünden 60 sn
    // geçmediyse skip et. WiFi'de min aralık yok (30 sn timer tick'i zaten yeterli).
    if (_lastFlushAt != null && await _isCellular()) {
      final since = DateTime.now().difference(_lastFlushAt!);
      if (since < _cellularMinInterval) {
        if (kDebugMode) {
          debugPrint(
            '[Analytics] flush skipped — cellular throttle '
            '(${_cellularMinInterval.inSeconds - since.inSeconds}s left)',
          );
        }
        return;
      }
    }
    while (_buffer.isNotEmpty) {
      final batch = _buffer.take(_maxBatchSize).toList(growable: false);
      final sent = await _sendBatch(batch);
      if (!sent) return; // retry'lar tükendi; buffer dursun, sonra tekrar dene
      _buffer.removeRange(0, batch.length);
      _lastFlushAt = DateTime.now();
      await _persistBuffer();
    }
  }

  Future<bool> _isCellular() async {
    try {
      final results = await Connectivity().checkConnectivity();
      // connectivity_plus 6.x → List<ConnectivityResult>
      return results.contains(ConnectivityResult.mobile) &&
          !results.contains(ConnectivityResult.wifi) &&
          !results.contains(ConnectivityResult.ethernet);
    } catch (_) {
      return false; // emin değilsek throttle uygulama, WiFi varsay
    }
  }

  /// Tek batch'i exponential backoff ile gönderir.
  /// Dönüş: `true` → batch sunucuya teslim edildi (ya 2xx ya da 4xx-drop);
  ///         `false` → ağ/sunucu hatası, buffer'da kalmalı.
  Future<bool> _sendBatch(List<AnalyticsEvent> batch) async {
    final dio = _ref.read(apiServiceProvider).dio;
    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final body = {'events': batch.map((e) => e.toJson()).toList()};
        await dio.post(
          ApiEndpoints.analyticsEvents,
          data: body,
          options: Options(
            // Anonim akış destekli — header'ı boş bırakmaya gerek yok,
            // ApiService interceptor'ı token varsa otomatik ekler.
            validateStatus: (status) => status != null && status < 500,
          ),
        );
        return true;
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (status != null && status >= 400 && status < 500 &&
            status != 408 && status != 413 && status != 429) {
          // 400 → event geçersiz; drop edip ilerle.
          LogService.w(
            'Analytics batch dropped (HTTP $status): ${ApiException.fromDioError(e).message}',
            tag: 'Analytics',
          );
          return true;
        }
        // 413 / 429 / 5xx / network → backoff + retry.
        final delay = Duration(milliseconds: 500 * (1 << attempt));
        if (kDebugMode) {
          debugPrint(
            '[Analytics] flush attempt ${attempt + 1} failed (status=$status), '
            'retrying in ${delay.inMilliseconds}ms',
          );
        }
        await Future<void>.delayed(delay);
      }
    }
    return false;
  }

  /// Buffer'ı SharedPreferences'a serileştir. Crash/kill durumunda kullanılır.
  Future<void> _persistBuffer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_buffer.isEmpty) {
        await prefs.remove(_kBufferKey);
        return;
      }
      final encoded = jsonEncode(_buffer.map((e) => e.toJson()).toList());
      await prefs.setString(_kBufferKey, encoded);
    } catch (e) {
      if (kDebugMode) debugPrint('[Analytics] persist failed: $e');
    }
  }

  Future<void> _restoreBuffer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kBufferKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      for (final entry in decoded) {
        if (entry is Map<String, dynamic>) {
          _buffer.add(AnalyticsEvent.fromJson(entry));
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Analytics] restore failed: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(flush());
    }
  }

  static String _newSessionId() {
    final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
    final rand = Random.secure().nextInt(1 << 32).toRadixString(16);
    return '$ts-$rand';
  }

  static String _platformLabel() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      if (Platform.isMacOS) return 'macos';
      if (Platform.isWindows) return 'windows';
      if (Platform.isLinux) return 'linux';
    } catch (_) {
      // Platform unsupported on this build target.
    }
    return 'unknown';
  }

  /// `mobile_analytics_todo.md` §6 — PII filtreleme.
  ///
  /// Kuralllar:
  ///   * `query` alanı (varsa) trim + 64 karakter cap.
  ///   * `website_tapped`: `url` → `host` (tam URL gönderilmez).
  ///   * `error_occurred`: `stack`/`stack_trace` silinir, `message` ≤ 80 chr.
  ///   * Her event için: anahtarında `phone`, `email`, `password`, `token`
  ///     geçen alanlar silinir. (`phone_tapped` event ADI hariç — orada zaten
  ///     `entity_id` gibi nötr alanlar var.)
  @visibleForTesting
  static Map<String, Object?> sanitize(
    String eventName,
    Map<String, Object?> props,
  ) =>
      _sanitize(eventName, props);

  static Map<String, Object?> _sanitize(
    String eventName,
    Map<String, Object?> props,
  ) {
    if (props.isEmpty) return const {};
    final out = Map<String, Object?>.from(props);

    // query trim + cap
    final q = out['query'];
    if (q is String) {
      final trimmed = q.trim();
      out['query'] = trimmed.length > 64 ? trimmed.substring(0, 64) : trimmed;
    }

    // website_tapped: tam URL gönderme; sadece host
    if (eventName == AnalyticsEvents.websiteTapped && out['url'] is String) {
      try {
        out['host'] = Uri.parse(out['url']! as String).host;
      } catch (_) {
        // parse edemediysek sessizce vazgeç
      }
      out.remove('url');
    }

    // error_occurred: stack trace dışarı çıkmaz; mesajı kırp
    if (eventName == AnalyticsEvents.errorOccurred) {
      out.remove('stack');
      out.remove('stack_trace');
      out.remove('stackTrace');
      final m = out['message'];
      if (m is String && m.length > 80) {
        out['message'] = m.substring(0, 80);
      }
    }

    // PII keywords — anahtarda geçen her şey silinir.
    // Not: `phone_tapped` event ADI'ndaki "phone" property anahtarı değil;
    // property tarafında bu alanlar bulunmamalı zaten.
    out.removeWhere((k, _) {
      final ks = k.toLowerCase();
      return ks.contains('phone_number') ||
          ks.contains('email') ||
          ks.contains('password') ||
          ks.contains('token') ||
          ks == 'phone';
    });

    return out;
  }
}

class AnalyticsEvent {
  const AnalyticsEvent({
    required this.name,
    required this.properties,
    required this.occurredAt,
    required this.sessionId,
    required this.platform,
    required this.locale,
    required this.appVersion,
    this.userId,
  });

  final String name;
  final Map<String, Object?> properties;
  final DateTime occurredAt;
  final String sessionId;
  final String? userId;
  final String platform;
  final String locale;
  final String appVersion;

  Map<String, Object?> toJson() => {
        'event_name': name,
        'properties': properties,
        'occurred_at': occurredAt.toIso8601String(),
        'session_id': sessionId,
        if (userId != null) 'user_id': userId,
        'platform': platform,
        'locale': locale,
        'app_version': appVersion,
      };

  factory AnalyticsEvent.fromJson(Map<String, dynamic> json) {
    return AnalyticsEvent(
      name: json['event_name'] as String? ?? 'unknown',
      properties: (json['properties'] as Map?)?.cast<String, Object?>() ??
          const {},
      occurredAt: DateTime.tryParse(json['occurred_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
      sessionId: json['session_id'] as String? ?? '',
      userId: json['user_id'] as String?,
      platform: json['platform'] as String? ?? 'unknown',
      locale: json['locale'] as String? ?? 'tr',
      appVersion: json['app_version'] as String? ?? '1.0.0',
    );
  }
}

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService(ref);
});
