import 'dart:async';
import 'package:flutter/material.dart';
import '../models/program_response.dart';
import '../models/saved_program.dart';
import '../models/workout_log.dart';
import '../services/workout_log_service.dart';
import '../theme/app_theme.dart';

class WorkoutExecutionScreen extends StatefulWidget {
  final SavedProgram savedProgram;

  const WorkoutExecutionScreen({
    super.key,
    required this.savedProgram,
  });

  @override
  State<WorkoutExecutionScreen> createState() => _WorkoutExecutionScreenState();
}

class _WorkoutExecutionScreenState extends State<WorkoutExecutionScreen> {
  final _logService = WorkoutLogService();

  late final List<_WorkoutSetItem> _sets;
  final List<SetLog> _setLogs = [];
  final List<PauseLog> _currentPauses = [];

  late final DateTime _workoutStartedAt;
  DateTime? _setStartedAt;
  DateTime? _pausedAt;

  int _currentIndex = 0;
  int _completedDistance = 0;
  int _pausedAccumulatedSeconds = 0;
  int _elapsedWorkoutSeconds = 0;
  int _elapsedSetSeconds = 0;
  bool _isPaused = false;
  bool _isSaving = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _workoutStartedAt = DateTime.now();
    _sets = _flattenSets(widget.savedProgram.program);
    if (_sets.isNotEmpty) {
      _startCurrentSet();
    }
    _startTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startTicker() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedWorkoutSeconds =
            DateTime.now().difference(_workoutStartedAt).inSeconds;

        final startedAt = _setStartedAt;
        if (startedAt != null && _currentIndex < _sets.length) {
          int pausedSec = _pausedAccumulatedSeconds;
          if (_isPaused && _pausedAt != null) {
            pausedSec += DateTime.now().difference(_pausedAt!).inSeconds;
          }
          final raw = DateTime.now().difference(startedAt).inSeconds;
          _elapsedSetSeconds = (raw - pausedSec).clamp(0, raw);
        }
      });
    });
  }

  List<_WorkoutSetItem> _flattenSets(ProgramLevel program) {
    final items = <_WorkoutSetItem>[];
    for (final e in program.warmup) {
      items.add(_WorkoutSetItem(section: '워밍업', exercise: e));
    }
    for (final e in program.mainSet) {
      items.add(_WorkoutSetItem(section: '메인 세트', exercise: e));
    }
    for (final e in program.cooldown) {
      items.add(_WorkoutSetItem(section: '쿨다운', exercise: e));
    }
    return items;
  }

  void _startCurrentSet() {
    _setStartedAt = DateTime.now();
    _pausedAt = null;
    _pausedAccumulatedSeconds = 0;
    _currentPauses.clear();
    _isPaused = false;
  }

  void _togglePause() {
    if (_sets.isEmpty || _isSaving) return;

    setState(() {
      if (!_isPaused) {
        _pausedAt = DateTime.now();
        _isPaused = true;
      } else {
        final now = DateTime.now();
        final pausedAt = _pausedAt;
        if (pausedAt != null) {
          final sec = now.difference(pausedAt).inSeconds;
          _pausedAccumulatedSeconds += sec;
          _currentPauses.add(
            PauseLog(pausedAt: pausedAt, durationSeconds: sec),
          );
        }
        _pausedAt = null;
        _isPaused = false;
      }
    });
  }

  Future<void> _completeCurrentSet({required bool skipped}) async {
    if (_sets.isEmpty || _isSaving) return;

    final now = DateTime.now();

    if (_isPaused && _pausedAt != null) {
      final sec = now.difference(_pausedAt!).inSeconds;
      _pausedAccumulatedSeconds += sec;
      _currentPauses.add(
        PauseLog(pausedAt: _pausedAt!, durationSeconds: sec),
      );
      _isPaused = false;
      _pausedAt = null;
    }

    final item = _sets[_currentIndex];
    final startedAt = _setStartedAt ?? _workoutStartedAt;
    final rawDuration = now.difference(startedAt).inSeconds;
    final activeDuration = (rawDuration - _pausedAccumulatedSeconds).clamp(0, rawDuration);

    final status = skipped ? 'skipped' : 'completed';
    final setLog = SetLog(
      exercise: item.exercise.description,
      distance: item.exercise.distance,
      repeat: item.exercise.repeat,
      status: status,
      durationSeconds: activeDuration,
      pauses: List<PauseLog>.from(_currentPauses),
    );

    final isLastSet = _currentIndex == _sets.length - 1;

    setState(() {
      _setLogs.add(setLog);
      if (!skipped) {
        _completedDistance += item.exercise.totalDistance;
      }
      if (!isLastSet) {
        _currentIndex += 1;
      }
    });

    if (isLastSet) {
      await _saveAndExit(result: 'completed');
      return;
    }

    _startCurrentSet();
  }

  Future<void> _saveAndExit({required String result}) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    if (result == 'stopped' && _currentIndex < _sets.length) {
      final now = DateTime.now();
      final startedAt = _setStartedAt ?? _workoutStartedAt;
      int pausedSec = _pausedAccumulatedSeconds;
      if (_isPaused && _pausedAt != null) {
        pausedSec += now.difference(_pausedAt!).inSeconds;
      }
      final rawDuration = now.difference(startedAt).inSeconds;
      final activeDuration = (rawDuration - pausedSec).clamp(0, rawDuration);

      final item = _sets[_currentIndex];
      _setLogs.add(
        SetLog(
          exercise: item.exercise.description,
          distance: item.exercise.distance,
          repeat: item.exercise.repeat,
          status: 'stopped',
          durationSeconds: activeDuration,
          pauses: List<PauseLog>.from(_currentPauses),
        ),
      );
    }

    final log = WorkoutLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      programTitle: widget.savedProgram.title,
      levelLabel: widget.savedProgram.levelLabel,
      trainingGoal: widget.savedProgram.trainingGoal,
      startedAt: _workoutStartedAt,
      completedAt: DateTime.now(),
      plannedDistance: widget.savedProgram.program.totalDistance,
      completedDistance: _completedDistance,
      sets: List<SetLog>.from(_setLogs),
    );

    await _logService.saveLog(log);

    if (!mounted) return;
    Navigator.pop(context, result);
  }

  Future<void> _stopWorkout() async {
    final shouldStop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('운동 중단', style: TextStyle(color: Colors.white)),
        content: const Text(
          '지금까지 진행한 기록을 저장하고 중단할까요?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('계속하기'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('중단', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (shouldStop == true) {
      await _saveAndExit(result: 'stopped');
    }
  }

  int get _remainingDistance {
    final remain = widget.savedProgram.program.totalDistance - _completedDistance;
    return remain < 0 ? 0 : remain;
  }

  String _formatDuration(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final total = _sets.length;
    final current = _currentIndex + 1;
    final progress = total == 0 ? 0.0 : _currentIndex / total;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: _sets.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: _isSaving ? null : () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Swim Session',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: _isSaving ? null : _stopWorkout,
                            child: const Text(
                              '중단',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${current > total ? total : current}/$total 세트',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              backgroundColor: Colors.white.withValues(alpha: 0.12),
                              valueColor: const AlwaysStoppedAnimation(AppTheme.primaryBlue),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _metricChip(
                                  Icons.hourglass_bottom,
                                  '전체 ${_formatDuration(_elapsedWorkoutSeconds)}',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _metricChip(
                                  Icons.timer,
                                  '세트 ${_formatDuration(_elapsedSetSeconds)}',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _metricChip(
                                  Icons.route,
                                  '남은 ${_remainingDistance}m',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildCurrentSetCard(),
                      ),
                    ),
                    _buildControls(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildCurrentSetCard() {
    final item = _sets[_currentIndex];
    final ex = item.exercise;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              item.section,
              style: const TextStyle(
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            ex.description,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metricChip(Icons.straighten, '${ex.distance}m'),
              _metricChip(Icons.repeat, '${ex.repeat}회'),
              _metricChip(Icons.route, '${ex.totalDistance}m'),
              _metricChip(Icons.timer, '휴식 ${ex.restSeconds}초'),
            ],
          ),
          if (ex.notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              ex.notes,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
          const Spacer(),
          if (_isPaused)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
              ),
              child: const Text(
                '일시정지 중',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _metricChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: AppTheme.primaryDark.withValues(alpha: 0.9),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isSaving ? null : _togglePause,
                icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                label: Text(_isPaused ? '재개' : '일시정지'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving ? null : () => _completeCurrentSet(skipped: true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: BorderSide(color: Colors.orange.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('스킵'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: _isSaving ? null : () => _completeCurrentSet(skipped: false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('완료'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, color: Colors.white.withValues(alpha: 0.4), size: 52),
          const SizedBox(height: 10),
          Text(
            '실행할 세트가 없습니다.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _WorkoutSetItem {
  final String section;
  final Exercise exercise;

  _WorkoutSetItem({
    required this.section,
    required this.exercise,
  });
}
