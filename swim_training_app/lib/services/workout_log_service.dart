import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/workout_log.dart';

class WorkoutLogService {
  static const int maxLogs = 100;

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference? get _collection {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('workout_logs');
  }

  Future<List<WorkoutLog>> getLogs() async {
    final col = _collection;
    if (col == null) return [];

    final snapshot = await col.orderBy('started_at', descending: true).get();
    return snapshot.docs
        .map((doc) => WorkoutLog.fromJson(doc.data() as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveLog(WorkoutLog log) async {
    final col = _collection;
    if (col == null) return;

    await col.doc(log.id).set(log.toJson());

    // 최대 개수 제한 - 초과 시 오래된 것 삭제
    final snapshot = await col.orderBy('started_at', descending: true).get();
    if (snapshot.docs.length > maxLogs) {
      final batch = _db.batch();
      for (final doc in snapshot.docs.skip(maxLogs)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  Future<void> deleteLog(String id) async {
    final col = _collection;
    if (col == null) return;
    await col.doc(id).delete();
  }

  Future<void> clearLogs() async {
    final col = _collection;
    if (col == null) return;

    final snapshot = await col.get();
    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<List<WorkoutLog>> getRecentLogs({int limit = 3}) async {
    final col = _collection;
    if (col == null) return [];

    final snapshot = await col
        .orderBy('started_at', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => WorkoutLog.fromJson(doc.data() as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, int>> getPeriodSummary({
    required DateTime start,
    required DateTime end,
  }) async {
    final logs = await getLogs();
    final filtered = logs.where(
      (l) =>
          !l.completedAt.isBefore(start) &&
          l.completedAt.isBefore(end),
    );

    final distance = filtered.fold<int>(0, (sum, l) => sum + l.completedDistance);
    final count = filtered.length;
    final minutes = filtered.fold<int>(
      0,
      (sum, l) => sum + l.completedAt.difference(l.startedAt).inMinutes,
    );

    return {
      'distance': distance,
      'count': count,
      'minutes': minutes,
    };
  }

  Future<Map<String, int>> getWeeklySummary({DateTime? reference}) async {
    final now = reference ?? DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final end = start.add(const Duration(days: 7));
    return getPeriodSummary(start: start, end: end);
  }

  Future<Map<String, int>> getMonthlySummary({DateTime? reference}) async {
    final now = reference ?? DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1);
    return getPeriodSummary(start: start, end: end);
  }

  /// 이번 주 총 거리
  Future<int> getWeeklyDistance() async {
    final summary = await getWeeklySummary();
    return summary['distance'] ?? 0;
  }

  Future<int> getMonthlyDistance() async {
    final summary = await getMonthlySummary();
    return summary['distance'] ?? 0;
  }

  /// 총 운동 횟수
  Future<int> getTotalWorkoutCount() async {
    final logs = await getLogs();
    return logs.length;
  }

  Future<int> getWeeklyWorkoutCount() async {
    final summary = await getWeeklySummary();
    return summary['count'] ?? 0;
  }

  Future<int> getMonthlyWorkoutCount() async {
    final summary = await getMonthlySummary();
    return summary['count'] ?? 0;
  }
}
