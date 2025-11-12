package com.example.safety_app

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.telephony.SmsManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "safety_app/sms"
    private val smsPermission = Manifest.permission.SEND_SMS
    private val requestCode = 2001

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
                    try {
                        val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= 31) {
                            this.getSystemService(SmsManager::class.java)
                        } else {
                            SmsManager.getDefault()
                        }
                        smsManager.sendTextMessage(to, null, message, null, null)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SMS_ERROR", e.message, null)
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
