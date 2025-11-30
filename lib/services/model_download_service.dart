import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';

class ModelDownloadService {
  static final ModelDownloadService _instance = ModelDownloadService._internal();
  factory ModelDownloadService() => _instance;
  ModelDownloadService._internal();

  final Dio _dio = Dio();
  CancelToken? _cancelToken;
  
  // State
  bool _isDownloading = false;
  double _progress = 0.0;
  String? _currentFileName;
  
  // Speed & ETA calculation
  int? _totalBytes;
  DateTime? _lastUpdateTime;
  double _lastProgress = 0.0;
  double _speed = 0.0; // B/s
  Duration? _timeRemaining;

  // Stream for UI updates
  final _controller = StreamController<DownloadStatus>.broadcast();
  Stream<DownloadStatus> get statusStream => _controller.stream;

  bool get isDownloading => _isDownloading;
  double get progress => _progress;
  String? get currentFileName => _currentFileName;
  double get speed => _speed;
  Duration? get timeRemaining => _timeRemaining;

  Future<void> downloadModel({
    required String url,
    required String fileName,
    int? totalBytes,
  }) async {
    if (_isDownloading) return;

    _isDownloading = true;
    _currentFileName = fileName;
    _progress = 0.0;
    _totalBytes = totalBytes;
    _lastProgress = 0.0;
    _lastUpdateTime = DateTime.now();
    _speed = 0.0;
    _timeRemaining = null;
    _cancelToken = CancelToken();
    
    _notifyListeners();

    try {
      final dir = await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/$fileName';

      await _dio.download(
        url,
        savePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final double newProgress = received / total;
            _totalBytes = total; // Update total bytes from actual response if available

            // Calculate Speed & ETA
            final now = DateTime.now();
            if (_lastUpdateTime != null) {
              final timeDelta = now.difference(_lastUpdateTime!).inMilliseconds / 1000.0;
              if (timeDelta > 0.5) { // Update every 0.5s
                final progressDelta = newProgress - _lastProgress;
                final bytesDelta = progressDelta * total;
                
                final bytesPerSecond = bytesDelta / timeDelta;
                _speed = bytesPerSecond; // B/s
                
                if (newProgress < 1.0 && _speed > 0) {
                  final remainingBytes = (1.0 - newProgress) * total;
                  final remainingSeconds = remainingBytes / bytesPerSecond;
                  _timeRemaining = Duration(seconds: remainingSeconds.round());
                }
                
                _lastProgress = newProgress;
                _lastUpdateTime = now;
              }
            } else {
              _lastUpdateTime = now;
              _lastProgress = newProgress;
            }

            _progress = newProgress;
            _notifyListeners();
          }
        },
      );

      _isDownloading = false;
      _progress = 1.0;
      _speed = 0.0;
      _timeRemaining = null;
      _cancelToken = null;
      _notifyListeners();

    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        debugPrint("Download cancelled");
      } else {
        debugPrint("Download failed: $e");
      }
      _isDownloading = false;
      _speed = 0.0;
      _timeRemaining = null;
      _cancelToken = null;
      _notifyListeners();
    }
  }

  Future<void> cancelDownload() async {
    if (_isDownloading && _cancelToken != null) {
      _cancelToken!.cancel();
      _isDownloading = false;
      _cancelToken = null;
      _notifyListeners();
    }
  }

  Future<bool> isModelDownloaded(String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    return await file.exists();
  }
  
  Future<void> deleteModel(String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    if (await file.exists()) {
      await file.delete();
    }
  }

  void _notifyListeners() {
    _controller.add(DownloadStatus(
      isDownloading: _isDownloading,
      progress: _progress,
      fileName: _currentFileName,
      speed: _speed,
      timeRemaining: _timeRemaining,
    ));
  }
}

class DownloadStatus {
  final bool isDownloading;
  final double progress;
  final String? fileName;
  final double speed; // B/s
  final Duration? timeRemaining;

  DownloadStatus({
    required this.isDownloading,
    required this.progress,
    this.fileName,
    this.speed = 0.0,
    this.timeRemaining,
  });
}
