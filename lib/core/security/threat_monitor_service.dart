import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freerasp/freerasp.dart';

import '../services/log_service.dart';

/// Runtime Application Self-Protection (RASP) izleme servisi — freeRASP/Talsec.
///
/// [DeviceIntegrityService] (flutter_jailbreak_detection) yalnızca root/jailbreak
/// bakıyordu. Bu servis onu genişletir; native seviyede şunları tespit eder:
/// - **Hooking framework** (Frida, Xposed, Shadow) → `Threat.hooks`
/// - **Debugger bağlı** → `Threat.debug`
/// - **Emülatör / simülatör** → `Threat.simulator`
/// - **Repack / imza değişikliği** (APK yeniden imzalanmış) → `Threat.appIntegrity`
/// - **Root / jailbreak** (Magisk, unc0ver, Dopamine…) → `Threat.privilegedAccess`
/// - **Resmî olmayan mağaza / yükleme** → `Threat.unofficialStore`
/// - Cihaz-bağı kopması, güvenli donanım yokluğu, ADB, dev mode, ekran kaydı…
///
/// Tasarım kararları:
/// - `killOnBypass: false` — uygulamayı native tarafta SERT kapatmıyoruz. Bazı
///   sinyaller (systemVPN, devMode, unsecureWiFi) meşru kullanıcılarda da çıkar;
///   sert kill yanlış-pozitifte çökme demek olurdu. Tehditleri Dart tarafında
///   toplayıp yalnızca KRİTİK olanları UX kısıtına bağlıyoruz ([isCritical]).
/// - `isProd: !kDebugMode` — debug'da dev moduna alır (debugger/emülatör sürekli
///   alarm vermesin; geliştirme bloke olmasın).
///
/// Konfigürasyon `--dart-define` ile verilir (gerçek release değerleri
/// `scripts/build_release.*` içinden enjekte edilir; kaynağa gömülmez):
/// - `SECURITY_WATCHER_MAIL`   → haftalık Talsec güvenlik raporu e-postası
/// - `ANDROID_SIGNING_HASHES`  → release imza sertifikası SHA-256 (base64),
///                               virgülle ayrılmış. Boşsa debug hash kullanılır.
/// - `IOS_TEAM_ID`             → Apple Developer Team ID (repack tespiti için)
/// - `IOS_BUNDLE_IDS`          → izinli bundle id(ler), virgülle ayrılmış
class ThreatMonitorService {
  ThreatMonitorService._();

  static const String _watcherMail = String.fromEnvironment(
    'SECURITY_WATCHER_MAIL',
    defaultValue: 'guvenlik@smartsamsun.com',
  );

  static const String _androidHashesRaw = String.fromEnvironment(
    'ANDROID_SIGNING_HASHES',
    // Debug keystore imza hash'i (2026-07-07 `gradlew :app:signingReport`).
    // Release build'de `--dart-define=ANDROID_SIGNING_HASHES=<release-hash>`
    // ile override edilir; aksi halde her release'de appIntegrity alarmı çıkar.
    defaultValue: 'xuFnOVjQjpx+4lx8rArhhiWXwWHbWbg087AgPw095ZY=',
  );

  static const String _packageName = 'com.smartsamsun.mobil';

  static const String _iosTeamId = String.fromEnvironment(
    'IOS_TEAM_ID',
    defaultValue: '',
  );

  static const String _iosBundleIdsRaw = String.fromEnvironment(
    'IOS_BUNDLE_IDS',
    defaultValue: 'com.smartsamsun.mobil',
  );

  static List<String> _split(String raw) => raw
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);

  static bool _started = false;

  /// Şu ana dek tespit edilen tehditler (main isolate ömrü boyunca birikir).
  static final Set<Threat> _detected = <Threat>{};

  /// Yeni tehdit tespit edildiğinde tetiklenir (UI provider'ları dinler).
  static final StreamController<Set<Threat>> _threatController =
      StreamController<Set<Threat>>.broadcast();

  static Stream<Set<Threat>> get threatStream => _threatController.stream;

  static Set<Threat> get detectedThreats => Set.unmodifiable(_detected);

  /// UX kısıtına (QR ödeme / puan işlemleri) yol açan KRİTİK tehditler.
  /// systemVPN/devMode/unsecureWiFi gibi düşük-güven sinyalleri hariç.
  static const Set<Threat> _criticalThreats = {
    Threat.hooks,
    Threat.privilegedAccess,
    Threat.appIntegrity,
    Threat.debug,
    Threat.simulator,
    Threat.unofficialStore,
    Threat.deviceBinding,
  };

  static bool get hasCriticalThreat =>
      _detected.any(_criticalThreats.contains);

  /// Uygulama başlangıcında bir kez çağrılır (main.dart paralel görevleri).
  ///
  /// Desteklenmeyen platformlarda (web/desktop) veya hata durumunda sessizce
  /// no-op olur — uygulama açılışı asla bloke edilmez.
  static Future<void> start() async {
    if (_started) return;
    if (!(Platform.isAndroid || Platform.isIOS)) return;

    try {
      Talsec.instance.attachListener(_buildCallback());

      final config = TalsecConfig(
        watcherMail: _watcherMail,
        isProd: !kDebugMode,
        killOnBypass: false,
        androidConfig: Platform.isAndroid
            ? AndroidConfig(
                packageName: _packageName,
                signingCertHashes: _split(_androidHashesRaw),
                supportedStores: const ['com.android.vending'],
              )
            : null,
        iosConfig: Platform.isIOS
            ? IOSConfig(
                bundleIds: _split(_iosBundleIdsRaw),
                teamId: _iosTeamId,
              )
            : null,
      );

      await Talsec.instance.start(config);
      _started = true;
      LogService.i('ThreatMonitor (freeRASP) started', tag: 'Security');
    } catch (e, st) {
      LogService.e(
        'ThreatMonitor start failed — RASP korumasız devam ediyor',
        tag: 'Security',
        error: e,
        stackTrace: st,
      );
    }
  }

  static void _record(Threat threat) {
    _detected.add(threat);
    _threatController.add(detectedThreats);
    final critical = _criticalThreats.contains(threat);
    LogService.w(
      '${critical ? '🚨 KRİTİK' : '⚠️'} RASP tehdit: ${threat.name}',
      tag: 'Security',
    );
  }

  static ThreatCallback _buildCallback() => ThreatCallback(
        onHooks: () => _record(Threat.hooks),
        onDebug: () => _record(Threat.debug),
        onSimulator: () => _record(Threat.simulator),
        onAppIntegrity: () => _record(Threat.appIntegrity),
        onPrivilegedAccess: () => _record(Threat.privilegedAccess),
        onUnofficialStore: () => _record(Threat.unofficialStore),
        onDeviceBinding: () => _record(Threat.deviceBinding),
        onObfuscationIssues: () => _record(Threat.obfuscationIssues),
        onDeviceID: () => _record(Threat.deviceId),
        onPasscode: () => _record(Threat.passcode),
        onSecureHardwareNotAvailable: () =>
            _record(Threat.secureHardwareNotAvailable),
        onSystemVPN: () => _record(Threat.systemVPN),
        onDevMode: () => _record(Threat.devMode),
        onADBEnabled: () => _record(Threat.adbEnabled),
        onScreenshot: () => _record(Threat.screenshot),
        onScreenRecording: () => _record(Threat.screenRecording),
        onMultiInstance: () => _record(Threat.multiInstance),
        onUnsecureWiFi: () => _record(Threat.unsecureWiFi),
        onTimeSpoofing: () => _record(Threat.timeSpoofing),
        onLocationSpoofing: () => _record(Threat.locationSpoofing),
        onAutomation: () => _record(Threat.automation),
      );
}

// ─── Riverpod Provider'ları ───────────────────────────────────────────────────

/// Tespit edilen tehdit kümesini canlı yayınlar. Başlangıçta o ana dek
/// birikmiş tehditlerle seed'lenir, sonra stream'i dinler.
final activeThreatsProvider = StreamProvider<Set<Threat>>((ref) {
  return ThreatMonitorService.threatStream;
});

/// Kritik bir RASP tehdidi (hook/root/repack/debugger…) aktif mi?
///
/// [deviceIntegrityProvider] (jailbreak) ile birlikte QR ödeme gibi riskli
/// özelliklerin gate'lenmesinde kullanılır. `activeThreatsProvider`'ı izler ki
/// yeni tehdit geldikçe yeniden değerlensin; kararı statik durumdan verir.
final criticalThreatProvider = Provider<bool>((ref) {
  ref.watch(activeThreatsProvider);
  return ThreatMonitorService.hasCriticalThreat;
});
