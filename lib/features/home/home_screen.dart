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
import 'package:swift_speak/features/home/tips_data.dart';

import 'package:swift_speak/features/paywall/paywall_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:swift_speak/models/user_stats.dart';

import 'package:swift_speak/services/theme_service.dart';
import 'package:swift_speak/features/connectors/connectors_screen.dart';
import 'package:swift_speak/features/languages/languages_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ThemeService _themeService = ThemeService();
  bool _hasMicPermission = false;
  bool _showSetupTip = false;

  @override
  void initState() {
    super.initState();
    _checkMicPermission();
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





  Future<void> _saveSetupTipPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showSetupTip', false);
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
                    fontSize: 24,
                  ),
            ),
            const SizedBox(height: 20),
            
            // Quick Tips Carousel removed as per request
            // Was here: if (_showQuickTips) ...

            // Usage / Pro Card
            if (user != null)
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
                  
                  final stats = UserStats.fromMap(snapshot.data!.data() as Map<String, dynamic>);
                  if (stats.isPro) return const SizedBox.shrink(); // Don't show if already pro (or maybe show "Pro Active"?)

                  return Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      // Monochrome background or subtle grey to be minimalistic
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                      boxShadow: [
                         if (!isDark)
                           BoxShadow(
                             color: Colors.black.withOpacity(0.05),
                             blurRadius: 10,
                             offset: const Offset(0, 4),
                           ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Weekly Usage",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              "${(stats.usagePercentage * 100).toInt()}%",
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: stats.usagePercentage,
                            // Background track color
                            backgroundColor: isDark ? Colors.white10 : Colors.black12,
                            // Active bar color: White in dark mode, Black in light mode
                            valueColor: AlwaysStoppedAnimation<Color>(
                              stats.isAtLimit 
                                  ? Colors.redAccent 
                                  : (isDark ? Colors.white : Colors.black),
                            ),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallScreen()));
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? Colors.white : Colors.black,
                              foregroundColor: isDark ? Colors.black : Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text("Upgrade to Pro"),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

            
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
              color: const Color(0xFF405573), // User specified blue-grey
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StyleScreen())),
            ),
            const SizedBox(height: 16),
            _buildFeatureCard(
              context,
              title: "Connectors",
              subtitle: "Integrate with other apps",
              icon: Icons.hub,
              color: const Color(0xFF6D5580), // User specified purple
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConnectorsScreen())),
            ),
            const SizedBox(height: 16),
            _buildFeatureCard(
              context,
              title: "Languages",
              subtitle: "Select speech language",
              icon: Icons.language,
              color: const Color(0xFF5C6BC0), // Indigo
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LanguagesScreen())),
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
                Image.asset(
                  'assets/images/logo.png',
                  height: 80, // Adjust height as needed
                  width: 80,
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
          ListTile(
            leading: const Icon(Icons.star, color: Colors.amber),
            title: const Text('Upgrade to Pro'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallScreen()));
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
          color: color, // Always use the assigned color
          borderRadius: BorderRadius.circular(20),
          // No border needed as colors are distinct
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2), // Consistent semi-transparent white
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon, 
                color: Colors.white, // Always white icon
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
                    style: const TextStyle(
                      color: Colors.white, // Always white text
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70, // Always white70 subtitle
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios, 
              color: Colors.white54, // Always white54 arrow
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
