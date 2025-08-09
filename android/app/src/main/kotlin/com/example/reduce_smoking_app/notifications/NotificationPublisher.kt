package com.example.reduce_smoking_app.notifications

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import androidx.core.app.NotificationCompat
import com.example.reduce_smoking_app.R

class NotificationPublisher : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val title = intent.getStringExtra("title") ?: "Cigarette time"
        val body  = intent.getStringExtra("body")  ?: "Do you want to smoke this cigarette?"
        val reqCode = intent.getIntExtra("reqCode", 1000)

        createChannel(context)

        // Action intents
        val acceptIntent = Intent(context, ActionReceiver::class.java).apply {
            action = ActionReceiver.ACTION_ACCEPT
        }
        val acceptPI = PendingIntent.getBroadcast(
            context, reqCode + 5000, acceptIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val skipIntent = Intent(context, ActionReceiver::class.java).apply {
            action = ActionReceiver.ACTION_SKIP
        }
        val skipPI = PendingIntent.getBroadcast(
            context, reqCode + 9000, skipIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val notification = NotificationCompat.Builder(context, NotificationScheduler.CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(R.mipmap.ic_launcher) // or a monochrome status icon
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .addAction(R.drawable.ic_smoke, "Smoke now", acceptPI)
            .addAction(R.drawable.ic_skip,  "Skip",      skipPI)
            .build()

        nm.notify(reqCode, notification)
    }

    private fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(NotificationScheduler.CHANNEL_ID) == null) {
                val ch = NotificationChannel(
                    NotificationScheduler.CHANNEL_ID,
                    "Smoking Schedule",
                    NotificationManager.IMPORTANCE_HIGH
                )
                ch.description = "Exact alarms and reminder notifications for cigarette schedule."
                ch.enableLights(true); ch.lightColor = Color.WHITE
                ch.enableVibration(true)
                nm.createNotificationChannel(ch)
            }
        }
    }
}
