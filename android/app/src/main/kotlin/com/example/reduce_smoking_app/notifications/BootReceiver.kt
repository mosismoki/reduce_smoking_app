package com.example.reduce_smoking_app.notifications

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // TODO: Recreate today's alarms if you persist the plan natively.
        // For now, do nothing. Flutter can re-schedule when the app opens.
    }
}
