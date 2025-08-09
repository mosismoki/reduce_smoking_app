package com.example.reduce_smoking_app

import android.content.Context
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.example.reduce_smoking_app.notifications.NotificationScheduler

class MainActivity : FlutterActivity() {
    private val CHANNEL = "smoking.native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // args: List<Long> epochMillis
                "scheduleList" -> {
                    val args = call.arguments as Map<*, *>
                    val times = args["times"] as List<*>
                    val title = (args["title"] as? String) ?: "Cigarette time"
                    val body = (args["body"] as? String) ?: "Do you want to smoke this cigarette?"

                    var rc = 1000
                    times.forEach {
                        val t = (it as Number).toLong()
                        NotificationScheduler.scheduleSingle(this, rc, t, title, body)
                        rc++
                    }
                    result.success(true)
                }

                "cancelAll" -> {
                    NotificationScheduler.cancelAll(this)
                    result.success(true)
                }

                "getTodayCounts" -> {
                    val prefs = getSharedPreferences("smoke_prefs", Context.MODE_PRIVATE)
                    val smoked = prefs.getInt("smoked_today", 0)
                    val skipped = prefs.getInt("skipped_today", 0)
                    result.success(mapOf("smoked_today" to smoked, "skipped_today" to skipped))
                }

                "resetTodayCounts" -> {
                    val prefs = getSharedPreferences("smoke_prefs", Context.MODE_PRIVATE)
                    prefs.edit().putInt("smoked_today", 0).putInt("skipped_today", 0).apply()
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Debug: schedule a notification 15 seconds from now
        val t = System.currentTimeMillis() + 15_000L
        NotificationScheduler.scheduleSingle(
            /* context = */ this,
            /* requestCode = */ 1100,
            /* triggerAtMillis = */ t,
            /* title = */ "Cigarette time",
            /* body  = */ "Do you want to smoke this cigarette?"
        )
    }
}
