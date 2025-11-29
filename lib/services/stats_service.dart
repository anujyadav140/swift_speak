import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:swift_speak/models/user_stats.dart';

class StatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<UserStats> getUserStats() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(UserStats());
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('stats')
        .doc('summary')
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return UserStats.fromMap(snapshot.data()!);
      } else {
        return UserStats();
      }
    });
  }

  Future<void> updateStats(int newWords, Duration duration) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('stats')
        .doc('summary');

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      UserStats currentStats;

      if (snapshot.exists && snapshot.data() != null) {
        currentStats = UserStats.fromMap(snapshot.data()!);
      } else {
        currentStats = UserStats();
      }

      // Calculate new streak
      int newStreak = currentStats.currentStreak;
      DateTime now = DateTime.now();
      DateTime today = DateTime(now.year, now.month, now.day);
      
      if (currentStats.lastActiveDate != null) {
        DateTime lastActive = currentStats.lastActiveDate!;
        DateTime lastActiveDay = DateTime(lastActive.year, lastActive.month, lastActive.day);

        if (today.difference(lastActiveDay).inDays == 1) {
          newStreak++;
        } else if (today.difference(lastActiveDay).inDays > 1) {
          newStreak = 1; // Reset streak
        }
        // If same day, streak doesn't change
      } else {
        newStreak = 1; // First day
      }

      final updatedStats = UserStats(
        currentStreak: newStreak,
        lastActiveDate: now,
        totalWords: currentStats.totalWords + newWords,
        totalDurationSeconds: currentStats.totalDurationSeconds + duration.inSeconds,
      );

      transaction.set(docRef, updatedStats.toMap());
    });
  }
}
