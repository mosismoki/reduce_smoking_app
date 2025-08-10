package com.example.reduce_smoking_app

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.content.edit
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.example.reduce_smoking_app.notifications.NotificationScheduler
import com.example.reduce_smoking_app.notifications.ActionReceiver

class MainActivity : FlutterActivity() {

    private val channelName = "smoking.native"
    private val notifPermissionReqCode = 1001

    private lateinit var methodChannel: MethodChannel
    private var countsReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleList" -> {
                    val args = call.arguments as Map<*, *>
                    val times = (args["times"] as List<*>?)?.map { (it as Number).toLong() } ?: emptyList()
                    val title = (args["title"] as? String) ?: "Cigarette time"
                    val body  = (args["body"]  as? String) ?: "Do you want to smoke this cigarette?"
                    var rc = 1000
                    times.forEach { t -> NotificationScheduler.scheduleSingle(this, rc++, t, title, body) }
                    result.success(true)
                }
                "cancelAll" -> {
                    NotificationScheduler.cancelAll(this); result.success(true)
                }
                "getTodayCounts" -> {
                    val p = getSharedPreferences("smoke_prefs", Context.MODE_PRIVATE)
                    result.success(mapOf("smoked_today" to p.getInt("smoked_today", 0),
                        "skipped_today" to p.getInt("skipped_today", 0)))
                }
                "resetTodayCounts" -> {
                    val p = getSharedPreferences("smoke_prefs", Context.MODE_PRIVATE)
                    p.edit { putInt("smoked_today", 0); putInt("skipped_today", 0) }
                    result.success(true)
                }
                "openExactAlarmSettings" -> {
                    NotificationScheduler.openExactAlarmSettings(this); result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Android 13+ notification permission
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), notifPermissionReqCode)
        }

        // Listen for native counter changes (from ActionReceiver)
        countsReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action == ActionReceiver.ACTION_COUNTS_CHANGED) {
                    val p = getSharedPreferences("smoke_prefs", Context.MODE_PRIVATE)
                    val smoked  = p.getInt("smoked_today", 0)
                    val skipped = p.getInt("skipped_today", 0)
                    methodChannel.invokeMethod(
                        "onCountsChanged",
                        mapOf("smoked_today" to smoked, "skipped_today" to skipped)
                    )
                }
            }
        }
        registerReceiver(
            countsReceiver,
            IntentFilter(com.example.reduce_smoking_app.notifications.ActionReceiver.ACTION_COUNTS_CHANGED),
            Context.RECEIVER_NOT_EXPORTED
        )
    }

    override fun onDestroy() {
        countsReceiver?.let { unregisterReceiver(it) }
        countsReceiver = null
        super.onDestroy()
    }
}
