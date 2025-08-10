package com.example.reduce_smoking_app

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.content.edit
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.example.reduce_smoking_app.notifications.NotificationScheduler

class MainActivity : FlutterActivity() {

    private val channelName = "smoking.native"
    private val notifPermissionReqCode = 1001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    // args: Map<String, Any> with "times": List<Long>, optional "title", "body"
                    "scheduleList" -> {
                        val args = call.arguments as Map<*, *>
                        val times = (args["times"] as List<*>?)?.map { (it as Number).toLong() } ?: emptyList()
                        val title = (args["title"] as? String) ?: "Cigarette time"
                        val body  = (args["body"]  as? String) ?: "Do you want to smoke this cigarette?"

                        var rc = 1000
                        times.forEach { t ->
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
                        val smoked  = prefs.getInt("smoked_today", 0)
                        val skipped = prefs.getInt("skipped_today", 0)
                        result.success(mapOf("smoked_today" to smoked, "skipped_today" to skipped))
                    }

                    "resetTodayCounts" -> {
                        val prefs = getSharedPreferences("smoke_prefs", Context.MODE_PRIVATE)
                        prefs.edit {
                            putInt("smoked_today", 0)
                            putInt("skipped_today", 0)
                        }
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Android 13+ requires runtime permission for notifications
        if (Build.VERSION.SDK_INT >= 33) {
            if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED
            ) {
                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), notifPermissionReqCode)
                return // wait for user response
            }
        }

        // Debug: schedule a test notification 15 seconds from now (remove after testing)
        scheduleTestNotification()
    }

    private fun scheduleTestNotification() {
        val t = System.currentTimeMillis() + 15_000L
        NotificationScheduler.scheduleSingle(
            this,
            1100,
            t,
            "Cigarette time",
            "Do you want to smoke this cigarette?"
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == notifPermissionReqCode &&
            grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        ) {
            scheduleTestNotification()
        }
    }
}
