import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/model_download_service.dart';
import 'dart:async';

class LocalModelScreen extends StatefulWidget {
  const LocalModelScreen({super.key});

  @override
  State<LocalModelScreen> createState() => _LocalModelScreenState();
}

class _LocalModelScreenState extends State<LocalModelScreen> {
  final ModelDownloadService _downloadService = ModelDownloadService();
  StreamSubscription? _subscription;

  // Placeholder URL - REPLACE WITH ACTUAL FIREBASE STORAGE URL
  static const String _gemmaUrl = "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf?download=true";
  static const String _gemmaFileName = "llama-3.2-1b-q4.gguf";

  final Map<String, dynamic> _gemmaModel = {
    'name': 'Llama 3.2 1B Q4',
    'size': '808 MB',
    'description': 'Lightweight model by Meta, optimized for mobile.',
    'isDownloaded': false,
    'isDownloading': false,
    'isChecking': true,
    'progress': 0.0,
    'speed': 0.0,
    'type': 'local',
  };

  final Map<String, dynamic> _geminiFlashModel = {
    'name': 'Gemini 2.0 Flash Lite',
    'size': 'Cloud',
    'description': 'Fast cloud inference by Google.',
    'isDownloaded': true,
    'isDownloading': false,
    'isChecking': false,
    'type': 'cloud',
  };

  String _activeModel = '';

  @override
  void initState() {
    super.initState();
    _downloadService.init(); // Initialize background downloader
    _checkDownloadStatus();
    _loadSavedModel();
    
    _subscription = _downloadService.statusStream.listen((status) {
      if (mounted && status.fileName == _gemmaFileName) {
        setState(() {
          _gemmaModel['isDownloading'] = status.isDownloading;
          _gemmaModel['progress'] = status.progress;
          _gemmaModel['speed'] = status.speed;
          _gemmaModel['timeRemaining'] = status.timeRemaining;
          
          if (!status.isDownloading && status.progress >= 1.0) {
             _gemmaModel['isDownloaded'] = true;
             _checkDownloadStatus();
          }
        });
      }
    });

    // Check if already downloading (e.g. came back to screen)
    if (_downloadService.isDownloading && _downloadService.currentFileName == _gemmaFileName) {
       setState(() {
         _gemmaModel['isDownloading'] = true;
         _gemmaModel['progress'] = _downloadService.progress;
         _gemmaModel['speed'] = _downloadService.speed;
         _gemmaModel['timeRemaining'] = _downloadService.timeRemaining;
       });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSavedModel() async {
    final prefs = await SharedPreferences.getInstance();
    final savedModel = prefs.getString('selected_model');
    if (mounted) {
      setState(() {
        _activeModel = savedModel ?? 'Gemini 2.0 Flash Lite';
      });
    }
  }

  Future<void> _checkDownloadStatus() async {
    // Expected size: 1708582784 bytes
    final isDownloaded = await _downloadService.isModelDownloaded(_gemmaFileName);
    if (mounted) {
      setState(() {
        _gemmaModel['isDownloaded'] = isDownloaded;
        _gemmaModel['isChecking'] = false;
        
        // Safety check: if active model is Gemma but not downloaded, revert
        if (_activeModel == 'Llama 3.2 1B Q4' && !isDownloaded) {
             _activeModel = 'Gemini 2.0 Flash Lite';
             _saveModelPreference('Gemini 2.0 Flash Lite');
        }
      });
    }
  }

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) return "${bytesPerSecond.toStringAsFixed(1)} B/s";
    if (bytesPerSecond < 1024 * 1024) return "${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s";
    return "${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s";
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  Future<void> _toggleDownload() async {
    if (_gemmaModel['isDownloaded']) {
      // Delete
      await _downloadService.deleteModel(_gemmaFileName);
      if (mounted) {
        setState(() {
          _gemmaModel['isDownloaded'] = false;
          if (_activeModel == 'Llama 3.2 1B Q4') {
            _activeModel = 'Gemini 2.0 Flash Lite'; // Revert to default
            _saveModelPreference('Gemini 2.0 Flash Lite');
          }
        });
      }
    } else {
      // Download or Resume
      if (_gemmaModel['isDownloading']) {
        // If currently downloading, this button shouldn't be the primary action usually, 
        // but we'll keep it as "Cancel" or similar if needed. 
        // However, we are adding specific Pause/Resume buttons below.
        // For the main button, let's make it "Cancel" if downloading.
        _downloadService.cancelDownload();
      } else {
        // Start new download
        _downloadService.downloadModel(
          url: _gemmaUrl,
          fileName: _gemmaFileName,
          totalBytes: 847249408, // Exact size from logs
        );
      }
    }
  }

  Future<void> _pauseDownload() async {
    await _downloadService.pauseDownload();
    setState(() {
      _gemmaModel['isDownloading'] = false;
    });
  }

  Future<void> _resumeDownload() async {
    await _downloadService.resumeDownload();
    setState(() {
      _gemmaModel['isDownloading'] = true;
    });
  }

  Future<void> _saveModelPreference(String modelName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_model', modelName);
  }

  void _activateModel(String modelName) {
    setState(() {
      _activeModel = modelName;
    });
    _saveModelPreference(modelName);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Switched to $modelName")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Select a Model",
          style: GoogleFonts.ebGaramond(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildModelCard(
            model: _geminiFlashModel,
            isActive: _activeModel == 'Gemini 2.0 Flash Lite',
            isDark: isDark,
            textColor: textColor,
          ),
          const SizedBox(height: 16),
          _buildModelCard(
            model: _gemmaModel,
            isActive: _activeModel == 'Llama 3.2 1B Q4',
            isDark: isDark,
            textColor: textColor,
            isDownloadable: true,
          ),
        ],
      ),
    );
  }

  Widget _buildModelCard({
    required Map<String, dynamic> model,
    required bool isActive,
    required bool isDark,
    required Color textColor,
    bool isDownloadable = false,
  }) {
    final isDownloaded = model['isDownloaded'] as bool;
    final isDownloading = model['isDownloading'] as bool;
    final isChecking = model['isChecking'] ?? false; // Get checking state
    final progress = model['progress'] ?? 0.0;
    final speed = model['speed'] ?? 0.0;

    final width = MediaQuery.of(context).size.width;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: isActive 
            ? Border.all(color: Colors.blueAccent, width: 2) 
            : Border.all(color: Colors.transparent),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                model['name'],
                style: TextStyle(
                  color: textColor,
                  fontSize: width * 0.055, // 18 * 1.1 / 360 approx
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_activeModel.isNotEmpty) // Only show switch after model is loaded
                  Switch(
                    value: isActive,
                    onChanged: isDownloaded ? (val) {
                      if (val) _activateModel(model['name']);
                    } : null, // Disable if not downloaded
                    activeColor: Colors.blueAccent,
                  )
              else
                   // Placeholder to keep layout stable while loading
                   const SizedBox(width: 50, height: 40),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            model['size'],
            style: TextStyle(
              color: Colors.grey,
              fontSize: width * 0.043, // 14 * 1.1 / 360 approx
            ),
          ),
          const SizedBox(height: 8),
          Text(
            model['description'],
            style: TextStyle(
              color: textColor.withOpacity(0.8),
              fontSize: width * 0.043, // 14 * 1.1 / 360 approx
            ),
          ),
          const SizedBox(height: 16),
          
          if (isDownloadable) ...[
            if (isDownloading || (progress > 0 && progress < 1.0 && !isDownloaded)) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isDownloading ? "Downloading..." : "Paused",
                    style: GoogleFonts.inter(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  Row(
                    children: [
                      if (isDownloading)
                        IconButton(
                          icon: const Icon(Icons.pause, color: Colors.orange),
                          onPressed: _pauseDownload,
                          tooltip: "Pause",
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.play_arrow, color: Colors.green),
                          onPressed: _resumeDownload,
                          tooltip: "Resume",
                        ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: _downloadService.cancelDownload,
                        tooltip: "Cancel",
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[300],
                color: isDownloading ? Colors.blueAccent : Colors.orange,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "${(progress * 100).toStringAsFixed(2)}%",
                    style: TextStyle(color: textColor.withOpacity(0.6), fontSize: width * 0.037), // 12 * 1.1
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatSpeed(speed),
                        style: TextStyle(color: textColor.withOpacity(0.6), fontSize: width * 0.037), // 12 * 1.1
                      ),
                      if (model['timeRemaining'] != null)
                        Text(
                          "ETA: ${_formatDuration(model['timeRemaining']!)}",
                          style: TextStyle(color: textColor.withOpacity(0.6), fontSize: width * 0.037), // 12 * 1.1
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ] else if (!isDownloading && !isDownloaded) ...[
               SizedBox(
                width: double.infinity,
                child: isChecking 
                    ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))
                    : ElevatedButton(
                        onPressed: _toggleDownload,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.white : Colors.black,
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          "Download",
                          style: TextStyle(fontSize: width * 0.043), // 14 * 1.1
                        ),
                      ),
              ),
            ] else if (isDownloaded) ...[
               SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _toggleDownload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.1),
                    foregroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    "Delete",
                    style: TextStyle(fontSize: width * 0.043), // 14 * 1.1
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
