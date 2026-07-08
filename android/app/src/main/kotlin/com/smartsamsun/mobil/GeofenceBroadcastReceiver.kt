package com.smartsamsun.mobil

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent
import org.json.JSONArray
import org.json.JSONObject

/**
 * Geofence ENTER tetiklemelerini alır (uygulama kapalı/Doze olsa bile OS uyandırır),
 * 24s cooldown'u kontrol eder ve admin-tanımlı bölge mesajıyla bildirim gösterir.
 * Bildirime dokununca MainActivity payload extra ile açılır → Dart deep-link.
 */
class GeofenceBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val event = GeofencingEvent.fromIntent(intent) ?: return
        if (event.hasError()) return
        if (event.geofenceTransition != Geofence.GEOFENCE_TRANSITION_ENTER) return
        val triggered = event.triggeringGeofences ?: return

        val app = context.applicationContext
        val prefs = app.getSharedPreferences(GeofenceManager.PREFS, Context.MODE_PRIVATE)
        val zonesRaw = prefs.getString(GeofenceManager.KEY_ZONES, null) ?: return
        val channelId = prefs.getString(GeofenceManager.KEY_CHANNEL_ID, "location_alerts")
            ?: "location_alerts"
        val channelName = prefs.getString(GeofenceManager.KEY_CHANNEL_NAME, "Konum Bildirimleri")
            ?: "Konum Bildirimleri"
        val channelDesc = prefs.getString(GeofenceManager.KEY_CHANNEL_DESC, "") ?: ""
        val cooldownMs = prefs.getInt(GeofenceManager.KEY_COOLDOWN_HOURS, 24).toLong() * 3_600_000L

        val zonesArr = try { JSONArray(zonesRaw) } catch (e: Exception) { return }
        val byId = HashMap<String, JSONObject>()
        for (i in 0 until zonesArr.length()) {
            val o = zonesArr.getJSONObject(i)
            byId[o.optString("id")] = o
        }

        ensureChannel(app, channelId, channelName, channelDesc)

        val now = System.currentTimeMillis()
        for (g in triggered) {
            val id = g.requestId ?: continue
            val z = byId[id] ?: continue
            val cdKey = "geofence_last_trigger_$id"
            val last = prefs.getLong(cdKey, 0L)
            if (now - last < cooldownMs) continue
            prefs.edit().putLong(cdKey, now).apply()
            showNotification(app, channelId, id, z)
        }
    }

    private fun ensureChannel(ctx: Context, id: String, name: String, desc: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val mgr = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (mgr.getNotificationChannel(id) == null) {
                val ch = NotificationChannel(id, name, NotificationManager.IMPORTANCE_HIGH)
                ch.description = desc
                mgr.createNotificationChannel(ch)
            }
        }
    }

    private fun showNotification(ctx: Context, channelId: String, id: String, z: JSONObject) {
        val title = z.optString("title", "")
        val body = z.optString("body", "")
        val deeplinkId = z.optString("deeplinkId", "")

        val tapIntent = Intent(ctx, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK)
        if (deeplinkId.isNotEmpty()) {
            val payload = JSONObject()
                .put("target", "district_detail")
                .put("id", deeplinkId)
            tapIntent.putExtra(GeofenceManager.EXTRA_PAYLOAD, payload.toString())
        }

        var piFlags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            piFlags = piFlags or PendingIntent.FLAG_IMMUTABLE
        }
        val contentPi = PendingIntent.getActivity(ctx, id.hashCode(), tapIntent, piFlags)

        val builder = NotificationCompat.Builder(ctx, channelId)
            .setSmallIcon(ctx.applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setColor(Color.parseColor("#26A69A"))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(contentPi)

        try {
            NotificationManagerCompat.from(ctx).notify(id.hashCode(), builder.build())
        } catch (e: SecurityException) {
            // POST_NOTIFICATIONS verilmemişse sessiz geç.
        }
    }
}
