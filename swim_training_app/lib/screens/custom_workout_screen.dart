import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../models/program_response.dart';
import '../models/saved_program.dart';
import '../services/local_storage_service.dart';

class CustomWorkoutScreen extends StatefulWidget {
  final VoidCallback? onProgramSaved;

  const CustomWorkoutScreen({super.key, this.onProgramSaved});

  @override
  State<CustomWorkoutScreen> createState() => _CustomWorkoutScreenState();
}

class _CustomWorkoutScreenState extends State<CustomWorkoutScreen> {
  final _titleController = TextEditingController(text: '나만의 훈련');
  final _memoController = TextEditingController();
  String _selectedLevel = 'intermediate';
  final List<Exercise> _warmup = [];
  final List<Exercise> _mainSet = [];
  final List<Exercise> _cooldown = [];

  int get _totalDistance {
    int total = 0;
    for (final e in _warmup) total += e.totalDistance;
    for (final e in _mainSet) total += e.totalDistance;
    for (final e in _cooldown) total += e.totalDistance;
    return total;
  }

  int get _totalExercises => _warmup.length + _mainSet.length + _cooldown.length;

  final Map<String, String> _levelLabels = {
    'beginner': '초급',
    'intermediate': '중급',
    'advanced': '고급',
  };

  @override
  void dispose() {
    _titleController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 헤더
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        '커스텀 훈련 만들기',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 본문
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 제목 입력
                      _buildInputField(
                        controller: _titleController,
                        label: '훈련 제목',
                        icon: Icons.edit,
                      ),
                      const SizedBox(height: 16),

                      // 레벨 선택
                      const Text(
                        '레벨',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: _levelLabels.entries.map((entry) {
                          final isSelected = _selectedLevel == entry.key;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedLevel = entry.key),
                              child: Container(
                                margin: EdgeInsets.only(
                                  right: entry.key != 'advanced' ? 8 : 0,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: isSelected ? AppTheme.primaryGradient : null,
                                  color: isSelected ? null : AppTheme.cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.transparent
                                        : AppTheme.primaryBlue.withOpacity(0.2),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    entry.value,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // 총 거리 표시
                      if (_totalExercises > 0)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.primaryBlue.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.pool, color: AppTheme.primaryBlue, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '총 ${_totalDistance}m · $_totalExercises개 세트',
                                style: const TextStyle(
                                  color: AppTheme.primaryBlue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // 워밍업 섹션
                      _buildSection(
                        title: 'Warm-up',
                        icon: Icons.wb_sunny_rounded,
                        color: AppTheme.warmupOrange,
                        exercises: _warmup,
                        sectionKey: 'warmup',
                      ),
                      const SizedBox(height: 16),

                      // 메인세트 섹션
                      _buildSection(
                        title: 'Main Set',
                        icon: Icons.fitness_center,
                        color: AppTheme.mainsetRed,
                        exercises: _mainSet,
                        sectionKey: 'mainSet',
                      ),
                      const SizedBox(height: 16),

                      // 쿨다운 섹션
                      _buildSection(
                        title: 'Cool-down',
                        icon: Icons.ac_unit,
                        color: AppTheme.cooldownBlue,
                        exercises: _cooldown,
                        sectionKey: 'cooldown',
                      ),
                      const SizedBox(height: 16),

                      // 메모
                      _buildInputField(
                        controller: _memoController,
                        label: '메모 (선택)',
                        icon: Icons.note,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 24),

                      // 저장 버튼
                      GestureDetector(
                        onTap: _totalExercises > 0 ? _saveProgram : null,
                        child: Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: _totalExercises > 0
                                ? const LinearGradient(
                                    colors: [Color(0xFF00E676), Color(0xFF00C853)],
                                  )
                                : null,
                            color: _totalExercises > 0 ? null : AppTheme.cardColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: _totalExercises > 0
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF00E676).withOpacity(0.3),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.save_rounded,
                                  color: _totalExercises > 0
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.3),
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '프로그램 저장',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: _totalExercises > 0
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Exercise> exercises,
    required String sectionKey,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 섹션 헤더
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const Spacer(),
            // 총 거리
            if (exercises.isNotEmpty)
              Text(
                '${exercises.fold<int>(0, (sum, e) => sum + e.totalDistance)}m',
                style: TextStyle(
                  fontSize: 13,
                  color: color.withOpacity(0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // 운동 리스트
        ...exercises.asMap().entries.map((entry) {
          final idx = entry.key;
          final exercise = entry.value;
          return _buildExerciseItem(exercise, sectionKey, idx, color);
        }),

        // 추가 버튼
        GestureDetector(
          onTap: () => _addExercise(sectionKey),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, color: color, size: 20),
                const SizedBox(width: 6),
                Text(
                  '세트 추가',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseItem(Exercise exercise, String sectionKey, int index, Color color) {
    final String mainLine;
    if (exercise.repeat > 1) {
      mainLine = '${exercise.repeat} x ${exercise.distance} ${exercise.description}';
    } else {
      mainLine = '${exercise.distance} ${exercise.description}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    children: [
                      TextSpan(text: mainLine),
                      if (exercise.cycleTime != null)
                        TextSpan(
                          text: ' @ ${exercise.cycleTime}',
                          style: const TextStyle(
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
                if (exercise.notes.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    exercise.notes,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // 편집
          GestureDetector(
            onTap: () => _editExercise(sectionKey, index),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.edit, size: 16, color: Colors.white.withOpacity(0.4)),
            ),
          ),
          const SizedBox(width: 4),
          // 삭제
          GestureDetector(
            onTap: () {
              setState(() {
                _getList(sectionKey).removeAt(index);
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close, size: 16, color: Colors.redAccent.withOpacity(0.6)),
            ),
          ),
        ],
      ),
    );
  }

  List<Exercise> _getList(String sectionKey) {
    switch (sectionKey) {
      case 'warmup':
        return _warmup;
      case 'mainSet':
        return _mainSet;
      case 'cooldown':
        return _cooldown;
      default:
        return _mainSet;
    }
  }

  void _addExercise(String sectionKey) {
    _showExerciseDialog(sectionKey, null, null);
  }

  void _editExercise(String sectionKey, int index) {
    final exercise = _getList(sectionKey)[index];
    _showExerciseDialog(sectionKey, exercise, index);
  }

  void _showExerciseDialog(String sectionKey, Exercise? existing, int? index) {
    final descController = TextEditingController(text: existing?.description ?? '');
    final notesController = TextEditingController(text: existing?.notes ?? '');
    final cycleController = TextEditingController(text: existing?.cycleTime ?? '');
    int distance = existing?.distance ?? 50;
    int repeat = existing?.repeat ?? 1;
    int restSeconds = existing?.restSeconds ?? 15;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return Container(
            padding: EdgeInsets.fromLTRB(
                24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 핸들
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    existing != null ? '세트 수정' : '세트 추가',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 설명
                  _buildDialogField(descController, '운동 설명', Icons.pool),
                  const SizedBox(height: 16),

                  // 거리
                  _buildDialogNumber(
                    label: '거리 (m)',
                    icon: Icons.straighten,
                    value: distance,
                    step: 25,
                    min: 25,
                    onChanged: (v) => setDialogState(() => distance = v),
                  ),
                  const SizedBox(height: 12),

                  // 반복
                  _buildDialogNumber(
                    label: '반복',
                    icon: Icons.repeat,
                    value: repeat,
                    step: 1,
                    min: 1,
                    onChanged: (v) => setDialogState(() => repeat = v),
                  ),
                  const SizedBox(height: 12),

                  // 휴식
                  _buildDialogNumber(
                    label: '휴식 (초)',
                    icon: Icons.timer,
                    value: restSeconds,
                    step: 5,
                    min: 0,
                    onChanged: (v) => setDialogState(() => restSeconds = v),
                  ),
                  const SizedBox(height: 12),

                  // 사이클 타임
                  _buildDialogField(cycleController, '사이클 타임 (예: 1:30)', Icons.av_timer),
                  const SizedBox(height: 12),

                  // 총 거리
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.pool, color: AppTheme.primaryBlue, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '총 거리: ${distance * repeat}m',
                          style: const TextStyle(
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 노트
                  _buildDialogField(notesController, '코칭 노트 (선택)', Icons.lightbulb_outline, maxLines: 2),
                  const SizedBox(height: 24),

                  // 저장
                  GestureDetector(
                    onTap: () {
                      if (descController.text.trim().isEmpty) return;
                      final cycleText = cycleController.text.trim();
                      final exercise = Exercise(
                        description: descController.text.trim(),
                        distance: distance,
                        repeat: repeat,
                        restSeconds: restSeconds,
                        notes: notesController.text.trim(),
                        cycleTime: cycleText.isNotEmpty ? cycleText : null,
                      );
                      setState(() {
                        final list = _getList(sectionKey);
                        if (index != null) {
                          list[index] = exercise;
                        } else {
                          list.add(exercise);
                        }
                      });
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          existing != null ? '수정 완료' : '추가',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Widget _buildDialogField(TextEditingController controller, String label, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: AppTheme.primaryBlue, size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryBlue),
        ),
      ),
    );
  }

  Widget _buildDialogNumber({
    required String label,
    required IconData icon,
    required int value,
    required int step,
    required int min,
    required Function(int) onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryBlue, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
          ),
        ),
        GestureDetector(
          onTap: () {
            if (value - step >= min) onChanged(value - step);
          },
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.remove, color: Colors.white, size: 18),
          ),
        ),
        SizedBox(
          width: 60,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        GestureDetector(
          onTap: () => onChanged(value + step),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: AppTheme.primaryBlue, size: 20),
        filled: true,
        fillColor: AppTheme.cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryBlue),
        ),
      ),
    );
  }

  Future<void> _saveProgram() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _totalExercises == 0) return;

    final levelLabel = _levelLabels[_selectedLevel] ?? '중급';
    final program = ProgramLevel(
      level: _selectedLevel,
      levelLabel: levelLabel,
      description: title,
      warmup: List.from(_warmup),
      mainSet: List.from(_mainSet),
      cooldown: List.from(_cooldown),
      totalDistance: _totalDistance,
      estimatedMinutes: (_totalDistance / 60).ceil(), // 대략적 추정
    );

    final savedProgram = SavedProgram(
      id: const Uuid().v4(),
      title: title,
      program: program,
      levelLabel: levelLabel,
      savedAt: DateTime.now(),
      memo: _memoController.text.trim().isNotEmpty ? _memoController.text.trim() : null,
      trainingGoal: 'custom',
      strokes: ['custom'],
    );

    try {
      final storage = LocalStorageService();
      await storage.saveProgram(savedProgram);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('프로그램이 저장되었습니다!'),
            backgroundColor: Color(0xFF00C853),
          ),
        );
        widget.onProgramSaved?.call();
        Navigator.pop(context, 'saved');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 실패: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}
