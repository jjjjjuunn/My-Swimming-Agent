import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Agent SSE 이벤트 타입
enum AgentEventType { token, toolStart, toolEnd, done, error }

class AgentEvent {
  final AgentEventType type;
  final String? content;
  final String? toolName;
  final Map<String, dynamic>? programData;

  const AgentEvent({
    required this.type,
    this.content,
    this.toolName,
    this.programData,
  });
}

class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class AgentService {
  // 싱글턴 — 앱이 살아있는 동안 대화 이력 유지
  static final AgentService _instance = AgentService._internal();
  factory AgentService() => _instance;
  AgentService._internal();

  static String get _host => Platform.isAndroid ? '10.0.2.2' : 'localhost';
  static String get _baseUrl => 'http://$_host:8000/api/v1';

  final List<ChatMessage> _history = [];
  List<ChatMessage> get history => List.unmodifiable(_history);

  /// 이미 인사를 했는지 여부 — 탭 재진입 시 중복 인사 방지
  bool hasGreeted = false;

  void addUserMessage(String content) {
    _history.add(ChatMessage(role: 'user', content: content));
  }

  void addAssistantMessage(String content) {
    _history.add(ChatMessage(role: 'assistant', content: content));
  }

  void clearHistory() {
    _history.clear();
    hasGreeted = false;
  }

  /// SSE 스트리밍으로 Agent와 대화
  Stream<AgentEvent> chatStream({
    required String message,
    String? userId,
  }) async* {
    final url = Uri.parse('$_baseUrl/agent/chat/stream');

    final body = jsonEncode({
      'message': message,
      if (userId != null) 'user_id': userId,
      'chat_history':
          _history.map((m) => m.toJson()).toList(),
    });

    final request = http.Request('POST', url)
      ..headers['Content-Type'] = 'application/json'
      ..body = body;

    final client = http.Client();
    try {
      final response = await client.send(request);

      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString();
        yield AgentEvent(
          type: AgentEventType.error,
          content: '서버 오류 (${response.statusCode}): $errorBody',
        );
        return;
      }

      await for (final chunk
          in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (!chunk.startsWith('data: ')) continue;
        final jsonStr = chunk.substring(6);
        if (jsonStr.isEmpty) continue;

        try {
          final data = jsonDecode(jsonStr) as Map<String, dynamic>;
          final type = data['type'] as String?;

          switch (type) {
            case 'token':
              yield AgentEvent(
                type: AgentEventType.token,
                content: data['content'] as String?,
              );
            case 'tool_start':
              yield AgentEvent(
                type: AgentEventType.toolStart,
                toolName: data['tool'] as String?,
              );
            case 'tool_end':
              yield AgentEvent(
                type: AgentEventType.toolEnd,
                toolName: data['tool'] as String?,
                programData: data['program_data'] as Map<String, dynamic>?,
              );
            case 'done':
              yield AgentEvent(type: AgentEventType.done);
            case 'error':
              yield AgentEvent(
                type: AgentEventType.error,
                content: data['content'] as String?,
              );
          }
        } catch (_) {
          // malformed JSON — skip
        }
      }
    } catch (e) {
      yield AgentEvent(
        type: AgentEventType.error,
        content: '연결 오류: $e',
      );
    } finally {
      client.close();
    }
  }

  /// 도구 이름 → 사용자 표시 라벨
  static String toolDisplayName(String toolName) {
    const labels = {
      'get_user_profile': '프로필 확인 중...',
      'get_workout_history': '운동 기록 분석 중...',
      'generate_program': '프로그램 생성 중...',
      'analyze_feedback': '피드백 분석 중...',
      'get_search_history': '검색 히스토리 확인 중...',
      'get_weakness_analysis': '약점 분석 중...',
      'save_user_equipment': '장비 저장 중...',
      'get_user_equipment': '장비 확인 중...',
      'save_condition': '컨디션 저장 중...',
      'get_today_condition': '컨디션 확인 중...',
      'save_workout_memo': '메모 저장 중...',
    };
    return labels[toolName] ?? '$toolName 실행 중...';
  }
}
