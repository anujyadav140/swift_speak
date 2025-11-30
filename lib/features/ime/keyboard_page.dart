import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/speech_service.dart';
import '../../services/gemini_service.dart';
import '../../services/dictionary_service.dart';
import '../../services/snippet_service.dart';
import '../../services/style_service.dart';
import '../../models/snippet.dart';
import '../../widgets/border_beam_painter.dart';

class KeyboardPage extends StatefulWidget {
  const KeyboardPage({super.key});

  @override
  State<KeyboardPage> createState() => _KeyboardPageState();
}

class _KeyboardPageState extends State<KeyboardPage> with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _channel = MethodChannel('com.example.swift_speak/ime');
  final SpeechService _speechService = SpeechService();
  final GeminiService _geminiService = GeminiService();
  final DictionaryService _dictionaryService = DictionaryService();
  final SnippetService _snippetService = SnippetService();
  final StyleService _styleService = StyleService();
  
  bool _isListening = false;
  double _soundLevel = 0.0;
  
  // Text Handling
  String _accumulatedText = ""; // Text from previous sessions
  String _currentText = "";     // Text from current session
  String _status = "READY";
  String _appContext = "";      // Detected app type
  bool _shouldBeListening = false; // User intent to listen
  bool _hasPermission = false;
  List<DictionaryTerm> _userTerms = [];
  List<Snippet> _snippets = [];
  
  // Stream subscriptions
  StreamSubscription? _resultSubscription;
  StreamSubscription? _soundLevelSubscription;
  StreamSubscription? _statusSubscription;
  StreamSubscription? _dictionarySubscription;
  StreamSubscription? _snippetSubscription;

  // Animation controllers
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
    _initializeSpeech();
    _subscribeToDictionary();
    _subscribeToSnippets();
    
    // Slower animation for a smoother look
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5500), 
    )..repeat();
    
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == "appPackageName") {
      final packageName = call.arguments as String;
      debugPrint("Received package name: $packageName");
      final type = await _geminiService.classifyApp(packageName);
      if (mounted) {
        setState(() {
          _appContext = type;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    _resultSubscription?.cancel();
    _soundLevelSubscription?.cancel();
    _statusSubscription?.cancel();
    _dictionarySubscription?.cancel();
    _snippetSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    final status = await Permission.microphone.status;
    if (mounted) {
      setState(() {
        _hasPermission = status.isGranted;
      });
    }
  }

  Future<void> _openPermissionsPage() async {
    try {
      await _channel.invokeMethod('openPermissionsPage');
    } catch (e) {
      debugPrint("Failed to open permissions page: $e");
    }
  }

  void _subscribeToDictionary() {
    _dictionarySubscription = _dictionaryService.getTerms().listen((terms) {
      if (mounted) {
        setState(() {
          _userTerms = terms;
        });
      }
    });
  }

  void _subscribeToSnippets() {
    _snippetSubscription = _snippetService.getSnippets().listen((snippets) {
      if (mounted) {
        setState(() {
          _snippets = snippets;
        });
      }
    });
  }

  Future<void> _initializeSpeech() async {
    try {
      bool available = await _speechService.initialize();
      if (mounted) {
        setState(() => _status = available ? "READY" : "MIC UNAVAILABLE");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = "ERROR");
      }
    }
  }

  void _toggleListening() async {
    if (!_hasPermission) {
      _openPermissionsPage();
      return;
    }

    if (_shouldBeListening) {
      // User clicked Stop -> Process with Gemini
      await _stopListeningAndProcess();
    } else {
      // User clicked Start
      setState(() {
        _shouldBeListening = true;
        _isListening = true; // UI state
        _status = "LISTENING...";
        _accumulatedText = "";
        _currentText = "";
      });
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    if (!_hasPermission) {
      _openPermissionsPage();
      return;
    }

    // 1. Result Listener
    _resultSubscription?.cancel();
    _resultSubscription = _speechService.onResult.listen((result) {
      if (mounted) {
        setState(() {
          String newText = result.recognizedWords;
          // Check if the new text starts with what we've already accumulated.
          // This happens if the speech engine keeps history across our manual "stops".
          if (_accumulatedText.isNotEmpty && newText.startsWith(_accumulatedText)) {
            _currentText = newText.substring(_accumulatedText.length).trim();
          } else {
            _currentText = newText;
          }

          if (result.finalResult) {
             _accumulatedText = "$_accumulatedText $_currentText".trim();
             _currentText = "";
          }
        });
      }
    });

    // 2. Sound Level Listener
    _soundLevelSubscription?.cancel();
    _soundLevelSubscription = _speechService.onSoundLevel.listen((level) {
      if (mounted) {
        setState(() {
          double normalized = level.abs() / 10.0;
          if (normalized > 1.0) normalized = 1.0;
          _soundLevel = normalized;
        });
      }
    });

    // 3. Status Listener
    _statusSubscription?.cancel();
    _statusSubscription = _speechService.onStatus.listen((status) {
      debugPrint("Status update: $status");
      
      if (status == 'done' || status == 'notListening') {
        // Engine stopped. Save whatever we have.
        if (mounted && _currentText.isNotEmpty) {
           setState(() {
             _accumulatedText = "$_accumulatedText $_currentText".trim();
             _currentText = "";
           });
           debugPrint("Saved text on stop: $_accumulatedText");
        }

        // If user still wants to listen, restart.
        if (_shouldBeListening && mounted) {
          debugPrint("Restarting listening loop...");
          Future.delayed(const Duration(milliseconds: 100), () {
            if (_shouldBeListening && mounted) {
               _speechService.startListening();
            }
          });
        } else {
           if (mounted) setState(() => _isListening = false);
        }
      } else if (status == 'listening') {
        if (mounted) setState(() => _isListening = true);
      }
    });

    try {
      await _speechService.startListening();
    } catch (e) {
      debugPrint("Start listening error: $e");
      if (mounted) {
        setState(() {
          _shouldBeListening = false;
          _isListening = false;
          _status = "ERROR";
        });
      }
    }
  }

  Future<void> _stopListeningAndProcess() async {
    _shouldBeListening = false; // Stop the loop
    
    // 1. Stop speech service
    await _speechService.stopListening();
    
    // 2. Wait briefly for final status/results
    await Future.delayed(const Duration(milliseconds: 500));

    // 3. Cancel listeners
    await _resultSubscription?.cancel();
    await _soundLevelSubscription?.cancel();
    await _statusSubscription?.cancel();
    _resultSubscription = null;
    _soundLevelSubscription = null;
    _statusSubscription = null;
    
    // 4. Combine text
    String fullText = "$_accumulatedText $_currentText".trim();
    
    if (mounted) {
      setState(() {
        _isListening = false;
        _soundLevel = 0.0;
      });
    }

    if (fullText.isEmpty) {
      setState(() => _status = "READY");
      return;
    }

    // 5. Process
    setState(() => _status = "FORMATTING...");
    
    // Get style instruction based on app context
    String styleInstruction = "";
    if (_appContext.isNotEmpty) {
      styleInstruction = await _styleService.getStyleInstruction(_appContext);
      debugPrint("Applying style: $styleInstruction");
    }

    String formattedText = await _geminiService.formatText(
      fullText, 
      userTerms: _userTerms, 
      snippets: _snippets,
      styleInstruction: styleInstruction
    );

    // 6. Commit
    await _commitText(formattedText);

    if (mounted) {
      setState(() {
        _accumulatedText = "";
        _currentText = "";
        _status = "SENT";
      });

      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && !_shouldBeListening) {
          setState(() => _status = "READY");
        }
      });
    }
  }

  Future<void> _commitText(String text) async {
    if (text.isNotEmpty) {
      try {
        await _channel.invokeMethod('commitText', {'text': "$text "});
      } catch (e) {
        debugPrint("Error committing text: $e");
      }
    }
  }

  Future<void> _switchKeyboard() async {
    try {
      await _channel.invokeMethod('switchKeyboard');
    } catch (e) {
      debugPrint("Error switching keyboard: $e");
    }
  }

  Future<void> _openSettings() async {
    try {
      await _channel.invokeMethod('openSettings');
    } catch (e) {
      debugPrint("Error opening settings: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Colors.black;
    const Color accentColor = Colors.white;
    
    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: false,
      body: !_hasPermission 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.mic_off, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    "Microphone Access Required",
                    style: GoogleFonts.ebGaramond(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _openPermissionsPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Grant Access"),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Top Row: Status & Settings
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _appContext.isNotEmpty ? "$_appContext • $_status" : _status,
                        style: const TextStyle(
                          color: accentColor,
                          fontSize: 14,
                          letterSpacing: 1.5,
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: _openSettings,
                        icon: const Icon(Icons.settings, color: accentColor),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),

                  // 2. Digital Waveform (Center)
                  Expanded(
                    child: Center(
                      child: _isListening 
                        ? SizedBox(
                            width: double.infinity,
                            height: 100,
                            child: CustomPaint(
                              painter: DigitalWaveformPainter(
                                level: _soundLevel,
                                color: accentColor,
                                animation: _animationController,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                    ),
                  ),

                  // 4. Bottom Controls: Keyboard, Mic
                  Padding(
                    padding: const EdgeInsets.only(bottom: 40.0),
                    child: SizedBox(
                      height: 80, // Fixed height for the control area
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Left: Keyboard Switcher
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 32.0),
                              child: IconButton(
                                onPressed: _switchKeyboard,
                                icon: const Icon(Icons.keyboard, color: accentColor),
                                iconSize: 28,
                              ),
                            ),
                          ),

                          // Center: Mic Button
                          MicButton(
                            isListening: _isListening,
                            onTap: _toggleListening,
                            animationController: _animationController,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class MicButton extends StatelessWidget {
  final bool isListening;
  final VoidCallback onTap;
  final AnimationController animationController;

  const MicButton({
    super.key,
    required this.isListening,
    required this.onTap,
    required this.animationController,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 70,
        height: 70,
        child: CustomPaint(
          // Show beam when NOT listening (Initial state)
          painter: !isListening ? BorderBeamPainter(animation: animationController) : null,
          child: Container(
            decoration: BoxDecoration(
              color: isListening ? Colors.white.withOpacity(0.1) : Colors.transparent,
              shape: BoxShape.circle,
              // Show solid border when listening (Clicked state)
              border: isListening 
                  ? Border.all(color: Colors.white, width: 2)
                  : null, 
            ),
            child: Icon(
              isListening ? Icons.mic : Icons.mic_none,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }
}

// Digital Analog Style Waveform (Vertical Bars)
class DigitalWaveformPainter extends CustomPainter {
  final double level;
  final Color color;
  final Animation<double> animation;

  DigitalWaveformPainter({
    required this.level, 
    required this.color,
    required this.animation,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    final width = size.width;
    final height = size.height;
    final centerY = height / 2;
    
    // Number of bars
    final int barCount = 30;
    final double barWidth = (width - 40) / barCount / 2; // Spacing included
    final double spacing = barWidth;
    
    final double startX = 20.0;

    for (int i = 0; i < barCount; i++) {
      double x = startX + i * (barWidth + spacing);
      
      // Calculate height based on level and position (center peaks)
      double distFromCenter = 1.0 - (2.0 * (i / barCount - 0.5)).abs();
      
      // Base height (idle animation) - Smooth sine wave
      double baseHeight = 4.0 + math.sin(animation.value * math.pi * 2 + i * 0.5) * 2.0;
      
      // Active height
      double activeHeight = 0.0;
      if (level > 0.01) {
        // Smooth "random" using sine waves at different frequencies
        // This avoids the frantic flickering of Random()
        double smoothRandom = math.sin(animation.value * math.pi * 4 + i) * 0.5 + 0.5;
        activeHeight = level * 60 * distFromCenter * (0.5 + smoothRandom * 0.5);
      }
      
      double totalHeight = baseHeight + activeHeight;
      
      // Draw rounded rect
      RRect bar = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, centerY), width: barWidth, height: totalHeight),
        Radius.circular(barWidth / 2),
      );
      
      canvas.drawRRect(bar, paint);
    }
  }

  @override
  bool shouldRepaint(DigitalWaveformPainter oldDelegate) => true;
}
