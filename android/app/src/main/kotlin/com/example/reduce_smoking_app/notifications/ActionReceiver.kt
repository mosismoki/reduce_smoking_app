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
        const val ACTION_COUNTS_CHANGED = "SMOKE_COUNTS_CHANGED"

        // FlutterSharedPreferences + prefix
        private const val FLUTTER_PREF_FILE = "FlutterSharedPreferences"
        private const val PFX = "flutter."

        private const val KEY_SMOKED = PFX + "smoked_today"
        private const val KEY_SKIPPED = PFX + "skipped_today"
        private const val KEY_CIGS_PER_DAY = PFX + "cigsPerDay"
        private const val KEY_WINDOW_END_TS = PFX + "smokingWindowEndTs"
        private const val KEY_NEXT_TS = PFX + "nextCigTimestamp"

        private const val MIN_INTERVAL_SEC = 30
    }

    // 👇 خواندن امن مقدارهای Flutter (ممکنه Long/Int/String باشن)
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

        // فاصله بر اساس cigsPerDay با حداقل 30 ثانیه
        val raw = getFlutterInt(prefs, KEY_CIGS_PER_DAY, 1)
        val cpd = raw.coerceIn(1, 2000)
        val intervalSec = max(MIN_INTERVAL_SEC, (86400.0 / cpd).toInt())
        val intervalMs = intervalSec * 1000L

        var windowEnd = 0L
        var nextAt = 0L
        var didAccept = false

        when (intent.action) {
            ACTION_ACCEPT -> {
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
                SmokingNotification.scheduleWindowEndCancel(context, windowEnd)
                scheduleNextAlarm(context, nextAt)
            }

            ACTION_SKIP -> {
                val skipped = getFlutterInt(prefs, KEY_SKIPPED, 0) + 1
                nextAt = now + intervalMs

                prefs.edit {
                    putInt(KEY_SKIPPED, skipped)
                    putLong(KEY_WINDOW_END_TS, 0L)
                    putLong(KEY_NEXT_TS, nextAt)
                }

                SmokingNotification.cancelCountdown(context)
                scheduleNextAlarm(context, nextAt)
            }

            else -> return
        }

        // بستن نوتیف فعلی (اگه آی‌دی همراه intent اومده)
        val notifId = intent.getIntExtra("notifId", -1)
        if (notifId != -1) {
            try { NotificationManagerCompat.from(context).cancel(notifId) } catch (_: Throwable) {}
        }

        // اطلاع به اپ برای آپدیت UI
        val bcast = Intent(ACTION_COUNTS_CHANGED).apply {
            setPackage(context.packageName)
            putExtra("action", if (didAccept) "accept" else "skip")
            putExtra("smoked_today", getFlutterInt(prefs, KEY_SMOKED, 0))
            putExtra("skipped_today", getFlutterInt(prefs, KEY_SKIPPED, 0))
            putExtra("smokingWindowEndTs", windowEnd) // اگر skip شده باشد 0 است
            putExtra("nextCigTimestamp", nextAt)
            putExtra("next_at_millis", nextAt) // سازگاری
        }
        context.sendBroadcast(bcast)

        Log.d("ActionReceiver", "cpd=$cpd interval=${intervalSec}s next=$nextAt windowEnd=$windowEnd")
    }

    private fun scheduleNextAlarm(context: Context, triggerAtMillis: Long) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, ReminderReceiver::class.java)
        val pi = PendingIntent.getBroadcast(
            context, 101, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val canExact = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try { am.canScheduleExactAlarms() } catch (_: Throwable) { false }
        } else true

        try {
            if (canExact) am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
            else am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
        } catch (_: SecurityException) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
        }
    }
}
