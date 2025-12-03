import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swift_speak/services/calendar_service.dart';
import 'package:permission_handler/permission_handler.dart';

class GoogleCalendarConnectorScreen extends StatefulWidget {
  const GoogleCalendarConnectorScreen({super.key});

  @override
  State<GoogleCalendarConnectorScreen> createState() => _GoogleCalendarConnectorScreenState();
}

class _GoogleCalendarConnectorScreenState extends State<GoogleCalendarConnectorScreen> {
  final CalendarService _calendarService = CalendarService();
  bool _isConnected = false;
  String? _userEmail;
  bool _isLoading = true;
  bool _hasPermissions = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    await _checkConnectionStatus();
    await _checkPermissions();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _checkConnectionStatus() async {
    final user = _calendarService.currentUser;
    if (mounted) {
      setState(() {
        _isConnected = user != null;
        _userEmail = user?.email;
      });
    }
  }

  Future<void> _checkPermissions() async {
    final mic = await Permission.microphone.status;
    
    // Check storage/photos status
    bool storage = false;
    final photosStatus = await Permission.photos.status;
    
    if (photosStatus.isGranted) {
      storage = true;
    } else if (photosStatus.isLimited) {
      // Treat limited as NOT fully granted for our purpose (we need all screenshots)
      // But maybe we accept it if the user manually selected the screenshot folder?
      // For now, let's say false to prompt them to upgrade, OR true but warn?
      // The user wants it to work. If they selected the right photo, it works.
      // But "Cursor empty" suggests they didn't.
      // Let's treat limited as FALSE to force the "Grant Permissions" step to remain incomplete/tapable.
      storage = false; 
    } else {
      // Fallback to legacy storage
      if (await Permission.storage.status.isGranted) {
        storage = true;
      }
    }
    
    if (mounted) {
      setState(() {
        _hasPermissions = mic.isGranted && storage;
      });
    }
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.microphone,
      Permission.storage,
      Permission.photos,
    ].request();
    await _checkPermissions();
  }

  Future<void> _connect() async {
    setState(() => _isLoading = true);
    try {
      final user = await _calendarService.signIn();
      if (mounted) {
        setState(() {
          _isConnected = user != null;
          _userEmail = user?.email;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error connecting to Google Calendar: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to connect: $e")),
        );
      }
    }
  }

  Future<void> _disconnect() async {
    setState(() => _isLoading = true);
    try {
      await _calendarService.signOut();
      if (mounted) {
        setState(() {
          _isConnected = false;
          _userEmail = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error disconnecting: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          "Google Calendar",
          style: GoogleFonts.ebGaramond(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Image.asset(
                            "assets/images/google_calendar_icon.png",
                            width: 64,
                            height: 64,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Google Calendar Integration",
                          style: TextStyle(
                            color: textColor,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isConnected 
                              ? "Connected as $_userEmail" 
                              : "Connect your account to schedule events directly from your keyboard.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? Colors.grey : Colors.black54,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_isConnected)
                          OutlinedButton.icon(
                            onPressed: _disconnect,
                            icon: const Icon(Icons.logout),
                            label: const Text("Disconnect"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                            ),
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: _connect,
                            icon: const Icon(Icons.login),
                            label: const Text("Connect Google Calendar"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  const Divider(),
                  const SizedBox(height: 24),

                  // Instructions
                  Text(
                    "How to use",
                    style: TextStyle(
                      color: textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildStep(
                    context,
                    step: 1,
                    title: "Grant Permissions",
                    description: "Allow microphone and storage access for the app to work.",
                    isCompleted: _hasPermissions,
                    onTap: _hasPermissions ? null : _requestPermissions,
                  ),
                  _buildStep(
                    context,
                    step: 2,
                    title: "Connect Account",
                    description: "Ensure your Google Calendar account is connected above.",
                    isCompleted: _isConnected,
                  ),
                  _buildStep(
                    context,
                    step: 3,
                    title: "Open Keyboard",
                    description: "Go to any app (like Messages or WhatsApp) and open the Swift Speak keyboard.",
                  ),
                  _buildStep(
                    context,
                    step: 4,
                    title: "Take a Screenshot",
                    description: "Take a screenshot of an event flyer, a text message with a date, or any schedule details.",
                  ),
                  _buildStep(
                    context,
                    step: 5,
                    title: "Smart Scheduling",
                    description: "Swift Speak will automatically detect the screenshot, analyze the event details, and propose a calendar entry. Tap 'Add Event' to save it.",
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStep(
    BuildContext context, {
    required int step,
    required String title,
    required String description,
    bool isCompleted = false,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isCompleted ? Colors.green : (isDark ? Colors.grey[800] : Colors.grey[200]),
                shape: BoxShape.circle,
              ),
              child: isCompleted 
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : Text(
                      "$step",
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: isDark ? Colors.grey : Colors.black54,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }
}
