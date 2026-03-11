import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SearchHistoryItem {
  final String id;
  final String query;
  final DateTime timestamp;

  SearchHistoryItem({
    required this.id,
    required this.query,
    required this.timestamp,
  });

  factory SearchHistoryItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final timestampData = data['timestamp'];
    DateTime timestamp;
    
    if (timestampData is Timestamp) {
      timestamp = timestampData.toDate();
    } else {
      timestamp = DateTime.now();
    }
    
    return SearchHistoryItem(
      id: doc.id,
      query: data['query'] ?? '',
      timestamp: timestamp,
    );
  }
}

class SearchHistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 현재 사용자의 검색 기록 컬렉션 참조
  CollectionReference? get _historyCollection {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _firestore.collection('users').doc(user.uid).collection('search_history');
  }

  /// 검색어 저장 (중복 방지 - 같은 검색어면 timestamp만 업데이트)
  Future<void> saveSearchQuery(String query) async {
    final collection = _historyCollection;
    if (collection == null) return;

    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return;

    try {
      // 같은 검색어가 있는지 확인
      final existing = await collection
          .where('query', isEqualTo: trimmedQuery)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        // 기존 검색어가 있으면 timestamp 업데이트
        await existing.docs.first.reference.update({
          'timestamp': Timestamp.now(),
        });
      } else {
        // 새 검색어 추가
        await collection.add({
          'query': trimmedQuery,
          'timestamp': Timestamp.now(),
        });
      }
    } catch (e) {
      print('검색어 저장 실패: $e');
    }
  }

  /// 검색 기록 가져오기 (최신순)
  Future<List<SearchHistoryItem>> getSearchHistory({int limit = 20}) async {
    final collection = _historyCollection;
    if (collection == null) return [];

    try {
      final snapshot = await collection
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => SearchHistoryItem.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('검색 기록 가져오기 실패: $e');
      return [];
    }
  }

  /// 검색 기록 스트림 (실시간 업데이트)
  Stream<List<SearchHistoryItem>> searchHistoryStream({int limit = 20}) {
    final collection = _historyCollection;
    if (collection == null) return Stream.value([]);

    return collection
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SearchHistoryItem.fromFirestore(doc))
            .toList());
  }

  /// 개별 검색어 삭제
  Future<void> deleteSearchQuery(String id) async {
    final collection = _historyCollection;
    if (collection == null) return;

    try {
      await collection.doc(id).delete();
    } catch (e) {
      // 삭제 실패 시 무시
    }
  }

  /// 전체 검색 기록 삭제
  Future<void> deleteAllSearchHistory() async {
    final collection = _historyCollection;
    if (collection == null) return;

    try {
      final snapshot = await collection.get();
      final batch = _firestore.batch();
      
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
    } catch (e) {
      print('전체 검색 기록 삭제 실패: $e');
    }
  }
}
