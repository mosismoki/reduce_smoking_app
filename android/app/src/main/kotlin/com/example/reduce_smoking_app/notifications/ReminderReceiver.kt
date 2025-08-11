package com.example.reduce_smoking_app.notifications

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class ReminderReceiver : BroadcastReceiver() {

    companion object {
        // یک شناسهٔ notification بده؛ اگر دوست داری داینامیکش کنیم بعداً از extra می‌گیریم
        private const val REQ_CODE = 1001
    }

    override fun onReceive(context: Context, intent: Intent) {
        // می‌تونی عنوان/متن رو از آلارم بفرستی؛ اگر نبود، پیش‌فرض می‌ذاریم
        val title = intent.getStringExtra("title") ?: "Time to smoke?"
        val body  = intent.getStringExtra("body")  ?: "You can smoke now."

        // فوروارد به ناشر مرکزی نوتیف
        val publish = Intent(context, NotificationPublisher::class.java).apply {
            putExtra("title", title)
            putExtra("body",  body)
            putExtra("reqCode", REQ_CODE)
        }
        context.sendBroadcast(publish)
    }
}
