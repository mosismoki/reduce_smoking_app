// android/app/src/main/kotlin/com/example/reduce_smoking_app/notifications/ReminderReceiver.kt
package com.example.reduce_smoking_app.notifications

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.example.reduce_smoking_app.MainActivity
import com.example.reduce_smoking_app.R

class ReminderReceiver : BroadcastReceiver() {

    companion object {
        private const val CHANNEL_ID = "smoke_schedule_channel"
        private const val CHANNEL_NAME = "Smoking Schedule"

        // واحد با همه جا: یادآور «وقت سیگار»
        private const val NOTIF_ID = 1001

        private const val REQ_ACCEPT = 201
        private const val REQ_SKIP   = 202
        private const val REQ_OPEN   = 203
        private const val TAG = "ReminderReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        ensureChannel(context)

        // Android 13+: بدون اجازه، نوتیف نشان داده نمی‌شود
        if (Build.VERSION.SDK_INT >= 33) {
            val granted = ContextCompat.checkSelfPermission(
                context, Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) {
                Log.w(TAG, "POST_NOTIFICATIONS not granted; skipping notify()")
                return
            }
        }
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) {
            Log.w(TAG, "Notifications disabled by user; skipping notify()")
            return
        }

        // اگر نوتیف شمارش پنجره باز مانده، جمعش کن (پاک‌سازی UI)
        try { SmokingNotification.cancelCountdown(context) } catch (_: Throwable) {}

        // --- اکشن‌ها → ActionReceiver
        val acceptIntent = Intent(context, ActionReceiver::class.java).apply {
            action = ActionReceiver.ACTION_ACCEPT
            putExtra("notifId", NOTIF_ID)
        }
        val acceptPI = PendingIntent.getBroadcast(
            context, REQ_ACCEPT, acceptIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val skipIntent = Intent(context, ActionReceiver::class.java).apply {
            action = ActionReceiver.ACTION_SKIP
            putExtra("notifId", NOTIF_ID)
        }
        val skipPI = PendingIntent.getBroadcast(
            context, REQ_SKIP, skipIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // --- تَپ روی بدنه → باز کردن اپ (MainActivity)
        val openIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val openPI = PendingIntent.getActivity(
            context, REQ_OPEN, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            // اگر ic_notification نداری، از ic_launcher استفاده کن
            .setSmallIcon(
                try { R.drawable.ic_notification } catch (_: Throwable) { R.mipmap.ic_launcher }
            )
            .setContentTitle("Cigarette time")
            .setContentText("Do you want to smoke this cigarette?")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(Notification.CATEGORY_REMINDER)
            .setDefaults(NotificationCompat.DEFAULT_ALL) // صدا/ویبره/نور (برای heads-up)
            .setAutoCancel(true)
            .setOngoing(false)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(openPI)
            .addAction(0, "Smoke now", acceptPI)
            .addAction(0, "Skip", skipPI)

        try {
            NotificationManagerCompat.from(context).notify(NOTIF_ID, builder.build())
            Log.d(TAG, "notify() posted (id=$NOTIF_ID)")
        } catch (se: SecurityException) {
            Log.w(TAG, "SecurityException on notify(): ${se.message}")
        } catch (t: Throwable) {
            Log.e(TAG, "notify() failed: ${t.message}")
        }
    }

    private fun ensureChannel(ctx: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(CHANNEL_ID) == null) {
                val ch = NotificationChannel(
                    CHANNEL_ID,
                    CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Shows cigarette reminder notifications"
                    enableLights(true)
                    enableVibration(true)
                }
                nm.createNotificationChannel(ch)
            }
        }
    }
}
