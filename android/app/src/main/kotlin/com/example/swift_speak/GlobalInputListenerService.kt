package com.example.swift_speak

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.content.Intent
import android.view.accessibility.AccessibilityNodeInfo
import android.util.Log

class GlobalInputListenerService : AccessibilityService() {
    private var lastInputState = false

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        // Check for focus changes or window state changes
        if (event.eventType == AccessibilityEvent.TYPE_VIEW_FOCUSED || 
            event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            
            var isInputActive = false
            val source = event.source
            
            if (source != null) {
                // Try to find the view that currently has input focus
                val focused = source.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
                if (focused != null) {
                    isInputActive = focused.isEditable
                    focused.recycle()
                } else {
                    // Fallback: if this event is view focused, check the source itself
                    if (event.eventType == AccessibilityEvent.TYPE_VIEW_FOCUSED) {
                        isInputActive = source.isEditable
                    }
                }
                source.recycle()
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
