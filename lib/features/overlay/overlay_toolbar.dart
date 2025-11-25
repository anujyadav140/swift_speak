import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class OverlayToolbar extends StatefulWidget {
  const OverlayToolbar({super.key});

  @override
  State<OverlayToolbar> createState() => _OverlayToolbarState();
}

class _OverlayToolbarState extends State<OverlayToolbar> with TickerProviderStateMixin {
  bool _isExpanded = false;
  bool _isInputActive = false;
  bool _isRecording = false;
  late AnimationController _borderBeamController;
  
  // Recording vars
  late AudioRecorder _audioRecorder;
  Timer? _amplitudeTimer;
  List<double> _amplitudes = [];
  final int _maxAmplitudes = 30; // Number of bars to show

  @override
  void initState() {
    super.initState();
    _borderBeamController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _audioRecorder = AudioRecorder();

    // Listen to data shared from the main app
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is bool) {
        setState(() {
          _isInputActive = event;
        });
      }
    });
  }

  @override
  void dispose() {
    _borderBeamController.dispose();
    _stopRecording();
    _audioRecorder.dispose();
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

  Future<void> _startRecording() async {
    debugPrint("Starting recording...");
    try {
      // Skip hasPermission check in overlay as it may return false in Service context
      // We assume permission was granted in the main app
      debugPrint("Attempting to record without explicit permission check in overlay...");
      
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/temp_audio.m4a';
      
      // record 5.1.0 API
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      
      setState(() {
        _isRecording = true;
        _amplitudes.clear();
        // Initialize with zeros
        _amplitudes = List.filled(_maxAmplitudes, 0.0, growable: true);
      });

      _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) async {
        final amplitude = await _audioRecorder.getAmplitude();
        final currentAmp = amplitude.current; // dB value usually -160 to 0
        
        // Normalize dB to 0.0 - 1.0 range for visualization
        // Assuming noise floor around -60dB and max 0dB
        double normalized = (currentAmp + 60) / 60;
        if (normalized < 0) normalized = 0;
        if (normalized > 1) normalized = 1;

        setState(() {
          _amplitudes.add(normalized);
          if (_amplitudes.length > _maxAmplitudes) {
            _amplitudes.removeAt(0);
          }
        });
      });
    } catch (e) {
      debugPrint("Error starting recording: $e");
    }
  }

  Future<void> _stopRecording() async {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    if (_isRecording) {
      await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _amplitudes.clear();
      });
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("OverlayToolbar building..."); // Confirm rendering
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
              duration: const Duration(milliseconds: 600), // Adjusted to 600ms
              curve: Curves.easeInOut,
              width: _isExpanded ? 200 : 50, // Reduced width
              height: _isExpanded ? 60 : 100,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(30),
                // border: Border.all(color: Colors.red, width: 4), // Removed red border
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

    final double spacing = size.width / (amplitudes.length - 1);
    final double centerY = size.height / 2;

    for (int i = 0; i < amplitudes.length; i++) {
      final double x = i * spacing;
      final double height = amplitudes[i] * size.height;
      
      // Draw from right to left? 
      // If list is [old, ..., new], and we draw i=0 at x=0, then old is left, new is right.
      // User said "AUDIO WAVEFORMS ARE FROM RIGHT TO LEFT".
      // This usually means new data enters from right and moves left.
      // So drawing index 0 at left is correct for that flow.
      
      canvas.drawLine(
        Offset(x, centerY - height / 2),
        Offset(x, centerY + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return true; // Force repaint as list is mutated in place
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
