package com.example.reduce_smoking_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.*
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleList" -> {
                    val times = call.argument<List<Long>>("times") ?: emptyList()
                    scheduleList(times)
                    result.success(true)
                }
                "cancelAll" -> {
                    cancelAll()
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
                    Handler(Looper.getMainLooper()).post {
                        channel.invokeMethod("onCountsChanged", data)
                    }
                }
            }
        }

        val filter = IntentFilter(ActionReceiver.ACTION_COUNTS_CHANGED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // For API 33+: must specify NOT_EXPORTED (internal to app)
            registerReceiver(countsReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(countsReceiver, filter)
        }
    }

    override fun onDestroy() {
        try { unregisterReceiver(countsReceiver) } catch (_: Throwable) {}
        countsReceiver = null
        super.onDestroy()
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
                if (canExact) am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, t, pi)
                else am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, t, pi)
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
