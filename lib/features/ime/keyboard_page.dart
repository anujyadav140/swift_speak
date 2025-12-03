import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/speech_service.dart';
import '../../services/gemini_service.dart';
import '../../services/dictionary_service.dart';
import '../../services/snippet_service.dart';
import '../../services/style_service.dart';
import '../../services/local_llm_service.dart';
import '../../services/calendar_service.dart';
import '../../services/stats_service.dart';
import '../../models/snippet.dart';
import '../../widgets/border_beam_painter.dart';
import '../../services/screenshot_service.dart';
import 'dart:io';

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
  final LocalLLMService _localLLMService = LocalLLMService();
  final StatsService _statsService = StatsService();
  final ScreenshotService _screenshotService = ScreenshotService();
  
  bool _isListening = false;
  double _soundLevel = 0.0;
  
  // Smart Schedule State
  bool _isAnalyzingScreenshot = false;
  String _loadingMessage = "Connecting...";
  AnalysisResult? _screenshotResult;
  bool _isScheduling = false;
  bool _showSuccessAnimation = false;
  bool _eventScheduled = false;
  
  // Text Handling
  String _accumulatedText = ""; // Text from previous sessions
  String _currentText = "";     // Text from current session
  String _status = "READY";
  String _appContext = "";      // Detected app type
  String _currentPackageName = ""; // Raw package name
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

  DateTime? _listeningStartTime;

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
    _setupScreenshotListener();
    
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
          _currentPackageName = packageName;
        });
      }
    } else if (call.method == "refreshSettings") {
      debugPrint("Refreshing settings (Style/Model)...");
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      debugPrint("Settings refreshed.");
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
    _screenshotService.stopListening();
    super.dispose();
  }

  void _setupScreenshotListener() {
    debugPrint("KeyboardPage: Setting up screenshot listener");
    _screenshotService.onScreenshotDetected = (path) {
      debugPrint("KeyboardPage: Screenshot detected callback triggered for $path");
      _handleScreenshot(path);
    };
    _screenshotService.startListening();
  }

  Future<void> _handleScreenshot(String path) async {
    debugPrint("KeyboardPage: _handleScreenshot called with path: $path");
    if (!mounted) {
      debugPrint("KeyboardPage: _handleScreenshot - not mounted, returning.");
      return;
    }
    
    setState(() {
      _isAnalyzingScreenshot = true;
      _loadingMessage = "Reading message...";
      _screenshotResult = null;
      _status = "ANALYZING...";
      _eventScheduled = false; // Reset scheduling state
    });

    try {
      final result = await _geminiService.analyzeScreenshot(
        path,
        onStatusUpdate: (status) {
          if (mounted) {
            setState(() {
              _loadingMessage = status;
            });
          }
        },
      );
      
      if (mounted) {
        setState(() {
          _isAnalyzingScreenshot = false;
          _screenshotResult = result;
          _status = "SUGGESTION READY";
        });
        
        // Auto-execution removed. Waiting for user action.
      }
    } catch (e) {
      debugPrint("Screenshot Analysis Error: $e");
      if (mounted) {
        setState(() {
          _isAnalyzingScreenshot = false;
          _status = "ERROR";
        });
      }
    }
  }

  // _executeSuggestion removed as all actions are now manual.

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
        _listeningStartTime = DateTime.now();
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
          _currentText = _extractNewText(_accumulatedText, newText);

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

    // Check selected model
    final prefs = await SharedPreferences.getInstance();
    final selectedModel = prefs.getString('selected_model') ?? 'Gemini 2.0 Flash Lite';
    
    String formattedText;

    if (selectedModel != 'Gemini 2.0 Flash Lite') {
      debugPrint("KeyboardPage: Using Local Model: $selectedModel");
      
      String modelFileName = 'llama-3.2-1b-q4.gguf'; // Default
      if (selectedModel == 'Gemma 2 2B IT Q4') {
        modelFileName = 'gemma-2-2b-it-Q4_K_M.gguf';
      } else if (selectedModel == 'Qwen 2.5 1.5B Instruct') {
        modelFileName = 'qwen2.5-1.5b-instruct-q4_k_m.gguf';
      }

      try {
        await _localLLMService.loadModel(modelFileName);
        formattedText = await _localLLMService.formatText(
          fullText,
          userTerms: _userTerms,
          snippets: _snippets,
          styleInstruction: styleInstruction,
          modelName: selectedModel, // Pass model name for template selection
        );
      } catch (e) {
        debugPrint("Local Model Error: $e. Falling back to Cloud.");
        formattedText = await _geminiService.formatText(
          fullText, 
          userTerms: _userTerms, 
          snippets: _snippets,
          styleInstruction: styleInstruction
        );
      }
    } else {
      debugPrint("KeyboardPage: Using Cloud Model: Gemini 2.0 Flash Lite (Selected: $selectedModel)");
      formattedText = await _geminiService.formatText(
        fullText, 
        userTerms: _userTerms, 
        snippets: _snippets,
        styleInstruction: styleInstruction
      );
    }

    // 6. Commit
    await _commitText(formattedText);

    // 7. Update Stats
    final duration = _listeningStartTime != null 
        ? DateTime.now().difference(_listeningStartTime!) 
        : Duration.zero;
    
    final wordCount = formattedText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    
    if (wordCount > 0) {
      _statsService.updateStats(wordCount, duration, packageName: _currentPackageName);
    }

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

  String _extractNewText(String accumulated, String newText) {
    if (accumulated.isEmpty) return newText;
    
    // Normalize strings for comparison (lowercase, trim)
    final normalizedAccumulated = accumulated.toLowerCase().trim();
    final normalizedNew = newText.toLowerCase().trim();

    // 1. Exact Prefix Match
    if (normalizedNew.startsWith(normalizedAccumulated)) {
      return newText.substring(accumulated.length).trim();
    }

    // 2. Word-based Overlap Check (Robust)
    // This handles cases where the engine might change punctuation or slight wording in the history
    final accWords = normalizedAccumulated.split(RegExp(r'\s+'));
    final newWords = normalizedNew.split(RegExp(r'\s+'));

    // If new text is shorter than accumulated, it's likely fresh text (or a weird reset).
    // We assume it's fresh to avoid losing data, unless it's a pure subset.
    if (newWords.length < accWords.length) {
       // Check if new text is just a suffix of accumulated (duplicate event)
       if (normalizedAccumulated.endsWith(normalizedNew)) {
         return ""; // Ignore duplicate
       }
       return newText;
    }

    // Check if the start of newWords matches accWords
    bool isPrefix = true;
    for (int i = 0; i < accWords.length; i++) {
      if (newWords[i] != accWords[i]) {
        isPrefix = false;
        break;
      }
    }

    if (isPrefix) {
      // Reconstruct the non-overlapping part from the original string
      if (newText.length >= accumulated.length) {
         final suffixWords = newText.trim().split(RegExp(r'\s+')).sublist(accWords.length);
         return suffixWords.join(' ');
      }
    }

    // 3. Tail-Head Overlap Check (Segment Merging)
    // Check if the END of accumulated matches the START of newText
    // This handles cases where the engine sends "A B C" then "C D E" (overlap "C")
    // We only strip if overlap is significant (>= 2 words) to avoid stripping intentional repetitions like "really really"
    int maxOverlap = 0;
    final int maxCheck = math.min(accWords.length, newWords.length);
    
    for (int i = 1; i <= maxCheck; i++) {
      // Check if last i words of acc match first i words of new
      bool match = true;
      for (int j = 0; j < i; j++) {
        if (accWords[accWords.length - i + j] != newWords[j]) {
          match = false;
          break;
        }
      }
      if (match) {
        maxOverlap = i;
      }
    }

    if (maxOverlap >= 2) {
       // Strip the first maxOverlap words from newText
       final suffixWords = newWords.sublist(maxOverlap);
       return suffixWords.join(' ');
    }

    return newText;
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
                  
                  const SizedBox(height: 4),

                  // 2. Digital Waveform (Center) or Smart Schedule UI
                  Expanded(
                    child: Center(
                      child: _isAnalyzingScreenshot 
                        ? _buildLoadingView(accentColor)
                        : _showSuccessAnimation
                            ? _buildSuccessAnimation(accentColor)
                            : _screenshotResult != null 
                                ? _buildResultView(accentColor)
                                : _isListening 
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
                  if (!_isAnalyzingScreenshot && _screenshotResult == null && !_showSuccessAnimation)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 40.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 80, // Fixed height for the control area
                      child: Stack(
                        alignment: Alignment.center,
                        children: [


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

  Widget _buildLoadingView(Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/logo.png', width: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: SizedBox(
                  width: 20,
                  child: LoadingIndicator(color: color),
                ),
              ),
              Image.asset('assets/images/google_calendar.png', width: 40),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _loadingMessage,
          style: GoogleFonts.notoSerif( // Closest to Times New Roman in Google Fonts
            color: color, 
            fontSize: 16,
            fontStyle: FontStyle.italic,
          ), 
        ),
      ],
    );
  }

  Widget _buildResultView(Color color) {
    final hasProposal = _screenshotResult?.proposedEvent != null;
    final conflictingEvent = _screenshotResult?.conflictingEvent;
    final explanation = _screenshotResult?.text ?? "";
    final replyMessage = _screenshotResult?.replyMessage ?? "";
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 60.0), // Add margin below the content
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Explanation Text
                  Text(
                    explanation,
                    style: GoogleFonts.notoSerif(
                      color: Colors.white, 
                      fontSize: 14,
                    ),
                  ),
                  
                  const SizedBox(height: 12),

                  // 2. Conflicting Event (if any)
                  if (conflictingEvent != null && conflictingEvent.isNotEmpty && conflictingEvent != "null") ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white38),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_busy, color: Colors.redAccent, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // "Conflict" label removed as requested
                                Text(
                                  conflictingEvent,
                                  style: GoogleFonts.notoSerif(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 3. Proposed Event (if any)
                  if (hasProposal) ...[
                     Container(
                       padding: const EdgeInsets.all(12),
                       decoration: BoxDecoration(
                         color: Colors.grey[900],
                         borderRadius: BorderRadius.circular(8),
                         border: Border.all(color: Colors.white38),
                       ),
                       child: Row(
                         children: [
                           const Icon(Icons.event, color: Colors.white, size: 20),
                           const SizedBox(width: 12),
                           Expanded(
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text(
                                   "Proposed Event",
                                   style: GoogleFonts.notoSerif(
                                    color: Colors.white54,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                 ),
                                 Text(
                                   _screenshotResult!.proposedEvent!.title,
                                   style: GoogleFonts.notoSerif(color: Colors.white, fontWeight: FontWeight.bold),
                                 ),
                                 Text(
                                   "${_formatDate(_screenshotResult!.proposedEvent!.start)}",
                                   style: GoogleFonts.notoSerif(color: Colors.white70, fontSize: 12),
                                 ),
                               ],
                             ),
                           ),
                         ],
                       ),
                     ),
                     const SizedBox(height: 12),
                  ],

                  // 4. Reply Preview (Chat Bubble style)
                  if (replyMessage.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(2),
                          ),
                        ),
                        child: Text(
                          replyMessage,
                          style: GoogleFonts.notoSerif(
                            color: Colors.white,
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),

          // 5. Actions - Removed for auto-execution
          // 5. Actions - Restored for manual event addition
          // 5. Actions - Manual Control
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Dismiss Button
              TextButton(
                onPressed: () {
                  setState(() {
                    _screenshotResult = null;
                    _status = "READY";
                  });
                },
                style: TextButton.styleFrom(foregroundColor: Colors.white54),
                child: const Text("Dismiss"),
              ),
              
              const SizedBox(width: 8),

              // Add Event Button (Conditional)
              if (hasProposal && (conflictingEvent == null || conflictingEvent == "null" || conflictingEvent.isEmpty))
                ElevatedButton.icon(
                  onPressed: (_isScheduling || _eventScheduled) ? null : () async {
                    setState(() => _isScheduling = true);
                    try {
                      final event = _screenshotResult!.proposedEvent!;
                      await CalendarService().insertEvent(event.title, event.start, event.end);
                      
                      if (mounted) {
                        setState(() {
                          _isScheduling = false;
                          _showSuccessAnimation = true;
                          _status = "SCHEDULED";
                          _eventScheduled = true;
                        });
                      }
                      
                      await Future.delayed(const Duration(seconds: 2));
                      
                      if (mounted) {
                        setState(() {
                          _showSuccessAnimation = false;
                          // Don't dismiss, let user insert text
                          _status = "READY";
                        });
                      }
                    } catch (e) {
                      debugPrint("Error scheduling: $e");
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Failed to add event: $e")),
                        );
                        setState(() => _isScheduling = false);
                      }
                    }
                  },
                  icon: _isScheduling 
                      ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : (_eventScheduled ? const Icon(Icons.check, size: 16) : const Icon(Icons.calendar_month, size: 16)),
                  label: Text(_eventScheduled ? "Added" : "Add Event", style: GoogleFonts.notoSerif(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),

              if (hasProposal && (conflictingEvent == null || conflictingEvent == "null" || conflictingEvent.isEmpty))
                const SizedBox(width: 8),

              // Insert Text Button
              ElevatedButton.icon(
                onPressed: () async {
                  await _commitText(replyMessage);
                  if (mounted) {
                    setState(() {
                      _screenshotResult = null;
                      _status = "SENT";
                    });
                    Future.delayed(const Duration(seconds: 1), () {
                      if (mounted && _status == "SENT") setState(() => _status = "READY");
                    });
                  }
                },
                icon: const Icon(Icons.send, size: 16),
                label: Text("Insert", style: GoogleFonts.notoSerif(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[700],
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessAnimation(Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo.png', width: 40),
            const SizedBox(width: 16),
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 32),
            const SizedBox(width: 16),
            Image.asset('assets/images/google_calendar.png', width: 40),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          "Event Added!",
          style: GoogleFonts.notoSerif(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    // Simple formatter, or use intl if available
    return "${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }
}

class LoadingIndicator extends StatefulWidget {
  final Color color;
  const LoadingIndicator({super.key, required this.color});

  @override
  State<LoadingIndicator> createState() => _LoadingIndicatorState();
}

class _LoadingIndicatorState extends State<LoadingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Icon(Icons.sync, color: widget.color, size: 20),
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
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Beam Animation (Only when NOT listening)
          if (!isListening)
            SizedBox(
              width: 72,
              height: 72,
              child: CustomPaint(
                painter: BeamBorderPainter(animation: animationController),
              ),
            ),

          // Button Container
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // When listening: Transparent bg, White border
              // When idle: Transparent bg, No border (Beam handles it)
              color: Colors.transparent, 
              border: isListening 
                  ? Border.all(color: Colors.white, width: 2) 
                  : null, 
              // BoxShadow removed as requested
            ),
            child: Icon(
              Icons.mic, // Always mic icon as requested
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }
}

class BeamBorderPainter extends CustomPainter {
  final Animation<double> animation;

  BeamBorderPainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    // Reduce radius slightly to ensure the 1px stroke is fully visible and not clipped
    // Radius 36 puts the stroke center at the edge. 
    // We want the outer edge of the stroke to be at most 36.
    // So radius + 0.5 <= 36. Radius <= 35.5.
    // Let's use 35.0 to be safe and give it a bit of breathing room.
    final radius = (size.width / 2) - 2.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5; // Slightly thicker than 1px for better visibility

    // Create a sweep gradient for the beam effect
    final startAngle = animation.value * 2 * math.pi;
    
    final gradient = SweepGradient(
      startAngle: 0.0,
      endAngle: 2 * math.pi,
      colors: const [
        Colors.transparent,
        Colors.white,
        Colors.transparent,
      ],
      stops: const [
        0.2, // Start fading in later
        0.5, // Peak
        0.8, // End fading out earlier
      ],
      transform: GradientRotation(startAngle),
    );

    paint.shader = gradient.createShader(rect);

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(BeamBorderPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}

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
      ..style = PaintingStyle.fill;

    final width = size.width;
    final height = size.height;
    final centerY = height / 2;
    
    // Number of bars
    const int barCount = 5;
    // Spacing between bars
    const double spacing = 10.0; // Increased to 10.0
    // Total width of all bars and spacing
    // We want them centered.
    // Let's say each bar is 12px wide.
    const double barWidth = 12.0; // Increased to 12.0
    
    final totalBarWidth = (barCount * barWidth) + ((barCount - 1) * spacing);
    final startX = (width - totalBarWidth) / 2;
    
    for (int i = 0; i < barCount; i++) {
      // Calculate height for this bar
      // Center bar is tallest, outer bars shorter
      // Base height + dynamic height based on level
      
      double scaleFactor;
      // Simple bell curve-ish scaling for 5 bars: 0.6, 0.8, 1.0, 0.8, 0.6
      if (i == 0 || i == 4) {
        scaleFactor = 0.6;
      } else if (i == 1 || i == 3) {
        scaleFactor = 0.8;
      } else {
        scaleFactor = 1.0;
      }
      
      // Animate slightly with the animation controller to keep it alive even when silent
      // Removed breathing animation as requested to avoid "squiggles"
      // final breathing = 0.1 * math.sin((animation.value * 2 * math.pi) + (i * 0.5));
      
      // Dynamic height based on sound level
      // Max height is maybe 40px
      final dynamicHeight = 40.0 * level * scaleFactor;
      final baseHeight = 10.0 * scaleFactor; // Minimum height
      
      final barHeight = baseHeight + dynamicHeight; // + (baseHeight * breathing);
      
      final x = startX + (i * (barWidth + spacing));
      final top = centerY - (barHeight / 2);
      final bottom = centerY + (barHeight / 2);
      
      final rrect = RRect.fromLTRBR(
        x, 
        top, 
        x + barWidth, 
        bottom, 
        const Radius.circular(3.0),
      );
      
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(DigitalWaveformPainter oldDelegate) {
    return oldDelegate.level != level || 
           oldDelegate.color != color || 
           oldDelegate.animation != animation;
  }
}
