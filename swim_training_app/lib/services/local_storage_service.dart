import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/saved_program.dart';

class LocalStorageService {
  static const int maxSavedPrograms = 30;

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference? get _collection {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('saved_programs');
  }

  /// 프로그램 저장
  Future<void> saveProgram(SavedProgram program) async {
    final col = _collection;
    if (col == null) return;

    // 중복 체크: 같은 ID면 업데이트, 없으면 개수 제한 확인 후 추가
    final existing = await col.doc(program.id).get();
    if (!existing.exists) {
      final snapshot = await col.get();
      if (snapshot.docs.length >= maxSavedPrograms) {
        throw Exception('최대 $maxSavedPrograms개까지만 저장할 수 있습니다.\n오래된 프로그램을 삭제하고 다시 시도해주세요.');
      }
    }

    await col.doc(program.id).set(program.toJson());
  }

  /// 저장된 프로그램 목록 조회
  Future<List<SavedProgram>> getSavedPrograms() async {
    final col = _collection;
    if (col == null) return [];

    final snapshot = await col.orderBy('saved_at', descending: true).get();
    return snapshot.docs
        .map((doc) => SavedProgram.fromJson(doc.data() as Map<String, dynamic>))
        .toList();
  }

  /// 특정 프로그램 조회
  Future<SavedProgram?> getProgram(String id) async {
    final col = _collection;
    if (col == null) return null;

    final doc = await col.doc(id).get();
    if (!doc.exists) return null;
    return SavedProgram.fromJson(doc.data() as Map<String, dynamic>);
  }

  /// 프로그램 삭제
  Future<void> deleteProgram(String id) async {
    final col = _collection;
    if (col == null) return;
    await col.doc(id).delete();
  }

  /// 프로그램 업데이트 (메모, 제목 등)
  Future<void> updateProgram(SavedProgram program) async {
    await saveProgram(program);
  }

  /// 모든 프로그램 삭제 (초기화)
  Future<void> clearAllPrograms() async {
    final col = _collection;
    if (col == null) return;

    final snapshot = await col.get();
    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
