import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/program_request.dart';
import '../models/program_response.dart';

class ProgramApiService {
  // Android 에뮬레이터에서 Mac localhost 접근: 10.0.2.2
  // iOS 시뮬레이터 / macOS: localhost
  static String get _host => Platform.isAndroid ? '10.0.2.2' : 'localhost';
  static String get baseUrl => 'http://$_host:8000/api/v1';
  
  /// AI 수영 프로그램 생성
  /// 
  /// [request] 프로그램 생성 요청 정보
  /// 
  /// Returns: 생성된 프로그램 응답
  /// 
  /// Throws: [Exception] API 호출 실패 시
  Future<ProgramResponse> generateProgram(ProgramRequest request) async {
    final url = Uri.parse('$baseUrl/generate-program');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
        return ProgramResponse.fromJson(jsonResponse);
      } else {
        final errorBody = utf8.decode(response.bodyBytes);
        throw Exception('프로그램 생성 실패: ${response.statusCode} - $errorBody');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('네트워크 오류: $e');
    }
  }

  /// LLM API 연결 테스트
  /// 
  /// Returns: 테스트 성공 여부와 응답 메시지
  /// 
  /// Throws: [Exception] API 호출 실패 시
  Future<Map<String, dynamic>> testLlmConnection() async {
    final url = Uri.parse('$baseUrl/test-llm');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('테스트 실패: ${response.statusCode}');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('네트워크 오류: $e');
    }
  }

  /// Mock 데이터로 프로그램 테스트 (API 할당량 절약)
  /// 
  /// [request] 프로그램 생성 요청 정보
  /// 
  /// Returns: Mock 프로그램 응답
  /// 
  /// Throws: [Exception] API 호출 실패 시
  Future<ProgramResponse> testProgram(ProgramRequest request) async {
    final url = Uri.parse('$baseUrl/test-program');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
        return ProgramResponse.fromJson(jsonResponse);
      } else {
        final errorBody = utf8.decode(response.bodyBytes);
        throw Exception('테스트 실패: ${response.statusCode} - $errorBody');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('네트워크 오류: $e');
    }
  }

  /// API 헬스 체크
  /// 
  /// Returns: 서버 상태 정보
  /// 
  /// Throws: [Exception] API 호출 실패 시
  Future<Map<String, dynamic>> healthCheck() async {
    final url = Uri.parse('http://$_host:8000/health');
    
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('Health check 실패: ${response.statusCode}');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('서버 연결 실패: $e');
    }
  }

  /// AI 운동 피드백 생성
  Future<String> getAiFeedback({
    required List<Map<String, dynamic>> workoutLogs,
    String? purpose,
    String? userMessage,
    String? userId,
  }) async {
    final url = Uri.parse('$baseUrl/ai-feedback');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'workout_logs': workoutLogs,
          if (purpose != null) 'purpose': purpose,
          if (userMessage != null) 'user_message': userMessage,
          if (userId != null) 'user_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonResponse['feedback'] as String;
      } else {
        final errorBody = utf8.decode(response.bodyBytes);
        throw Exception('피드백 생성 실패: ${response.statusCode} - $errorBody');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('네트워크 오류: $e');
    }
  }

  Future<Map<String, dynamic>> feedbackToProgram({
    required String feedbackText,
    String? trainingGoal,
    List<String>? strokes,
  }) async {
    final url = Uri.parse('$baseUrl/feedback-to-program');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'feedback_text': feedbackText,
          if (trainingGoal != null) 'training_goal': trainingGoal,
          if (strokes != null) 'strokes': strokes,
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonResponse['program'] as Map<String, dynamic>;
      } else {
        final errorBody = utf8.decode(response.bodyBytes);
        throw Exception('프로그램 변환 실패: ${response.statusCode} - $errorBody');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('네트워크 오류: $e');
    }
  }
}
