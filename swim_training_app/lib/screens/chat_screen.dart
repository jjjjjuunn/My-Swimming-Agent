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
  // 싱글턴 서비스 — 앱 생명주기 동안 대화 이력 유지
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
  bool _timedOut = false; // 타임아웃 이후 스트림 이벤트 무시용

  /// 장비 Quick Reply 표시 여부
  bool _showEquipmentChips = false;
  final List<String> _selectedEquipment = [];

  static const _equipmentOptions = [
    {'key': 'all', 'label': '전부 사용 가능'},
    {'key': 'fins', 'label': '핀(오리발)'},
    {'key': 'paddles', 'label': '패들'},
    {'key': 'kickboard', 'label': '킥보드'},
    {'key': 'pull_buoy', 'label': '풀부이'},
    {'key': 'none', 'label': '장비 없음'},
  ];

  @override
  void initState() {
    super.initState();
    // 싱글턴에 저장된 이전 메시지 복원 후 인사 또는 이력 표시
    _restoreHistory();
    // hasGreeted=true 이지만 history가 없으면 이전 인사가 실패한 것 → 재시도
    if (_agentService.hasGreeted && _messages.isEmpty) {
      _agentService.hasGreeted = false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialMessage != null) {
        _sendInitialMessage(widget.initialMessage!);
      } else if (!_agentService.hasGreeted) {
        _sendGreeting();
      } else if (_messages.isNotEmpty) {
        _scrollToBottom();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── 싱글턴 이력에서 UI 메시지 복원 (initState에서만 호출) ──
  void _restoreHistory() {
    for (final msg in _agentService.history) {
      _messages.add(_ChatDisplayMessage(
        role: msg.role,
        content: msg.content,
      ));
    }
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
    _agentService.hasGreeted = true;
    setState(() {
      _isLoading = true;
      _streamingText = '';
      _activeToolLabel = null;
    });
    _scrollToBottom(); // 타이핑 버블 즉시 표시

    final userId = FirebaseAuth.instance.currentUser?.uid;
    await _processStream(
      message: '사용자에게 인사하고 오늘 컨디션을 물어봐주세요.',
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

    // 180초 타임아웃 — 서버가 응답하지 않는 경우 로딩 상태를 해제
    Timer? _timeoutTimer;
    _timedOut = false;
    _timeoutTimer = Timer(const Duration(seconds: 180), () {
      if (_isLoading && mounted) {
        _timedOut = true; // await for 루프에서 다음 이벤트 수신 시 break
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
      if (_timedOut) break; // 타임아웃 후 도착한 이벤트 무시 → 중복 메시지 방지
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
          _scrollToBottom(); // 타이핑 버블의 툴 라벨이 보이도록 스크롤

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
              if (_detectEquipmentQuestion(fullText)) {
                _showEquipmentChips = true;
                _selectedEquipment.clear();
              }
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

  bool _detectEquipmentQuestion(String text) {
    const keywords = ['장비', '도구', '킥보드', '풀부이', '핀', '패들', '오리발', '사용 가능', '사용할 수'];
    final lower = text.toLowerCase();
    final hasKeyword = keywords.any((k) => lower.contains(k));
    final isQuestion = lower.contains('?') || lower.contains('있') || lower.contains('어요') || lower.contains('나요') || lower.contains('할 수');
    return hasKeyword && isQuestion;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
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
          bottom: false,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildMessageList()),
              _buildEquipmentChips(),
              _buildInput(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final canGoBack = ModalRoute.of(context)?.canPop ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          if (canGoBack)
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 36,
                height: 36,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.arrow_back_ios_new,
                    color: Colors.white.withValues(alpha: 0.6), size: 16),
              ),
            ),
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
                const Text(
                  '온라인',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // 대화 초기화 버튼
          GestureDetector(
            onTap: () {
              setState(() {
                _messages.clear();
                _streamingText = '';
              });
              _agentService.clearHistory();
              _sendGreeting();
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.refresh_rounded,
                  color: Colors.white.withValues(alpha: 0.6), size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    final hasStreamingText = _streamingText.isNotEmpty;
    final showToolBubble = _isLoading && _activeToolLabel != null;
    final showTypingBubble =
        _isLoading && !hasStreamingText && _activeToolLabel == null;
    final showTrailingLoader = _isLoading && hasStreamingText;

    if (_messages.isEmpty &&
        !hasStreamingText &&
        !showToolBubble &&
        !showTypingBubble) {
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

    // reverse: true 에서 bottom에 표시할 trailing 아이템 목록 (bottom → top 순서)
    final trailing = <Widget>[];
    if (showTypingBubble) trailing.add(_TypingBubble(toolLabel: _activeToolLabel));
    if (showToolBubble && !hasStreamingText) trailing.add(_TypingBubble(toolLabel: _activeToolLabel));
    if (showTrailingLoader) trailing.add(_TypingBubble(toolLabel: _activeToolLabel));
    if (hasStreamingText) {
      trailing.add(_buildBubble(
        _ChatDisplayMessage(role: 'assistant', content: _streamingText),
        isStreaming: true,
      ));
    }

    final totalCount = _messages.length + trailing.length;

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        // reverse: true → index 0 = 화면 맨 아래
        // trailing 아이템이 맨 아래, 그 위로 메시지 (최신→과거)
        if (index < trailing.length) {
          return trailing[index];
        }
        final msgIndex = _messages.length - 1 - (index - trailing.length);
        return _buildBubble(_messages[msgIndex]);
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

  void _onEquipmentChipTap(String key) {
    setState(() {
      if (key == 'all') {
        _selectedEquipment.clear();
        _selectedEquipment.addAll(['fins', 'paddles', 'kickboard', 'pull_buoy']);
        _showEquipmentChips = false;
        _sendEquipmentSelection();
      } else if (key == 'none') {
        _selectedEquipment.clear();
        _showEquipmentChips = false;
        _sendEquipmentSelection();
      } else {
        if (_selectedEquipment.contains(key)) {
          _selectedEquipment.remove(key);
        } else {
          _selectedEquipment.add(key);
        }
      }
    });
  }

  void _sendEquipmentSelection() {
    final labels = {
      'fins': '핀(오리발)', 'paddles': '패들',
      'kickboard': '킥보드', 'pull_buoy': '풀부이',
    };
    final text = _selectedEquipment.isEmpty
        ? '장비 없이 맨몸으로 할게요'
        : '오늘 사용할 장비: ${_selectedEquipment.map((k) => labels[k] ?? k).join(', ')}';

    _controller.text = text;
    _sendMessage();
  }

  void _confirmEquipmentSelection() {
    setState(() => _showEquipmentChips = false);
    _sendEquipmentSelection();
  }

  Widget _buildEquipmentChips() {
    if (!_showEquipmentChips) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '오늘 사용할 장비를 선택하세요',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _equipmentOptions.map((opt) {
              final key = opt['key']!;
              final label = opt['label']!;
              final isAllOrNone = key == 'all' || key == 'none';
              final isSelected = !isAllOrNone && _selectedEquipment.contains(key);

              return GestureDetector(
                onTap: () => _onEquipmentChipTap(key),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isSelected ? AppTheme.primaryGradient : null,
                    color: isSelected ? null : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: isAllOrNone
                        ? Border.all(color: Colors.white24)
                        : null,
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_selectedEquipment.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D2FF),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _confirmEquipmentSelection,
                child: Text(
                  '선택 완료 (${_selectedEquipment.length}개)',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
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

/// Coach가 응답 생성 중일 때 보여주는 타이핑 인디케이터 말풍선
/// - toolLabel == null  → 점 3개 애니메이션 (기본 상태)
/// - toolLabel != null  → 스피너 + 툴 진행 라벨 (e.g. '프로그램 생성 중...')
class _TypingBubble extends StatefulWidget {
  final String? toolLabel;
  const _TypingBubble({this.toolLabel});

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  // 삼각파(triangle wave) — 각 점에 1/3 주기 오프셋 적용
  double _dotOpacity(double t, int i) {
    final v = (t * 3.0 - i) % 1.0;
    return v < 0.5 ? v * 2.0 : (1.0 - v) * 2.0;
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: widget.toolLabel != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.toolLabel!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              )
            : AnimatedBuilder(
                animation: _anim,
                builder: (_, __) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final opacity = _dotOpacity(_anim.value, i);
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white
                            .withValues(alpha: 0.25 + opacity * 0.75),
                      ),
                    );
                  }),
                ),
              ),
      ),
    );
  }
}
