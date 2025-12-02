package com.example.swift_speak

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

import android.database.ContentObserver
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.swift_speak/input_state"
    private var eventSink: EventChannel.EventSink? = null
    private var screenshotObserver: ContentObserver? = null
    private var screenshotChannel: MethodChannel? = null

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "com.example.swift_speak.INPUT_STATE") {
                val isActive = intent.getBooleanExtra("is_active", false)
                android.util.Log.d("SwiftSpeakMain", "Received Broadcast: $isActive")
                runOnUiThread {
                    eventSink?.success(isActive)
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    val filter = IntentFilter("com.example.swift_speak.INPUT_STATE")
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
                    } else {
                        registerReceiver(receiver, filter)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    unregisterReceiver(receiver)
                    eventSink = null
                }
            }
        )
        
        // Handle method calls for opening settings
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.swift_speak/settings").setMethodCallHandler { call, result ->
            if (call.method == "openAccessibilitySettings") {
                val intent = Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS)
                startActivity(intent)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        // Handle app navigation intent
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.swift_speak/app").setMethodCallHandler { call, result ->
            if (call.method == "checkIntent") {
                val route = intent?.getStringExtra("route")
                result.success(route)
                intent?.removeExtra("route")
            } else {
                result.notImplemented()
            }
        }

        // Handle screenshot detection
        screenshotChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.swift_speak/screenshot")
        screenshotChannel?.setMethodCallHandler { call, result ->
            if (call.method == "startListening") {
                startScreenshotListening()
                result.success(null)
            } else if (call.method == "stopListening") {
                stopScreenshotListening()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun startScreenshotListening() {
        if (screenshotObserver != null) return
        
        android.util.Log.d("SwiftSpeakMain", "Starting screenshot listening...")
        val handler = Handler(Looper.getMainLooper())
        screenshotObserver = object : ContentObserver(handler) {
            override fun onChange(selfChange: Boolean, uri: Uri?) {
                super.onChange(selfChange, uri)
                android.util.Log.d("SwiftSpeakMain", "ContentObserver onChange: $uri")
                handleMediaChange()
            }
        }
        
        contentResolver.registerContentObserver(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            true,
            screenshotObserver!!
        )
    }

    private fun stopScreenshotListening() {
        android.util.Log.d("SwiftSpeakMain", "Stopping screenshot listening...")
        screenshotObserver?.let {
            contentResolver.unregisterContentObserver(it)
            screenshotObserver = null
        }
    }

    private fun handleMediaChange() {
        android.util.Log.d("SwiftSpeakMain", "Handling media change...")
        val projection = arrayOf(
            MediaStore.Images.Media.DATA,
            MediaStore.Images.Media.DATE_ADDED
        )
        val sortOrder = "${MediaStore.Images.Media.DATE_ADDED} DESC"
        
        try {
            contentResolver.query(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                projection,
                null,
                null,
                sortOrder
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val pathColumn = cursor.getColumnIndex(MediaStore.Images.Media.DATA)
                    val dateColumn = cursor.getColumnIndex(MediaStore.Images.Media.DATE_ADDED)
                    
                    if (pathColumn != -1 && dateColumn != -1) {
                        val path = cursor.getString(pathColumn)
                        val dateAdded = cursor.getLong(dateColumn)
                        
                        val currentTime = System.currentTimeMillis() / 1000
                        val diff = currentTime - dateAdded
                        
                        android.util.Log.d("SwiftSpeakMain", "Latest image: $path, Added: $dateAdded, Current: $currentTime, Diff: $diff")

                        // Check if it's a screenshot (by path) and recent (last 5 seconds)
                        if (diff <= 5 && path.contains("Screenshots", true)) {
                            android.util.Log.d("SwiftSpeakMain", "Screenshot detected! Sending to Flutter.")
                            runOnUiThread {
                                screenshotChannel?.invokeMethod("onScreenshot", path)
                            }
                        } else {
                            android.util.Log.d("SwiftSpeakMain", "Ignored: Not a recent screenshot.")
                        }
                    }
                } else {
                    android.util.Log.d("SwiftSpeakMain", "Cursor empty.")
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("SwiftSpeakMain", "Error handling media change", e)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }
}
