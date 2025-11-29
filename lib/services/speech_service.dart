import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

class SpeechService {
  final SpeechToText _speechToText = SpeechToText();
  
  // Streams for UI updates
  final _onResultController = StreamController<SpeechRecognitionResult>.broadcast();
  Stream<SpeechRecognitionResult> get onResult => _onResultController.stream;

  final _onSoundLevelController = StreamController<double>.broadcast();
  Stream<double> get onSoundLevel => _onSoundLevelController.stream;

  final _onStatusController = StreamController<String>.broadcast();
  Stream<String> get onStatus => _onStatusController.stream;

  // State
  bool get isListening => _speechToText.isListening;
  bool _speechEnabled = false;

  Future<bool> initialize() async {
    if (_speechEnabled) return true;
    
    try {
      _speechEnabled = await _speechToText.initialize(
        onError: _onError,
        onStatus: _onStatus,
        debugLogging: true,
      );
      debugPrint("SpeechService: Initialized = $_speechEnabled");
    } catch (e) {
      debugPrint("SpeechService: Init Error: $e");
    }
    return _speechEnabled;
  }

  Future<void> startListening() async {
    if (!_speechEnabled) {
      bool success = await initialize();
      if (!success) return;
    }

    if (_speechToText.isListening) return;

    try {
      _onStatusController.add('listening');
      
      await _speechToText.listen(
        onResult: (result) => _onResultController.add(result),
        onSoundLevelChange: (level) => _onSoundLevelController.add(level),
      );
    } catch (e) {
      debugPrint("SpeechService: Start Error: $e");
      _onStatusController.add('notListening');
    }
  }

  Future<void> stopListening() async {
    await _speechToText.stop();
    _onStatusController.add('notListening');
  }

  void _onStatus(String status) {
    debugPrint("SpeechService: Status = $status");
    _onStatusController.add(status);
  }

  void _onError(SpeechRecognitionError error) {
    debugPrint("SpeechService: Error = ${error.errorMsg}");
    // We don't auto-restart here anymore. The UI will handle restarts if needed.
  }

  void dispose() {
    _onResultController.close();
    _onSoundLevelController.close();
    _onStatusController.close();
  }
}
