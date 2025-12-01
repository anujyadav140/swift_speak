import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';

class ModelDownloadService {
  static final ModelDownloadService _instance = ModelDownloadService._internal();
  factory ModelDownloadService() => _instance;
  ModelDownloadService._internal();

  // State
  bool _isDownloading = false;
  double _progress = 0.0;
  String? _currentFileName;
  String? _taskId;
  
  // Speed & ETA calculation
  int? _totalBytes;
  DateTime? _lastUpdateTime;
  double _lastProgress = 0.0;
  double _speed = 0.0; // B/s
  Duration? _timeRemaining;
  Timer? _pollingTimer;

  // Stream for UI updates
  final _controller = StreamController<DownloadStatus>.broadcast();
  Stream<DownloadStatus> get statusStream => _controller.stream;

  bool get isDownloading => _isDownloading;
  double get progress => _progress;
  String? get currentFileName => _currentFileName;
  double get speed => _speed;
  Duration? get timeRemaining => _timeRemaining;

  // Background Isolate Communication
  final ReceivePort _port = ReceivePort();

  bool _isInitialized = false;

  void init() {
    if (_isInitialized) return;
    _bindBackgroundIsolate();
    FlutterDownloader.registerCallback(downloadCallback);
    _isInitialized = true;
  }

  void _bindBackgroundIsolate() {
    bool isSuccess = IsolateNameServer.registerPortWithName(_port.sendPort, 'downloader_send_port');
    if (!isSuccess) {
      _unbindBackgroundIsolate();
      _bindBackgroundIsolate();
      return;
    }
    _port.listen((dynamic data) {
      String id = data[0];
      int statusIdx = data[1];
      int progress = data[2];
      
      if (_taskId == id) {
        final double newProgress = progress / 100.0;
        
        // Calculate Speed & ETA
        final now = DateTime.now();
        if (_lastUpdateTime != null) {
          final timeDelta = now.difference(_lastUpdateTime!).inMilliseconds / 1000.0;
          // Only update speed if enough time has passed (e.g. > 500ms) or significant progress
          // This prevents jitter if callbacks are too fast
          if (timeDelta > 0.5 && _totalBytes != null && newProgress > _lastProgress) {
            final progressDelta = newProgress - _lastProgress;
            final bytesDelta = progressDelta * _totalBytes!;
            final bytesPerSecond = bytesDelta / timeDelta;
            
            // Simple smoothing
            _speed = (_speed == 0) ? bytesPerSecond : (_speed * 0.7) + (bytesPerSecond * 0.3);
            
            if (newProgress < 1.0 && _speed > 0) {
              final remainingBytes = (1.0 - newProgress) * _totalBytes!;
              final remainingSeconds = remainingBytes / _speed;
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
        
        if (statusIdx == DownloadTaskStatus.complete.index) {
          _isDownloading = false;
          _progress = 1.0;
          _speed = 0.0;
          _timeRemaining = null;
          _notifyListeners();
        } else if (statusIdx == DownloadTaskStatus.failed.index || statusIdx == DownloadTaskStatus.canceled.index) {
          _isDownloading = false;
          _speed = 0.0;
          _timeRemaining = null;
          _notifyListeners();
        } else if (statusIdx == DownloadTaskStatus.running.index) {
           _isDownloading = true;
           _notifyListeners();
        }
      }
    });
  }

  void _unbindBackgroundIsolate() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
  }

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
    
    _notifyListeners();

    final dir = await getApplicationDocumentsDirectory();
    
    // Check if file exists and delete it
    final file = File('${dir.path}/$fileName');
    if (await file.exists()) {
      await file.delete();
    }

    _taskId = await FlutterDownloader.enqueue(
      url: url,
      savedDir: dir.path,
      fileName: fileName,
      showNotification: true,
      openFileFromNotification: false,
      saveInPublicStorage: false,
    );
    // No polling needed anymore
  }

  Future<void> cancelDownload() async {
    if (_isDownloading && _taskId != null) {
      await FlutterDownloader.cancel(taskId: _taskId!);
      _isDownloading = false;
      _notifyListeners();
    }
  }

  Future<void> pauseDownload() async {
    if (_isDownloading && _taskId != null) {
      await FlutterDownloader.pause(taskId: _taskId!);
      _isDownloading = false;
      _notifyListeners();
    }
  }

  Future<void> resumeDownload() async {
    if (!_isDownloading && _taskId != null) {
      final newTaskId = await FlutterDownloader.resume(taskId: _taskId!);
      _taskId = newTaskId;
      _isDownloading = true;
      _notifyListeners();
    }
  }

  Future<bool> isModelDownloaded(String fileName, {int? expectedBytes}) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    
    if (!await file.exists()) return false;
    
    if (expectedBytes != null) {
      final length = await file.length();
      return length == expectedBytes;
    }
    
    return true;
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

// Top-level callback
@pragma('vm:entry-point')
void downloadCallback(String id, int status, int progress) {
  final SendPort? send = IsolateNameServer.lookupPortByName('downloader_send_port');
  send?.send([id, status, progress]);
}
