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
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "Here's a personal stats of your productivity with Swift Speak.",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
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
                        subtitle: "Welcome!",
                      ),
                      _buildStatCard(
                        context,
                        title: "AVERAGE SPEED",
                        value: "${stats.wpm.toStringAsFixed(0)} words per minute",
                        emoji: "🏅",
                        subtitle: "Top 5% of all Flow users",
                      ),
                      _buildStatCard(
                        context,
                        title: "TOTAL WORDS DICTATED",
                        value: "${stats.totalWords}",
                        emoji: "🚀",
                        subtitle: "You've written 9 cover letters!", // Placeholder
                      ),
                      _buildStatCard(
                        context,
                        title: "TOTAL APPS USED",
                        value: "${stats.totalAppsUsed} apps",
                        emoji: "⭐",
                        subtitle: "You are almost at flow mastery!",
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
    required String subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.grey[900] : Colors.grey[100];

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
                ),
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 20, // Slightly smaller to fit "words per minute"
                  ),
              children: [
                TextSpan(text: value),
                const TextSpan(text: " "),
                TextSpan(text: emoji),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                ),
          ),
        ],
      ),
    );
  }
}
