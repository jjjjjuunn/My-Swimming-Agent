import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/saved_program.dart';
import '../models/program_response.dart';
import '../services/local_storage_service.dart';
import 'workout_execution_screen.dart';

class SavedProgramDetailScreen extends StatefulWidget {
  final SavedProgram savedProgram;
  /// 채팅 화면에서 진입한 경우 true — 저장 버튼 표시
  final bool isFromChat;

  const SavedProgramDetailScreen({
    super.key,
    required this.savedProgram,
    this.isFromChat = false,
  });

  @override
  State<SavedProgramDetailScreen> createState() =>
      _SavedProgramDetailScreenState();
}

class _SavedProgramDetailScreenState extends State<SavedProgramDetailScreen> {
  late SavedProgram _currentProgram;
  final _storageService = LocalStorageService();
  bool _isSaving = false;
  bool _isEditMode = false;
  bool _isSavedToMyProgram = false;

  // 변경 이력 관리
  ProgramLevel? _originalProgramState;  // 화면 진입 시의 원본
  ProgramLevel get _originalProgram => 
      widget.savedProgram.originalProgram ?? // 저장된 원본 우선
      _originalProgramState ?? 
      widget.savedProgram.program;
  ProgramLevel? _savedProgramState;
  ProgramLevel get _savedProgram => _savedProgramState ?? widget.savedProgram.program;
  List<ProgramLevel> _historyStack = [];
  int _historyIndex = -1;

  // 실제 변경사항이 있는지 프로그램 비교로 판단
  bool get _hasChanges => !_programsEqual(_currentProgram.program, _savedProgram);

  bool _programsEqual(ProgramLevel a, ProgramLevel b) {
    if (a.totalDistance != b.totalDistance) return false;
    if (a.estimatedMinutes != b.estimatedMinutes) return false;
    if (!_exerciseListEqual(a.warmup, b.warmup)) return false;
    if (!_exerciseListEqual(a.mainSet, b.mainSet)) return false;
    if (!_exerciseListEqual(a.cooldown, b.cooldown)) return false;
    return true;
  }

  bool _exerciseListEqual(List<Exercise> a, List<Exercise> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].description != b[i].description ||
          a[i].distance != b[i].distance ||
          a[i].repeat != b[i].repeat ||
          a[i].restSeconds != b[i].restSeconds ||
          a[i].notes != b[i].notes) {
        return false;
      }
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _currentProgram = widget.savedProgram;
    // originalProgram이 없으면 현재 프로그램을 원본으로 저장
    if (widget.savedProgram.originalProgram == null) {
      _originalProgramState = widget.savedProgram.program;
    }
    _savedProgramState = widget.savedProgram.program;
    _historyStack = [_savedProgram];
    _historyIndex = 0;
  }

  // 히스토리에 저장
  void _saveToHistory(ProgramLevel program) {
    // 현재 인덱스 이후의 히스토리 삭제 (새로운 분기 시작)
    if (_historyIndex < _historyStack.length - 1) {
      _historyStack = _historyStack.sublist(0, _historyIndex + 1);
    }
    _historyStack.add(program);
    _historyIndex++;
    
    // 히스토리 최대 20개로 제한
    if (_historyStack.length > 20) {
      _historyStack.removeAt(0);
      _historyIndex--;
    }
  }

  // 뒤로가기 (Undo)
  void _undo() {
    if (_historyIndex > 0) {
      setState(() {
        _historyIndex--;
        _currentProgram = _currentProgram.copyWith(
          program: _historyStack[_historyIndex],
        );
      });
    }
  }

  // 앞으로가기 (Redo)
  void _redo() {
    if (_historyIndex < _historyStack.length - 1) {
      setState(() {
        _historyIndex++;
        _currentProgram = _currentProgram.copyWith(
          program: _historyStack[_historyIndex],
        );
      });
    }
  }

  // 초기화 (Reset)
  void _reset() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.refresh, color: Colors.orange, size: 48),
              const SizedBox(height: 16),
              const Text(
                '원래 프로그램으로 되돌리시겠습니까?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '최초 생성된 원본 프로그램으로 되돌립니다',
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.grey.shade700,
                            Colors.grey.shade800,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(12),
                          child: const Center(
                            child: Text(
                              '취소',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.orange, Colors.deepOrange],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            setState(() {
                              _historyStack = [_originalProgram];
                              _historyIndex = 0;
                              _currentProgram = _currentProgram.copyWith(
                                program: _originalProgram,
                              );
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: const Center(
                            child: Text(
                              '초기화',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 운동 항목 수정
  void _editExercise(String section, int index) {
    final List<Exercise> exercises;
    switch (section) {
      case 'warmup':
        exercises = _currentProgram.program.warmup;
        break;
      case 'mainSet':
        exercises = _currentProgram.program.mainSet;
        break;
      case 'cooldown':
        exercises = _currentProgram.program.cooldown;
        break;
      default:
        return;
    }

    final exercise = exercises[index];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ExerciseEditSheet(
        exercise: exercise,
        onSave: (updatedExercise) {
          final newList = List<Exercise>.from(exercises);
          newList[index] = updatedExercise;

          ProgramLevel newProgram;
          switch (section) {
            case 'warmup':
              newProgram = _currentProgram.program.copyWith(warmup: newList);
              break;
            case 'mainSet':
              newProgram = _currentProgram.program.copyWith(mainSet: newList);
              break;
            case 'cooldown':
              newProgram = _currentProgram.program.copyWith(cooldown: newList);
              break;
            default:
              return;
          }

          final updated = newProgram.recalculate();
          setState(() {
            _currentProgram = _currentProgram.copyWith(
              program: updated,
            );
          });
          _saveToHistory(updated);
        },
      ),
    );
  }

  // 전체 일괄 수정
  void _editAll() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BulkEditSheet(
        program: _currentProgram.program,
        onSave: (updatedProgram) {
          final updated = updatedProgram.recalculate();
          setState(() {
            _currentProgram = _currentProgram.copyWith(
              program: updated,
            );
          });
          _saveToHistory(updated);
        },
      ),
    );
  }

  // 메모 수정
  void _editMemo() {
    final controller = TextEditingController(text: _currentProgram.memo ?? '');
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '메모 수정',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                maxLines: 4,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '메모를 입력하세요',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryBlue,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      '취소',
                      style: TextStyle(color: Colors.white.withOpacity(0.6)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryBlue,
                          AppTheme.primaryBlue.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _currentProgram = _currentProgram.copyWith(
                              memo: controller.text.trim(),
                            );
                          });
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          child: Text(
                            '저장',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 변경사항 저장
  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      await _storageService.updateProgram(_currentProgram);
      setState(() {
        _savedProgramState = _currentProgram.program;
        _historyStack = [_savedProgram];
        _historyIndex = 0;
        _isEditMode = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('변경사항이 저장되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // 뒤로가기 시 변경사항 확인
  Future<bool> _onWillPop() async {
    if (!_hasChanges) {
      Navigator.pop(context, _currentProgram);
      return false;
    }
    final action = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.orange, size: 48),
              const SizedBox(height: 16),
              const Text(
                '저장하지 않은 변경사항이 있습니다',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '저장하지 않고 나가시겠습니까?',
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.grey.shade700,
                            Colors.grey.shade800,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(context, 'discard'),
                          borderRadius: BorderRadius.circular(12),
                          child: const Center(
                            child: Text(
                              '나가기',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryBlue,
                            AppTheme.primaryBlue.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(context, 'save'),
                          borderRadius: BorderRadius.circular(12),
                          child: const Center(
                            child: Text(
                              '저장 후 나가기',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (action == 'save') {
      await _saveChanges();
      if (mounted) Navigator.pop(context, _currentProgram);
    } else if (action == 'discard') {
      if (mounted) Navigator.pop(context, null);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final program = _currentProgram.program;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.backgroundGradient,
          ),
          child: SafeArea(
            child: Column(
              children: [
                // 헤더
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => _onWillPop(),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentProgram.title,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_currentProgram.levelLabel} · ${_currentProgram.trainingGoal}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 편집 모드 토글
                      Container(
                        decoration: BoxDecoration(
                          color: _isEditMode
                              ? AppTheme.primaryBlue.withOpacity(0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          onPressed: () {
                            setState(() => _isEditMode = !_isEditMode);
                          },
                          icon: Icon(
                            _isEditMode ? Icons.edit_off : Icons.edit,
                            color: _isEditMode
                                ? AppTheme.primaryBlue
                                : Colors.white,
                          ),
                          tooltip: _isEditMode ? '편집 종료' : '편집 모드',
                        ),
                      ),
                    ],
                  ),
                ),

                // 프로그래 정보
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: AppTheme.cardGradient,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryBlue.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildInfoItem(
                          Icons.straighten,
                          '${program.totalDistance}m',
                          '총 거리',
                        ),
                        _buildInfoItem(
                          Icons.access_time,
                          '${program.estimatedMinutes}분',
                          '예상 시간',
                        ),
                        _buildInfoItem(
                          Icons.fitness_center,
                          _currentProgram.levelLabel,
                          '난이도',
                        ),
                      ],
                    ),
                  ),
                ),

                // 메모 영역
                if (_currentProgram.memo != null &&
                    _currentProgram.memo!.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: GestureDetector(
                      onTap: _editMemo,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.note,
                                size: 16,
                                color: Colors.white.withOpacity(0.5)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _currentProgram.memo!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.6),
                                ),
                              ),
                            ),
                            Icon(Icons.edit,
                                size: 14,
                                color: Colors.white.withOpacity(0.4)),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: GestureDetector(
                      onTap: _editMemo,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                            style: BorderStyle.solid,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add,
                                size: 16,
                                color: Colors.white.withOpacity(0.5)),
                            const SizedBox(width: 8),
                            Text(
                              '메모 추가',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // 편집 모드 전체 수정 버튼 + 히스토리 컨트롤
                if (_isEditMode)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        // 전체 일괄 수정 버튼
                        Expanded(
                          child: GestureDetector(
                            onTap: _editAll,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.primaryBlue.withOpacity(0.15),
                                    AppTheme.primaryBlue.withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.primaryBlue.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.tune,
                                      color: AppTheme.primaryBlue, size: 20),
                                  const SizedBox(width: 8),
                                  const Text(
                                    '전체 일괄 수정',
                                    style: TextStyle(
                                      color: AppTheme.primaryBlue,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // 히스토리 컨트롤 버튼들
                        Row(
                          children: [
                            // Undo 버튼
                            _buildHistoryButton(
                              icon: Icons.undo,
                              onTap: _historyIndex > 0 ? _undo : null,
                              enabled: _historyIndex > 0,
                            ),
                            const SizedBox(width: 8),
                            // Redo 버튼
                            _buildHistoryButton(
                              icon: Icons.redo,
                              onTap: _historyIndex < _historyStack.length - 1
                                  ? _redo
                                  : null,
                              enabled: _historyIndex < _historyStack.length - 1,
                            ),
                            const SizedBox(width: 8),
                            // Reset 버튼 (편집 모드에서 항상 활성화)
                            _buildHistoryButton(
                              icon: Icons.refresh,
                              onTap: _reset,
                              enabled: true,
                              color: Colors.orange,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),

                // 운동 목록
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _buildSectionHeader(
                          '워밍업', Icons.wb_sunny, AppTheme.warmupOrange),
                      const SizedBox(height: 12),
                      ...program.warmup
                          .asMap()
                          .entries
                          .map((e) =>
                              _buildExerciseCard(e.value, 'warmup', e.key)),

                      const SizedBox(height: 24),
                      _buildSectionHeader(
                          '메인 세트', Icons.fitness_center, AppTheme.mainsetRed),
                      const SizedBox(height: 12),
                      ...program.mainSet
                          .asMap()
                          .entries
                          .map((e) =>
                              _buildExerciseCard(e.value, 'mainSet', e.key)),

                      const SizedBox(height: 24),
                      _buildSectionHeader(
                          '쿨다운', Icons.ac_unit, AppTheme.cooldownBlue),
                      const SizedBox(height: 12),
                      ...program.cooldown
                          .asMap()
                          .entries
                          .map((e) =>
                              _buildExerciseCard(e.value, 'cooldown', e.key)),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),

                // 하단 버튼 영역
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryDark.withOpacity(0.9),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 채팅에서 진입: 내 프로그램에 저장 버튼
                      if (widget.isFromChat) ...[
                        GestureDetector(
                          onTap: _isSaving || _isSavedToMyProgram
                              ? null
                              : () async {
                                  setState(() => _isSaving = true);
                                  try {
                                    await _storageService
                                        .saveProgram(_currentProgram);
                                    setState(
                                        () => _isSavedToMyProgram = true);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content:
                                              Text('내 프로그램에 저장되었습니다 ✅'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text('저장 실패: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  } finally {
                                    setState(() => _isSaving = false);
                                  }
                                },
                          child: Container(
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: _isSavedToMyProgram
                                  ? null
                                  : const LinearGradient(
                                      colors: [
                                        Color(0xFF00B4D8),
                                        Color(0xFF0077B6),
                                      ],
                                    ),
                              color: _isSavedToMyProgram
                                  ? Colors.white.withOpacity(0.08)
                                  : null,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _isSavedToMyProgram
                                              ? Icons.check_circle_outline
                                              : Icons.bookmark_add_outlined,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _isSavedToMyProgram
                                              ? '저장됨'
                                              : '내 프로그램에 저장',
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
                        ),
                        const SizedBox(height: 10),
                      ],
                      // 저장 버튼 (변경사항이 있을 때만, 채팅 외)
                      if (!widget.isFromChat && _hasChanges) ...[
                        GestureDetector(
                          onTap: _isSaving ? null : _saveChanges,
                          child: Container(
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primaryBlue,
                                  AppTheme.primaryBlue.withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryBlue.withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      '변경사항 저장',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      // Let's Start 버튼 (채팅에서 열었을 때는 숨김)
                      if (!widget.isFromChat)
                      GestureDetector(
                        onTap: _hasChanges
                            ? null
                            : () async {
                                final result = await Navigator.push<String>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => WorkoutExecutionScreen(
                                      savedProgram: _currentProgram,
                                    ),
                                  ),
                                );

                                if (!context.mounted) return;
                                if (result == 'completed') {
                                  // 운동 완료 → 홈 화면으로 이동 신호 전달
                                  Navigator.of(context).pop('workout_completed');
                                } else if (result == 'stopped') {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('운동이 중단되고 기록이 저장되었습니다.'),
                                    ),
                                  );
                                }
                              },
                        child: Container(
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: _hasChanges
                                ? null
                                : const LinearGradient(
                                    colors: [
                                      Color(0xFF00E676),
                                      Color(0xFF00C853),
                                    ],
                                  ),
                            color: _hasChanges
                                ? Colors.white.withOpacity(0.08)
                                : null,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: _hasChanges
                                ? null
                                : [
                                    BoxShadow(
                                      color: const Color(0xFF00E676)
                                          .withOpacity(0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_arrow_rounded,
                                  color: _hasChanges
                                      ? Colors.white.withOpacity(0.3)
                                      : Colors.white,
                                  size: 26,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Let's Start!",
                                  style: TextStyle(
                                    color: _hasChanges
                                        ? Colors.white.withOpacity(0.3)
                                        : Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryButton({
    required IconData icon,
    required VoidCallback? onTap,
    required bool enabled,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: enabled
              ? (color ?? AppTheme.primaryBlue).withOpacity(0.15)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled
                ? (color ?? AppTheme.primaryBlue).withOpacity(0.4)
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Icon(
          icon,
          color: enabled
              ? (color ?? AppTheme.primaryBlue)
              : Colors.white.withOpacity(0.3),
          size: 20,
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryBlue, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseCard(Exercise exercise, String section, int index) {
    // swim.com 스타일 포맷: "4 x 100 자유형 @ 2:15"
    final String mainLine;
    if (exercise.repeat > 1) {
      mainLine = '${exercise.repeat} x ${exercise.distance} ${exercise.description}';
    } else {
      mainLine = '${exercise.distance} ${exercise.description}';
    }

    return GestureDetector(
      onTap: _isEditMode ? () => _editExercise(section, index) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: AppTheme.cardGradient,
          borderRadius: BorderRadius.circular(12),
          border: _isEditMode
              ? Border.all(
                  color: AppTheme.primaryBlue.withOpacity(0.3),
                  width: 1,
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 메인 라인: "4 x 100 캐치업 드릴 @ 2:15"
            Row(
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.3,
                      ),
                      children: [
                        TextSpan(text: mainLine),
                        if (exercise.cycleTime != null) ...[
                          TextSpan(
                            text: ' @ ${exercise.cycleTime}',
                            style: TextStyle(
                              color: AppTheme.primaryBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_isEditMode)
                  Icon(Icons.edit,
                      size: 16,
                      color: AppTheme.primaryBlue.withOpacity(0.6)),
              ],
            ),
            // 코칭 노트
            if (exercise.notes.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                exercise.notes,
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white60),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 개별 운동 편집 바텀 시트
// ─────────────────────────────────────────────

class _ExerciseEditSheet extends StatefulWidget {
  final Exercise exercise;
  final Function(Exercise) onSave;

  const _ExerciseEditSheet({
    required this.exercise,
    required this.onSave,
  });

  @override
  State<_ExerciseEditSheet> createState() => _ExerciseEditSheetState();
}

class _ExerciseEditSheetState extends State<_ExerciseEditSheet> {
  late TextEditingController _descController;
  late TextEditingController _notesController;
  late TextEditingController _cycleTimeController;
  late int _distance;
  late int _repeat;
  late int _restSeconds;

  @override
  void initState() {
    super.initState();
    _descController =
        TextEditingController(text: widget.exercise.description);
    _notesController = TextEditingController(text: widget.exercise.notes);
    _cycleTimeController =
        TextEditingController(text: widget.exercise.cycleTime ?? '');
    _distance = widget.exercise.distance;
    _repeat = widget.exercise.repeat;
    _restSeconds = widget.exercise.restSeconds;
  }

  @override
  void dispose() {
    _descController.dispose();
    _notesController.dispose();
    _cycleTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
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

            const Text(
              '운동 수정',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),

            // 운동 설명
            _buildTextField(
              controller: _descController,
              label: '운동 설명',
              icon: Icons.description,
            ),
            const SizedBox(height: 20),

            // 거리
            _buildNumberControl(
              label: '거리 (m)',
              icon: Icons.straighten,
              value: _distance,
              step: 25,
              min: 25,
              onChanged: (v) => setState(() => _distance = v),
            ),
            const SizedBox(height: 16),

            // 횟수
            _buildNumberControl(
              label: '횟수',
              icon: Icons.repeat,
              value: _repeat,
              step: 1,
              min: 1,
              onChanged: (v) => setState(() => _repeat = v),
            ),
            const SizedBox(height: 16),

            // 휴식 시간
            _buildNumberControl(
              label: '휴식 (초)',
              icon: Icons.timer,
              value: _restSeconds,
              step: 5,
              min: 0,
              onChanged: (v) => setState(() => _restSeconds = v),
            ),
            const SizedBox(height: 16),

            // 사이클 타임
            _buildTextField(
              controller: _cycleTimeController,
              label: '사이클 타임 (예: 2:15)',
              icon: Icons.av_timer,
            ),
            const SizedBox(height: 16),

            // 총 거리 표시
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.pool,
                      color: AppTheme.primaryBlue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '총 거리: ${_distance * _repeat}m',
                    style: const TextStyle(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 노트
            _buildTextField(
              controller: _notesController,
              label: '코칭 노트',
              icon: Icons.lightbulb_outline,
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // 저장 버튼
            GestureDetector(
              onTap: () {
                final cycleText = _cycleTimeController.text.trim();
                final updated = widget.exercise.copyWith(
                  description: _descController.text.trim(),
                  distance: _distance,
                  repeat: _repeat,
                  restSeconds: _restSeconds,
                  notes: _notesController.text.trim(),
                  cycleTime: cycleText.isNotEmpty ? cycleText : null,
                );
                widget.onSave(updated);
                Navigator.pop(context);
              },
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryBlue,
                      AppTheme.primaryBlue.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryBlue.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    '적용',
                    style: TextStyle(
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
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
        prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.4)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppTheme.primaryBlue,
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildNumberControl({
    required String label,
    required IconData icon,
    required int value,
    required int step,
    required int min,
    required Function(int) onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.4), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 15,
            ),
          ),
        ),
        // 감소 버튼
        GestureDetector(
          onTap: () {
            if (value - step >= min) onChanged(value - step);
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.remove, color: Colors.white, size: 20),
          ),
        ),
        Container(
          width: 70,
          alignment: Alignment.center,
          child: Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // 증가 버튼
        GestureDetector(
          onTap: () => onChanged(value + step),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.add, color: AppTheme.primaryBlue, size: 20),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// 전체 일괄 수정 바텀 시트
// ─────────────────────────────────────────────

class _BulkEditSheet extends StatefulWidget {
  final ProgramLevel program;
  final Function(ProgramLevel) onSave;

  const _BulkEditSheet({
    required this.program,
    required this.onSave,
  });

  @override
  State<_BulkEditSheet> createState() => _BulkEditSheetState();
}

class _BulkEditSheetState extends State<_BulkEditSheet> {
  late double _restMultiplier;
  late double _repeatMultiplier;
  late int _globalRestAdjust;

  @override
  void initState() {
    super.initState();
    _restMultiplier = 1.0;
    _repeatMultiplier = 1.0;
    _globalRestAdjust = 0;
  }

  List<Exercise> _applyBulkEdit(List<Exercise> exercises) {
    return exercises.map((e) {
      int newRepeat = (e.repeat * _repeatMultiplier).round().clamp(1, 99);
      int newRest = ((e.restSeconds * _restMultiplier) + _globalRestAdjust)
          .round()
          .clamp(0, 600);
      return e.copyWith(repeat: newRepeat, restSeconds: newRest);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
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

            const Text(
              '전체 일괄 수정',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '모든 운동 항목에 동일하게 적용됩니다',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 28),

            // 횟수 배율
            _buildSliderControl(
              label: '횟수 조절',
              icon: Icons.repeat,
              value: _repeatMultiplier,
              min: 0.5,
              max: 2.0,
              divisions: 6,
              displayValue: '${(_repeatMultiplier * 100).round()}%',
              onChanged: (v) => setState(() => _repeatMultiplier = v),
            ),
            const SizedBox(height: 24),

            // 휴식 시간 배율
            _buildSliderControl(
              label: '휴식 시간 배율',
              icon: Icons.timer,
              value: _restMultiplier,
              min: 0.5,
              max: 2.0,
              divisions: 6,
              displayValue: '${(_restMultiplier * 100).round()}%',
              onChanged: (v) => setState(() => _restMultiplier = v),
            ),
            const SizedBox(height: 24),

            // 휴식 시간 추가/감소
            Row(
              children: [
                Icon(Icons.more_time,
                    color: Colors.white.withOpacity(0.4), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '휴식 시간 추가/감소',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 15,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    if (_globalRestAdjust - 5 >= -60) {
                      setState(() => _globalRestAdjust -= 5);
                    }
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child:
                        const Icon(Icons.remove, color: Colors.white, size: 20),
                  ),
                ),
                Container(
                  width: 70,
                  alignment: Alignment.center,
                  child: Text(
                    '${_globalRestAdjust >= 0 ? '+' : ''}${_globalRestAdjust}초',
                    style: TextStyle(
                      color: _globalRestAdjust == 0
                          ? Colors.white
                          : _globalRestAdjust > 0
                              ? Colors.green
                              : Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    if (_globalRestAdjust + 5 <= 60) {
                      setState(() => _globalRestAdjust += 5);
                    }
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add,
                        color: AppTheme.primaryBlue, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // 미리보기
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '변경 미리보기',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_repeatMultiplier != 1.0)
                    _buildPreviewItem(
                        '횟수', '×${_repeatMultiplier.toStringAsFixed(1)}'),
                  if (_restMultiplier != 1.0)
                    _buildPreviewItem(
                        '휴식 배율', '×${_restMultiplier.toStringAsFixed(1)}'),
                  if (_globalRestAdjust != 0)
                    _buildPreviewItem('휴식 추가',
                        '${_globalRestAdjust >= 0 ? '+' : ''}${_globalRestAdjust}초'),
                  if (_repeatMultiplier == 1.0 &&
                      _restMultiplier == 1.0 &&
                      _globalRestAdjust == 0)
                    Text(
                      '변경사항 없음',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 적용 버튼
            GestureDetector(
              onTap: () {
                final updated = widget.program.copyWith(
                  warmup: _applyBulkEdit(widget.program.warmup),
                  mainSet: _applyBulkEdit(widget.program.mainSet),
                  cooldown: _applyBulkEdit(widget.program.cooldown),
                );
                widget.onSave(updated);
                Navigator.pop(context);
              },
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryBlue,
                      AppTheme.primaryBlue.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryBlue.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    '전체 적용',
                    style: TextStyle(
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
  }

  Widget _buildSliderControl({
    required String label,
    required IconData icon,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String displayValue,
    required Function(double) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.4), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 15,
                ),
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: value == 1.0
                    ? Colors.white.withOpacity(0.1)
                    : AppTheme.primaryBlue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                displayValue,
                style: TextStyle(
                  color: value == 1.0 ? Colors.white70 : AppTheme.primaryBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: AppTheme.primaryBlue,
            inactiveTrackColor: Colors.white.withOpacity(0.1),
            thumbColor: AppTheme.primaryBlue,
            overlayColor: AppTheme.primaryBlue.withOpacity(0.2),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.6), fontSize: 14)),
          const SizedBox(width: 8),
          Text(value,
              style: const TextStyle(
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
        ],
      ),
    );
  }
}
