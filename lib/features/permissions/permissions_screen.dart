import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../services/calendar_service.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> with WidgetsBindingObserver {
  PermissionStatus _micStatus = PermissionStatus.denied;
  PermissionStatus _storageStatus = PermissionStatus.denied;
  GoogleSignInAccount? _calendarUser;
  final CalendarService _calendarService = CalendarService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
    _calendarService.onCurrentUserChanged.listen((user) {
      if (mounted) setState(() => _calendarUser = user);
    });
    _calendarUser = _calendarService.currentUser;
  }

  // ... existing dispose ...

  // ... existing didChangeAppLifecycleState ...

  Future<void> _checkPermissions() async {
    final micStatus = await Permission.microphone.status;
    
    // Check storage (different for Android 13+)
    PermissionStatus storageStatus;
    if (await Permission.mediaLibrary.status.isGranted || await Permission.storage.status.isGranted || await Permission.photos.status.isGranted) {
       storageStatus = PermissionStatus.granted;
    } else {
       storageStatus = await Permission.storage.status;
    }

    if (mounted) {
      setState(() {
        _micStatus = micStatus;
        _storageStatus = storageStatus;
      });
    }
  }

  Future<void> _handleMicPermission() async {
    if (_micStatus.isGranted) return;
    if (_micStatus.isPermanentlyDenied) {
      await openAppSettings();
    } else {
      final status = await Permission.microphone.request();
      if (mounted) setState(() => _micStatus = status);
    }
  }

  Future<void> _handleStoragePermission() async {
    if (_storageStatus.isGranted) return;

    if (_storageStatus.isPermanentlyDenied) {
      await openAppSettings();
    } else {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
        Permission.photos,
      ].request();
      
      if (mounted) _checkPermissions();
    }
  }

  Future<void> _handleCalendarAuth() async {
    if (_calendarUser != null) {
      // Already connected, show dialog to disconnect
      final shouldDisconnect = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Disconnect Calendar?"),
          content: Text("Do you want to disconnect ${_calendarUser!.email}?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Disconnect")),
          ],
        ),
      );

      if (shouldDisconnect == true) {
        await _calendarService.signOut();
      }
    } else {
      // Connect
      await _calendarService.signIn();
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Permissions",
          style: GoogleFonts.ebGaramond(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: MediaQuery.of(context).size.width * 0.066,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPermissionItem(
            title: "Microphone",
            description: "Required for speech-to-text functionality.",
            icon: Icons.mic,
            status: _micStatus,
            onTap: _handleMicPermission,
            textColor: textColor,
            isDark: isDark,
          ),
          _buildPermissionItem(
            title: "Screenshot Access",
            description: "Required to analyze screenshots for scheduling.",
            icon: Icons.image,
            status: _storageStatus,
            onTap: _handleStoragePermission,
            textColor: textColor,
            isDark: isDark,
          ),
          _buildAuthItem(
            title: "Google Calendar",
            description: _calendarUser != null 
                ? "Connected as ${_calendarUser!.email}" 
                : "Connect to check availability.",
            icon: Icons.calendar_month,
            isConnected: _calendarUser != null,
            onTap: _handleCalendarAuth,
            textColor: textColor,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildAuthItem({
    required String title,
    required String description,
    required IconData icon,
    required bool isConnected,
    required VoidCallback onTap,
    required Color textColor,
    required bool isDark,
  }) {
    final color = isConnected ? Colors.green : Colors.blue;
    final statusText = isConnected ? "Connected" : "Tap to Connect";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
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
                      fontSize: MediaQuery.of(context).size.width * 0.0495,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: MediaQuery.of(context).size.width * 0.0385,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: MediaQuery.of(context).size.width * 0.0385,
                    ),
                  ),
                ],
              ),
            ),
            if (isConnected)
              const Icon(Icons.check_circle, color: Colors.green)
            else
              const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionItem({
    required String title,
    required String description,
    required IconData icon,
    required PermissionStatus status,
    required VoidCallback onTap,
    required Color textColor,
    required bool isDark,
  }) {
    final isGranted = status.isGranted;
    final color = isGranted ? Colors.green : (status.isPermanentlyDenied ? Colors.red : Colors.orange);
    final statusText = isGranted ? "Granted" : (status.isPermanentlyDenied ? "Denied (Open Settings)" : "Tap to Allow");

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
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
                      fontSize: MediaQuery.of(context).size.width * 0.0495, // 18 -> 0.0495
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: MediaQuery.of(context).size.width * 0.0385, // 14 -> 0.0385
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: MediaQuery.of(context).size.width * 0.0385, // 14 -> 0.0385
                    ),
                  ),
                ],
              ),
            ),
            if (isGranted)
              const Icon(Icons.check_circle, color: Colors.green)
            else
              const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
