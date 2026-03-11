import 'package:flutter/material.dart';
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
import 'ai_feedback_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onNavigateToProgram;
  final VoidCallback? onNavigateToMyProgram;

  const HomeScreen({
    super.key,
    this.onNavigateToProgram,
    this.onNavigateToMyProgram,
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

    if (mounted) {
      setState(() {
        _recentPrograms = programs.take(1).toList();
        _recentLogs = logs;
        _weeklyDistance = weeklyDist;
        _weeklyCount = weeklyCount;
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
                        const SizedBox(height: 24),
                        _buildStatsSummaryCard(),
                        const SizedBox(height: 28),
                        _buildMyWorkoutSection(),
                        const SizedBox(height: 28),
                        _buildWorkoutHistorySection(),
                        const SizedBox(height: 28),
                        _buildAiFeedbackSection(),
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

  // ── AI Feedback 섹션 ──
  Widget _buildAiFeedbackSection() {
    final hasLogs = _recentLogs.isNotEmpty;

    return GestureDetector(
      onTap: hasLogs
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AiFeedbackScreen(
                    recentLogs: _recentLogs,
                    onNavigateToMyProgram: widget.onNavigateToMyProgram,
                  ),
                ),
              );
            }
          : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: hasLogs
              ? const LinearGradient(
                  colors: [Color(0xFF1A2744), Color(0xFF0A2A3F)],
                )
              : null,
          color: hasLogs ? null : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasLogs
                ? AppTheme.primaryBlue.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: hasLogs ? AppTheme.primaryGradient : null,
                color: hasLogs ? null : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.auto_awesome,
                color:
                    hasLogs ? Colors.white : Colors.white.withValues(alpha: 0.3),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI Feedback',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasLogs
                        ? '최근 운동을 분석해드릴게요'
                        : '운동 기록이 있으면 AI가 분석해줘요',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (hasLogs)
              const Icon(
                Icons.arrow_forward_ios,
                color: AppTheme.primaryBlue,
                size: 16,
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