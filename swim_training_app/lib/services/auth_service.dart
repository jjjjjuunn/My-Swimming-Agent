import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // 현재 로그인한 사용자
  User? get currentUser => _auth.currentUser;

  // 인증 상태 스트림
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 이메일/비밀번호 회원가입
  Future<UserModel?> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
    String? nickname,
  }) async {
    try {
      final UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) return null;

      // 프로필 업데이트
      if (displayName != null) {
        await user.updateDisplayName(displayName);
      }

      // Firestore에 사용자 정보 저장
      final userModel = UserModel(
        uid: user.uid,
        email: email,
        displayName: displayName,
        nickname: nickname,
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
      );

      await _firestore.collection('users').doc(user.uid).set(userModel.toMap());

      // 이메일 인증 발송 후 로그아웃 (인증 전 앱 사용 방지)
      await user.sendEmailVerification();
      await _auth.signOut();
      print('✅ 회원가입 성공, 인증 메일 발송: $email');
      throw 'VERIFICATION_EMAIL_SENT';
    } on FirebaseAuthException catch (e) {
      print('❌ FirebaseAuthException: code=${e.code}, message=${e.message}');
      // 이미 가입됐지만 미인증인 계정 → 인증 메일 재발송
      if (e.code == 'email-already-in-use') {
        try {
          final signInCred = await _auth.signInWithEmailAndPassword(
            email: email, password: password,
          );
          final existingUser = signInCred.user;
          if (existingUser != null && !existingUser.emailVerified) {
            await existingUser.sendEmailVerification();
            await _auth.signOut();
            throw 'VERIFICATION_EMAIL_SENT';
          }
          await _auth.signOut();
        } catch (inner) {
          if (inner.toString() == 'VERIFICATION_EMAIL_SENT') rethrow;
          // 비밀번호 불일치 등 → 일반 에러 표시
        }
      }
      throw _handleAuthException(e);
    } catch (e) {
      if (e.toString() == 'VERIFICATION_EMAIL_SENT') rethrow;
      print('❌ 회원가입 오류 (상세): $e');
      throw '회원가입 중 오류가 발생했습니다: $e';
    }
  }

  // 이메일/비밀번호 로그인
  Future<UserModel?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) return null;

      // 이메일 인증 확인
      await user.reload();
      if (!user.emailVerified) {
        await _auth.signOut();
        throw 'EMAIL_NOT_VERIFIED';
      }

      // Firestore에서 사용자 정보 가져오기
      final doc = await _firestore.collection('users').doc(user.uid).get();
      
      if (!doc.exists) {
        // 문서가 없으면 새로 생성
        final userModel = UserModel(
          uid: user.uid,
          email: email,
          displayName: user.displayName,
          photoURL: user.photoURL,
          createdAt: DateTime.now(),
          lastLogin: DateTime.now(),
        );
        await _firestore.collection('users').doc(user.uid).set(userModel.toMap());
        return userModel;
      }

      // 마지막 로그인 시간 업데이트
      final userModel = UserModel.fromMap(doc.data()!);
      final updatedUser = userModel.copyWith(lastLogin: DateTime.now());
      await _firestore.collection('users').doc(user.uid).update({
        'lastLogin': DateTime.now().toIso8601String(),
      });

      print('✅ 로그인 성공: $email');
      return updatedUser;
    } on FirebaseAuthException catch (e) {
      print('❌ 로그인 실패: ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ 로그인 오류: $e');
      rethrow;
    }
  }

  // Google 로그인
  Future<UserModel?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) return null;

      // Firestore에서 사용자 정보 확인
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final existing = doc.exists ? doc.data()! : null;

      final userModel = UserModel(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName,
        photoURL: user.photoURL,
        nickname: existing?['nickname'],
        lastNicknameChange: existing?['lastNicknameChange'] != null
            ? DateTime.parse(existing!['lastNicknameChange'])
            : null,
        createdAt: existing?['createdAt'] != null
            ? DateTime.parse(existing!['createdAt'])
            : DateTime.now(),
        lastLogin: DateTime.now(),
        level: existing?['level'],
        purpose: existing?['purpose'],
        favoriteStrokes: List<String>.from(existing?['favoriteStrokes'] ?? []),
        goals: List<String>.from(existing?['goals'] ?? []),
        personalRecords: Map<String, dynamic>.from(existing?['personalRecords'] ?? {}),
        onboardingCompleted: existing?['onboardingCompleted'] ?? false,
        onboardingCompletedAt: existing?['onboardingCompletedAt'] != null
            ? DateTime.parse(existing!['onboardingCompletedAt'])
            : null,
      );

      await _firestore.collection('users').doc(user.uid).set(userModel.toMap(), SetOptions(merge: true));

      print('✅ Google 로그인 성공: ${user.email}');
      return userModel;
    } on FirebaseAuthException catch (e) {
      print('❌ Google 로그인 인증 오류: ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ Google 로그인 오류: $e');
      rethrow;
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
      print('✅ 로그아웃 성공');
    } catch (e) {
      print('❌ 로그아웃 오류: $e');
      rethrow;
    }
  }

  // 인증 메일 재발송
  Future<void> resendVerificationEmail({required String email, required String password}) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      await credential.user?.sendEmailVerification();
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw '인증 메일 재발송에 실패했습니다.';
    }
  }

  // 계정 탈퇴
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw '로그인된 사용자가 없습니다.';
      }

      // Firestore에서 사용자 데이터 삭제 (실패해도 계속 진행)
      try {
        await _firestore.collection('users').doc(user.uid).delete();
        print('✅ Firestore 사용자 데이터 삭제 완료');
      } catch (firestoreError) {
        print('⚠️ Firestore 삭제 실패 (계속 진행): $firestoreError');
        // Firestore 삭제 실패해도 계정은 삭제 진행
      }

      // Firebase Auth 계정 삭제
      await user.delete();
      print('✅ 계정 탈퇴 성공');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        print('❌ 재인증 필요: 보안을 위해 다시 로그인해주세요.');
        throw '보안을 위해 다시 로그인 후 시도해주세요.';
      }
      print('❌ 계정 탈퇴 실패: ${e.message}');
      rethrow;
    } catch (e) {
      print('❌ 계정 탈퇴 오류: $e');
      rethrow;
    }
  }

  // 사용자 정보 가져오기
  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data()!);
    } catch (e) {
      print('❌ 사용자 정보 가져오기 실패: $e');
      return null;
    }
  }

  // 온보딩 완료 여부 확인
  Future<bool> checkOnboardingCompleted(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return false;
      return doc.data()?['onboardingCompleted'] ?? false;
    } catch (e) {
      print('❌ 온보딩 상태 확인 실패: $e');
      return false;
    }
  }

  // 사용자 정보 업데이트
  Future<void> updateUserData(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.uid).update(user.toMap());
      print('✅ 사용자 정보 업데이트 성공');
    } catch (e) {
      print('❌ 사용자 정보 업데이트 실패: $e');
      rethrow;
    }
  }

  // 닉네임 변경 (4주 제한)
  Future<void> updateNickname(String newNickname) async {
    final user = currentUser;
    if (user == null) throw '로그인이 필요합니다.';

    try {
      // 현재 사용자 정보 가져오기
      final userData = await getUserData(user.uid);
      if (userData == null) throw '사용자 정보를 찾을 수 없습니다.';

      // 4주 제한 체크
      if (!userData.canChangeNickname) {
        final daysLeft = userData.daysUntilNicknameChange;
        throw '닉네임은 4주에 한 번만 변경할 수 있습니다.\n${daysLeft}일 후에 다시 시도해주세요.';
      }

      // 닉네임 업데이트
      await _firestore.collection('users').doc(user.uid).update({
        'nickname': newNickname,
        'lastNicknameChange': DateTime.now().toIso8601String(),
      });

      print('✅ 닉네임 변경 성공: $newNickname');
    } catch (e) {
      print('❌ 닉네임 변경 실패: $e');
      rethrow;
    }
  }

  // 이름(displayName) 변경
  Future<void> updateDisplayName(String newName) async {
    final user = currentUser;
    if (user == null) throw '로그인이 필요합니다.';

    try {
      // Firebase Auth 프로필 업데이트
      await user.updateDisplayName(newName);
      
      // Firestore 업데이트
      await _firestore.collection('users').doc(user.uid).update({
        'displayName': newName,
      });

      print('✅ 이름 변경 성공: $newName');
    } catch (e) {
      print('❌ 이름 변경 실패: $e');
      rethrow;
    }
  }

  // Firebase Auth 예외 처리
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return '비밀번호가 너무 약합니다.';
      case 'email-already-in-use':
        return '이미 사용 중인 이메일입니다.';
      case 'invalid-email':
        return '유효하지 않은 이메일 주소입니다.';
      case 'user-not-found':
        return '사용자를 찾을 수 없습니다.';
      case 'wrong-password':
        return '잘못된 비밀번호입니다.';
      case 'user-disabled':
        return '비활성화된 계정입니다.';
      case 'too-many-requests':
        return '너무 많은 시도가 있었습니다. 나중에 다시 시도해주세요.';
      default:
        return e.message ?? '인증 오류가 발생했습니다.';
    }
  }
}
