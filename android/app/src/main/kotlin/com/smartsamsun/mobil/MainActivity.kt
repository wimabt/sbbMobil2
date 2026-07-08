package com.smartsamsun.mobil

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.view.WindowManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private val channelName = "com.smartsamsun.mobil/secure_screen"
  private val prefsRecoveryChannel = "com.smartsamsun.mobil/prefs_recovery"
  private val geofenceChannel = "com.smartsamsun.mobil/geofence"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "enable" -> {
            runOnUiThread { window.addFlags(WindowManager.LayoutParams.FLAG_SECURE) }
            result.success(null)
          }
          "disable" -> {
            runOnUiThread { window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE) }
            result.success(null)
          }
          else -> result.notImplemented()
        }
      }

    // Legacy SharedPreferences XML'i bozulduğunda (java.io.EOFException via
    // LegacySharedPreferencesPlugin$ListEncoder.decode) Flutter tarafından
    // erişilemez hale geliyor. Bu kanal, Dart tarafının native temizleme
    // yapmasına izin verir — path tahminine gerek yok, doğrudan
    // Context.getSharedPreferences() üzerinden silinir.
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, prefsRecoveryChannel)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "clearFlutterPrefs" -> {
            try {
              val prefs = applicationContext
                .getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
              val committed = prefs.edit().clear().commit()
              result.success(committed)
            } catch (e: Exception) {
              result.error("clear_failed", e.message, null)
            }
          }
          else -> result.notImplemented()
        }
      }

    // ── Native geofencing köprüsü ──────────────────────────────────────────
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, geofenceChannel)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "registerZones" -> {
            try {
              GeofenceManager.register(
                applicationContext,
                call.argument<String>("zones") ?: "[]",
                call.argument<String>("channelId") ?: "location_alerts",
                call.argument<String>("channelName") ?: "Konum Bildirimleri",
                call.argument<String>("channelDesc") ?: "",
                call.argument<Int>("cooldownHours") ?: 24
              )
              result.success(null)
            } catch (e: Exception) {
              result.error("register_failed", e.message, null)
            }
          }
          "clearZones" -> {
            GeofenceManager.clear(applicationContext)
            result.success(null)
          }
          "monitoredCount" -> result.success(GeofenceManager.count(applicationContext))
          "consumePendingTap" -> {
            val prefs = applicationContext
              .getSharedPreferences(GeofenceManager.PREFS, Context.MODE_PRIVATE)
            val payload = prefs.getString(GeofenceManager.KEY_PENDING_TAP, null)
            if (payload != null) {
              prefs.edit().remove(GeofenceManager.KEY_PENDING_TAP).apply()
            }
            result.success(payload)
          }
          "requestAlwaysPermission" -> {
            val granted = ContextCompat.checkSelfPermission(
              applicationContext,
              android.Manifest.permission.ACCESS_BACKGROUND_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
            result.success(granted)
          }
          else -> result.notImplemented()
        }
      }

    // Uygulama, geofence bildirimine dokunularak (kapalıyken) açıldıysa launch
    // intent'inde payload taşır — sakla; Dart drainPendingTap ile çeker.
    stashGeofenceTap(intent)
  }

  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    setIntent(intent)
    stashGeofenceTap(intent)
  }

  private fun stashGeofenceTap(intent: Intent?) {
    val payload = intent?.getStringExtra(GeofenceManager.EXTRA_PAYLOAD) ?: return
    applicationContext
      .getSharedPreferences(GeofenceManager.PREFS, Context.MODE_PRIVATE)
      .edit().putString(GeofenceManager.KEY_PENDING_TAP, payload).apply()
  }
}
