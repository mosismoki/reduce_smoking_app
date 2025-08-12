package com.example.reduce_smoking_app.notifications

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class SmokingWindowEndReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        // پایان پنجره: نوتیف تایمر را ببند
        SmokingNotification.cancelCountdown(context)

        // به Flutter خبر بده (اختیاری اما مفید برای سوئیچ UI)
        context.sendBroadcast(Intent(ActionReceiver.ACTION_COUNTS_CHANGED).apply {
            putExtra("event", "windowFinished")
        })
        // توجه: نوتیف نوبت بعدی قبلاً در ActionReceiver زمان‌بندی شده است
    }
}
