// android/app/src/main/kotlin/com/example/reduce_smoking_app/MainActivity.kt
package com.example.reduce_smoking_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.*
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import com.example.reduce_smoking_app.notifications.ActionReceiver
import com.example.reduce_smoking_app.notifications.ReminderReceiver
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private companion object {
        const val CHANNEL = "smoking.native"
    }

    private lateinit var channel: MethodChannel
    private var countsReceiver: BroadcastReceiver? = null

    // هندشیک برای جلوگیری از ارسال ایونت قبل از آماده شدن فلاتر
    private var flutterReady = false
    private var pendingCounts: HashMap<String, Any>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                // Dart ممکنه این نام را صدا بزند
                "scheduleEpochList",
                    // و یا این یکی
                "scheduleList" -> {
                    @Suppress("UNCHECKED_CAST")
                    val times = (call.argument<List<Long>>("times")
                        ?: call.argument<List<Long>>("epochs"))
                        ?: emptyList()
                    scheduleList(times)
                    result.success(true)
                }

                "cancelAll" -> {
                    cancelAll()
                    result.success(true)
                }

                // از main.dart بعد از اولین فریم ارسال می‌شود
                "flutterReady" -> {
                    flutterReady = true
                    // اگر ایونت معوقه داریم، همین حالا بفرست
                    pendingCounts?.let { data ->
                        safePostToFlutter("onCountsChanged", data)
                    }
                    pendingCounts = null
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Receiver for app-internal broadcast from ActionReceiver
        countsReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action == ActionReceiver.ACTION_COUNTS_CHANGED) {
                    val data = hashMapOf<String, Any>(
                        "smoked_today" to intent.getIntExtra("smoked_today", 0),
                        "skipped_today" to intent.getIntExtra("skipped_today", 0),
                        "smokingWindowEndTs" to intent.getLongExtra("smokingWindowEndTs", 0L),
                        "nextCigTimestamp" to intent.getLongExtra("nextCigTimestamp", 0L),
                        "next_at_millis" to intent.getLongExtra("next_at_millis", 0L),
                        "window_timeout" to intent.getBooleanExtra("window_timeout", false)
                    )
                    sendCountsToFlutter(data)
                }
            }
        }

        val filter = IntentFilter(ActionReceiver.ACTION_COUNTS_CHANGED)

        // ✅ این نسخه با ContextCompat روی تمام APIها فلگ NOT_EXPORTED را رعایت می‌کند
        ContextCompat.registerReceiver(
            /* context = */ this,
            /* receiver = */ countsReceiver,
            /* filter = */ filter,
            /* flags = */ ContextCompat.RECEIVER_NOT_EXPORTED
        )
    }

    override fun onDestroy() {
        countsReceiver?.let {
            try { unregisterReceiver(it) } catch (_: Throwable) {}
        }
        countsReceiver = null
        super.onDestroy()
    }

    // ----------------- Helpers -----------------

    private fun sendCountsToFlutter(data: HashMap<String, Any>) {
        if (flutterReady) {
            safePostToFlutter("onCountsChanged", data)
        } else {
            // فلاتر هنوز آماده نیست → آخرین وضعیت را نگه می‌داریم
            pendingCounts = data
        }
    }

    private fun safePostToFlutter(method: String, args: Any?) {
        Handler(Looper.getMainLooper()).post {
            try {
                channel.invokeMethod(method, args)
            } catch (_: Throwable) {
                // اگر به هر دلیل در این لحظه خطا داد، در pending نگه می‌داریم
                if (method == "onCountsChanged" && args is HashMap<*, *>) {
                    @Suppress("UNCHECKED_CAST")
                    pendingCounts = args as HashMap<String, Any>
                }
            }
        }
    }

    private fun scheduleList(times: List<Long>) {
        val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        times.forEachIndexed { idx, t ->
            val intent = Intent(this, ReminderReceiver::class.java)
            val pi = PendingIntent.getBroadcast(
                this, 1000 + idx, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val canExact = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                try { am.canScheduleExactAlarms() } catch (_: Throwable) { false }
            } else true

            try {
                if (canExact) {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, t, pi)
                } else {
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, t, pi)
                }
            } catch (_: SecurityException) {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, t, pi)
            }
        }
    }

    private fun cancelAll() {
        val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (req in 1000..1100) {
            val intent = Intent(this, ReminderReceiver::class.java)
            val pi = PendingIntent.getBroadcast(
                this, req, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            am.cancel(pi)
        }
    }
}
