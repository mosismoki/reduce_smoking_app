package com.example.reduce_smoking_app.notifications

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationManagerCompat

class ActionReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_ACCEPT = "SMOKE_ACCEPT"
        const val ACTION_SKIP   = "SMOKE_SKIP"
        const val ACTION_COUNTS_CHANGED = "SMOKE_COUNTS_CHANGED"

        private const val PREFS = "smoke_prefs"
        private const val KEY_SMOKED = "smoked_today"
        private const val KEY_SKIPPED = "skipped_today"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        when (intent.action) {
            ACTION_ACCEPT -> {
                val n = prefs.getInt(KEY_SMOKED, 0) + 1
                prefs.edit().putInt(KEY_SMOKED, n).apply()
                Log.d("ActionReceiver", "Accepted. smoked_today=$n")
            }
            ACTION_SKIP -> {
                val n = prefs.getInt(KEY_SKIPPED, 0) + 1
                prefs.edit().putInt(KEY_SKIPPED, n).apply()
                Log.d("ActionReceiver", "Skipped. skipped_today=$n")
            }
        }

        // Dismiss the posted notification if we got its id
        val notifId = intent.getIntExtra("notifId", -1)
        if (notifId != -1) NotificationManagerCompat.from(context).cancel(notifId)

        // Let the app (Flutter) know counters changed
        context.sendBroadcast(Intent(ACTION_COUNTS_CHANGED))
    }
}
