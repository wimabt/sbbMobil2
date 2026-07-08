package com.smartsamsun.mobil

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingClient
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import org.json.JSONArray

/**
 * Native (OS) geofencing yöneticisi — Play Services GeofencingClient sarmalayıcı.
 *
 * Bölge içerikleri (başlık/mesaj/payload, aktif dilde) Dart'tan gelir ve
 * SharedPreferences'a yazılır; tetiklenince [GeofenceBroadcastReceiver] bunları
 * okuyup bildirimi gösterir (uygulama kapalı/Doze olsa bile). Reboot sonrası
 * [GeofenceBootReceiver] prefs'ten yeniden kaydeder.
 */
object GeofenceManager {
    const val PREFS = "sbb_geofence_native"
    const val KEY_ZONES = "zones"
    const val KEY_CHANNEL_ID = "channel_id"
    const val KEY_CHANNEL_NAME = "channel_name"
    const val KEY_CHANNEL_DESC = "channel_desc"
    const val KEY_COOLDOWN_HOURS = "cooldown_hours"
    const val KEY_PENDING_TAP = "pending_tap"
    const val EXTRA_PAYLOAD = "geofence_payload"
    const val ACTION = "com.smartsamsun.mobil.ACTION_GEOFENCE"
    private const val REQUEST_CODE = 90210

    private fun client(ctx: Context): GeofencingClient =
        LocationServices.getGeofencingClient(ctx.applicationContext)

    private fun transitionPendingIntent(ctx: Context): PendingIntent {
        val intent = Intent(ctx.applicationContext, GeofenceBroadcastReceiver::class.java)
            .setAction(ACTION)
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Geofencing PendingIntent Android 12+'da MUTABLE olmalı.
            flags = flags or PendingIntent.FLAG_MUTABLE
        }
        return PendingIntent.getBroadcast(ctx.applicationContext, REQUEST_CODE, intent, flags)
    }

    @SuppressLint("MissingPermission")
    fun register(
        ctx: Context,
        zonesJson: String,
        channelId: String,
        channelName: String,
        channelDesc: String,
        cooldownHours: Int
    ) {
        val app = ctx.applicationContext
        app.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString(KEY_ZONES, zonesJson)
            .putString(KEY_CHANNEL_ID, channelId)
            .putString(KEY_CHANNEL_NAME, channelName)
            .putString(KEY_CHANNEL_DESC, channelDesc)
            .putInt(KEY_COOLDOWN_HOURS, cooldownHours)
            .apply()

        val arr = JSONArray(zonesJson)
        val geofences = ArrayList<Geofence>()
        for (i in 0 until arr.length()) {
            val z = arr.getJSONObject(i)
            val id = z.optString("id")
            if (id.isEmpty()) continue
            val radius = z.optDouble("radius", 0.0).toFloat()
            if (radius <= 0f) continue
            geofences.add(
                Geofence.Builder()
                    .setRequestId(id)
                    .setCircularRegion(z.optDouble("lat"), z.optDouble("lng"), radius)
                    .setExpirationDuration(Geofence.NEVER_EXPIRE)
                    .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER)
                    .build()
            )
        }

        val pi = transitionPendingIntent(app)
        // Önce eskiyi temizle, tamamlanınca yenisini ekle (çakışma olmasın).
        client(app).removeGeofences(pi).addOnCompleteListener {
            if (geofences.isEmpty()) return@addOnCompleteListener
            val request = GeofencingRequest.Builder()
                .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
                .addGeofences(geofences)
                .build()
            client(app).addGeofences(request, pi)
        }
    }

    fun clear(ctx: Context) {
        val app = ctx.applicationContext
        client(app).removeGeofences(transitionPendingIntent(app))
        app.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .remove(KEY_ZONES).apply()
    }

    fun count(ctx: Context): Int {
        val raw = ctx.applicationContext
            .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_ZONES, null) ?: return 0
        return try { JSONArray(raw).length() } catch (e: Exception) { 0 }
    }

    /** Reboot / paket güncelleme sonrası prefs'ten yeniden kaydeder. */
    fun reRegisterFromPrefs(ctx: Context) {
        val prefs = ctx.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val zones = prefs.getString(KEY_ZONES, null) ?: return
        register(
            ctx,
            zones,
            prefs.getString(KEY_CHANNEL_ID, "location_alerts") ?: "location_alerts",
            prefs.getString(KEY_CHANNEL_NAME, "Konum Bildirimleri") ?: "Konum Bildirimleri",
            prefs.getString(KEY_CHANNEL_DESC, "") ?: "",
            prefs.getInt(KEY_COOLDOWN_HOURS, 24)
        )
    }
}
