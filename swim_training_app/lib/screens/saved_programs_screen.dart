import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/saved_program.dart';
import '../services/local_storage_service.dart';
import 'saved_program_detail_screen.dart';
import 'package:intl/intl.dart';

class SavedProgramsScreen extends StatefulWidget {
  final VoidCallback? onWorkoutCompleted;

  const SavedProgramsScreen({super.key, this.onWorkoutCompleted});

  @override
  State<SavedProgramsScreen> createState() => _SavedProgramsScreenState();
}

class _SavedProgramsScreenState extends State<SavedProgramsScreen> {
  final _storageService = LocalStorageService();
  List<SavedProgram> _savedPrograms = [];
  bool _isLoading = true;
  bool _isSelectMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadPrograms();
  }

  Future<void> _loadPrograms() async {
    setState(() => _isLoading = true);
    try {
      final programs = await _storageService.getSavedPrograms();
      setState(() {
        _savedPrograms = programs..sort((a, b) => b.savedAt.compareTo(a.savedAt));
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('프로그램 로드 실패: $e')),
        );
      }
    }
  }

  Future<void> _deleteProgram(String id) async {
    try {
      await _storageService.deleteProgram(id);
      await _loadPrograms();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로그램이 삭제되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
      }
    }
  }

  void _toggleSelectMode() {
    setState(() {
      _isSelectMode = !_isSelectMode;
      _selectedIds.clear();
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIds.length == _savedPrograms.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(_savedPrograms.map((p) => p.id));
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('프로그램 삭제', style: TextStyle(color: Colors.white)),
        content: Text(
          '선택한 ${_selectedIds.length}개의 프로그램을 삭제하시겠습니까?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    for (final id in _selectedIds.toList()) {
      await _storageService.deleteProgram(id);
    }

    setState(() {
      _isSelectMode = false;
      _selectedIds.clear();
    });
    await _loadPrograms();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('선택한 프로그램이 삭제되었습니다')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.backgroundGradient,
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _savedPrograms.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildActionBar(),
                    Expanded(child: _buildProgramList()),
                    if (_isSelectMode && _selectedIds.isNotEmpty)
                      _buildDeleteBar(),
                  ],
                ),
    );
  }

  Widget _buildActionBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_isSelectMode) ...[
            GestureDetector(
              onTap: _toggleSelectAll,
              child: Row(
                children: [
                  Icon(
                    _selectedIds.length == _savedPrograms.length
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    color: AppTheme.primaryBlue,
                    size: 22,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _selectedIds.length == _savedPrograms.length
                        ? '전체 해제'
                        : '전체 선택',
                    style: const TextStyle(
                      color: AppTheme.primaryBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${_selectedIds.length}개 선택',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
          ] else
            Text(
              '총 ${_savedPrograms.length}개',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
          GestureDetector(
            onTap: _toggleSelectMode,
            child: Text(
              _isSelectMode ? '취소' : '선택',
              style: const TextStyle(
                color: AppTheme.primaryBlue,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: ElevatedButton.icon(
          onPressed: _deleteSelected,
          icon: const Icon(Icons.delete_outline, size: 20),
          label: Text('${_selectedIds.length}개 삭제'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '저장된 프로그램이 없습니다',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '프로그램을 생성하고 저장해보세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgramList() {
    return RefreshIndicator(
      onRefresh: _loadPrograms,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _savedPrograms.length,
        itemBuilder: (context, index) {
          final program = _savedPrograms[index];
          return _buildProgramCard(program);
        },
      ),
    );
  }

  Widget _buildProgramCard(SavedProgram program) {
    final dateFormat = DateFormat('yyyy.MM.dd HH:mm');
    final isSelected = _selectedIds.contains(program.id);
    
    return Dismissible(
      key: Key(program.id),
      direction: _isSelectMode ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.cardColor,
            title: const Text('프로그램 삭제', style: TextStyle(color: Colors.white)),
            content: Text(
              '${program.title}을(를) 삭제하시겠습니까?',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('삭제', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) => _deleteProgram(program.id),
      child: GestureDetector(
        onTap: () async {
          if (_isSelectMode) {
            setState(() {
              if (isSelected) {
                _selectedIds.remove(program.id);
              } else {
                _selectedIds.add(program.id);
              }
            });
            return;
          }
          final result = await Navigator.push<dynamic>(
            context,
            MaterialPageRoute(
              builder: (context) => SavedProgramDetailScreen(
                savedProgram: program,
              ),
            ),
          );
          // 운동 완료 시 홈으로 이동
          if (result == 'workout_completed') {
            widget.onWorkoutCompleted?.call();
            return;
          }
          // 변경된 프로그램이 돌아오면 목록 새로고침
          if (result is SavedProgram) {
            _loadPrograms();
          }
        },
        onLongPress: () {
          if (!_isSelectMode) {
            setState(() {
              _isSelectMode = true;
              _selectedIds.add(program.id);
            });
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: isSelected ? null : AppTheme.cardGradient,
            color: isSelected ? AppTheme.primaryBlue.withValues(alpha: 0.15) : null,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryBlue.withValues(alpha: 0.6)
                  : AppTheme.primaryBlue.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isSelectMode) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 12),
                  child: Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isSelected
                        ? AppTheme.primaryBlue
                        : Colors.white.withValues(alpha: 0.3),
                    size: 24,
                  ),
                ),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            program.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            program.levelLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      program.program.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildInfoChip(Icons.pool, '${program.program.totalDistance}m'),
                        const SizedBox(width: 8),
                        _buildInfoChip(Icons.access_time, '${program.program.estimatedMinutes}분'),
                        const SizedBox(width: 8),
                        _buildInfoChip(Icons.calendar_today, dateFormat.format(program.savedAt)),
                      ],
                    ),
                    if (program.memo != null && program.memo!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.note, size: 16, color: Colors.white60),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                program.memo!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white60,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white60),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }
}
