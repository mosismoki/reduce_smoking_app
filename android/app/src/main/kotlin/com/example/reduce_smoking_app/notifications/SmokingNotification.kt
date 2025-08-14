package com.example.reduce_smoking_app.notifications

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.example.reduce_smoking_app.MainActivity
import com.example.reduce_smoking_app.R
import java.util.Locale
import kotlin.math.max

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
                    NotificationManager.IMPORTANCE_DEFAULT
                ).apply { setShowBadge(false) }
                nm.createNotificationChannel(ch)
            }
        }
    }

    /** نمایش نوتیف شمارشِ پنجرهٔ ۵ دقیقه‌ای */
    fun showSmokingCountdown(ctx: Context, windowEndMillis: Long) {
        ensureChannel(ctx)

        // Android 13+: بدون مجوز، نوتیف نده
        if (Build.VERSION.SDK_INT >= 33) {
            val granted = ContextCompat.checkSelfPermission(
                ctx, Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) return
        }
        if (!NotificationManagerCompat.from(ctx).areNotificationsEnabled()) return

        // تپ روی بدنه → باز کردن اپ
        val openIntent = Intent(ctx, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val openPI = PendingIntent.getActivity(
            ctx, 301, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // زمان باقی‌مانده تا پایان پنجره
        val now = System.currentTimeMillis()
        val remainMs = max(0L, windowEndMillis - now)

        val builder = NotificationCompat.Builder(ctx, CHANNEL_ID)
            .setSmallIcon(
                try { R.drawable.ic_notification } catch (_: Throwable) { R.mipmap.ic_launcher }
            )
            .setContentTitle("Smoking window (5 min)")
            .setContentText("Time left…")
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(openPI)
            // اگر به هر دلیل آلارم پایان پنجره نرسید، خود نوتیف بعد از پنجره خودش بسته شود
            .setTimeoutAfter(remainMs + 1000)

        // Chronometer countdown برای API 24+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            builder
                .setUsesChronometer(true)
                .setShowWhen(true)
                .setChronometerCountDown(true)
                // نقطهٔ مرجع باید "الان + باقیمانده" باشد تا تأخیر منفی نشود
                .setWhen(now + remainMs)
        } else {
            // Fallback: متن mm:ss
            val mm = (remainMs / 60000L).toInt()
            val ss = ((remainMs % 60000L) / 1000L).toInt()
            builder.setContentText(String.format(Locale.US, "Time left: %02d:%02d", mm, ss))
        }

        try {
            NotificationManagerCompat.from(ctx).notify(NOTIF_ID_TIMER, builder.build())
        } catch (_: SecurityException) {
            // اگر مجوز در لحظه رد شد، بی‌سروصدا رد شو
        }
    }

    /** بستن نوتیف تایمر ۵ دقیقه‌ای */
    fun cancelCountdown(ctx: Context) {
        NotificationManagerCompat.from(ctx).cancel(NOTIF_ID_TIMER)
    }
}
