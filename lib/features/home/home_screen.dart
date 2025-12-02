import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swift_speak/features/stats/stats_screen.dart';
import 'package:swift_speak/features/dictionary/dictionary_screen.dart';
import 'package:swift_speak/features/style/style_screen.dart';
import 'package:swift_speak/features/snippets/snippets_screen.dart';
import 'package:swift_speak/features/local_model/local_model_screen.dart';
import 'package:swift_speak/features/permissions/permissions_screen.dart';
import 'package:swift_speak/features/home/quick_tips_screen.dart';
import 'package:swift_speak/features/home/quick_tips_carousel.dart';
import 'package:swift_speak/services/theme_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ThemeService _themeService = ThemeService();
  bool _hasMicPermission = false;
  bool _showQuickTips = false; // Default to false to prevent flash

  @override
  void initState() {
    super.initState();
    _checkMicPermission();
    _loadQuickTipsPreference();
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

  Future<void> _loadQuickTipsPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final shouldShow = prefs.getBool('showQuickTips') ?? true;
    if (mounted && shouldShow) {
      setState(() {
        _showQuickTips = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? "User";

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Swift Speak",
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
              Icons.bar_chart,
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
      drawer: _buildDrawer(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome back, $userName 👋",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
            ),
            const SizedBox(height: 20),
            
            // Quick Tips Carousel (Conditional)
            if (_showQuickTips) ...[
              QuickTipsCarousel(
                onDismiss: () {
                  setState(() {
                    _showQuickTips = false;
                  });
                },
              ),
              const SizedBox(height: 24),
            ],
            
            // Feature Cards List
            _buildFeatureCard(
              context,
              title: "Dictionary",
              subtitle: "Manage your personal dictionary",
              icon: Icons.book,
              color: const Color(0xFF607D8B), // Blue Grey
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DictionaryScreen())),
            ),
            const SizedBox(height: 16),
            _buildFeatureCard(
              context,
              title: "Snippets",
              subtitle: "Manage text shortcuts",
              icon: Icons.content_cut,
              color: const Color(0xFF00897B), // Teal
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SnippetsScreen())),
            ),
            const SizedBox(height: 16),
            _buildFeatureCard(
              context,
              title: "Style",
              subtitle: "Customize your tone",
              icon: Icons.auto_awesome,
              color: const Color(0xFFEC407A), // Pink
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StyleScreen())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.graphic_eq,
                  size: 48,
                  color: Colors.white,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Swift Speak',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.lightbulb_outline),
            title: const Text('Quick Tips'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(context, MaterialPageRoute(builder: (_) => const QuickTipsScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.verified_user),
            title: const Text('Permissions'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PermissionsScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.memory),
            title: const Text('AI Model'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(context, MaterialPageRoute(builder: (_) => const LocalModelScreen()));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign Out'),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? Colors.black : color,
          borderRadius: BorderRadius.circular(20),
          border: isDark ? Border.all(color: color, width: 1) : null,
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? color.withOpacity(0.2) : Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon, 
                color: isDark ? color : Colors.white, 
                size: 28,
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
                      color: isDark ? Colors.white : Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDark ? Colors.grey : Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios, 
              color: isDark ? Colors.grey : Colors.white54, 
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
