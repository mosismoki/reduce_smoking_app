package com.example.reduce_smoking_app.notifications

import android.Manifest
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class ReminderReceiver : BroadcastReceiver() {

    companion object {
        const val CHANNEL_ID = "smoke_channel"
        const val NOTIF_ID = 1001
    }

    override fun onReceive(context: Context, intent: Intent) {
        val acceptIntent = Intent(context, ActionReceiver::class.java).apply {
            action = ActionReceiver.ACTION_ACCEPT
        }
        val acceptPI = PendingIntent.getBroadcast(
            context,
            201,
            acceptIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val skipIntent = Intent(context, ActionReceiver::class.java).apply {
            action = ActionReceiver.ACTION_SKIP
        }
        val skipPI = PendingIntent.getBroadcast(
            context,
            202,
            skipIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notif = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("Time to smoke?")
            .setContentText("Accept or Skip this cigarette.")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .addAction(0, "Accept", acceptPI)
            .addAction(0, "Skip", skipPI)
            .build()

        // Android 13+: require POST_NOTIFICATIONS permission
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
            != PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        try {
            NotificationManagerCompat.from(context).notify(NOTIF_ID, notif)
        } catch (_: SecurityException) {
            // Silently ignore if system blocks the notification (rare)
        }
    }
}
