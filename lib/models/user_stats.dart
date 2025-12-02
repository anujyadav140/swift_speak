import 'package:cloud_firestore/cloud_firestore.dart';

class UserStats {
  final int currentStreak;
  final DateTime? lastActiveDate;
  final int totalWords;
  final int totalDurationSeconds;
  final int totalAppsUsed;
  final List<String> usedAppPackages;

  UserStats({
    this.currentStreak = 0,
    this.lastActiveDate,
    this.totalWords = 0,
    this.totalDurationSeconds = 0,
    this.totalAppsUsed = 0,
    this.usedAppPackages = const [],
  });

  double get wpm {
    if (totalDurationSeconds == 0) return 0;
    return (totalWords / (totalDurationSeconds / 60));
  }

  factory UserStats.fromMap(Map<String, dynamic> map) {
    return UserStats(
      currentStreak: map['currentStreak'] ?? 0,
      lastActiveDate: map['lastActiveDate'] != null
          ? (map['lastActiveDate'] as Timestamp).toDate()
          : null,
      totalWords: map['totalWords'] ?? 0,
      totalDurationSeconds: map['totalDurationSeconds'] ?? 0,
      totalAppsUsed: map['totalAppsUsed'] ?? 0,
      usedAppPackages: List<String>.from(map['usedAppPackages'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'currentStreak': currentStreak,
      'lastActiveDate': lastActiveDate != null
          ? Timestamp.fromDate(lastActiveDate!)
          : null,
      'totalWords': totalWords,
      'totalDurationSeconds': totalDurationSeconds,
      'totalAppsUsed': totalAppsUsed,
      'usedAppPackages': usedAppPackages,
    };
  }
}
