import 'package:cloud_firestore/cloud_firestore.dart';

class UserStats {
  final int currentStreak;
  final DateTime? lastActiveDate;
  final int totalWords;
  final int totalDurationSeconds;
  final int totalAppsUsed;
  final List<String> usedAppPackages;
  
  // Paywall fields
  final String subscriptionTier; // "FREE" or "PRO"
  final int tokenUsageCurrentPeriod;
  final DateTime? billingPeriodEnd;

  UserStats({
    this.currentStreak = 0,
    this.lastActiveDate,
    this.totalWords = 0,
    this.totalDurationSeconds = 0,
    this.totalAppsUsed = 0,
    this.usedAppPackages = const [],
    this.subscriptionTier = 'FREE',
    this.tokenUsageCurrentPeriod = 0,
    this.billingPeriodEnd,
  });

  double get wpm {
    if (totalDurationSeconds == 0) return 0;
    return (totalWords / (totalDurationSeconds / 60));
  }
  
  bool get isPro => subscriptionTier == 'PRO';
  
  // 10k tokens/week (~30 sentences or 5 screenshots)
  static const int freeTierWeeklyLimit = 10000;
  
  bool get isAtLimit {
    if (isPro) return false;
    return tokenUsageCurrentPeriod >= freeTierWeeklyLimit;
  }
  
  double get usagePercentage {
     if (isPro) return 0.0;
     if (freeTierWeeklyLimit == 0) return 1.0;
     return (tokenUsageCurrentPeriod / freeTierWeeklyLimit).clamp(0.0, 1.0);
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
      subscriptionTier: map['subscriptionTier'] ?? 'FREE',
      tokenUsageCurrentPeriod: map['tokenUsageCurrentPeriod'] ?? 0,
      billingPeriodEnd: map['billingPeriodEnd'] != null
          ? (map['billingPeriodEnd'] as Timestamp).toDate()
          : null,
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
      'subscriptionTier': subscriptionTier,
      'tokenUsageCurrentPeriod': tokenUsageCurrentPeriod,
      'billingPeriodEnd': billingPeriodEnd != null 
          ? Timestamp.fromDate(billingPeriodEnd!)
          : null,
    };
  }
}
