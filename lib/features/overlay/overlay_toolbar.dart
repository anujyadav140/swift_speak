import 'dart:async';
import 'dart:math' as math;
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../../services/speech_service.dart';

class OverlayToolbar extends StatefulWidget {
  const OverlayToolbar({super.key});

  @override
  State<OverlayToolbar> createState() => _OverlayToolbarState();
}

class _OverlayToolbarState extends State<OverlayToolbar> with TickerProviderStateMixin {
  bool _isExpanded = false;
  bool _isInputActive = false;
  // bool _isProcessing = false; // Removed blocking UI state
  late AnimationController _borderBeamController;
  
  // Services
  final SpeechService _speechService = SpeechService();
  
  // STT State
  bool _isRecording = false;
  
  // Waveform State
  List<double> _amplitudes = [];
  final int _maxAmplitudes = 40; // More bars for smoother look
  double _latestSoundLevel = 0.0;
  Timer? _waveformTimer;
  
  // AI Vars
  late GenerativeModel _model;
  
  // Deduplication vars
  String _lastInjectedText = '';
  DateTime _lastInjectionTime = DateTime.fromMillisecondsSinceEpoch(0);

  // Subscriptions
  StreamSubscription? _resultSubscription;
  StreamSubscription? _soundLevelSubscription;
  StreamSubscription? _statusSubscription;

  @override
  void initState() {
    super.initState();
    _borderBeamController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _initVertexAI();
    _setupSpeechListeners();

    // Listen to data shared from the main app
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is bool) {
        if (event) {
          // Input Active: Auto Expand first
          setState(() {
            _isExpanded = true;
            // Resize immediately for expansion
            FlutterOverlayWindow.resizeOverlay(220, 70, true);
          });
          
          // Delay beam activation until expansion finishes (250ms)
          Future.delayed(const Duration(milliseconds: 250), () {
            if (mounted) {
              setState(() {
                _isInputActive = true;
              });
            }
          });
        } else {
          // Input Inactive: Collapse and hide beam
          setState(() {
            _isInputActive = false;
            _isExpanded = false;
            // Resize back to collapsed state
            FlutterOverlayWindow.resizeOverlay(70, 120, true);
          });
        }
      }
    });
  }

  void _initVertexAI() {
    // Initialize Gemini 1.5 Flash for speed
    _model = FirebaseVertexAI.instance.generativeModel(model: 'gemini-2.0-flash-lite');
  }

  void _setupSpeechListeners() {
    // 1. Result Listener
    _resultSubscription = _speechService.onResult.listen((result) {
      if (result.finalResult) {
        if (result.recognizedWords.isNotEmpty) {
          _processAndInject(result.recognizedWords);
        }
      }
    });

    // 2. Sound Level Listener (for Waveform)
    _soundLevelSubscription = _speechService.onSoundLevel.listen((level) {
       // Just update the target level, don't setState here to avoid jank
       // Normalize: STT often returns -10 to 10 or similar.
       // We want a value between 0.0 and 1.0.
       // Assuming level is in dB-like range or raw amplitude. 
       // Let's try a simple absolute normalization first.
       double normalized = level.abs() / 10.0;
       if (normalized > 1.0) normalized = 1.0;
       _latestSoundLevel = normalized;
    });

    // 3. Status Listener
    _statusSubscription = _speechService.onStatus.listen((status) {
      // Handle status updates if needed
    });
  }

  void _startWaveformTimer() {
    _waveformTimer?.cancel();
    // 60 FPS update loop for smooth animation
    _waveformTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) return;
      
      setState(() {
        // Smoothly interpolate towards the latest level
        // This creates a "falloff" effect
        double current = _amplitudes.isEmpty ? 0.0 : _amplitudes.last;
        double target = _latestSoundLevel;
        
        // Interpolation factor (adjust for speed)
        double lerp = 0.2; 
        double next = current + (target - current) * lerp;
        
        // Add some noise if it's too static to make it look "alive"
        if (next < 0.05) next = math.max(0.02, next + (math.Random().nextDouble() * 0.05));

        _amplitudes.add(next);
        if (_amplitudes.length > _maxAmplitudes) {
          _amplitudes.removeAt(0);
        }
      });
    });
  }

  void _stopWaveformTimer() {
    _waveformTimer?.cancel();
    _waveformTimer = null;
    if (mounted) {
      setState(() {
        _amplitudes.clear();
        _latestSoundLevel = 0.0;
      });
    }
  }

  @override
  void dispose() {
    _borderBeamController.dispose();
    _waveformTimer?.cancel();
    _resultSubscription?.cancel();
    _soundLevelSubscription?.cancel();
    _statusSubscription?.cancel();
    _speechService.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    // Adjust overlay size based on state
    if (_isExpanded) {
      FlutterOverlayWindow.resizeOverlay(220, 70, true); // Adjusted width
    } else {
      FlutterOverlayWindow.resizeOverlay(70, 120, true); // Enable drag when contracted
    }
  }

  Future<void> _toggleRecording() async {
    setState(() {
      _isRecording = !_isRecording;
    });

    if (_isRecording) {
      // Start
      _amplitudes = List.filled(_maxAmplitudes, 0.05, growable: true); // Init with low noise
      _startWaveformTimer();
      await _speechService.startListening();
    } else {
      // Stop
      _stopWaveformTimer();
      await _speechService.stopListening();
    }
  }

  Future<void> _processAndInject(String rawText) async {
    if (rawText.trim().isEmpty) return;
    
    // Don't block UI with _isProcessing
    // Just process in background

    try {
      final prompt = "Rewrite the following text with proper grammar, punctuation, and capitalization. Do not add any introductory or concluding remarks. Output ONLY the corrected text: '$rawText'";
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      String correctedText = response.text ?? rawText;
      // Remove any potential leading/trailing quotes or markdown that the model might add
      correctedText = correctedText.replaceAll(RegExp(r'^["`]+|["`]+$'), '').trim();
      
      debugPrint("Gemini Corrected: $correctedText");
      
      _injectText(correctedText);
    } catch (e) {
      debugPrint("Gemini Error: $e");
      _injectText(rawText);
    }
  }

  void _injectText(String text) {
    final now = DateTime.now();
    
    // 1. Exact duplicate guard (Glitch loop protection)
    if (text == _lastInjectedText && now.difference(_lastInjectionTime).inMilliseconds < 2000) {
      debugPrint("Duplicate injection prevented: $text");
      return;
    }

    String textToInject = text;

    // 2. Overlap removal (Context awareness)
    if (_lastInjectedText.isNotEmpty) {
      String cleaned = _removeOverlap(_lastInjectedText, text);
      if (cleaned != text) {
        debugPrint("Overlap detected. Original: '$text', Cleaned: '$cleaned'");
        textToInject = cleaned;
      }
    }

    if (textToInject.trim().isEmpty) {
      return;
    }

    debugPrint("Injecting text: $textToInject");
    FlutterOverlayWindow.insertText(" $textToInject"); // Add space for continuity
    _lastInjectedText = text; // Store the full text we received/processed
    _lastInjectionTime = now;
  }

  String _removeOverlap(String last, String current) {
    if (last.isEmpty || current.isEmpty) return current;

    List<String> lastWords = last.trim().split(' ');
    List<String> currentWords = current.trim().split(' ');

    int maxOverlap = 0;
    // Check for overlap of size k
    for (int k = 1; k <= lastWords.length && k <= currentWords.length; k++) {
      // Check if the last k words of 'last' match the first k words of 'current'
      List<String> suffix = lastWords.sublist(lastWords.length - k);
      List<String> prefix = currentWords.sublist(0, k);
      
      bool match = true;
      for (int i = 0; i < k; i++) {
        // Normalize: Remove punctuation and lowercase for comparison
        String w1 = suffix[i].toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
        String w2 = prefix[i].toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
        if (w1 != w2) {
          match = false;
          break;
        }
      }
      
      if (match) {
        maxOverlap = k;
      }
    }

    if (maxOverlap > 0) {
      // Remove the first k words from current
      return currentWords.sublist(maxOverlap).join(' ');
    }
    
    return current;
  }

  @override
  Widget build(BuildContext context) {
    // Monochromatic Theme Colors
    const Color primaryColor = Colors.black;
    const Color onPrimaryColor = Colors.white;

    return Material(
      color: Colors.transparent,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Border Beam Animation
            if (_isInputActive)
              AnimatedBuilder(
                animation: _borderBeamController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: BorderBeamPainter(
                      progress: _borderBeamController.value,
                      color: Colors.white,
                      borderRadius: 30,
                    ),
                    child: SizedBox(
                      width: _isExpanded ? 200 : 50, // Reduced width
                      height: _isExpanded ? 60 : 100,
                    ),
                  );
                },
              ),
            // Main Container
            AnimatedContainer(
              duration: const Duration(milliseconds: 250), // Faster animation
              curve: Curves.easeInOut,
              width: _isExpanded ? 200 : 50, // Reduced width
              height: _isExpanded ? 60 : 100,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              // Wrap content in Material to ensure InkWell/IconButton splashes are visible on top of the container color
              child: Material(
                color: Colors.transparent,
                child: _isExpanded ? _buildExpandedToolbar(onPrimaryColor) : _buildCollapsedView(onPrimaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsedView(Color iconColor) {
    return InkWell(
      onTap: _toggleExpand,
      borderRadius: BorderRadius.circular(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chevron_left,
            color: iconColor,
            size: 30,
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedToolbar(Color iconColor) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Container(
        width: 200, // Ensure Row takes full expanded width for even spacing
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (_isRecording) ...[
               // Custom Waveform
               Expanded(
                 child: CustomPaint(
                   size: const Size(120, 40),
                   painter: WaveformPainter(
                     amplitudes: _amplitudes,
                     color: Colors.white,
                   ),
                 ),
               ),
            ] else ...[
              IconButton(
                onPressed: _toggleExpand,
                icon: Icon(Icons.chevron_right, color: iconColor),
              ),
            ],
            
            // Mic Button (Always visible, highlighted when recording)
            Container(
              decoration: _isRecording ? BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ) : null,
              child: IconButton(
                onPressed: _toggleRecording,
                icon: Icon(Icons.mic, color: iconColor),
              ),
            ),

            if (!_isRecording) ...[
              IconButton(
                onPressed: () {
                  debugPrint("Copy Pressed");
                },
                icon: Icon(Icons.copy, color: iconColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final Color color;

  WaveformPainter({required this.amplitudes, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    // Use a fixed number of bars for consistency or dynamic based on width
    // Here we just draw what we have
    final double spacing = size.width / (amplitudes.length > 1 ? amplitudes.length - 1 : 1);
    final double centerY = size.height / 2;

    for (int i = 0; i < amplitudes.length; i++) {
      final double x = i * spacing;
      // Amplify the visual effect
      final double height = (amplitudes[i] * size.height * 1.5).clamp(2.0, size.height);
      
      canvas.drawLine(
        Offset(x, centerY - height / 2),
        Offset(x, centerY + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return true; 
  }
}

class BorderBeamPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double borderRadius;

  BorderBeamPainter({
    required this.progress,
    required this.color,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // Create a sweep gradient that rotates
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..shader = SweepGradient(
        colors: [Colors.transparent, color, Colors.transparent],
        stops: const [0.0, 0.5, 1.0],
        startAngle: 0.0,
        endAngle: math.pi * 2,
        transform: GradientRotation(progress * math.pi * 2),
      ).createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(BorderBeamPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
