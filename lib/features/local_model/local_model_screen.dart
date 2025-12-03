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

  // Model Definitions
  final List<Map<String, dynamic>> _models = [
    {
      'name': 'Gemini 2.0 Flash Lite',
      'fileName': 'cloud',
      'url': '',
      'size': 'Cloud',
      'description': 'Fast cloud inference by Google.',
      'tags': ['Fastest', 'Most Accurate'],
      'isDownloaded': true,
      'isDownloading': false,
      'isChecking': false,
      'type': 'cloud',
    },
    {
      'name': 'Llama 3.2 1B Q4',
      'fileName': 'llama-3.2-1b-q4.gguf',
      'url': 'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf?download=true',
      'size': '808 MB',
      'description': 'Lightweight model by Meta, optimized for mobile.',
      'tags': ['Fastest'],
      'isDownloaded': false,
      'isDownloading': false,
      'isChecking': true,
      'progress': 0.0,
      'speed': 0.0,
      'type': 'local',
      'totalBytes': 847249408,
    },
    {
      'name': 'Gemma 2 2B IT Q4',
      'fileName': 'gemma-2-2b-it-Q4_K_M.gguf',
      'url': 'https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf?download=true',
      'size': '1.6 GB',
      'description': 'Google\'s latest lightweight open model (Gemma 2).',
      'tags': ['Most Accurate'],
      'isDownloaded': false,
      'isDownloading': false,
      'isChecking': true,
      'progress': 0.0,
      'speed': 0.0,
      'type': 'local',
      'totalBytes': 1700000000, // Approx
    },
    {
      'name': 'Qwen 2.5 1.5B Instruct',
      'fileName': 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
      'url': 'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf?download=true',
      'size': '1.0 GB',
      'description': 'State-of-the-art tiny model by Alibaba.',
      'tags': ['Balanced'],
      'isDownloaded': false,
      'isDownloading': false,
      'isChecking': true,
      'progress': 0.0,
      'speed': 0.0,
      'type': 'local',
      'totalBytes': 986000000, // Approx
    },
  ];

  String _activeModel = '';

  @override
  void initState() {
    super.initState();
    _downloadService.init(); // Initialize background downloader
    _checkAllDownloads();
    _loadSavedModel();
    
    _subscription = _downloadService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          // Find the model being downloaded
          final index = _models.indexWhere((m) => m['fileName'] == status.fileName);
          if (index != -1) {
            _models[index]['isDownloading'] = status.isDownloading;
            _models[index]['progress'] = status.progress;
            _models[index]['speed'] = status.speed;
            _models[index]['timeRemaining'] = status.timeRemaining;
            
            if (!status.isDownloading && status.progress >= 1.0) {
               _models[index]['isDownloaded'] = true;
               _checkAllDownloads();
            }
          }
        });
      }
    });

    // Check if already downloading (e.g. came back to screen)
    if (_downloadService.isDownloading) {
       final index = _models.indexWhere((m) => m['fileName'] == _downloadService.currentFileName);
       if (index != -1) {
         setState(() {
           _models[index]['isDownloading'] = true;
           _models[index]['progress'] = _downloadService.progress;
           _models[index]['speed'] = _downloadService.speed;
           _models[index]['timeRemaining'] = _downloadService.timeRemaining;
         });
       }
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

  Future<void> _checkAllDownloads() async {
    for (var model in _models) {
      if (model['type'] == 'local') {
        final isDownloaded = await _downloadService.isModelDownloaded(model['fileName']);
        if (mounted) {
          setState(() {
            model['isDownloaded'] = isDownloaded;
            model['isChecking'] = false;
            
            // Safety check: if active model is this one but not downloaded, revert
            if (_activeModel == model['name'] && !isDownloaded) {
                 _activeModel = 'Gemini 2.0 Flash Lite';
                 _saveModelPreference('Gemini 2.0 Flash Lite');
            }
          });
        }
      }
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

  Future<void> _toggleDownload(Map<String, dynamic> model) async {
    final fileName = model['fileName'];
    
    if (model['isDownloaded']) {
      // Delete
      await _downloadService.deleteModel(fileName);
      if (mounted) {
        setState(() {
          model['isDownloaded'] = false;
          if (_activeModel == model['name']) {
            _activeModel = 'Gemini 2.0 Flash Lite'; // Revert to default
            _saveModelPreference('Gemini 2.0 Flash Lite');
          }
        });
      }
    } else {
      // Download or Resume
      if (model['isDownloading']) {
        _downloadService.cancelDownload();
      } else {
        // Start new download
        _downloadService.downloadModel(
          url: model['url'],
          fileName: fileName,
          totalBytes: model['totalBytes'],
        );
      }
    }
  }

  Future<void> _pauseDownload(Map<String, dynamic> model) async {
    await _downloadService.pauseDownload();
    setState(() {
      model['isDownloading'] = false;
    });
  }

  Future<void> _resumeDownload(Map<String, dynamic> model) async {
    await _downloadService.resumeDownload();
    setState(() {
      model['isDownloading'] = true;
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
    
    final cloudModels = _models.where((m) => m['type'] == 'cloud').toList();
    final localModels = _models.where((m) => m['type'] == 'local').toList();

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
          // Cloud Section
          _buildSectionHeader(
            title: "Cloud Models",
            description: "Fastest performance. Requires internet connection. Your text is processed securely in the cloud.",
            textColor: textColor,
            icon: Icons.cloud_queue,
          ),
          const SizedBox(height: 16),
          ...cloudModels.map((model) => Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: _buildModelCard(
              model: model,
              isActive: _activeModel == model['name'],
              isDark: isDark,
              textColor: textColor,
              isDownloadable: false,
            ),
          )),

          const SizedBox(height: 24),
          Divider(color: Colors.grey.withOpacity(0.2)),
          const SizedBox(height: 24),

          // Local Section
          _buildSectionHeader(
            title: "On-Device Models",
            description: "Private and offline. Runs entirely on your phone. No internet required.",
            textColor: textColor,
            icon: Icons.smartphone,
          ),
          
          // Disclaimer
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Note: The first request may take a few seconds to load the model. Subsequent requests will be much faster.",
                    style: TextStyle(
                      color: textColor.withOpacity(0.8),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          ...localModels.map((model) => Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: _buildModelCard(
              model: model,
              isActive: _activeModel == model['name'],
              isDark: isDark,
              textColor: textColor,
              isDownloadable: true,
            ),
          )),
          
          const SizedBox(height: 40), // Bottom padding
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String description,
    required Color textColor,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.blueAccent, size: 24),
            const SizedBox(width: 12),
            Text(
              title,
              style: GoogleFonts.inter(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: TextStyle(
            color: textColor.withOpacity(0.6),
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
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
    final isChecking = model['isChecking'] ?? false;
    final progress = model['progress'] ?? 0.0;
    final speed = model['speed'] ?? 0.0;
    final tags = model['tags'] as List<String>? ?? [];

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
                  fontSize: width * 0.055,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_activeModel.isNotEmpty) 
                  Switch(
                    value: isActive,
                    onChanged: (isDownloaded || !isDownloadable) ? (val) {
                      if (val) _activateModel(model['name']);
                    } : null, 
                    activeColor: Colors.blueAccent,
                  )
              else
                   const SizedBox(width: 50, height: 40),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            model['size'],
            style: TextStyle(
              color: Colors.grey,
              fontSize: width * 0.043,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            model['description'],
            style: TextStyle(
              color: textColor.withOpacity(0.8),
              fontSize: width * 0.043,
            ),
          ),
          
          // Tags Section
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((tag) {
                Color chipColor = Colors.blue.withOpacity(0.1);
                Color chipTextColor = Colors.blue;
                
                if (tag.contains("Privacy Warning")) {
                  chipColor = Colors.orange.withOpacity(0.1);
                  chipTextColor = Colors.orange;
                } else if (tag.contains("Fastest") || tag.contains("Accurate")) {
                  chipColor = Colors.green.withOpacity(0.1);
                  chipTextColor = Colors.green;
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: chipColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      color: chipTextColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 16),
          
          if (isDownloadable) ...[
            // ... (rest of download UI)
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
                          onPressed: () => _pauseDownload(model),
                          tooltip: "Pause",
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.play_arrow, color: Colors.green),
                          onPressed: () => _resumeDownload(model),
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
                    style: TextStyle(color: textColor.withOpacity(0.6), fontSize: width * 0.037),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatSpeed(speed),
                        style: TextStyle(color: textColor.withOpacity(0.6), fontSize: width * 0.037),
                      ),
                      if (model['timeRemaining'] != null)
                        Text(
                          "ETA: ${_formatDuration(model['timeRemaining']!)}",
                          style: TextStyle(color: textColor.withOpacity(0.6), fontSize: width * 0.037),
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
                        onPressed: () => _toggleDownload(model),
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
                          style: TextStyle(fontSize: width * 0.043),
                        ),
                      ),
              ),
            ] else if (isDownloaded) ...[
               SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _toggleDownload(model),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.red.withOpacity(0.1) : Colors.red[900],
                    foregroundColor: isDark ? Colors.red : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    "Delete",
                    style: TextStyle(fontSize: width * 0.043),
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
