package com.example.reduce_smoking_app.notifications

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.edit
import kotlin.math.max

class ActionReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_ACCEPT = "SMOKE_ACCEPT"
        const val ACTION_SKIP   = "SMOKE_SKIP"
        const val ACTION_WINDOW_TIMEOUT = "WINDOW_TIMEOUT"

        const val ACTION_COUNTS_CHANGED = "SMOKE_COUNTS_CHANGED"

        private const val FLUTTER_PREF_FILE = "FlutterSharedPreferences"
        private const val PFX = "flutter."

        private const val KEY_SMOKED = PFX + "smoked_today"
        private const val KEY_SKIPPED = PFX + "skipped_today"
        private const val KEY_CIGS_PER_DAY = PFX + "cigsPerDay"
        private const val KEY_WINDOW_END_TS = PFX + "smokingWindowEndTs"
        private const val KEY_NEXT_TS = PFX + "nextCigTimestamp"

        private const val MIN_INTERVAL_SEC = 30

        private const val REQ_REMINDER_NEXT_AT = 101
        private const val REQ_WINDOW_TIMEOUT   = 202
    }

    private fun getFlutterInt(prefs: SharedPreferences, key: String, def: Int = 0): Int {
        val v = prefs.all[key]
        return when (v) {
            is Int -> v
            is Long -> v.toInt()
            is String -> v.toIntOrNull() ?: def
            else -> def
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val prefs = context.getSharedPreferences(FLUTTER_PREF_FILE, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()

        val raw = getFlutterInt(prefs, KEY_CIGS_PER_DAY, 1)
        val cpd = raw.coerceIn(1, 2000)
        val intervalSec = max(MIN_INTERVAL_SEC, (86400.0 / cpd).toInt())
        val intervalMs = intervalSec * 1000L

        var windowEnd = 0L
        var nextAt = 0L
        var didAccept = false
        var didSkip = false

        when (intent.action) {
            ACTION_ACCEPT -> {
                cancelWindowTimeout(context)
                didAccept = true
                windowEnd = now + 5 * 60_000L
                nextAt = windowEnd + intervalMs

                val smoked = getFlutterInt(prefs, KEY_SMOKED, 0) + 1
                prefs.edit {
                    putInt(KEY_SMOKED, smoked)
                    putLong(KEY_WINDOW_END_TS, windowEnd)
                    putLong(KEY_NEXT_TS, nextAt)
                }

                SmokingNotification.showSmokingCountdown(context, windowEnd)
                scheduleWindowTimeout(context, windowEnd)

                cancelNextReminder(context)
                scheduleNextReminder(context, nextAt)
            }

            ACTION_SKIP -> {
                cancelWindowTimeout(context)
                didSkip = true
                val skipped = getFlutterInt(prefs, KEY_SKIPPED, 0) + 1
                nextAt = now + intervalMs

                prefs.edit {
                    putInt(KEY_SKIPPED, skipped)
                    putLong(KEY_WINDOW_END_TS, 0L)
                    putLong(KEY_NEXT_TS, nextAt)
                }

                SmokingNotification.cancelCountdown(context)

                cancelNextReminder(context)
                scheduleNextReminder(context, nextAt)
            }

            ACTION_WINDOW_TIMEOUT -> {
                SmokingNotification.cancelCountdown(context)
                cancelWindowTimeout(context)
                prefs.edit { putLong(KEY_WINDOW_END_TS, 0L) }
                windowEnd = 0L
                nextAt = prefs.getLong(KEY_NEXT_TS, 0L)

                if (nextAt <= 0L) {
                    nextAt = now + intervalMs
                    prefs.edit { putLong(KEY_NEXT_TS, nextAt) }
                    cancelNextReminder(context)
                    scheduleNextReminder(context, nextAt)
                }
                didSkip = false
            }

            else -> return
        }

        val notifId = intent.getIntExtra("notifId", -1)
        if (notifId != -1) {
            try { NotificationManagerCompat.from(context).cancel(notifId) } catch (_: Throwable) {}
        }

        val bcast = Intent(ACTION_COUNTS_CHANGED).apply {
            setPackage(context.packageName)
            putExtra("action", when {
                didAccept -> "accept"
                didSkip   -> "skip"
                else      -> "none"
            })
            putExtra("smoked_today", getFlutterInt(prefs, KEY_SMOKED, 0))
            putExtra("skipped_today", getFlutterInt(prefs, KEY_SKIPPED, 0))
            putExtra("smokingWindowEndTs", windowEnd)
            putExtra("nextCigTimestamp", nextAt)
            putExtra("next_at_millis", nextAt)
            putExtra("window_timeout", intent.action == ACTION_WINDOW_TIMEOUT)
        }
        context.sendBroadcast(bcast)

        Log.d("ActionReceiver",
            "cpd=$cpd interval=${intervalSec}s action=${intent.action} next=$nextAt windowEnd=$windowEnd"
        )
    }

    private fun scheduleNextReminder(context: Context, triggerAtMillis: Long) { /* بدون تغییر */ }
    private fun cancelNextReminder(context: Context) { /* بدون تغییر */ }
    private fun scheduleWindowTimeout(context: Context, windowEndMillis: Long) { /* بدون تغییر */ }
    private fun cancelWindowTimeout(context: Context) { /* بدون تغییر */ }
}
