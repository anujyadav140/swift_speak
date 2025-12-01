package com.example.swift_speak;

import android.content.Intent;
import android.inputmethodservice.InputMethodService;
import android.view.View;
import android.view.ViewGroup;
import android.view.inputmethod.InputConnection;
import android.view.inputmethod.InputMethodManager;
import android.widget.FrameLayout;

import io.flutter.FlutterInjector;
import io.flutter.embedding.android.FlutterView;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.dart.DartExecutor;
import io.flutter.plugin.common.MethodChannel;

import io.flutter.embedding.android.RenderMode;

public class SwiftSpeakIMEService extends InputMethodService {
    private FlutterEngine flutterEngine;
    private FlutterView flutterView;
    private static final String CHANNEL = "com.example.swift_speak/ime";

    private MethodChannel methodChannel;

    @Override
    public void onCreate() {
        super.onCreate();
        android.util.Log.d("SwiftSpeakIME", "onCreate: Initializing Flutter Engine");

        // Initialize Flutter Engine
        flutterEngine = new FlutterEngine(this);

        // Start executing Dart code to pre-warm the engine.
        flutterEngine.getDartExecutor().executeDartEntrypoint(
                new DartExecutor.DartEntrypoint(
                        FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                        "imeMain"));

        // Setup Method Channel
        methodChannel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL);
        methodChannel.setMethodCallHandler(
                (call, result) -> {
                    if (call.method.equals("commitText")) {
                        String text = call.argument("text");
                        android.util.Log.d("SwiftSpeakIME", "commitText: " + text);
                        InputConnection ic = getCurrentInputConnection();
                        if (ic != null) {
                            boolean success = ic.commitText(text, 1);
                            android.util.Log.d("SwiftSpeakIME", "ic.commitText result: " + success);
                            result.success(success);
                        } else {
                            android.util.Log.e("SwiftSpeakIME", "InputConnection is null");
                            result.error("NO_INPUT_CONNECTION", "Input connection is null", null);
                        }
                    } else if (call.method.equals("switchKeyboard")) {
                        InputMethodManager imeManager = (InputMethodManager) getSystemService(
                                INPUT_METHOD_SERVICE);
                        if (imeManager != null) {
                            imeManager.showInputMethodPicker();
                        }
                        result.success(true);
                    } else if (call.method.equals("openSettings")) {
                        Intent intent = new Intent(SwiftSpeakIMEService.this, MainActivity.class);
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                        startActivity(intent);
                        result.success(true);
                    } else if (call.method.equals("openPermissionsPage")) {
                        Intent intent = new Intent(SwiftSpeakIMEService.this, MainActivity.class);
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                        intent.putExtra("route", "/permissions");
                        startActivity(intent);
                        result.success(true);
                    } else {
                        result.notImplemented();
                    }
                });
    }

    @Override
    public View onCreateInputView() {
        android.util.Log.d("SwiftSpeakIME", "onCreateInputView: Creating Flutter View");

        // Detach existing view if present to prevent engine confusion
        if (flutterView != null) {
            flutterView.detachFromFlutterEngine();
        }

        // Calculate height (e.g. 350dp)
        int height = (int) (350 * getResources().getDisplayMetrics().density);

        // Create a FrameLayout to hold the FlutterView
        FrameLayout layout = new FrameLayout(this);
        layout.setLayoutParams(new ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                height));

        // Create FlutterView with Texture Mode to avoid SurfaceView Z-ordering/blank
        // issues
        flutterView = new FlutterView(this, RenderMode.texture);
        flutterView.attachToFlutterEngine(flutterEngine);

        layout.addView(flutterView, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                height));
        return layout;
    }

    @Override
    public void onStartInputView(android.view.inputmethod.EditorInfo info, boolean restarting) {
        super.onStartInputView(info, restarting);
        android.util.Log.d("SwiftSpeakIME", "onStartInputView: Resuming Flutter Engine");
        if (flutterEngine != null) {
            flutterEngine.getLifecycleChannel().appIsResumed();
        }

        // Force redraw to prevent blank screen
        if (flutterView != null) {
            flutterView.invalidate();
        }

        // Send package name to Flutter
        if (info != null && info.packageName != null) {
            android.util.Log.d("SwiftSpeakIME", "App Package: " + info.packageName);
            methodChannel.invokeMethod("appPackageName", info.packageName);
        }

        // Force refresh settings (Style/Model)
        methodChannel.invokeMethod("refreshSettings", null);
    }

    @Override
    public void onFinishInputView(boolean finishingInput) {
        super.onFinishInputView(finishingInput);
        android.util.Log.d("SwiftSpeakIME", "onFinishInputView: Keeping Flutter Engine Running");
        // Commenting out pause to prevent blank screen on resume
        // if (flutterEngine != null) {
        // flutterEngine.getLifecycleChannel().appIsPaused();
        // }
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        android.util.Log.d("SwiftSpeakIME", "onDestroy: Cleaning up");
        if (flutterView != null) {
            flutterView.detachFromFlutterEngine();
        }
        if (flutterEngine != null) {
            flutterEngine.destroy();
        }
    }
}
