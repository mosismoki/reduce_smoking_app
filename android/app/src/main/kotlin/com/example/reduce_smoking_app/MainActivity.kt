// android/app/src/main/kotlin/com/example/reduce_smoking_app/MainActivity.kt
package com.example.reduce_smoking_app

import android.Manifest
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.*
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.example.reduce_smoking_app.notifications.ActionReceiver
import com.example.reduce_smoking_app.notifications.ReminderReceiver
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private companion object {
        const val CHANNEL = "smoking.native"

        private const val FLUTTER_PREF_FILE = "FlutterSharedPreferences"
        private const val PFX = "flutter."
        private const val KEY_SMOKED = PFX + "smoked_today"
        private const val KEY_SKIPPED = PFX + "skipped_today"
        private const val KEY_WINDOW_END_TS = PFX + "smokingWindowEndTs"
        private const val KEY_NEXT_TS = PFX + "nextCigTimestamp"

        private const val REQ_CODE_POST_NOTIF = 1001
        private const val TAG = "MainActivity"
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
                // Android scheduling (epoch list)
                "scheduleEpochList", "scheduleList" -> {
                    val times = call.argument<List<Long>>("times")
                        ?: call.argument<List<Long>>("epochs")
                        ?: emptyList()
                    scheduleList(times)
                    result.success(true)
                }

                "cancelAll" -> {
                    cancelAll()
                    result.success(true)
                }

                // بعد از اولین فریم از فلاتر ارسال می‌شود
                "flutterReady" -> {
                    flutterReady = true
                    pendingCounts?.let { data -> safePostToFlutter("onCountsChanged", data) }
                    pendingCounts = null
                    result.success(true)
                }

                // Bridge های کمکی برای Prefs
                "getTodayCounts" -> {
                    val prefs = getSharedPreferences(FLUTTER_PREF_FILE, Context.MODE_PRIVATE)
                    val smoked = getFlutterInt(prefs, KEY_SMOKED, 0)
                    val skipped = getFlutterInt(prefs, KEY_SKIPPED, 0)
                    result.success(
                        mapOf(
                            "smoked_today" to smoked,
                            "skipped_today" to skipped
                        )
                    )
                }

                "resetTodayCounts" -> {
                    val prefs = getSharedPreferences(FLUTTER_PREF_FILE, Context.MODE_PRIVATE)
                    prefs.edit()
                        .putInt(KEY_SMOKED, 0)
                        .putInt(KEY_SKIPPED, 0)
                        .apply()
                    sendCountsToFlutter(
                        hashMapOf(
                            "smoked_today" to 0,
                            "skipped_today" to 0,
                            "smokingWindowEndTs" to prefs.getLong(KEY_WINDOW_END_TS, 0L),
                            "nextCigTimestamp" to prefs.getLong(KEY_NEXT_TS, 0L),
                            "next_at_millis" to prefs.getLong(KEY_NEXT_TS, 0L),
                            "window_timeout" to false
                        )
                    )
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Receiver برای سینک نوتیف/آلارم → فلاتر
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
        ContextCompat.registerReceiver(
            this,
            countsReceiver,
            filter,
            ContextCompat.RECEIVER_NOT_EXPORTED
        )

        // Android 13+: مجوز اعلان / و اگر کلاً بسته است صفحه تنظیمات اعلان را باز کن
        requestPostNotificationsIfNeeded()
        ensureNotificationsEnabledUI()
    }

    override fun onDestroy() {
        countsReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: Throwable) {
            }
        }
        countsReceiver = null
        super.onDestroy()
    }

    // ----------------- Helpers -----------------

    private fun sendCountsToFlutter(data: HashMap<String, Any>) {
        if (flutterReady) safePostToFlutter("onCountsChanged", data)
        else pendingCounts = data
    }

    private fun safePostToFlutter(method: String, args: Any?) {
        Handler(Looper.getMainLooper()).post {
            try {
                channel.invokeMethod(method, args)
            } catch (_: Throwable) {
                if (method == "onCountsChanged" && args is HashMap<*, *>) {
                    @Suppress("UNCHECKED_CAST")
                    pendingCounts = args as HashMap<String, Any>
                }
            }
        }
    }

    // آلارم‌های اندروید برای یادآور «وقت سیگار»
    private fun scheduleList(times: List<Long>) {
        val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager

        times.forEachIndexed { idx, t ->
            val intent = Intent(this, ReminderReceiver::class.java)
            val pi = PendingIntent.getBroadcast(
                this,
                1000 + idx,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // روی S+ ممکنه نیاز به canScheduleExactAlarms باشه
            val canExact = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                try {
                    am.canScheduleExactAlarms()
                } catch (_: Throwable) {
                    false
                }
            } else true

            try {
                if (canExact) {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, t, pi)
                } else {
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, t, pi)
                }
                Log.d(TAG, "Scheduling alarm idx=$idx at=$t (canExact=$canExact)")
            } catch (_: SecurityException) {
                // اگر Exact مجاز نبود، با غیر دقیق ادامه بده
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, t, pi)
                Log.w(TAG, "SecurityException on setExact; fallback setAndAllowWhileIdle for idx=$idx at=$t")
            }
        }
    }

    private fun cancelAll() {
        val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (req in 1000..1100) {
            val intent = Intent(this, ReminderReceiver::class.java)
            val pi = PendingIntent.getBroadcast(
                this,
                req,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            am.cancel(pi)
            Log.d(TAG, "Cancel alarm req=$req")
        }
    }

    private fun getFlutterInt(prefs: SharedPreferences, key: String, def: Int = 0): Int {
        val v = prefs.all[key]
        return when (v) {
            is Int -> v
            is Long -> v.toInt()
            is String -> v.toIntOrNull() ?: def
            else -> def
        }
    }

    // ---------- Notification permission / settings ----------

    private fun requestPostNotificationsIfNeeded() {
        if (Build.VERSION.SDK_INT >= 33) {
            val has = ActivityCompat.checkSelfPermission(
                this, Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
            if (!has) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    REQ_CODE_POST_NOTIF
                )
            }
        }
    }

    private fun ensureNotificationsEnabledUI() {
        val nm = NotificationManagerCompat.from(this)
        if (!nm.areNotificationsEnabled()) {
            // کاربر اعلان‌ها را برای اپ خاموش کرده - صفحه تنظیمات اعلان اپ را باز کن
            val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            }
            try {
                startActivity(intent)
            } catch (_: Throwable) {
                // اگر دستگاه intent را ساپورت نکرد، بیخیال
            }
        }
    }
}
