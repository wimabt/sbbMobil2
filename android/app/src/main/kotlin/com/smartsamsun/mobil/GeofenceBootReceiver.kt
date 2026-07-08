package com.smartsamsun.mobil

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Reboot / paket güncellemesi sonrası OS geofence'leri silinir. Bu receiver
 * kayıtlı bölgeleri SharedPreferences'tan yeniden kaydeder.
 */
class GeofenceBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWERON",
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                GeofenceManager.reRegisterFromPrefs(context)
            }
        }
    }
}
