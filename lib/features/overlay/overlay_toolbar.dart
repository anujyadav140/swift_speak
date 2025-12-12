import 'dart:async';
import 'dart:math' as math;
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:flutter/material.dart';
import '../../services/dictionary_service.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../../services/speech_service.dart';
import '../../services/gemini_service.dart';
import '../../services/snippet_service.dart';
import '../../services/subscription_service.dart';
import '../../models/snippet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/local_llm_service.dart';
import '../../services/screenshot_service.dart';

class OverlayToolbar extends StatefulWidget {
  const OverlayToolbar({super.key});

  @override
  State<OverlayToolbar> createState() => _OverlayToolbarState();
}

class _OverlayToolbarState extends State<OverlayToolbar> with TickerProviderStateMixin {
  // ... existing state ...
  
  // Services
  final SpeechService _speechService = SpeechService();
  final GeminiService _geminiService = GeminiService();
  final SnippetService _snippetService = SnippetService();
  final DictionaryService _dictionaryService = DictionaryService();
  final LocalLLMService _localLLMService = LocalLLMService();

  // ... existing code ...
  final ScreenshotService _screenshotService = ScreenshotService();

  // State
  bool _isExpanded = false;
  bool _isInputActive = false;
  late AnimationController _animationController;
  bool _isRecording = false;
  double _latestSoundLevel = 0.0;
  String _lastInjectedText = '';
  DateTime _lastInjectionTime = DateTime.fromMillisecondsSinceEpoch(0);
  List<Snippet> _snippets = [];
  List<DictionaryTerm> _userTerms = [];
  
  // Smart Schedule State
  bool _isAnalyzingScreenshot = false;
  String? _screenshotResult;

  // Subscriptions
  StreamSubscription? _resultSubscription;
  StreamSubscription? _soundLevelSubscription;
  StreamSubscription? _statusSubscription;
  StreamSubscription? _snippetsSubscription;
  StreamSubscription? _dictionarySubscription;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _setupSpeechListeners();
    _setupDataListeners();
    _setupScreenshotListener();

    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is bool) {
        if (event) {
          setState(() {
            _isExpanded = true;
            FlutterOverlayWindow.resizeOverlay(260, 80, true);
          });
          Future.delayed(const Duration(milliseconds: 250), () {
            if (mounted) {
              setState(() {
                _isInputActive = true;
              });
            }
          });
        } else {
          setState(() {
            _isInputActive = false;
            _isExpanded = false;
            // Reset Smart Schedule state on collapse
            _isAnalyzingScreenshot = false;
            _screenshotResult = null;
            FlutterOverlayWindow.resizeOverlay(70, 120, true);
          });
        }
      }
    });
  }

  void _setupScreenshotListener() {
    debugPrint("OverlayToolbar: Setting up screenshot listener");
    _screenshotService.onScreenshotDetected = (path) {
      debugPrint("OverlayToolbar: Screenshot detected callback triggered for $path");
      _handleScreenshot(path);
    };
    _screenshotService.startListening();
  }

  Future<void> _handleScreenshot(String path) async {
    debugPrint("OverlayToolbar: Handling screenshot: $path");
    if (!mounted) {
      debugPrint("OverlayToolbar: Not mounted, ignoring screenshot");
      return;
    }
    
    setState(() {
      _isExpanded = true;
      _isAnalyzingScreenshot = true;
      _screenshotResult = null;
    });
    FlutterOverlayWindow.resizeOverlay(300, 150, true); // Larger for result

    try {
      final result = await _geminiService.analyzeScreenshot(path);
      if (mounted) {
        setState(() {
          _isAnalyzingScreenshot = false;
          _screenshotResult = result.text;
        });
      }
    } catch (e) {
      if (mounted) {
        bool isQuota = e is QuotaExceededException;
        setState(() {
          _isAnalyzingScreenshot = false;
          _screenshotResult = isQuota ? "Weekly limit reached. Upgrade to Pro." : "Error: $e";
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _resultSubscription?.cancel();
    _soundLevelSubscription?.cancel();
    _statusSubscription?.cancel();
    _snippetsSubscription?.cancel();
    _dictionarySubscription?.cancel();
    _speechService.dispose();
    _screenshotService.stopListening();
    super.dispose();
  }

  // ... existing methods ...



  Widget _buildContent(Color iconColor) {
    if (_isAnalyzingScreenshot) {
      return _buildLoadingView(iconColor);
    } else if (_screenshotResult != null) {
      return _buildResultView(iconColor);
    } else if (_isExpanded) {
      return _buildExpandedToolbar(iconColor);
    } else {
      return _buildCollapsedView(iconColor);
    }
  }

  Widget _buildLoadingView(Color iconColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.graphic_eq, color: Colors.blueAccent, size: 32),
            const SizedBox(width: 16),
            const SizedBox(
              width: 20, 
              height: 20, 
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)
            ),
            const SizedBox(width: 16),
            const Icon(Icons.calendar_month, color: Colors.greenAccent, size: 32),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          "Checking Schedule...",
          style: TextStyle(color: iconColor, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildResultView(Color iconColor) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                _screenshotResult!,
                style: TextStyle(color: iconColor, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                onPressed: () {
                  setState(() {
                    _screenshotResult = null;
                    _isExpanded = false;
                    FlutterOverlayWindow.resizeOverlay(70, 120, true);
                  });
                },
              ),
              ElevatedButton.icon(
                onPressed: () {
                  _injectText(_screenshotResult!);
                  setState(() {
                    _screenshotResult = null;
                    _isExpanded = false;
                    FlutterOverlayWindow.resizeOverlay(70, 120, true);
                  });
                },
                icon: const Icon(Icons.check, size: 16),
                label: const Text("Insert"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _setupDataListeners() {
    _snippetsSubscription = _snippetService.getSnippets().listen((snippets) {
      if (mounted) setState(() => _snippets = snippets);
    });
    _dictionarySubscription = _dictionaryService.getTerms().listen((terms) {
      if (mounted) setState(() => _userTerms = terms);
    });
  }

  void _setupSpeechListeners() {
    _resultSubscription = _speechService.onResult.listen((result) {
      if (result.finalResult && result.recognizedWords.isNotEmpty) {
        _processAndInject(result.recognizedWords);
      }
    });

    _soundLevelSubscription = _speechService.onSoundLevel.listen((level) {
       double normalized = level.abs() / 10.0;
       if (normalized > 1.0) normalized = 1.0;
       if (mounted) setState(() => _latestSoundLevel = normalized);
       FlutterOverlayWindow.sendAudioLevel(normalized);
    });
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    if (_isExpanded) {
      FlutterOverlayWindow.resizeOverlay(260, 80, true);
    } else {
      FlutterOverlayWindow.resizeOverlay(70, 120, true);
    }
  }

  Future<void> _toggleRecording() async {
    setState(() {
      _isRecording = !_isRecording;
    });

    if (_isRecording) {
      await _speechService.startListening();
    } else {
      await _speechService.stopListening();
      if (mounted) {
        setState(() {
          _latestSoundLevel = 0.0;
        });
      }
    }
  }

  Future<void> _processAndInject(String rawText) async {
    print("OverlayToolbar: Processing text: '$rawText'");
    if (rawText.trim().isEmpty) return;
    
    try {
      print("OverlayToolbar: Current available snippets count: ${_snippets.length}");
      for (var s in _snippets) {
        print("OverlayToolbar: Available snippet: '${s.shortcut}'");
      }

      // Check selected model
      final prefs = await SharedPreferences.getInstance();
      final selectedModel = prefs.getString('selected_model') ?? 'Gemini 2.0 Flash Lite';
      
      String correctedText;

      if (selectedModel == 'Llama 3.2 1B Q4') {
        print("OverlayToolbar: Using Local Model: Llama 3.2 1B Q4");
        try {
          // Ensure model is loaded
          await _localLLMService.loadModel('llama-3.2-1b-q4.gguf');
          
          correctedText = await _localLLMService.formatText(
            rawText,
            snippets: _snippets,
            userTerms: _userTerms,
          );
        } catch (e) {
           print("Local Model Error: $e. Falling back to Cloud.");
           correctedText = await _geminiService.formatText(
            rawText, 
            snippets: _snippets, 
            userTerms: _userTerms,
          );
        }
      } else {
        print("OverlayToolbar: Using Cloud Model: Gemini 2.0 Flash Lite (Selected: $selectedModel)");
        // Use GeminiService
        try {
          correctedText = await _geminiService.formatText(
            rawText, 
            snippets: _snippets, 
            userTerms: _userTerms,
          );
        } catch (e) {
          if (e is QuotaExceededException) {
             debugPrint("Quota exceeded");
             _injectText("Error: Weekly limit reached."); 
             return;
          }
          rethrow;
        }
      }
      
      debugPrint("AI Corrected: $correctedText");
      
      _injectText(correctedText);
    } catch (e) {
      debugPrint("AI Error: $e");
      _injectText(rawText);
    }
  }
// ... existing code ...

  Future<void> _injectText(String text) async {
    final now = DateTime.now();
    String textToInject = text;

    if (textToInject.trim().isEmpty) {
      return;
    }

    debugPrint("Injecting text: $textToInject");
    FlutterOverlayWindow.insertText(" $textToInject"); // Add space for continuity
    _lastInjectedText = text;
    _lastInjectionTime = now;
  }

  @override
  Widget build(BuildContext context) {
    // Dark Theme Colors
    const Color baseColor = Color(0xFF1A1A1A);
    const Color accentColor = Colors.white;
    const double borderRadius = 30.0; // Capsule shape

    return Material(
      color: Colors.transparent,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Glowing Beam Animation
            if (_isInputActive)
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: BorderBeamPainter(
                      animation: _animationController,
                      borderRadius: borderRadius,
                    ),
                    child: SizedBox(
                      width: _isExpanded ? 240 : 60,
                      height: 60,
                    ),
                  );
                },
              ),
            // Main Container
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              width: _isExpanded ? 240 : 60,
              height: 60,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Material(
                color: Colors.transparent,
                child: _buildContent(accentColor),
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
            size: 24,
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
        width: 240,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (_isRecording) ...[
               // Squiggly Waveform
               Expanded(
                 child: Container(
                   height: 30,
                   child: CustomPaint(
                     painter: SquigglyWaveformPainter(
                       level: _latestSoundLevel,
                       color: iconColor,
                       animation: _animationController,
                     ),
                   ),
                 ),
               ),
            ] else ...[
              IconButton(
                onPressed: _toggleExpand,
                icon: Icon(Icons.chevron_right, color: iconColor),
              ),
            ],
            
            const SizedBox(width: 8),

            // Mic Button
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _isRecording ? Colors.white : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: iconColor),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: _toggleRecording,
                icon: Icon(
                  _isRecording ? Icons.mic : Icons.mic_none, 
                  color: _isRecording ? Colors.black : iconColor,
                ),
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

// Squiggly Waveform Painter (Matches Keyboard)
class SquigglyWaveformPainter extends CustomPainter {
  final double level;
  final Color color;
  final Animation<double> animation;

  SquigglyWaveformPainter({
    required this.level, 
    required this.color,
    required this.animation,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final midY = size.height / 2;
    final width = size.width;

    path.moveTo(0, midY);

    final phase = animation.value * 2 * math.pi;

    // High frequency, chaotic waves
    for (double x = 0; x <= width; x++) {
      // Base wave
      double y = midY;
      
      if (level > 0.01) {
        // Active Speech
        double noise1 = math.sin(x * 0.1 + phase * 2);
        double noise2 = math.sin(x * 0.3 - phase * 3);
        double noise3 = math.sin(x * 0.05 + phase);
        
        double amplitude = level * size.height * 0.4;
        y += (noise1 * amplitude) + (noise2 * amplitude * 0.5) + (noise3 * amplitude * 0.25);
      } else {
        // Idle
        y += math.sin(x * 0.05 + phase) * 2;
      }

      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(SquigglyWaveformPainter oldDelegate) => true;
}

class BorderBeamPainter extends CustomPainter {
  final Animation<double> animation;
  final double borderRadius;

  BorderBeamPainter({
    required this.animation,
    required this.borderRadius,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0; // 1px border

    // Rotating gradient
    final gradient = SweepGradient(
      colors: [
        Colors.transparent,
        Colors.white,
        Colors.transparent,
      ],
      stops: const [0.0, 0.5, 1.0],
      startAngle: 0.0,
      endAngle: math.pi * 2,
      transform: GradientRotation(animation.value * 2 * math.pi),
    );

    paint.shader = gradient.createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(BorderBeamPainter oldDelegate) => true;
}
