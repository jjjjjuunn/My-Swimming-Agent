import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import '../models/workout_log.dart';
import '../models/program_response.dart';
import '../models/saved_program.dart';
import '../services/program_api_service.dart';
import '../services/local_storage_service.dart';

class AiFeedbackScreen extends StatefulWidget {
  final List<WorkoutLog> recentLogs;
  final VoidCallback? onNavigateToMyProgram;

  const AiFeedbackScreen({
    super.key,
    required this.recentLogs,
    this.onNavigateToMyProgram,
  });

  @override
  State<AiFeedbackScreen> createState() => _AiFeedbackScreenState();
}

class _AiFeedbackScreenState extends State<AiFeedbackScreen> {
  final _apiService = ProgramApiService();
  final _messageController = TextEditingController();
  bool _isLoading = false;
  bool _isSavingProgram = false;
  bool _showInput = true;
  String? _feedback;
  String? _error;
  String? _purpose;

  @override
  void initState() {
    super.initState();
    _loadPurpose();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadPurpose() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (mounted) {
      setState(() => _purpose = doc.data()?['purpose'] as String?);
    }
  }

  void _shareFeedback() {
    if (_feedback == null) return;
    Share.share(_feedback!, subject: 'AI 수영 트레이닝 피드백');
  }

  Future<void> _saveFeedbackAsProgram() async {
    if (_feedback == null) return;
    setState(() => _isSavingProgram = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final programData = await _apiService.feedbackToProgram(
        feedbackText: _feedback!,
        userId: user?.uid,
      );

      final level = ProgramLevel.fromJson(programData);
      final now = DateTime.now();
      final program = SavedProgram(
        id: 'ai_${now.millisecondsSinceEpoch}',
        title: 'AI 추천 훈련',
        program: level,
        levelLabel: 'AI 처방',
        savedAt: now,
        trainingGoal: 'overall',
        strokes: const ['freestyle'],
      );

      await LocalStorageService().saveProgram(program);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'My Program에 저장됐어요!',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0F5132),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            action: SnackBarAction(
              label: 'My Program 이동 →',
              textColor: const Color(0xFF6EE7A0),
              onPressed: () {
                Navigator.pop(context);
                widget.onNavigateToMyProgram?.call();
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 실패: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingProgram = false);
    }
  }

  Future<void> _loadFeedback() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _error = null;
      _showInput = false;
    });

    try {
      // 운동 기록을 Map으로 변환
      final logsData = widget.recentLogs.map((log) => {
        ...log.toJson(),
        'duration_minutes': log.durationMinutes,
        'completion_rate': log.completionRate,
      }).toList();

      final userMessage = _messageController.text.trim();

      final feedback = await _apiService.getAiFeedback(
        workoutLogs: logsData,
        purpose: _purpose,
        userMessage: userMessage.isNotEmpty ? userMessage : null,
        userId: FirebaseAuth.instance.currentUser?.uid,
      );

      if (mounted) {
        setState(() {
          _feedback = feedback;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.auto_awesome, color: AppTheme.primaryBlue, size: 24),
          const SizedBox(width: 8),
          const Text(
            'AI Feedback',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppTheme.primaryBlue),
            const SizedBox(height: 20),
            Text(
              '운동 기록을 분석하고 있어요...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    // 초기 입력 화면
    if (_showInput) {
      return _buildInputView();
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red.withValues(alpha: 0.7), size: 48),
              const SizedBox(height: 16),
              Text(
                '피드백 생성에 실패했어요',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _loadFeedback,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('다시 시도', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 분석 운동 요약
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Icon(Icons.analytics, color: AppTheme.primaryBlue, size: 20),
                const SizedBox(width: 10),
                Text(
                  '최근 ${widget.recentLogs.length}회 운동 분석 결과',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // AI 피드백 내용
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A2744), Color(0xFF0A2A3F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
            ),
            child: SelectableText(
              _feedback ?? '',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 15,
                height: 1.7,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 액션 버튼 영역
          Row(
            children: [
              // 다시 물어보기
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _showInput = true;
                    _feedback = null;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit, color: AppTheme.primaryBlue, size: 16),
                        const SizedBox(width: 6),
                        Text('다시 물어보기', style: TextStyle(color: AppTheme.primaryBlue, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 공유
              GestureDetector(
                onTap: _shareFeedback,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Icon(Icons.share, color: Colors.white.withValues(alpha: 0.7), size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 프로그램으로 저장
          GestureDetector(
            onTap: _isSavingProgram ? null : _saveFeedbackAsProgram,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: _isSavingProgram
                    ? const LinearGradient(colors: [Color(0xFF2A2A2A), Color(0xFF2A2A2A)])
                    : const LinearGradient(
                        colors: [Color(0xFF0F5132), Color(0xFF198754)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _isSavingProgram
                  ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('이 훈련을 My Program에 저장', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildInputView() {
    final hasLogs = widget.recentLogs.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 분석할 기록 안내
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Icon(Icons.fitness_center, color: AppTheme.primaryBlue, size: 20),
                const SizedBox(width: 10),
                Text(
                  hasLogs
                      ? '최근 ${widget.recentLogs.length}회 운동 기록을 분석합니다'
                      : '아직 운동 기록이 없어요',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 메시지 입력
          Text(
            '코치에게 물어보기',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '어떤 부분이 고민인지 알려주세요. 더 정확한 피드백을 드릴 수 있어요.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: TextField(
              controller: _messageController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: '예) 돌핀킥이 약한 것 같아요. 어떻게 보완하면 좋을까요?\n예) 최근에 피로가 많이 쌓이는 것 같아요.',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 13,
                  height: 1.5,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 분석 시작 버튼
          GestureDetector(
            onTap: hasLogs ? _loadFeedback : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: hasLogs
                    ? AppTheme.primaryGradient
                    : const LinearGradient(colors: [Color(0xFF2A2A2A), Color(0xFF2A2A2A)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    hasLogs ? 'AI 피드백 받기' : '운동 기록이 없어요',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
