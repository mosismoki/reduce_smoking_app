package com.example.reduce_smoking_app.notifications

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.edit
import kotlin.math.max

class ActionReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_ACCEPT = "SMOKE_ACCEPT"
        const val ACTION_SKIP   = "SMOKE_SKIP"

        // رویداد داخلی برای آپدیت UI (اسم قبلی‌ات را نگه داشتم تا تداخلی نشه)
        const val ACTION_COUNTS_CHANGED = "SMOKE_COUNTS_CHANGED"

        private const val PREFS = "smoke_prefs"
        private const val KEY_SMOKED = "smoked_today"
        private const val KEY_SKIPPED = "skipped_today"

        // قبلاً داشتی؛ برای سازگاری نگه می‌داریم
        private const val KEY_NEXT_AT = "next_at_millis"

        // کلیدهای جدید/قبلی برای منطق زمان‌بندی
        private const val KEY_CIGS_PER_DAY = "cigsPerDay"
        private const val KEY_WINDOW_END_TS = "smokingWindowEndTs"
        private const val KEY_NEXT_TS = "nextCigTimestamp"

        // اگر cigsPerDay در prefs نبود، این فاصله fallback است (دقیقه)
        private const val FALLBACK_INTERVAL_MIN = 30
    }

    override fun onReceive(context: Context, intent: Intent) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()

        // فاصله را از cigsPerDay حساب می‌کنیم؛ اگر نبود fallback
        val cigsPerDay = max(1, prefs.getInt(KEY_CIGS_PER_DAY, -1))
        val intervalMin = if (cigsPerDay > 0) (24 * 60) / cigsPerDay else FALLBACK_INTERVAL_MIN
        val intervalMs = intervalMin * 60_000L

        var didAccept = false
        var windowEnd = 0L
        var nextAt = 0L

        when (intent.action) {
            ACTION_ACCEPT -> {
                // ۵ دقیقه پنجرهٔ کشیدن سیگار
                didAccept = true
                windowEnd = now + 5 * 60_000L
                nextAt = windowEnd + intervalMs

                val smoked = prefs.getInt(KEY_SMOKED, 0) + 1
                prefs.edit {
                    putInt(KEY_SMOKED, smoked)
                    putLong(KEY_WINDOW_END_TS, windowEnd)
                    putLong(KEY_NEXT_TS, nextAt)
                    putLong(KEY_NEXT_AT, nextAt) // سازگاری با کد قبلی
                }

                // نوتیف تایمر ۵ دقیقه‌ای با کرونومتر معکوس
                SmokingNotification.showSmokingCountdown(context, windowEnd)
                // برنامه‌ریزی برای بستن نوتیف در پایان ۵ دقیقه
                SmokingNotification.scheduleWindowEndCancel(context, windowEnd)

                // نوتیف/آلارم نوبت بعدی
                scheduleNextAlarm(context, nextAt)

                Log.d("ActionReceiver", "ACCEPT → windowEnd=$windowEnd, nextAt=$nextAt, smoked=$smoked")
            }

            ACTION_SKIP -> {
                // بدون پنجره، مستقیم برو به نوبت بعدی
                val skipped = prefs.getInt(KEY_SKIPPED, 0) + 1
                nextAt = now + intervalMs

                prefs.edit {
                    putInt(KEY_SKIPPED, skipped)
                    putLong(KEY_WINDOW_END_TS, 0L)
                    putLong(KEY_NEXT_TS, nextAt)
                    putLong(KEY_NEXT_AT, nextAt) // سازگاری با کد قبلی
                }

                // اگر نوتیف تایمر قبلی باز است، ببندش
                SmokingNotification.cancelCountdown(context)

                // نوتیف/آلارم نوبت بعدی
                scheduleNextAlarm(context, nextAt)

                Log.d("ActionReceiver", "SKIP → nextAt=$nextAt, skipped=$skipped")
            }

            else -> return
        }

        // بستن نوتیف فعلیِ اقدام (Smoke/Skip)
        val notifId = intent.getIntExtra("notifId", -1)
        if (notifId != -1) {
            try { NotificationManagerCompat.from(context).cancel(notifId) } catch (_: Throwable) {}
        }

        // اطلاع به اپ برای آپدیت UI (یکسان با اسم قبلی‌ات)
        val bcast = Intent(ACTION_COUNTS_CHANGED).apply {
            setPackage(context.packageName)
            putExtra("action", if (didAccept) "accept" else "skip")
            putExtra("smoked_today", prefs.getInt(KEY_SMOKED, 0))
            putExtra("skipped_today", prefs.getInt(KEY_SKIPPED, 0))
            putExtra("smokingWindowEndTs", windowEnd) // اگر skip شده باشد 0 است
            putExtra("nextCigTimestamp", nextAt)
            putExtra("next_at_millis", nextAt) // سازگاری
        }
        context.sendBroadcast(bcast)
    }

    private fun scheduleNextAlarm(context: Context, triggerAtMillis: Long) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, ReminderReceiver::class.java)
        val pi = PendingIntent.getBroadcast(
            context,
            101,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val canExact = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try { am.canScheduleExactAlarms() } catch (_: Throwable) { false }
        } else true

        try {
            if (canExact) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
            } else {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
            }
        } catch (_: SecurityException) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
        }

        Log.d("ActionReceiver", "Next alarm scheduled at $triggerAtMillis")
    }
}
