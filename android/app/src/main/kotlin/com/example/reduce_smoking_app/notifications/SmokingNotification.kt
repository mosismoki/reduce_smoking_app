package com.example.reduce_smoking_app.notifications

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

object SmokingNotification {
    private const val CHANNEL_ID = "smoke_timer_channel"
    private const val CHANNEL_NAME = "Smoking Timer"
    private const val NOTIF_ID_TIMER = 2000
    private const val REQ_CANCEL = 2001

    private fun ensureChannel(ctx: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(CHANNEL_ID) == null) {
                val ch = NotificationChannel(
                    CHANNEL_ID,
                    CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_DEFAULT // برای دیده‌شدن تایمر
                ).apply { setShowBadge(false) }
                nm.createNotificationChannel(ch)
            }
        }
    }

    /** نوتیفیکیشن با کرونومتر (در اندروید 7.0+ معکوس؛ در 6.0 رو به جلو) */
    fun showSmokingCountdown(ctx: Context, windowEndMillis: Long) {
        ensureChannel(ctx)

        val openAppIntent = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)
        val contentPI = PendingIntent.getActivity(
            ctx, 0, openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val b = NotificationCompat.Builder(ctx, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle("Smoking window (5 min)")
            .setContentText("Time left…")
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setUsesChronometer(true)   // کرونومتر فعال
            .setShowWhen(true)          // زمانِ مرجع را نشان بده
            .setWhen(windowEndMillis)   // نقطه مرجع کرونومتر

            .setContentIntent(contentPI)

        // setChronometerCountDown فقط از API 24 به بالا در دسترس است
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            b.setChronometerCountDown(true)
        }
        val n = b.build()

        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIF_ID_TIMER, n)
    }

    /** آلارم پایان ۵ دقیقه برای بستن نوتیف */
    fun scheduleWindowEndCancel(ctx: Context, windowEndMillis: Long) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(ctx, SmokingWindowEndReceiver::class.java)
        val pi = PendingIntent.getBroadcast(
            ctx, REQ_CANCEL, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // اگر اجازه exact نداریم، set...WhileIdle می‌زنیم و SecurityException را هم هندل می‌کنیم
                if (am.canScheduleExactAlarms()) {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, windowEndMillis, pi)
                } else {
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, windowEndMillis, pi)
                }
            } else {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, windowEndMillis, pi)
            }
        } catch (_: SecurityException) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, windowEndMillis, pi)
        }
    }

    /** بستن نوتیف تایمر ۵ دقیقه‌ای */
    fun cancelCountdown(ctx: Context) {
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(NOTIF_ID_TIMER)
    }
}
