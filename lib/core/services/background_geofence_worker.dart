import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'log_service.dart';

// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  BACKGROUND GEOFENCE WORKER - WorkManager (LEGACY / DEVRE DIŞI)          ║
// ╠══════════════════════════════════════════════════════════════════════════╣
// ║  Eski 15 dk polling tabanlı geofence bildirimi ARTIK KULLANILMIYOR.     ║
// ║  Tek kaynak: native (OS) event geofencing (Android GeofencingClient /   ║
// ║  iOS region monitoring) → bkz. native_geofence_service.dart.            ║
// ║                                                                          ║
// ║  Bu dosya yalnızca eski kurulumlarda OS'ta zamanlanmış kalmış olabilen  ║
// ║  periyodik görevi GÜVENLE İPTAL etmek için tutulur; callbackDispatcher  ║
// ║  tetiklenirse bildirim GÖSTERMEZ (polling + native = çift bildirimdi).  ║
// ╚══════════════════════════════════════════════════════════════════════════╝

/// WorkManager task adı — benzersiz olmalı
const String kGeofenceTaskName = 'com.sbb.geofence_check';

/// WorkManager unique task adı (periodic task için)
const String kGeofenceUniqueTaskName = 'sbb_geofence_periodic';

/// SharedPreferences key: Background geofencing etkin mi?
const String kGeofenceEnabledKey = 'geofence_bg_enabled';

// ═══════════════════════════════════════════════════════════════════════════════
// TOP-LEVEL CALLBACK — WorkManager tarafından çağrılır
// ═══════════════════════════════════════════════════════════════════════════════

/// WorkManager dispatcher — bu fonksiyon TOP-LEVEL olmalı
///
/// `main.dart`'ta `Workmanager().initialize(callbackDispatcher)` ile kayıt edilir.
///
/// ARTIK BİLDİRİM GÖSTERMEZ: geofence bildirimleri tek kaynak olan native (OS)
/// event geofencing'e taşındı. Eski kurulumlardan OS'ta zamanlanmış kalmış
/// periyodik görev tetiklenirse, burada yalnızca kendini iptal ederiz — böylece
/// "Hoş Geldiniz" (native) + "Sınırlarındasınız" (polling) çift bildirimi olmaz.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    debugPrint(
      '🛑 [GeofenceBG] Legacy polling task fired ($taskName) → '
      'bildirim gösterilmiyor, görev iptal ediliyor (native geofencing aktif).',
    );
    // Eski periyodik görevi kalıcı olarak kaldır (native tek kaynak).
    try {
      await Workmanager().cancelByUniqueName(kGeofenceUniqueTaskName);
    } catch (_) {/* önemli değil */}
    return true;
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API — main.dart ve geofence_service.dart'tan çağrılır
// ═══════════════════════════════════════════════════════════════════════════════

/// WorkManager'ı başlat (main.dart'ta çağrılır)
///
/// Bu sadece bir kez çağrılmalı. Callback'i kayıt eder.
Future<void> initializeGeofenceWorker() async {
  await Workmanager().initialize(
    callbackDispatcher,
  );
  LogService.i('WorkManager initialized for geofence checks', tag: 'GeofenceBG');
}

/// Periyodik geofence kontrolünü başlat
///
/// Android'de minimum interval ~15 dakikadır.
/// iOS'ta BGTaskScheduler OS'un kararıyla çalışır.
Future<void> startPeriodicGeofenceCheck() async {
  // SharedPreferences'a etkin olduğunu kaydet
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(kGeofenceEnabledKey, true);

  await Workmanager().registerPeriodicTask(
    kGeofenceUniqueTaskName,
    kGeofenceTaskName,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: false,
      requiresCharging: false,
      requiresDeviceIdle: false,
      requiresStorageNotLow: false,
    ),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    backoffPolicy: BackoffPolicy.linear,
    backoffPolicyDelay: const Duration(minutes: 5),
    tag: 'geofence',
  );

  LogService.s(
    'Periodic geofence check registered (every ~15 min)',
    tag: 'GeofenceBG',
  );
}

/// Eski periyodik WorkManager görevini SADECE iptal eder (etkin bayrağına
/// `geofence_bg_enabled` DOKUNMADAN). Native geofencing'e geçişte, eski
/// kurulumlarda kayıtlı kalmış 15 dk polling görevini temizlemek için enable()
/// içinden çağrılır — servisin etkin durumu bozulmaz.
Future<void> cancelLegacyPeriodicGeofenceTask() async {
  try {
    await Workmanager().cancelByUniqueName(kGeofenceUniqueTaskName);
    LogService.i('Legacy periodic geofence task cancelled', tag: 'GeofenceBG');
  } catch (e) {
    LogService.w('cancelLegacyPeriodicGeofenceTask failed: $e', tag: 'GeofenceBG');
  }
}

/// Periyodik geofence kontrolünü durdur
Future<void> stopPeriodicGeofenceCheck() async {
  // SharedPreferences'a devre dışı olduğunu kaydet
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(kGeofenceEnabledKey, false);

  await Workmanager().cancelByUniqueName(kGeofenceUniqueTaskName);

  LogService.i('Periodic geofence check cancelled', tag: 'GeofenceBG');
}
