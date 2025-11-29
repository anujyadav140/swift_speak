package com.example.swift_speak

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityWindowInfo
import android.view.accessibility.AccessibilityNodeInfo
import android.util.Log
import android.content.Intent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle

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
                // sendBroadcast(intent) // Disabled per user request to remove overlay
                
                Log.d("SwiftSpeakAccess", "Broadcast Sent: $isInputActive")
            }
        }
    }

    override fun onInterrupt() {
        Log.d("SwiftSpeakAccess", "Service Interrupted")
    }
    
    private val textInjectionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "com.example.swift_speak.INSERT_TEXT") {
                val text = intent.getStringExtra("text")
                if (!text.isNullOrEmpty()) {
                    injectText(text)
                }
            }
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d("SwiftSpeakAccess", "Service Connected")
        
        val filter = IntentFilter("com.example.swift_speak.INSERT_TEXT")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(textInjectionReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(textInjectionReceiver, filter)
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(textInjectionReceiver)
    }

    private fun injectText(text: String) {
        Log.d("SwiftSpeakAccess", "Attempting to inject text: $text")
        val root = rootInActiveWindow
        if (root == null) {
            Log.e("SwiftSpeakAccess", "rootInActiveWindow is null")
            return
        }
        
        // Try finding focus first
        var focused = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
        if (focused == null) {
             Log.d("SwiftSpeakAccess", "No FOCUS_INPUT found, searching for editable node...")
             // Fallback: BFS to find first editable node
             focused = findEditableNode(root)
        }
        
        if (focused != null && focused.isEditable) {
            Log.d("SwiftSpeakAccess", "Found editable node: ${focused.className}")
            
            // Smart Insert Strategy (No Clipboard)
            var currentText = focused.text?.toString() ?: ""
            val hintText = focused.hintText?.toString()
            
            var start = focused.textSelectionStart
            var end = focused.textSelectionEnd
            
            // Fix for "Message" hint text being treated as content
            var isHint = false
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                isHint = focused.isShowingHintText
            }
            
            // Fallback: Check if text equals hint text
            if (!isHint && !hintText.isNullOrEmpty() && currentText == hintText) {
                isHint = true
            }
            
            // Aggressive Fallback: Explicitly ignore common hint texts like "Message"
            // This fixes the issue where some apps (like Google Messages) expose "Message" as text but don't set isShowingHintText
            if (!isHint && (currentText.equals("Message", ignoreCase = true) || 
                            currentText.equals("Type a message", ignoreCase = true) ||
                            currentText.equals("Search", ignoreCase = true))) {
                Log.d("SwiftSpeakAccess", "Detected common hint text: '$currentText'. Treating as empty.")
                isHint = true
            }

            if (isHint) {
                Log.d("SwiftSpeakAccess", "Field is showing hint text. Treating as empty.")
                currentText = ""
                start = 0
                end = 0
            }
            
            var newText = ""
            var newCursorPos = 0
            
            if (start >= 0 && end >= 0 && start <= currentText.length && end <= currentText.length) {
                // Insert at cursor or replace selection
                val selectionStart = Math.min(start, end)
                val selectionEnd = Math.max(start, end)
                
                val prefix = currentText.substring(0, selectionStart)
                val suffix = currentText.substring(selectionEnd)
                
                newText = prefix + text + suffix
                newCursorPos = prefix.length + text.length
                Log.d("SwiftSpeakAccess", "Inserting at cursor: $selectionStart")
            } else {
                // Append to end if no cursor info
                newText = currentText + text
                newCursorPos = newText.length
                Log.d("SwiftSpeakAccess", "Appending to end (no cursor info)")
            }
            
            // Apply new text
            val arguments = Bundle()
            arguments.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, newText)
            val success = focused.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
            Log.d("SwiftSpeakAccess", "SET_TEXT success: $success")
            
            // Restore cursor position
            if (success) {
                val selectionArgs = Bundle()
                selectionArgs.putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_START_INT, newCursorPos)
                selectionArgs.putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_END_INT, newCursorPos)
                focused.performAction(AccessibilityNodeInfo.ACTION_SET_SELECTION, selectionArgs)
            }
            
            focused.recycle()
        } else {
            Log.e("SwiftSpeakAccess", "No editable node found to inject text")
        }
        root.recycle()
    }

    private fun findEditableNode(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (node.isEditable) return node
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val result = findEditableNode(child)
            if (result != null) return result
            child.recycle()
        }
        return null
    }
}
