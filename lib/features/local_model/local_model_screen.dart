import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/model_download_service.dart';

class LocalModelScreen extends StatefulWidget {
  const LocalModelScreen({super.key});

  @override
  State<LocalModelScreen> createState() => _LocalModelScreenState();
}

class _LocalModelScreenState extends State<LocalModelScreen> {
  final ModelDownloadService _downloadService = ModelDownloadService();
  // CancelToken? _cancelToken; // Removed, managed by service

  // Placeholder URL - REPLACE WITH ACTUAL FIREBASE STORAGE URL
  static const String _gemmaUrl = "https://huggingface.co/bartowski/gemma-2-2b-it-abliterated-GGUF/resolve/main/gemma-2-2b-it-abliterated-Q4_K_M.gguf?download=true"; 
  static const String _gemmaFileName = "gemma-2b.bin";

  final Map<String, dynamic> _gemmaModel = {
    'name': 'Gemma 2B',
    'size': '1.5 GB',
    'description': 'Lightweight model by Google, optimized for mobile.',
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
    _checkDownloadStatus();
    _loadSavedModel();
    
    // Check for existing background tasks - REMOVED for Dio implementation
    // _downloadService.checkExistingTasks(_gemmaFileName);
    
    // Listen to download updates
    _downloadService.statusStream.listen((status) {
      if (mounted && status.fileName == _gemmaFileName) {
        setState(() {
          _gemmaModel['isDownloading'] = status.isDownloading;
          _gemmaModel['progress'] = status.progress;
          _gemmaModel['speed'] = status.speed;
          _gemmaModel['timeRemaining'] = status.timeRemaining;
          
          if (!status.isDownloading && status.progress == 1.0) {
             _gemmaModel['isDownloaded'] = true;
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
    // _cancelToken?.cancel(); // Removed
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
    final isDownloaded = await _downloadService.isModelDownloaded(_gemmaFileName);
    if (mounted) {
      setState(() {
        _gemmaModel['isDownloaded'] = isDownloaded;
        _gemmaModel['isChecking'] = false;
        
        // Safety check: if active model is Gemma but not downloaded, revert
        if (_activeModel == 'Gemma 2B' && !isDownloaded) {
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
          if (_activeModel == 'Gemma 2B') {
            _activeModel = 'Gemini 2.0 Flash Lite'; // Revert to default
            _saveModelPreference('Gemini 2.0 Flash Lite');
          }
        });
      }
    } else {
      // Download
      if (_gemmaModel['isDownloading']) {
        _downloadService.cancelDownload();
      } else {
        _downloadService.downloadModel(
          url: _gemmaUrl,
          fileName: _gemmaFileName,
          totalBytes: 1708582784, // Exact size from logs
        );
      }
    }
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
            isActive: _activeModel == 'Gemma 2B',
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
            if (isDownloading) ...[
              const Text(
                "⚠️ Do not close the app while downloading.",
                style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[300],
                color: Colors.blueAccent,
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
                          "ETA: ${_formatDuration(model['timeRemaining'])}",
                          style: TextStyle(color: textColor.withOpacity(0.6), fontSize: width * 0.037), // 12 * 1.1
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            SizedBox(
              width: double.infinity,
              child: isChecking 
                  ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))
                  : ElevatedButton(
                      onPressed: isDownloading ? null : _toggleDownload,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDownloaded 
                            ? Colors.red.withOpacity(0.1) 
                            : (isDark ? Colors.white : Colors.black),
                        foregroundColor: isDownloaded 
                            ? Colors.red 
                            : (isDark ? Colors.black : Colors.white),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        isDownloaded ? "Delete" : "Download",
                        style: TextStyle(fontSize: width * 0.043), // 14 * 1.1
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
