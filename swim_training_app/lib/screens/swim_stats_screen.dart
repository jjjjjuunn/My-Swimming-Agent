import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/workout_log_service.dart';
import '../theme/app_theme.dart';
import 'workout_history_screen.dart';

class SwimStatsScreen extends StatefulWidget {
  const SwimStatsScreen({super.key});

  @override
  State<SwimStatsScreen> createState() => _SwimStatsScreenState();
}

class _SwimStatsScreenState extends State<SwimStatsScreen> {
  final _logService = WorkoutLogService();

  String _mode = 'week'; // week, month
  DateTime _anchor = DateTime.now();
  bool _isLoading = true;
  Map<String, int> _summary = {'distance': 0, 'count': 0, 'minutes': 0};
  List<Map<String, dynamic>> _breakdown = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    late DateTime start;
    late DateTime end;
    if (_mode == 'week') {
      final weekStart = _anchor.subtract(Duration(days: _anchor.weekday - 1));
      start = DateTime(weekStart.year, weekStart.month, weekStart.day);
      end = start.add(const Duration(days: 7));
    } else {
      start = DateTime(_anchor.year, _anchor.month, 1);
      end = DateTime(_anchor.year, _anchor.month + 1, 1);
    }

    final summary = await _logService.getPeriodSummary(start: start, end: end);
    final logs = await _logService.getLogs();
    final filtered = logs
        .where((l) => !l.completedAt.isBefore(start) && l.completedAt.isBefore(end))
        .toList();

    final breakdown = <Map<String, dynamic>>[];
    if (_mode == 'week') {
      for (int i = 0; i < 7; i++) {
        final dayStart = start.add(Duration(days: i));
        final dayEnd = dayStart.add(const Duration(days: 1));
        final dayLogs = filtered
            .where((l) => !l.completedAt.isBefore(dayStart) && l.completedAt.isBefore(dayEnd))
            .toList();
        final count = dayLogs.length;
        if (count > 0) {
          breakdown.add({
            'label': DateFormat('M/d (E)').format(dayStart),
            'distance': dayLogs.fold<int>(0, (s, l) => s + l.completedDistance),
            'count': count,
            'minutes': dayLogs.fold<int>(0, (s, l) => s + l.durationMinutes),
            'start': dayStart,
            'end': dayEnd,
            'title': '${DateFormat('M/d').format(dayStart)} Swim History',
          });
        }
      }
    } else {
      DateTime cursor = start;
      int weekNo = 1;
      while (cursor.isBefore(end)) {
        final weekEnd = cursor.add(const Duration(days: 7)).isAfter(end)
            ? end
            : cursor.add(const Duration(days: 7));
        final weekLogs = filtered
            .where((l) => !l.completedAt.isBefore(cursor) && l.completedAt.isBefore(weekEnd))
            .toList();
        final count = weekLogs.length;
        if (count > 0) {
          breakdown.add({
            'label': '$weekNo주차',
            'distance': weekLogs.fold<int>(0, (s, l) => s + l.completedDistance),
            'count': count,
            'minutes': weekLogs.fold<int>(0, (s, l) => s + l.durationMinutes),
            'start': cursor,
            'end': weekEnd,
            'title': '${DateFormat('M/d').format(cursor)}-${DateFormat('M/d').format(weekEnd.subtract(const Duration(days: 1)))} Swim History',
          });
        }
        cursor = weekEnd;
        weekNo += 1;
      }
    }

    if (!mounted) return;
    setState(() {
      _summary = summary;
      _breakdown = breakdown;
      _isLoading = false;
    });
  }

  void _movePeriod(int delta) {
    setState(() {
      _anchor = _mode == 'week'
          ? _anchor.add(Duration(days: 7 * delta))
          : DateTime(_anchor.year, _anchor.month + delta, _anchor.day);
    });
    _load();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchor,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );

    if (picked == null) return;
    setState(() => _anchor = picked);
    _load();
  }

  void _openHistoryForRow(Map<String, dynamic> row) {
    final start = row['start'] as DateTime?;
    final end = row['end'] as DateTime?;
    final title = row['title'] as String?;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutHistoryScreen(
          startDate: start,
          endDate: end,
          title: title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      'Swim Stats',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _modeButton('week', '주간'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _modeButton('month', '월간'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => _movePeriod(-1),
                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickDate,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _mode == 'week'
                                  ? '${DateFormat('yyyy.MM.dd').format(_anchor.subtract(Duration(days: _anchor.weekday - 1)))} 주'
                                  : DateFormat('yyyy.MM').format(_anchor),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.calendar_month, color: Colors.white70, size: 18),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _movePeriod(1),
                      icon: const Icon(Icons.chevron_right, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
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
                            child: Row(
                              children: [
                                Expanded(child: _metric('거리', '${_summary['distance'] ?? 0}m')),
                                Expanded(child: _metric('횟수', '${_summary['count'] ?? 0}회')),
                                Expanded(child: _metric('시간', '${_summary['minutes'] ?? 0}분')),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            '상세 내역',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ..._breakdown.map((row) => GestureDetector(
                                onTap: () => _openHistoryForRow(row),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppTheme.cardColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.06),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          row['label'] as String,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    Expanded(
                                      child: Text(
                                        '${row['distance']}m',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.8),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        '${row['count']}회',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.8),
                                        ),
                                      ),
                                    ),
                                      Expanded(
                                        child: Text(
                                          '${row['minutes']}분',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.8),
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right,
                                        color: Colors.white54,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
                              )),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeButton(String value, String label) {
    final selected = _mode == value;
    return GestureDetector(
      onTap: () {
        if (_mode == value) return;
        setState(() => _mode = value);
        _load();
      },
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          gradient: selected ? AppTheme.primaryGradient : null,
          color: selected ? null : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppTheme.primaryBlue.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: selected ? 1.0 : 0.7),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
