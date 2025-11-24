package com.example.safety_app

import android.Manifest
import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.telephony.SmsManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
    private val channelName = "safety_app/sms"
    private val smsPermission = Manifest.permission.SEND_SMS
    private val requestCode = 2001
    private val handler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendSms" -> {
                    val to = call.argument<String>("to")
                    val message = call.argument<String>("message")
                    if (to.isNullOrBlank() || message.isNullOrBlank()) {
                        result.error("ARG_ERROR", "Missing 'to' or 'message'", null)
                        return@setMethodCallHandler
                    }
                    if (ContextCompat.checkSelfPermission(this, smsPermission) != PackageManager.PERMISSION_GRANTED) {
                        ActivityCompat.requestPermissions(this, arrayOf(smsPermission), requestCode)
                        result.error("PERMISSION", "SEND_SMS not granted", null)
                        return@setMethodCallHandler
                    }

                    val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= 31) {
                        this.getSystemService(SmsManager::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        SmsManager.getDefault()
                    }

                    val sentAction = "$channelName.SMS_SENT.${System.currentTimeMillis()}"
                    val intent = Intent(sentAction)
                    val sentIntent = PendingIntent.getBroadcast(
                        this,
                        sentAction.hashCode(),
                        intent,
                        if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_IMMUTABLE else 0
                    )

                    val receiverRegistered = AtomicBoolean(true)
                    var timeoutRunnable: Runnable? = null
                    val receiver = object : BroadcastReceiver() {
                        override fun onReceive(context: Context?, intent: Intent?) {
                            if (receiverRegistered.getAndSet(false)) {
                                try {
                                    unregisterReceiver(this)
                                } catch (_: IllegalArgumentException) {
                                }
                            }
                            timeoutRunnable?.let { handler.removeCallbacks(it) }
                            when (resultCode) {
                                Activity.RESULT_OK -> result.success(true)
                                SmsManager.RESULT_ERROR_GENERIC_FAILURE -> result.error("SMS_ERROR", "Eroare generică la trimiterea SMS-ului.", null)
                                SmsManager.RESULT_ERROR_NO_SERVICE -> result.error("SMS_ERROR", "Nu există rețea disponibilă pentru trimiterea SMS-ului.", null)
                                SmsManager.RESULT_ERROR_RADIO_OFF -> result.error("SMS_ERROR", "Radio-ul dispozitivului este oprit.", null)
                                SmsManager.RESULT_ERROR_NULL_PDU -> result.error("SMS_ERROR", "PDU null - mesaj invalid.", null)
                                else -> result.error("SMS_ERROR", "Trimiterea SMS-ului a eșuat (cod necunoscut).", null)
                            }
                        }
                    }

                    registerReceiver(receiver, IntentFilter(sentAction))

                    timeoutRunnable = Runnable {
                        if (receiverRegistered.getAndSet(false)) {
                            try {
                                unregisterReceiver(receiver)
                            } catch (_: IllegalArgumentException) {
                            }
                        }
                        result.error("SMS_TIMEOUT", "Confirmarea trimiterii SMS-ului a expirat.", null)
                    }

                    timeoutRunnable?.let { handler.postDelayed(it, 30_000) }

                    try {
                        smsManager.sendTextMessage(to, null, message, sentIntent, null)
                    } catch (e: Exception) {
                        if (receiverRegistered.getAndSet(false)) {
                            try {
                                unregisterReceiver(receiver)
                            } catch (_: IllegalArgumentException) {
                            }
                        }
                        timeoutRunnable?.let { handler.removeCallbacks(it) }
                        result.error("SMS_ERROR", e.message ?: "Eroare necunoscută la trimiterea SMS-ului.", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }
}
