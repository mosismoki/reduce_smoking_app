package com.example.reduce_smoking_app.notifications

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.app.PendingIntent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class ReminderReceiver : BroadcastReceiver() {
    companion object {
        const val CHANNEL_ID = "smoke_channel"
        const val NOTIF_ID = 1001
        const val ACTION_ACCEPT = "SMOKE_ACCEPT"
        const val ACTION_SKIP = "SMOKE_SKIP"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val acceptIntent = Intent(context, ActionReceiver::class.java).apply { action = ACTION_ACCEPT }
        val acceptPI = PendingIntent.getBroadcast(
            context, 201, acceptIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val skipIntent = Intent(context, ActionReceiver::class.java).apply { action = ACTION_SKIP }
        val skipPI = PendingIntent.getBroadcast(
            context, 202, skipIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
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

        NotificationManagerCompat.from(context).notify(NOTIF_ID, notif)
    }
}
