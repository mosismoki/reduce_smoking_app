package com.example.reduce_smoking_app.notifications

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.example.reduce_smoking_app.R

class NotificationPublisher : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val title   = intent.getStringExtra("title") ?: "Cigarette time"
        val body    = intent.getStringExtra("body")  ?: "Do you want to smoke this cigarette?"
        val reqCode = intent.getIntExtra("reqCode", 1000)

        // Android 13+ — ensure POST_NOTIFICATIONS is granted
        if (Build.VERSION.SDK_INT >= 33) {
            val granted = ContextCompat.checkSelfPermission(
                context, Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) return
        }

        // App/channel notifications may be disabled
        val nmCompat = NotificationManagerCompat.from(context)
        if (!nmCompat.areNotificationsEnabled()) return

        ensureChannel(context)

        // ACTION: Smoke
        val acceptIntent = Intent(context, ActionReceiver::class.java).apply {
            action = ActionReceiver.ACTION_ACCEPT
        }
        val acceptPI = PendingIntent.getBroadcast(
            context,
            reqCode + 5000,
            acceptIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // ACTION: Skip
        val skipIntent = Intent(context, ActionReceiver::class.java).apply {
            action = ActionReceiver.ACTION_SKIP
        }
        val skipPI = PendingIntent.getBroadcast(
            context,
            reqCode + 9000,
            skipIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, NotificationScheduler.CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .addAction(R.drawable.ic_smoke, "Smoke now", acceptPI)
            .addAction(R.drawable.ic_skip,  "Skip",      skipPI)
            .build()

        try {
            nmCompat.notify(reqCode, notification)
        } catch (_: SecurityException) {
            // Permission might have been revoked between check and notify.
        }
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(NotificationScheduler.CHANNEL_ID) == null) {
                val ch = NotificationChannel(
                    NotificationScheduler.CHANNEL_ID,
                    "Smoking Schedule",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Exact alarms and reminder notifications for cigarette schedule."
                    enableLights(true)
                    lightColor = Color.WHITE
                    enableVibration(true)
                }
                nm.createNotificationChannel(ch)
            }
        }
    }
}
