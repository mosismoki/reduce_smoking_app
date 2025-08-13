package com.example.reduce_smoking_app.notifications

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat

object SmokingNotification {
    private const val CHANNEL_ID = "smoke_timer_channel"
    private const val CHANNEL_NAME = "Smoking Timer"
    private const val NOTIF_ID_TIMER = 2000

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

    /** نمایش نوتیف شمارش معکوس ۵ دقیقه‌ای پنجرهٔ سیگار */
    fun showSmokingCountdown(ctx: Context, windowEndMillis: Long) {
        ensureChannel(ctx)

        val b = NotificationCompat.Builder(ctx, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle("Smoking window (5 min)")
            .setContentText("Time left…")
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setUsesChronometer(true)   // کرونومتر فعال
            .setShowWhen(true)          // زمانِ مرجع را نشان بده
            .setWhen(windowEndMillis)   // نقطهٔ مرجع کرونومتر (برای countdown)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            b.setChronometerCountDown(true)
        }

        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIF_ID_TIMER, b.build())
    }

    /** بستن نوتیف تایمر ۵ دقیقه‌ای */
    fun cancelCountdown(ctx: Context) {
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(NOTIF_ID_TIMER)
    }
}
