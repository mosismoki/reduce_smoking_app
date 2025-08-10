package com.example.reduce_smoking_app.notifications

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings

object NotificationScheduler {

    const val CHANNEL_ID = "smoke_schedule_native"

    fun scheduleSingle(
        context: Context,
        requestCode: Int,
        triggerAtMillis: Long,
        title: String,
        body: String
    ) {
        val intent = Intent(context, NotificationPublisher::class.java).apply {
            putExtra("title", title)
            putExtra("body", body)
            putExtra("reqCode", requestCode)
        }
        val pi = PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        if (Build.VERSION.SDK_INT >= 31 && !am.canScheduleExactAlarms()) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
            return
        }

        try {
            if (Build.VERSION.SDK_INT >= 23) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
            } else {
                am.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
            }
        } catch (_: SecurityException) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
        }
    }

    fun openExactAlarmSettings(context: Context) {
        if (Build.VERSION.SDK_INT >= 31) {
            val i = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(i)
        }
    }

    fun cancel(context: Context, requestCode: Int) {
        val intent = Intent(context, NotificationPublisher::class.java)
        val pi = PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(pi)
    }

    fun cancelAll(context: Context) {
        for (i in 1000..1199) cancel(context, i)
    }
}
