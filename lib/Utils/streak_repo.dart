import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StreakRepository {
  // cached CollectionReference pointing at /users so we don’t rebuild the path every call.
  final _users = FirebaseFirestore.instance.collection('users');

  /// Returns the new streak value (unchanged if it was already counted today).
  Future<int> incrementIfNeeded() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 0;

    return FirebaseFirestore.instance.runTransaction<int>((txn) async {
      final ref = _users.doc(uid);
      final snap = await txn.get(ref);
      final data = snap.data();

      int  streak = (data?['streak'] as int?) ?? 0;
      int  longest = (data?['longestStreak'] as int?) ?? 0;
      DateTime today = _midnight(DateTime.now());
      DateTime? last = (data?['lastActive'] as Timestamp?)?.toDate();

      final gap = last == null ? 1 : today.difference(last).inDays;

      if (gap == 0) return streak;         // already counted today
      if (gap == 1) {
        streak += 1;           // consecutive day
      } else {
        streak  = 1;           // reset
      }

      if (streak > longest) longest = streak;

      txn.set(ref, {
        'streak': streak,
        'lastActive': Timestamp.fromDate(today),
        'longestStreak': longest,
      }, SetOptions(merge: true));         // adds fields if missing

      return streak;
    });
  }

  DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);      // keeping it simple for now
}