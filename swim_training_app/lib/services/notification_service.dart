import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// 앱이 백그라운드에서 알림을 받았을 때의 콜백 — 반드시 톱레벨 함수여야 합니다.
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 백그라운드 알림 처리 — 기본 동작은 시스템 알림 표시
}

/// FCM Push 알림 관리 서비스
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static String get _host => Platform.isAndroid ? '10.0.2.2' : 'localhost';
  static String get _baseUrl => 'http://$_host:8000/api/v1';

/// FCM 초기화 + 토큰 등록
  Future<void> initialize({
    required Function(String action) onNotificationTap,
  }) async {
    // 권한 요청 (iOS)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    // FCM 토큰 가져오기 + 서버 등록
    final token = await _messaging.getToken();
    if (token != null) {
      await _registerToken(token);
    }

    // 토큰 갱신 시 자동 재등록
    _messaging.onTokenRefresh.listen(_registerToken);

    // 포그라운드 알림 수신
    FirebaseMessaging.onMessage.listen((message) {
      // 포그라운드에서는 시스템 알림이 표시되지 않으므로 직접 처리
      final action = message.data['action'] as String? ?? '';
      if (action.isNotEmpty) {
        onNotificationTap(action);
      }
    });

    // 알림 탭으로 앱 열었을 때 (백그라운드 → 포그라운드)
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final action = message.data['action'] as String? ?? '';
      if (action.isNotEmpty) {
        onNotificationTap(action);
      }
    });

    // 앱 종료 상태에서 알림 탭으로 열었을 때
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      final action = initialMessage.data['action'] as String? ?? '';
      if (action.isNotEmpty) {
        onNotificationTap(action);
      }
    }
  }

  /// FCM 토큰을 백엔드에 등록
  Future<void> _registerToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await http.post(
        Uri.parse('$_baseUrl/notifications/register-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': user.uid,
          'fcm_token': token,
        }),
      );
    } catch (e) {
      // 토큰 등록 실패 — 다음 기회에 재시도
    }
  }

  /// 알림 설정 저장
  Future<bool> savePreferences({
    required bool morningEnabled,
    required String morningTime,
    required bool postWorkoutEnabled,
    required bool weeklyReportEnabled,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/notifications/preferences'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': user.uid,
          'morning_enabled': morningEnabled,
          'morning_time': morningTime,
          'post_workout_enabled': postWorkoutEnabled,
          'weekly_report_enabled': weeklyReportEnabled,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// 알림 설정 조회
  Future<Map<String, dynamic>> getPreferences() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/notifications/preferences/${user.uid}'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['preferences'] as Map<String, dynamic>? ?? {};
      }
      return {};
    } catch (e) {
      return {};
    }
  }
}
