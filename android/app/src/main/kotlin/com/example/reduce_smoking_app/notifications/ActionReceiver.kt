package com.example.reduce_smoking_app.notifications

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.app.AlarmManager
import android.app.PendingIntent
import android.util.Log

class ActionReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_ACCEPT = "SMOKE_ACCEPT"
        const val ACTION_SKIP   = "SMOKE_SKIP"
        const val ACTION_COUNTS_CHANGED = "SMOKE_COUNTS_CHANGED" // local broadcast to app

        private const val PREFS = "smoke_prefs"
        private const val KEY_SMOKED = "smoked_today"
        private const val KEY_SKIPPED = "skipped_today"
        private const val KEY_NEXT_AT = "next_at_millis"
        private const val INTERVAL_MINUTES = 30 // TODO: replace with your real gap calc
    }

    override fun onReceive(context: Context, intent: Intent) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        var didAccept = false
        when (intent.action) {
            ACTION_ACCEPT -> {
                val n = prefs.getInt(KEY_SMOKED, 0) + 1
                prefs.edit().putInt(KEY_SMOKED, n).apply()
                didAccept = true
                Log.d("ActionReceiver", "Accepted. smoked_today=$n")
            }
            ACTION_SKIP -> {
                val n = prefs.getInt(KEY_SKIPPED, 0) + 1
                prefs.edit().putInt(KEY_SKIPPED, n).apply()
                Log.d("ActionReceiver", "Skipped. skipped_today=$n")
            }
        }

        // 1) Schedule next cigarette time in background (works even if app is closed)
        val nextAt = System.currentTimeMillis() + INTERVAL_MINUTES * 60_000L
        prefs.edit().putLong(KEY_NEXT_AT, nextAt).apply()
        scheduleNextAlarm(context, nextAt)

        // 2) Notify app (if it's running) so Flutter UI resets timer immediately
        val bcast = Intent(ACTION_COUNTS_CHANGED).apply {
            setPackage(context.packageName)
            putExtra("smoked_today", prefs.getInt(KEY_SMOKED, 0))
            putExtra("skipped_today", prefs.getInt(KEY_SKIPPED, 0))
            putExtra("action", if (didAccept) "accept" else "skip")
            putExtra("next_at_millis", nextAt)
        }
        context.sendBroadcast(bcast)
    }

    private fun scheduleNextAlarm(context: Context, triggerAtMillis: Long) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, ReminderReceiver::class.java) // your receiver that shows notification
        val pi = PendingIntent.getBroadcast(
            context,
            101,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
        Log.d("ActionReceiver", "Next alarm scheduled at $triggerAtMillis")
    }
}
