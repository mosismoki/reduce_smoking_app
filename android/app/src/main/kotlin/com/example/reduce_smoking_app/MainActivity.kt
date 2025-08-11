package com.example.reduce_smoking_app

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.example.reduce_smoking_app.notifications.ActionReceiver
import com.example.reduce_smoking_app.notifications.NotificationScheduler

class MainActivity : FlutterActivity() {

    private val CHANNEL_NAME = "smoking.native"
    private lateinit var methodChannel: MethodChannel
    private var countsReceiver: BroadcastReceiver? = null
    private val notifPermissionReqCode = 1001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)

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
                    result.success(mapOf(
                        "smoked_today" to p.getInt("smoked_today", 0),
                        "skipped_today" to p.getInt("skipped_today", 0)
                    ))
                }
                "resetTodayCounts" -> {
                    val p = getSharedPreferences("smoke_prefs", Context.MODE_PRIVATE)
                    p.edit().putInt("smoked_today", 0).putInt("skipped_today", 0).apply()
                    result.success(true)
                }
                "openExactAlarmSettings" -> {
                    com.example.reduce_smoking_app.notifications.NotificationScheduler.openExactAlarmSettings(this)
                    result.success(true)
                }
                "debugShowReminderNow" -> {
                    sendBroadcast(Intent(this, com.example.reduce_smoking_app.notifications.ReminderReceiver::class.java))
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ensureNotifChannel()

        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), notifPermissionReqCode)
        }

        countsReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                val action = intent.action ?: return
                if (action == ActionReceiver.ACTION_COUNTS_CHANGED || action == "SMOKE_COUNTS_CHANGED") {
                    val smoked    = intent.getIntExtra("smoked_today", 0)
                    val skipped   = intent.getIntExtra("skipped_today", 0)
                    val act       = intent.getStringExtra("action") ?: ""
                    val nextAt    = intent.getLongExtra("nextCigTimestamp", 0L)
                    val windowEnd = intent.getLongExtra("smokingWindowEndTs", 0L)

                    methodChannel.invokeMethod("onCountsChanged", mapOf(
                        "smoked_today" to smoked,
                        "skipped_today" to skipped,
                        "action" to act,
                        "next_at_millis" to nextAt,
                        "smokingWindowEndTs" to windowEnd
                    ))
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        val filter = IntentFilter().apply {
            addAction(ActionReceiver.ACTION_COUNTS_CHANGED)
            addAction("SMOKE_COUNTS_CHANGED")
        }
        if (Build.VERSION.SDK_INT >= 33) {
            registerReceiver(countsReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(countsReceiver, filter)
        }
        // هر بار که صفحه فعال می‌شود، وضعیت فعلی را هم به دارت پوش کن
        pushCountsNow()
    }

    override fun onPause() {
        super.onPause()
        countsReceiver?.let { unregisterReceiver(it) }
    }

    private fun ensureNotifChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "smoke_channel", "Smoking Reminders", NotificationManager.IMPORTANCE_HIGH
            )
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }
    }

    /** وضعیت فعلی را از SharedPreferences برداشته و به Flutter می‌فرستد */
    private fun pushCountsNow() {
        val p = getSharedPreferences("smoke_prefs", Context.MODE_PRIVATE)
        val smoked    = p.getInt("smoked_today", 0)
        val skipped   = p.getInt("skipped_today", 0)
        val nextAt    = p.getLong("nextCigTimestamp", 0L)
        val windowEnd = p.getLong("smokingWindowEndTs", 0L)

        methodChannel.invokeMethod("onCountsChanged", mapOf(
            "smoked_today" to smoked,
            "skipped_today" to skipped,
            "action" to "",
            "next_at_millis" to nextAt,
            "smokingWindowEndTs" to windowEnd
        ))
    }
}
