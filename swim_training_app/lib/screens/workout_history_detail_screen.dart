import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/workout_log.dart';
import '../theme/app_theme.dart';

class WorkoutHistoryDetailScreen extends StatelessWidget {
  final WorkoutLog log;

  const WorkoutHistoryDetailScreen({
    super.key,
    required this.log,
  });

  String _formatDuration(int? sec) {
    if (sec == null) return '-';
    if (sec < 60) return '$sec초';
    final min = sec ~/ 60;
    final remain = sec % 60;
    if (remain == 0) return '$min분';
    return '$min분 $remain초';
  }

  double _setPacePer50(SetLog setLog) {
    final sec = setLog.durationSeconds;
    final dist = setLog.totalDistance;
    if (sec == null || dist <= 0) return 0;
    return sec / dist * 50;
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('yyyy.MM.dd HH:mm').format(log.startedAt);
    final skipped = log.sets.where((s) => s.status == 'skipped').toList();

    final completedSets = log.sets.where(
      (s) => s.status == 'completed' && (s.durationSeconds ?? 0) > 0,
    ).toList()
      ..sort((a, b) => _setPacePer50(b).compareTo(_setPacePer50(a)));

    final slowest = completedSets.take(3).toList();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 20, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Swim Detail',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: AppTheme.cardGradient,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            log.programTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$date · ${log.levelLabel}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _chip(Icons.pool, '${log.completedDistance}m'),
                              _chip(Icons.flag, '${log.plannedDistance}m 계획'),
                              _chip(Icons.timer, _formatDuration(log.completedAt.difference(log.startedAt).inSeconds)),
                              _chip(Icons.percent, '${log.completionRate.toStringAsFixed(0)}%'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _insightCard(skipped, slowest),
                    const SizedBox(height: 14),
                    const Text(
                      '세트 상세',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...log.sets.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final setLog = entry.value;
                      final pace = _setPacePer50(setLog);

                      Color statusColor;
                      String statusLabel;
                      switch (setLog.status) {
                        case 'completed':
                          statusColor = AppTheme.success;
                          statusLabel = '완료';
                          break;
                        case 'skipped':
                          statusColor = Colors.orange;
                          statusLabel = '스킵';
                          break;
                        case 'stopped':
                          statusColor = Colors.redAccent;
                          statusLabel = '중단';
                          break;
                        default:
                          statusColor = Colors.white54;
                          statusLabel = setLog.status;
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${idx + 1}. ${setLog.exercise}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _chip(Icons.straighten, '${setLog.distance}m x ${setLog.repeat}'),
                                _chip(Icons.route, '${setLog.totalDistance}m'),
                                _chip(Icons.av_timer, _formatDuration(setLog.durationSeconds)),
                                if (pace > 0) _chip(Icons.speed, '50m ${pace.toStringAsFixed(1)}초'),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _insightCard(List<SetLog> skipped, List<SetLog> slowest) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '내가 약했던 구간',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (skipped.isNotEmpty)
            Text(
              '스킵한 세트 ${skipped.length}개',
              style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
            )
          else
            Text(
              '스킵한 세트 없음',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
            ),
          if (slowest.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '상대적으로 페이스가 느렸던 세트:',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 4),
            ...slowest.map((s) => Text(
                  '- ${s.exercise} (${_setPacePer50(s).toStringAsFixed(1)}초/50m)',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
                )),
          ],
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}
