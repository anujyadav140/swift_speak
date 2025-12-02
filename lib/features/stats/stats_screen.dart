import 'package:flutter/material.dart';
import 'package:swift_speak/models/user_stats.dart';
import 'package:swift_speak/services/stats_service.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final StatsService statsService = StatsService();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Your Stats"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<UserStats>(
        stream: statsService.getUserStats(),
        builder: (context, snapshot) {
          final stats = snapshot.data ?? UserStats();
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You've been Swiftly Speaking 🎉",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: MediaQuery.of(context).size.width * 0.066, // 24 -> 0.066
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.1,
                    children: [
                      _buildStatCard(
                        context,
                        title: "DAILY STREAK",
                        value: "${stats.currentStreak} days",
                        emoji: "👋",
                      ),
                      _buildStatCard(
                        context,
                        title: "AVERAGE SPEED",
                        value: "${stats.wpm.toStringAsFixed(0)} words per minute",
                        emoji: "🏅",
                      ),
                      _buildStatCard(
                        context,
                        title: "TOTAL WORDS DICTATED",
                        value: "${stats.totalWords}",
                        emoji: "🚀",
                      ),
                      _buildStatCard(
                        context,
                        title: "TOTAL APPS USED",
                        value: "${stats.totalAppsUsed} apps",
                        emoji: "⭐",
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required String emoji,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.grey[900] : Colors.grey[100];
    final width = MediaQuery.of(context).size.width;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                  letterSpacing: 1.2,
                  fontSize: width * 0.033, // approx 12 -> 0.033
                ),
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: width * 0.055, // 20 -> 0.055
                  ),
              children: [
                TextSpan(text: value),
                const TextSpan(text: " "),
                TextSpan(text: emoji),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
