package com.example.swift_speak

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.content.Intent
import android.view.accessibility.AccessibilityNodeInfo
import android.util.Log
import android.view.accessibility.AccessibilityWindowInfo

class GlobalInputListenerService : AccessibilityService() {
    private var lastInputState = false

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        // Check for focus changes or window state changes
        if (event.eventType == AccessibilityEvent.TYPE_VIEW_FOCUSED || 
            event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            
            var isInputActive = false
            
            // 1. Check if any window is an Input Method (Keyboard)
            // This requires flagRetrieveInteractiveWindows in config
            val windows = windows
            if (windows != null) {
                for (window in windows) {
                    if (window.type == AccessibilityWindowInfo.TYPE_INPUT_METHOD) {
                        isInputActive = true
                        break
                    }
                }
            }

            // 2. If keyboard not found, check for focused editable view in ALL interactive windows
            if (!isInputActive && windows != null) {
                for (window in windows) {
                    if (window.type == AccessibilityWindowInfo.TYPE_APPLICATION) {
                        val root = window.root
                        if (root != null) {
                            val focused = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
                            if (focused != null) {
                                if (focused.isEditable) {
                                    isInputActive = true
                                    focused.recycle()
                                    root.recycle()
                                    break // Found it!
                                }
                                focused.recycle()
                            }
                            root.recycle()
                        }
                    }
                }
            }
            
            // 3. Last resort fallback (event source)
            if (!isInputActive) {
                val source = event.source
                if (source != null) {
                    if (event.eventType == AccessibilityEvent.TYPE_VIEW_FOCUSED) {
                        isInputActive = source.isEditable
                    }
                    source.recycle()
                }
            }

            Log.d("SwiftSpeakAccess", "Input Active: $isInputActive")
            
            // Only broadcast if state changed
            if (isInputActive != lastInputState) {
                lastInputState = isInputActive
                
                // Send broadcast
                val intent = Intent("com.example.swift_speak.INPUT_STATE")
                intent.setPackage(packageName) // Make explicit to ensure delivery to background activity
                intent.putExtra("is_active", isInputActive)
                sendBroadcast(intent)
                
                Log.d("SwiftSpeakAccess", "Broadcast Sent: $isInputActive")
            }
        }
    }

    override fun onInterrupt() {
        Log.d("SwiftSpeakAccess", "Service Interrupted")
    }
    
    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d("SwiftSpeakAccess", "Service Connected")
    }
}
