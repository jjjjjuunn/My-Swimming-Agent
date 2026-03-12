import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/program_response.dart';
import '../models/saved_program.dart';
import '../services/agent_service.dart';
import '../theme/app_theme.dart';
import 'saved_program_detail_screen.dart';

class ChatScreen extends StatefulWidget {
  /// 운동 완료 후 자동 전송할 첫 메시지. null이면 기본 인사로 시작.
  final String? initialMessage;

  const ChatScreen({super.key, this.initialMessage});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _agentService = AgentService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  /// 화면에 보이는 메시지 목록 (user + assistant)
  final List<_ChatDisplayMessage> _messages = [];

  /// 현재 스트리밍 중인 assistant 응답 (토큰 단위 누적)
  String _streamingText = '';

  /// 스트리밍 중 수신된 프로그램 데이터
  Map<String, dynamic>? _pendingProgramData;

  /// 현재 실행 중인 Tool 표시
  String? _activeToolLabel;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialMessage != null) {
        _sendInitialMessage(widget.initialMessage!);
      } else {
        _sendGreeting();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── 운동 완료 후 자동 첫 메시지 ──
  Future<void> _sendInitialMessage(String message) async {
    setState(() {
      _messages.add(_ChatDisplayMessage(role: 'user', content: message));
      _isLoading = true;
      _streamingText = '';
      _activeToolLabel = null;
      _pendingProgramData = null;
    });
    _scrollToBottom();
    _agentService.addUserMessage(message);
    final userId = FirebaseAuth.instance.currentUser?.uid;
    await _processStream(message: message, userId: userId);
  }

  // ── 자동 인사 ──
  Future<void> _sendGreeting() async {
    setState(() {
      _isLoading = true;
      _streamingText = '';
      _activeToolLabel = null;
    });

    final userId = FirebaseAuth.instance.currentUser?.uid;
    await _processStream(
      message: '채팅을 시작합니다. 사용자에게 인사하고 오늘 컨디션을 물어봐주세요.',
      userId: userId,
    );
  }

  // ── 메시지 전송 ──
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    _controller.clear();

    setState(() {
      _messages.add(_ChatDisplayMessage(role: 'user', content: text));
      _isLoading = true;
      _streamingText = '';
      _activeToolLabel = null;
      _pendingProgramData = null;
    });
    _scrollToBottom();

    _agentService.addUserMessage(text);

    final userId = FirebaseAuth.instance.currentUser?.uid;
    await _processStream(message: text, userId: userId);
  }

  /// JSON 패턴 감지
  static final _jsonPattern = RegExp(
    r'[{}\[\]]|"(level|warmup|main_set|cooldown|description|distance|repeat|rest_seconds|cycle_time|total_distance|estimated_minutes|beginner|intermediate|advanced|level_label|notes)"',
  );

  /// 버퍼에서 JSON 부분 제거
  String _stripJson(String text) {
    // JSON 블록이 시작되는 위치 찾기
    final braceIdx = text.indexOf('{');
    if (braceIdx == -1) return text;
    // { 이전 텍스트가 있고, 그 뒤가 JSON 패턴이면 잘라냄
    final after = text.substring(braceIdx);
    if (_jsonPattern.hasMatch(after)) {
      return text.substring(0, braceIdx).trim();
    }
    return text;
  }

  /// 실제 SSE 스트림 처리
  Future<void> _processStream({
    required String message,
    String? userId,
  }) async {
    final buffer = StringBuffer();
    _pendingProgramData = null;
    bool _programToolActive = false; // generate_program 진행 중 토큰 무시

    // 120초 타임아웃 — 서버가 응답하지 않는 경우 로딩 상태를 해제
    Timer? _timeoutTimer;
    _timeoutTimer = Timer(const Duration(seconds: 120), () {
      if (_isLoading && mounted) {
        setState(() {
          _messages.add(_ChatDisplayMessage(
            role: 'assistant',
            content: '⚠️ 응답 시간이 초과됐어요. 다시 시도해주세요.',
          ));
          _streamingText = '';
          _isLoading = false;
          _activeToolLabel = null;
          _pendingProgramData = null;
        });
        _scrollToBottom();
      }
    });

    try {
    await for (final event
        in _agentService.chatStream(message: message, userId: userId)) {
      switch (event.type) {
        case AgentEventType.token:
          // generate_program 진행 중이면 토큰 무시
          if (_programToolActive) break;
          if (event.content != null) {
            // 개별 토큰에 JSON 패턴이 있으면 무시
            final c = event.content!;
            if (c.trim().isNotEmpty && _jsonPattern.hasMatch(c)) break;
            buffer.write(c);
            setState(() {
              _streamingText = buffer.toString();
              _activeToolLabel = null;
            });
            _scrollToBottom();
          }

        case AgentEventType.toolStart:
          if (event.toolName == 'generate_program') {
            _programToolActive = true;
          }
          setState(() {
            _activeToolLabel =
                AgentService.toolDisplayName(event.toolName ?? '');
          });

        case AgentEventType.toolEnd:
          // generate_program 결과 캡처
          if (event.programData != null) {
            _pendingProgramData = event.programData;
          }
          // generate_program 완료 후에도 토큰 차단 유지
          setState(() => _activeToolLabel = null);

        case AgentEventType.done:
          _timeoutTimer?.cancel();
          final rawText = buffer.toString();
          final fullText = _stripJson(rawText);
          if (fullText.isNotEmpty || _pendingProgramData != null) {
            if (fullText.isNotEmpty) {
              _agentService.addAssistantMessage(fullText);
            }
            setState(() {
              _messages.add(_ChatDisplayMessage(
                role: 'assistant',
                content: fullText.isNotEmpty
                    ? fullText
                    : (_pendingProgramData != null
                        ? '프로그램을 생성했어요! 아래에서 레벨별로 확인해보세요 👇'
                        : ''),
                programData: _pendingProgramData,
              ));
              _streamingText = '';
              _pendingProgramData = null;
            });
          }
          setState(() {
            _isLoading = false;
            _activeToolLabel = null;
          });
          _scrollToBottom();

        case AgentEventType.error:
          _timeoutTimer?.cancel();
          setState(() {
            _messages.add(_ChatDisplayMessage(
              role: 'assistant',
              content: '⚠️ ${event.content ?? "오류가 발생했습니다."}',
            ));
            _streamingText = '';
            _isLoading = false;
            _activeToolLabel = null;
            _pendingProgramData = null;
          });
          _scrollToBottom();
      }
    }
    } finally {
      _timeoutTimer?.cancel();
    }

    // stream 이 done 없이 끝난 경우
    if (_isLoading) {
      final leftover = buffer.toString();
      if (leftover.isNotEmpty) {
        _agentService.addAssistantMessage(leftover);
        setState(() {
          _messages.add(_ChatDisplayMessage(
            role: 'assistant',
            content: leftover,
            programData: _pendingProgramData,
          ));
        });
      }
      setState(() {
        _streamingText = '';
        _isLoading = false;
        _activeToolLabel = null;
        _pendingProgramData = null;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── UI ──
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildMessageList()),
              if (_activeToolLabel != null) _buildToolIndicator(),
              _buildInput(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.pool, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Swimming Coach',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  _isLoading ? '입력 중...' : '온라인',
                  style: TextStyle(
                    color: _isLoading
                        ? AppTheme.primaryBlue
                        : Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    final hasStreamingText = _streamingText.isNotEmpty;

    if (_messages.isEmpty && !hasStreamingText) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_outline,
                  color: Colors.white.withValues(alpha: 0.2), size: 48),
              const SizedBox(height: 16),
              Text(
                '오늘 컨디션이나 하고 싶은 운동을\n자유롭게 말해보세요 🏊',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length + (hasStreamingText ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < _messages.length) {
          return _buildBubble(_messages[index]);
        }
        // 스트리밍 중인 메시지
        return _buildBubble(
          _ChatDisplayMessage(role: 'assistant', content: _streamingText),
          isStreaming: true,
        );
      },
    );
  }

  Widget _buildBubble(_ChatDisplayMessage msg, {bool isStreaming = false}) {
    final isUser = msg.role == 'user';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? AppTheme.primaryBlue.withValues(alpha: 0.25)
              : AppTheme.cardColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: Border.all(
            color: isUser
                ? AppTheme.primaryBlue.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    msg.content,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
                if (isStreaming) ...[
                  const SizedBox(width: 4),
                  _buildCursor(),
                ],
              ],
            ),
            // 프로그램 카드
            if (msg.programData != null && !isStreaming)
              _buildProgramCard(msg.programData!),
          ],
        ),
      ),
    );
  }

  Widget _buildCursor() {
    return SizedBox(
      width: 2,
      height: 16,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.primaryBlue,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }

  Widget _buildToolIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primaryBlue.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _activeToolLabel ?? '',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: '메시지를 입력하세요...',
                hintStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient:
                    _controller.text.trim().isNotEmpty || !_isLoading
                        ? AppTheme.primaryGradient
                        : null,
                color: _controller.text.trim().isEmpty && _isLoading
                    ? Colors.white.withValues(alpha: 0.1)
                    : null,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ── 프로그램 카드 ──
  Widget _buildProgramCard(Map<String, dynamic> programData) {
    ProgramResponse? response;
    try {
      response = ProgramResponse.fromJson(programData);
    } catch (_) {
      return const SizedBox.shrink();
    }

    const goalLabels = {
      'speed': '스프린트',
      'endurance': '장거리',
      'technique': '드릴',
      'overall': '밸런스',
    };

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A2744), Color(0xFF0A2A3F)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryBlue.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.fitness_center,
                    color: AppTheme.primaryBlue, size: 18),
                const SizedBox(width: 8),
                Text(
                  '${goalLabels[response.trainingGoal] ?? response.trainingGoal} 프로그램',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildLevelButton(
              label: '초급',
              distance: '${response.beginner.totalDistance}m',
              minutes: '${response.beginner.estimatedMinutes}분',
              onTap: () => _openProgramLevel(response!, 'beginner'),
            ),
            const SizedBox(height: 6),
            _buildLevelButton(
              label: '중급',
              distance: '${response.intermediate.totalDistance}m',
              minutes: '${response.intermediate.estimatedMinutes}분',
              onTap: () => _openProgramLevel(response!, 'intermediate'),
            ),
            const SizedBox(height: 6),
            _buildLevelButton(
              label: '고급',
              distance: '${response.advanced.totalDistance}m',
              minutes: '${response.advanced.estimatedMinutes}분',
              onTap: () => _openProgramLevel(response!, 'advanced'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelButton({
    required String label,
    required String distance,
    required String minutes,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            Text(
              '$distance · $minutes',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right,
                color: Colors.white.withValues(alpha: 0.4), size: 18),
          ],
        ),
      ),
    );
  }

  void _openProgramLevel(ProgramResponse response, String level) {
    final ProgramLevel programLevel;
    final String levelLabel;

    switch (level) {
      case 'beginner':
        programLevel = response.beginner;
        levelLabel = '초급';
      case 'intermediate':
        programLevel = response.intermediate;
        levelLabel = '중급';
      default:
        programLevel = response.advanced;
        levelLabel = '고급';
    }

    final savedProgram = SavedProgram(
      id: 'agent_${DateTime.now().millisecondsSinceEpoch}',
      title: 'AI 코치 추천 · $levelLabel',
      program: programLevel,
      levelLabel: levelLabel,
      savedAt: DateTime.now(),
      trainingGoal: response.trainingGoal,
      strokes: response.strokes,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SavedProgramDetailScreen(
          savedProgram: savedProgram,
          isFromChat: true,
        ),
      ),
    );
  }
}

/// 채팅 화면용 메시지 (프로그램 데이터 포함 가능)
class _ChatDisplayMessage {
  final String role;
  final String content;
  final Map<String, dynamic>? programData;

  _ChatDisplayMessage({
    required this.role,
    required this.content,
    this.programData,
  });
}
