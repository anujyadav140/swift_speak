import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class ScreenshotService {
  static const MethodChannel _channel = MethodChannel('com.example.swift_speak/screenshot');
  
  // Callback for when a screenshot is detected
  Function(String path)? onScreenshotDetected;

  ScreenshotService() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> startListening() async {
    try {
      await _channel.invokeMethod('startListening');
    } catch (e) {
      debugPrint('Error starting screenshot listener: $e');
    }
  }

  Future<void> stopListening() async {
    try {
      await _channel.invokeMethod('stopListening');
    } catch (e) {
      debugPrint('Error stopping screenshot listener: $e');
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    debugPrint("ScreenshotService: Received method call ${call.method}");
    if (call.method == 'onScreenshot') {
      final String path = call.arguments as String;
      debugPrint('ScreenshotService: Screenshot detected at $path');
      onScreenshotDetected?.call(path);
    }
  }
}
