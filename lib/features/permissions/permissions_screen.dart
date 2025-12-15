import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import '../../services/calendar_service.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> with WidgetsBindingObserver {
  PermissionStatus _micStatus = PermissionStatus.denied;
  PermissionStatus _storageStatus = PermissionStatus.denied;
  bool _isKeyboardEnabled = false;
  static const platform = MethodChannel('com.anujsyadav.swiftspeak/settings');
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

  // ... existing dispose ...

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    final micStatus = await Permission.microphone.status;
    
    // Check keyboard status via MethodChannel
    bool keyboardEnabled = false;
    try {
      if (Theme.of(context).platform == TargetPlatform.android) {
        final bool result = await platform.invokeMethod('checkImeEnabled');
        keyboardEnabled = result;
      }
    } catch (e) {
      debugPrint("Failed to check keyboard status: $e");
    }

    // Check storage/photos status
    // Prioritize photos for Android 13+
    PermissionStatus storageStatus = await Permission.photos.status;
    
    if (!storageStatus.isGranted && !storageStatus.isLimited) {
      // Fallback to storage if photos is not relevant/granted
      final legacyStorage = await Permission.storage.status;
      if (legacyStorage.isGranted) {
        storageStatus = PermissionStatus.granted;
      } else if (legacyStorage.isPermanentlyDenied) {
        storageStatus = PermissionStatus.permanentlyDenied;
      }
      // If photos is denied but storage is denied, keep photos status or use storage?
      // Let's stick to the most relevant one.
      if (storageStatus.isDenied && legacyStorage.isDenied) {
         storageStatus = PermissionStatus.denied;
      }
    }

    if (mounted) {
      setState(() {
        _micStatus = micStatus;
        _storageStatus = storageStatus;
        _isKeyboardEnabled = keyboardEnabled;
      });
    }
  }

  Future<void> _handleMicPermission() async {
    // Always request first, even if limited/granted (might upgrade limited)
    if (!_micStatus.isPermanentlyDenied) {
      final status = await Permission.microphone.request();
      if (mounted) setState(() => _micStatus = status);
      return;
    }
    await openAppSettings();
  }

  Future<void> _handleStoragePermission() async {
    // Always request first
    if (!_storageStatus.isPermanentlyDenied) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
        Permission.photos,
      ].request();
      
      if (mounted) _checkPermissions();
      return;
    }
    await openAppSettings();
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
          _buildKeyboardItem(
            context,
            textColor: textColor,
            isDark: isDark,
            isEnabled: _isKeyboardEnabled,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8), // Compact margin
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Compact padding
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        borderRadius: BorderRadius.circular(16), // Slightly smaller radius
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10), // Compact icon padding
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05), // Neutral bg
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: textColor, size: 24), // Neutral icon color
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
                      fontSize: 18, // Fixed size
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14, // Fixed size
                    ),
                  ),
                  if (!isConnected) ...[
                    const SizedBox(height: 4),
                    Text(
                      "Tap to Connect",
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isConnected)
              const Icon(Icons.check, color: Colors.green, size: 24) // Green checkmark only
            else
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
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
    final isLimited = status.isLimited;
    
    // Treat limited as a warning state
    final color = isGranted 
        ? Colors.green 
        : (isLimited ? Colors.orange : (status.isPermanentlyDenied ? Colors.red : Colors.orange));
        
    final statusText = isGranted 
        ? "Granted" 
        : (isLimited 
            ? "Partial Access (Tap to Allow All)" 
            : (status.isPermanentlyDenied ? "Denied (Open Settings)" : "Tap to Allow"));

    return Container(
      margin: const EdgeInsets.only(bottom: 8), // Compact margin
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Compact padding
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05), // Neutral bg
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: textColor, size: 24), // Neutral icon color
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
                      fontSize: 18, // Fixed size
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14, // Fixed size
                    ),
                  ),
                  if (!isGranted || isLimited) ...[
                    const SizedBox(height: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isGranted && !isLimited)
              const Icon(Icons.check, color: Colors.green, size: 24) // Green checkmark only if fully granted
            else if (isLimited)
              const Icon(Icons.warning_amber, color: Colors.orange, size: 24)
            else
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyboardItem(
    BuildContext context, {
    required Color textColor,
    required bool isDark,
    required bool isEnabled,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () async {
          if (Theme.of(context).platform == TargetPlatform.android) {
            const intent = AndroidIntent(
              action: 'android.settings.INPUT_METHOD_SETTINGS',
            );
            await intent.launch();
            // The status will update automatically via didChangeAppLifecycleState when returning
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.keyboard, color: textColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "On-screen Keyboard",
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    "Required to use Swift Speak.",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  if (!isEnabled) ...[
                    const SizedBox(height: 4),
                    const Text(
                      "Tap to Open Settings",
                      style: TextStyle(
                        color: Colors.blue, 
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
             if (isEnabled)
               const Icon(Icons.check, color: Colors.green, size: 24)
             else
               const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}
