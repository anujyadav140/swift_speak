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
  CancelToken? _cancelToken;

  // Placeholder URL - REPLACE WITH ACTUAL FIREBASE STORAGE URL
  static const String _gemmaUrl = "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf?download=true";
  static const String _gemmaFileName = "llama-3.2-1b-q4.gguf";

  final Map<String, dynamic> _gemmaModel = {
    'name': 'Llama 3.2 1B Q4',
    'size': '808 MB',
    'description': 'Lightweight model by Meta, optimized for mobile.',
    'isDownloaded': false,
    'isDownloading': false,
    'progress': 0.0,
    'speed': 0.0,
    'type': 'local',
  };

  final Map<String, dynamic> _geminiFlashModel = {
    'name': 'Gemini 2.0 Flash Lite',
    'size': 'Cloud',
    'description': 'Fast cloud inference by Google.',
    'isDownloaded': true, // Always available
    'isDownloading': false,
    'type': 'cloud',
  };

  String _activeModel = ''; // Initialize to empty to prevent flash of wrong default

  @override
  void initState() {
    super.initState();
    _checkDownloadStatus();
    _loadSavedModel();
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
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
      });
    }
  }

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) return "${bytesPerSecond.toStringAsFixed(1)} B/s";
    if (bytesPerSecond < 1024 * 1024) return "${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s";
    return "${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s";
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
      // Download
      setState(() {
        _gemmaModel['isDownloading'] = true;
        _gemmaModel['progress'] = 0.0;
        _gemmaModel['speed'] = 0.0;
      });

      _cancelToken = CancelToken();

      try {
        await _downloadService.downloadModel(
          url: _gemmaUrl,
          fileName: _gemmaFileName,
          cancelToken: _cancelToken,
          onProgress: (progress, speed) {
            if (mounted) {
              setState(() {
                _gemmaModel['progress'] = progress;
                _gemmaModel['speed'] = speed;
              });
            }
          },
        );

        if (mounted) {
          setState(() {
            _gemmaModel['isDownloading'] = false;
            _gemmaModel['isDownloaded'] = true;
          });
        }
      } catch (e) {
        debugPrint("Download error: $e");
        if (mounted) {
          setState(() {
            _gemmaModel['isDownloading'] = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Download failed: $e")),
          );
        }
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
    final progress = model['progress'] ?? 0.0;
    final speed = model['speed'] ?? 0.0;

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
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isDownloaded)
                Switch(
                  value: isActive,
                  onChanged: (val) {
                    if (val) _activateModel(model['name']);
                  },
                  activeColor: Colors.blueAccent,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            model['size'],
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            model['description'],
            style: TextStyle(
              color: textColor.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          
          if (isDownloadable) ...[
            if (isDownloading) ...[
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
                    "${(progress * 100).toStringAsFixed(1)}%",
                    style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12),
                  ),
                  Text(
                    _formatSpeed(speed),
                    style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
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
                child: Text(isDownloaded ? "Delete" : "Download"),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
