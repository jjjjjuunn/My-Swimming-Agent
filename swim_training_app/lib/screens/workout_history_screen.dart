import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/workout_log.dart';
import '../services/workout_log_service.dart';
import '../theme/app_theme.dart';

class WorkoutHistoryScreen extends StatefulWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? title;

  const WorkoutHistoryScreen({
    super.key,
    this.startDate,
    this.endDate,
    this.title,
  });

  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen> {
  final _logService = WorkoutLogService();
  List<WorkoutLog> _logs = [];
  bool _isLoading = true;
  bool _isSelectMode = false;
  final Set<String> _selectedIds = {};
  String? _expandedLogId;

  bool get _isFiltered => widget.startDate != null || widget.endDate != null;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final logs = await _logService.getLogs();

    final start = widget.startDate;
    final end = widget.endDate;
    final filtered = logs.where((l) {
      final afterStart = start == null ? true : !l.completedAt.isBefore(start);
      final beforeEnd = end == null ? true : l.completedAt.isBefore(end);
      return afterStart && beforeEnd;
    }).toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt)); // 오래된 순 (시간순)

    if (!mounted) return;
    setState(() {
      _logs = filtered;
      _isLoading = false;
    });
  }

  Future<void> _deleteOne(WorkoutLog log) async {
    await _logService.deleteLog(log.id);
    await _loadLogs();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('기록이 삭제되었습니다.')),
    );
  }

  void _toggleSelectMode() {
    setState(() {
      _isSelectMode = !_isSelectMode;
      _selectedIds.clear();
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIds.length == _logs.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(_logs.map((e) => e.id));
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('선택 삭제', style: TextStyle(color: Colors.white)),
        content: Text(
          '${_selectedIds.length}개 기록을 삭제할까요?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (ok != true) return;
    for (final id in _selectedIds) {
      await _logService.deleteLog(id);
    }

    await _loadLogs();
    if (!mounted) return;
    setState(() {
      _isSelectMode = false;
      _selectedIds.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('선택한 기록이 삭제되었습니다.')),
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
                    Text(
                      widget.title ?? 'Swim History',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (!_isFiltered) ...[
                      if (_isSelectMode)
                        TextButton(
                          onPressed: _toggleSelectAll,
                          child: Text(
                            _selectedIds.length == _logs.length ? '해제' : '전체',
                            style: const TextStyle(
                              color: AppTheme.primaryBlue,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      TextButton(
                        onPressed: _toggleSelectMode,
                        child: Text(
                          _isSelectMode ? '취소' : '선택',
                          style: const TextStyle(
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _logs.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            onRefresh: _loadLogs,
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                20,
                                8,
                                20,
                                _isSelectMode ? 96 : 24,
                              ),
                              itemCount: _logs.length,
                              itemBuilder: (context, index) {
                                final log = _logs[index];
                                return _buildLogCard(log);
                              },
                            ),
                          ),
              ),
              if (_isSelectMode && _selectedIds.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryDark,
                    border: Border(
                      top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: ElevatedButton.icon(
                      onPressed: _deleteSelected,
                      icon: const Icon(Icons.delete_outline),
                      label: Text('${_selectedIds.length}개 삭제'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 68, color: Colors.white.withValues(alpha: 0.25)),
          const SizedBox(height: 12),
          Text(
            '아직 기록이 없어요',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 16),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int? sec) {
    if (sec == null) return '-';
    if (sec < 60) return '$sec초';
    final min = sec ~/ 60;
    final remain = sec % 60;
    if (remain == 0) return '$min분';
    return '$min분 $remain초';
  }

  Widget _buildLogCard(WorkoutLog log) {
    final date = DateFormat('yyyy.MM.dd HH:mm').format(log.startedAt);
    final isSelected = _selectedIds.contains(log.id);
    final isExpanded = _expandedLogId == log.id;

    final card = GestureDetector(
      onLongPress: () {
        if (_isFiltered || _isSelectMode) return;
        setState(() {
          _isSelectMode = true;
          _selectedIds.add(log.id);
        });
      },
      onTap: () {
        if (_isSelectMode) {
          setState(() {
            if (isSelected) {
              _selectedIds.remove(log.id);
            } else {
              _selectedIds.add(log.id);
            }
          });
          return;
        }

        setState(() {
          _expandedLogId = isExpanded ? null : log.id;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryBlue.withValues(alpha: 0.12)
              : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryBlue.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (_isSelectMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: isSelected
                          ? AppTheme.primaryBlue
                          : Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                Expanded(
                  child: Text(
                    log.programTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${log.completionRate.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: log.completionRate >= 80 ? AppTheme.success : AppTheme.warmupOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$date · ${log.levelLabel}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(Icons.pool, '${log.completedDistance}m'),
                _chip(Icons.flag, '${log.plannedDistance}m 계획'),
                _chip(Icons.timer, '${log.durationMinutes}분'),
                _chip(Icons.format_list_numbered, '${log.sets.length}세트'),
              ],
            ),
            if (isExpanded) ...[
              const SizedBox(height: 12),
              Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              const SizedBox(height: 12),
              const Text(
                '세트 상세',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ...log.sets.asMap().entries.map((entry) {
                final idx = entry.key;
                final setLog = entry.value;

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
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
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
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _smallChip(Icons.straighten, '${setLog.distance}m x ${setLog.repeat}'),
                          _smallChip(Icons.av_timer, _formatDuration(setLog.durationSeconds)),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
            if (!_isSelectMode)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: Colors.white.withValues(alpha: 0.5),
                      size: 20,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );

    if (_isSelectMode || _isFiltered) {
      return card;
    }

    return Dismissible(
      key: Key(log.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 16),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.cardColor,
            title: const Text('기록 삭제', style: TextStyle(color: Colors.white)),
            content: Text(
              '${log.programTitle} 기록을 삭제할까요?',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('삭제', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => _deleteOne(log),
      child: card,
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

  Widget _smallChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white60),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      ),
    );
  }
}
