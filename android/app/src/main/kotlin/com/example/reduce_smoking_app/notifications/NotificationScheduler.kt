package com.example.reduce_smoking_app.notifications

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

object NotificationScheduler {

    const val CHANNEL_ID = "smoke_schedule_native"

    // Schedules a single alarm at [triggerAtMillis].
    fun scheduleSingle(context: Context, requestCode: Int, triggerAtMillis: Long, title: String, body: String) {
        val intent = Intent(context, NotificationPublisher::class.java).apply {
            putExtra("title", title)
            putExtra("body", body)
            putExtra("reqCode", requestCode)
        }
        val pi = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
        } else {
            am.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
        }
    }

    fun cancel(context: Context, requestCode: Int) {
        val intent = Intent(context, NotificationPublisher::class.java)
        val pi = PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(pi)
    }

    fun cancelAll(context: Context) {
        // If you keep your requestCodes predictable (e.g., 1000..1099), loop & cancel.
        for (i in 1000..1199) cancel(context, i)
    }
}
