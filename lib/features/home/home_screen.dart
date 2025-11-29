
import 'package:avatar_glow/avatar_glow.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:swift_speak/features/home/quick_tips_screen.dart';
import 'package:swift_speak/features/stats/stats_screen.dart';
import 'package:swift_speak/features/dictionary/dictionary_screen.dart';
import 'package:swift_speak/features/style/style_screen.dart';
import 'package:swift_speak/features/snippets/snippets_screen.dart';

import 'package:swift_speak/services/theme_service.dart';
import '../../widgets/border_beam_painter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {

  final ThemeService _themeService = ThemeService();
  bool _hasMicPermission = false;

  int _selectedIndex = 1;
  late AnimationController _beamController;

  @override
  void initState() {
    super.initState();
    _checkMicPermission();
    _beamController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
  }

  @override
  void dispose() {
    _beamController.dispose();
    super.dispose();
  }

  Future<void> _checkMicPermission() async {
    final audioRecorder = AudioRecorder();
    final hasPermission = await audioRecorder.hasPermission();
    audioRecorder.dispose();
    if (mounted) {
      setState(() {
        _hasMicPermission = hasPermission;
      });
    }
  }

  Future<void> _requestMicPermission() async {
    if (_hasMicPermission) return;

    final status = await Permission.microphone.request();
    if (status.isGranted) {
      if (mounted) {
        setState(() {
          _hasMicPermission = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Microphone permission granted!")),
        );
      }
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Permission permanently denied. Opening settings..."),
          ),
        );
        await openAppSettings();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Permission denied. Please enable in App Settings.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              child: Text(
                'Swift Speak',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.logout, color: Theme.of(context).iconTheme.color),
              title: const Text('Sign Out'),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: Text(
          _selectedIndex == 0 
              ? "Dictionary" 
              : _selectedIndex == 2 
                  ? "Snippets"
                  : _selectedIndex == 3
                      ? "Style" 
                      : "Swift Speak",
          style: GoogleFonts.ebGaramond(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.emoji_events,
              color: Theme.of(context).iconTheme.color,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StatsScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: Theme.of(context).iconTheme.color,
            ),
            onPressed: () async {
              final newMode = isDark ? ThemeMode.light : ThemeMode.dark;
              await _themeService.updateThemeMode(newMode);
            },
          ),
        ],
      ),
      body: _selectedIndex == 0 
          ? const DictionaryScreen() 
          : _selectedIndex == 1 
              ? _buildHomeContent() 
              : _selectedIndex == 2
                  ? const SnippetsScreen()
                  : const StyleScreen(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.black : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white10 : Colors.black12,
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.book_outlined, Icons.book),
                _buildNavItem(1, Icons.home_outlined, Icons.home),
                _buildNavItem(2, Icons.content_cut_outlined, Icons.content_cut),
                _buildNavItem(3, Icons.auto_awesome_outlined, Icons.auto_awesome),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData iconOutlined, IconData iconFilled) {
    final isSelected = _selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: CustomPaint(
        painter: isSelected 
            ? BorderBeamPainter(
                animation: _beamController, 
                borderRadius: 20,
                color: isDark ? Colors.white : Colors.black,
              ) 
            : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.transparent,
          ),
          child: Icon(
            isSelected ? iconFilled : iconOutlined,
            color: isDark ? Colors.white : Colors.black,
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? "User";
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;

    // Responsive calculations
    final gridHeight = height * 0.25;
    final cardPadding = width * 0.04;
    final iconPadding = width * 0.025;
    final largeIconSize = width * 0.07;
    final smallIconSize = width * 0.05;
    final titleFontSize = width * 0.05;
    final subtitleFontSize = width * 0.03;

    return SingleChildScrollView(
      padding: EdgeInsets.all(width * 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Header
          Text(
            "Welcome back, $userName 👋",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                  fontSize: width * 0.055,
                ),
          ),


          SizedBox(height: width * 0.04),

          // Grid Layout
          SizedBox(
            height: gridHeight,
            child: Row(
              children: [
                // Left Column: Quick Tips (Yellow)
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const QuickTipsScreen()),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFC107), // Amber/Yellow
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: EdgeInsets.all(cardPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: EdgeInsets.all(iconPadding),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.lightbulb, color: Colors.white, size: largeIconSize),
                          ),
                          const Spacer(),
                          Text(
                            "Quick Tips",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: height * 0.005),
                          Text(
                            "Learn how to use Swift Speak",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: subtitleFontSize,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                SizedBox(width: width * 0.04),
                
                // Right Column
                Expanded(
                  child: Column(
                    children: [
                      // Top Right: Mic Permission (Purple)
                      Expanded(
                        child: GestureDetector(
                          onTap: _requestMicPermission,
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFF9575CD), // Purple
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: EdgeInsets.all(cardPadding * 0.8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(iconPadding * 0.8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _hasMicPermission ? Icons.mic : Icons.mic_off,
                                    color: Colors.white,
                                    size: smallIconSize,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _hasMicPermission ? "Mic Active" : "Enable Mic",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: titleFontSize * 0.8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _hasMicPermission ? "Ready" : "Tap to allow",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: subtitleFontSize * 0.9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      SizedBox(height: height * 0.02),
                      
                      // Bottom Right: Dictionary (Blue Grey)
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedIndex = 0;
                            });
                          },
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFF607D8B), // Blue Grey
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: EdgeInsets.all(cardPadding * 0.8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(iconPadding * 0.8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.book, color: Colors.white, size: smallIconSize),
                                ),
                                const Spacer(),
                                Text(
                                  "Dictionary",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: titleFontSize * 0.8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "Manage words",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: subtitleFontSize * 0.9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


}
