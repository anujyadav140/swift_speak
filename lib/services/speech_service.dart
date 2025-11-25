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
  bool _isListening = false;
  bool get isListening => _isListening;
  bool _speechEnabled = false;
  bool _userWantsToListen = false; // The "master switch"

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
    _userWantsToListen = true;
    await _start();
  }

  Future<void> stopListening() async {
    _userWantsToListen = false;
    _isListening = false;
    await _speechToText.stop();
    _onStatusController.add('notListening');
  }

  Future<void> _start() async {
    if (!_speechEnabled) {
      bool success = await initialize();
      if (!success) return;
    }

    if (_speechToText.isListening) return;

    try {
      _isListening = true;
      _onStatusController.add('listening');
      
      await _speechToText.listen(
        onResult: (result) => _onResultController.add(result),
        onSoundLevelChange: (level) => _onSoundLevelController.add(level),
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
      );
    } catch (e) {
      debugPrint("SpeechService: Start Error: $e");
      _isListening = false;
      _onStatusController.add('notListening');
    }
  }

  void _onStatus(String status) {
    debugPrint("SpeechService: Status = $status");
    _onStatusController.add(status);
    
    if (status == 'done' || status == 'notListening') {
      _isListening = false;
      // Auto-restart if the user still wants to listen
      if (_userWantsToListen) {
        debugPrint("SpeechService: Auto-restarting...");
        // Small delay to prevent tight loops
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_userWantsToListen) {
            _start();
          }
        });
      }
    }
  }

  void _onError(SpeechRecognitionError error) {
    debugPrint("SpeechService: Error = ${error.errorMsg}");
    
    // If it's a timeout or no match, we just restart if desired
    if (error.errorMsg == 'error_speech_timeout' || error.errorMsg == 'error_no_match') {
       if (_userWantsToListen) {
         _start();
       }
       return;
    }

    // For other errors, maybe backoff? For now, just try to restart if user wants it.
    if (_userWantsToListen) {
       Future.delayed(const Duration(milliseconds: 1000), () {
          if (_userWantsToListen) {
            _start();
          }
       });
    }
  }

  void dispose() {
    _onResultController.close();
    _onSoundLevelController.close();
    _onStatusController.close();
  }
}
