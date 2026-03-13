import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/saved_program.dart';
import '../models/workout_log.dart';
import '../services/local_storage_service.dart';
import '../services/workout_log_service.dart';
import 'saved_program_detail_screen.dart';
import 'workout_history_screen.dart';
import 'workout_history_detail_screen.dart';
import 'swim_stats_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onNavigateToProgram;
  final VoidCallback? onNavigateToMyProgram;
  final VoidCallback? onNavigateToCoach;

  const HomeScreen({
    super.key,
    this.onNavigateToProgram,
    this.onNavigateToMyProgram,
    this.onNavigateToCoach,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storageService = LocalStorageService();
  final _workoutLogService = WorkoutLogService();

  List<SavedProgram> _recentPrograms = [];
  List<WorkoutLog> _recentLogs = [];
  int _weeklyDistance = 0;
  int _weeklyCount = 0;
  bool _isLoading = true;
  bool _hasTodaySchedule = false;
  String? _todayScheduleTime;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final programs = await _storageService.getSavedPrograms();
    programs.sort((a, b) => b.savedAt.compareTo(a.savedAt));

    final logs = await _workoutLogService.getRecentLogs(limit: 3);
    final weeklyDist = await _workoutLogService.getWeeklyDistance();
    final weeklyCount = await _workoutLogService.getWeeklyWorkoutCount();

    // 오늘 수영 스케줄 확인
    bool hasTodaySchedule = false;
    String? todayTime;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users').doc(user.uid).get();
        if (doc.exists) {
          final schedule = doc.data()?['swim_schedule'] as Map<String, dynamic>?;
          if (schedule != null) {
            const dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
            final todayIdx = DateTime.now().weekday - 1;
            final todayKey = dayKeys[todayIdx];
            if (schedule.containsKey(todayKey)) {
              hasTodaySchedule = true;
              todayTime = schedule[todayKey] as String?;
            }
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _recentPrograms = programs.take(1).toList();
        _recentLogs = logs;
        _weeklyDistance = weeklyDist;
        _weeklyCount = weeklyCount;
        _hasTodaySchedule = hasTodaySchedule;
        _todayScheduleTime = todayTime;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildGreeting(),
                        const SizedBox(height: 16),
                        _buildCoachCard(),
                        const SizedBox(height: 24),
                        _buildStatsSummaryCard(),
                        const SizedBox(height: 28),
                        _buildMyWorkoutSection(),
                        const SizedBox(height: 28),
                        _buildWorkoutHistorySection(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  // ── 타이틀 ──
  Widget _buildGreeting() {
    return const Text(
      'My Swimming Agent',
      style: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        letterSpacing: 0.5,
      ),
    );
  }

  // ── 통계 요약 ──
  Widget _buildStatsSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryBlue.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          _buildStatItem(
            icon: Icons.date_range,
            value: '${_weeklyDistance}m',
            label: '이번 주 · $_weeklyCount회',
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _openSwimStats,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '주/월 상세 통계 보기',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.chevron_right, color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryBlue, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  // ── My Workout 섹션 ──
  Widget _buildMyWorkoutSection() {
    return Column(
      children: [
        _buildSectionHeader(
          title: 'My Swim Plan',
          onSeeAll: widget.onNavigateToMyProgram,
        ),
        const SizedBox(height: 12),
        if (_recentPrograms.isEmpty)
          _buildEmptyCard(
            icon: Icons.add_circle_outline,
            message: '아직 저장된 프로그램이 없어요\n프로그램을 생성해보세요!',
            onTap: widget.onNavigateToProgram,
          )
        else
          ..._recentPrograms.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildProgramCard(p),
              )),
      ],
    );
  }

  Widget _buildProgramCard(SavedProgram program) {
    const goalLabels = {
      'speed': '스프린트',
      'endurance': '장거리',
      'technique': '드릴',
      'overall': '밸런스',
    };

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SavedProgramDetailScreen(
              savedProgram: program,
            ),
          ),
        );
        _loadData();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  program.levelLabel.isNotEmpty
                      ? program.levelLabel.substring(0, 1)
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    program.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${program.levelLabel} · ${goalLabels[program.trainingGoal] ?? program.trainingGoal} · ${program.program.totalDistance}m',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ── Workout History 섹션 ──
  Widget _buildWorkoutHistorySection() {
    return Column(
      children: [
        _buildSectionHeader(
          title: 'Swim History',
          onSeeAll: _openWorkoutHistory,
        ),
        const SizedBox(height: 12),
        if (_recentLogs.isEmpty)
          _buildEmptyCard(
            icon: Icons.timer_outlined,
            message: '아직 운동 기록이 없어요\n프로그램 실행 후 자동으로 기록돼요!',
          )
        else
          ..._recentLogs.map((log) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildLogCard(log),
              )),
      ],
    );
  }

  Widget _buildLogCard(WorkoutLog log) {
    final dateStr = DateFormat('M/d (E)').format(log.startedAt);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkoutHistoryDetailScreen(log: log),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(Icons.check, color: AppTheme.success, size: 22),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.programTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$dateStr · ${log.completedDistance}m · ${log.durationMinutes}분',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${log.completionRate.toStringAsFixed(0)}%',
              style: TextStyle(
                color: log.completionRate >= 80
                    ? AppTheme.success
                    : AppTheme.warmupOrange,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openWorkoutHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WorkoutHistoryScreen(),
      ),
    );
    _loadData();
  }

  Future<void> _openSwimStats() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SwimStatsScreen(),
      ),
    );
    _loadData();
  }

  // ── 코치 카드 (홈 상단) ──
  Widget _buildCoachCard() {
    final weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];
    final todayName = weekdayNames[DateTime.now().weekday - 1];

    String title;
    String subtitle;
    IconData icon;

    if (_hasTodaySchedule) {
      title = '오늘($todayName) ${_todayScheduleTime ?? ""} 수영 예정!';
      subtitle = '코치에게 오늘의 맞춤 프로그램을 받아보세요';
      icon = Icons.pool;
    } else if (_recentLogs.isNotEmpty) {
      final daysSinceLast = DateTime.now()
          .difference(_recentLogs.first.startedAt)
          .inDays;
      if (daysSinceLast >= 3) {
        title = '${daysSinceLast}일째 쉬고 있어요';
        subtitle = '가벼운 훈련부터 다시 시작해볼까요?';
        icon = Icons.fitness_center;
      } else {
        title = '다음 훈련을 준비해볼까요?';
        subtitle = '코치가 최근 기록을 분석해서 추천해드려요';
        icon = Icons.auto_awesome;
      }
    } else {
      title = '첫 훈련을 시작해보세요!';
      subtitle = 'AI 코치가 맞춤 프로그램을 만들어드려요';
      icon = Icons.waving_hand;
    }

    return GestureDetector(
      onTap: () => widget.onNavigateToCoach?.call(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0D3B66), Color(0xFF14506A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primaryBlue.withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryBlue.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white70,
                size: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 공통 위젯 ──
  Widget _buildSectionHeader({
    required String title,
    VoidCallback? onSeeAll,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: const Text(
              '전체보기',
              style: TextStyle(
                color: AppTheme.primaryBlue,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyCard({
    required IconData icon,
    required String message,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.2), size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}