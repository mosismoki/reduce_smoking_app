package com.example.reduce_smoking_app.notifications

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat

class ReminderReceiver : BroadcastReceiver() {

    companion object {
        private const val CHANNEL_ID = "smoke_schedule_channel"
        private const val CHANNEL_NAME = "Smoking Schedule"
        private const val NOTIF_ID = 1001
    }

    override fun onReceive(context: Context, intent: Intent) {
        ensureChannel(context)

        // اگر اجازهٔ نوتیف نداریم، در Receiver کاری نمی‌توانیم بکنیم → خارج شو
        if (Build.VERSION.SDK_INT >= 33) {
            val granted = ContextCompat.checkSelfPermission(
                context, Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) return
        }
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) return

        // اکشن‌ها مستقیماً به ActionReceiver می‌روند
        val acceptIntent = Intent(context, ActionReceiver::class.java).apply {
            action = ActionReceiver.ACTION_ACCEPT
            putExtra("notifId", NOTIF_ID)
        }
        val acceptPI = PendingIntent.getBroadcast(
            context, 201, acceptIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val skipIntent = Intent(context, ActionReceiver::class.java).apply {
            action = ActionReceiver.ACTION_SKIP
            putExtra("notifId", NOTIF_ID)
        }
        val skipPI = PendingIntent.getBroadcast(
            context, 202, skipIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("Cigarette time")
            .setContentText("Do you want to smoke this cigarette?")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setOngoing(false)
            .addAction(0, "Smoke now", acceptPI)
            .addAction(0, "Skip", skipPI)
            .setContentIntent(null) // کلیک روی بدنه نوتیف اپ را باز نکند

        try {
            NotificationManagerCompat.from(context).notify(NOTIF_ID, builder.build())
        } catch (_: SecurityException) {
            // در صورت خطای امنیتی (اجازه رد شده)، بی‌سروصدا نادیده بگیر
        }
    }

    private fun ensureChannel(ctx: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(CHANNEL_ID) == null) {
                nm.createNotificationChannel(
                    NotificationChannel(CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_HIGH)
                )
            }
        }
    }
}
