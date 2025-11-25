import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:record/record.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {


  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  static const EventChannel _eventChannel = EventChannel('com.example.swift_speak/input_state');

  AppLifecycleState? _lastLifecycleState;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _lastLifecycleState = state;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _showOverlay();
    } else if (state == AppLifecycleState.resumed) {
      FlutterOverlayWindow.closeOverlay();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startListeningToInputState();
  }

  void _startListeningToInputState() {
    _eventChannel.receiveBroadcastStream().listen((event) {
      if (event is bool) {
        debugPrint("Input State Changed: $event");
        // Share data with the overlay
        FlutterOverlayWindow.shareData(event);
      }
    }, onError: (error) {
      debugPrint("Error listening to input state: $error");
    });
  }

  Future<void> _requestOverlayPermission() async {
    final bool status = await FlutterOverlayWindow.isPermissionGranted();
    if (!status) {
      final bool? granted = await FlutterOverlayWindow.requestPermission();
      if (granted == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Overlay permission granted!")),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Overlay permission already granted!")),
        );
      }
    }
  }

  Future<void> _showOverlay({bool force = false}) async {
    debugPrint("Attempting to show overlay. Force: $force");
    final bool status = await FlutterOverlayWindow.isPermissionGranted();
    debugPrint("Overlay permission status: $status");
    
    if (!status) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Overlay permission not granted! Requesting now...")),
        );
      }
      _requestOverlayPermission();
      return;
    }
    
    if (await FlutterOverlayWindow.isActive()) {
      if (force) {
        debugPrint("Overlay is active, but force is true. Closing and restarting...");
        await FlutterOverlayWindow.closeOverlay();
        // Give it a moment to close
        await Future.delayed(const Duration(milliseconds: 200));
      } else {
        debugPrint("Overlay is already active.");
        return;
      }
    }

    if (!force && _lastLifecycleState == AppLifecycleState.resumed) {
      debugPrint("App is resumed and force is false. Not showing overlay.");
      return;
    }

    debugPrint("Calling FlutterOverlayWindow.showOverlay");
    await FlutterOverlayWindow.showOverlay(
      enableDrag: true, // Enable drag
      overlayTitle: "Swift Speak",
      overlayContent: "Swift Speak Overlay",
      flag: OverlayFlag.defaultFlag,
      visibility: NotificationVisibility.visibilityPublic,
      alignment: OverlayAlignment.center, // Center the overlay
      height: 200, // Make it bigger
      width: 200,
    );
    debugPrint("FlutterOverlayWindow.showOverlay called");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Swift Speak Home"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Welcome to Swift Speak!",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Minimize the app to see the overlay.",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _requestOverlayPermission,
              child: const Text("Request Overlay Permission"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                const channel = MethodChannel('com.example.swift_speak/settings');
                await channel.invokeMethod('openAccessibilitySettings');
              },
              child: const Text("Enable Typing Detection (Accessibility)"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                 try {
                   final audioRecorder = AudioRecorder();
                   // Check and request permission
                   if (await audioRecorder.hasPermission()) {
                     if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Mic permission granted!")),
                        );
                     }
                   } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Permission denied. Please enable in App Settings.")),
                        );
                     }
                   }
                   audioRecorder.dispose();
                 } catch (e) {
                   debugPrint("Error requesting mic permission: $e");
                 }
              },
              child: const Text("Request Mic Permission"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _showOverlay(force: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
              child: const Text("Force Show Overlay"),
            ),
          ],
        ),
      ),
    );
  }
}
