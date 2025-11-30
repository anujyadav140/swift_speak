import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';

class QuickTipsScreen extends StatelessWidget {
  const QuickTipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Quick Tips"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          FadeInDown(
            child: Text(
              "Get Started with Swift Speak",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const SizedBox(height: 24),
          _buildStep(
            context,
            step: 1,
            title: "Enable the Keyboard",
            description:
                "Go to Settings > System > Languages & input > On-screen keyboard > Manage on-screen keyboards and enable 'Swift Speak'.",
            icon: Icons.settings,
            delay: 100,
          ),
          _buildStep(
            context,
            step: 2,
            title: "Select the Keyboard",
            description:
                "Tap on any text field to open your current keyboard. Tap the keyboard icon in the navigation bar (or notification shade) and select 'Swift Speak'.",
            icon: Icons.keyboard,
            delay: 200,
          ),
          _buildStep(
            context,
            step: 3,
            title: "Grant Permissions",
            description:
                "Ensure you have granted Microphone permission. The app needs this to listen to your voice.",
            icon: Icons.mic,
            delay: 300,
          ),
          _buildStep(
            context,
            step: 4,
            title: "Start Dictating",
            description:
                "Tap the microphone icon on the Swift Speak toolbar to start dictating. Tap it again to stop.",
            icon: Icons.record_voice_over,
            delay: 400,
          ),
        ],
      ),
    );
  }

  Widget _buildStep(
    BuildContext context, {
    required int step,
    required String title,
    required String description,
    required IconData icon,
    required int delay,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;

    return FadeInUp(
      delay: Duration(milliseconds: delay),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black12,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Text(
                "$step",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: width * 0.0495, // 18 -> 0.0495
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: width * 0.055, color: Theme.of(context).colorScheme.primary), // 20 -> 0.055
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: width * 0.044, // 16 -> 0.044 (approx for titleMedium)
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                          fontSize: width * 0.0385, // 14 -> 0.0385 (approx for bodyMedium)
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
