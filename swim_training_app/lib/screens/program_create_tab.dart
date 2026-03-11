import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../models/program_request.dart';
import '../models/program_response.dart';
import '../models/saved_program.dart';
import '../services/program_api_service.dart';
import '../services/local_storage_service.dart';

class ProgramCreateTab extends StatefulWidget {
  final VoidCallback? onProgramSaved;
  
  const ProgramCreateTab({super.key, this.onProgramSaved});

  @override
  State<ProgramCreateTab> createState() => _ProgramCreateTabState();
}

class _ProgramCreateTabState extends State<ProgramCreateTab> {
  String? _trainingGoal;
  final Set<String> _selectedStrokes = {};
  bool _useEquipment = false;
  final Set<String> _selectedEquipment = {};
  bool _isGenerating = false;
  final _apiService = ProgramApiService();
  String? _userPurpose;

  @override
  void initState() {
    super.initState();
    _loadUserPurpose();
  }

  Future<void> _loadUserPurpose() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists && mounted) {
      setState(() => _userPurpose = doc.data()?['purpose'] as String?);
    }
  }

  final List<Map<String, dynamic>> _trainingGoals = [
    {'id': 'speed', 'name': '스프린트'},
    {'id': 'endurance', 'name': '장거리'},
    {'id': 'technique', 'name': '드릴'},
    {'id': 'overall', 'name': '밸런스'},
  ];

  final List<Map<String, dynamic>> _strokes = [
    {'id': 'freestyle', 'name': '자유형'},
    {'id': 'butterfly', 'name': '접영'},
    {'id': 'backstroke', 'name': '배영'},
    {'id': 'breaststroke', 'name': '평영'},
    {'id': 'IM', 'name': 'IM'},
  ];

  final List<Map<String, dynamic>> _equipment = [
    {'id': 'fins', 'name': '오리발'},
    {'id': 'snorkel', 'name': '스노클'},
    {'id': 'paddles', 'name': '패들'},
    {'id': 'kickboard', 'name': '킥보드'},
    {'id': 'pull_buoy', 'name': '풀부이'},
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 훈련 목표 선택 (레벨 선택 제거됨)
          _buildSectionTitle('훈련 목표 (1개 선택)'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _trainingGoals.map((goal) {
              final isSelected = _trainingGoal == goal['id'];
              return _buildChip(
                goal['name'],
                isSelected,
                () {
                  setState(() {
                    _trainingGoal = goal['id'];
                              });
                            },
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 24),

                      // 종목 선택
                      _buildSectionTitle('집중 종목 (중복 가능)'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _strokes.map((stroke) {
                          final isSelected = _selectedStrokes.contains(stroke['id']);
                          return _buildChip(
                            stroke['name'],
                            isSelected,
                            () {
                              setState(() {
                                if (isSelected) {
                                  _selectedStrokes.remove(stroke['id']);
                                } else {
                                  _selectedStrokes.add(stroke['id']);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 24),

                      // 도구 사용 ON/OFF
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionTitle('도구 사용'),
                          Switch(
                            value: _useEquipment,
                            onChanged: (value) {
                              setState(() {
                                _useEquipment = value;
                                if (!value) {
                                  _selectedEquipment.clear();
                                }
                              });
                            },
                            activeColor: AppTheme.primaryBlue,
                          ),
                        ],
                      ),

                      // 도구 선택 (애니메이션)
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: _useEquipment
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      // 전체선택 칩
                                      _buildChip(
                                        _selectedEquipment.length == _equipment.length ? '전체해제' : '전체선택',
                                        _selectedEquipment.length == _equipment.length,
                                        () {
                                          setState(() {
                                            if (_selectedEquipment.length == _equipment.length) {
                                              _selectedEquipment.clear();
                                            } else {
                                              _selectedEquipment.addAll(
                                                _equipment.map((e) => e['id'] as String),
                                              );
                                            }
                                          });
                                        },
                                      ),
                                      ..._equipment.map((equip) {
                                        final isSelected = _selectedEquipment.contains(equip['id']);
                                        return _buildChip(
                                          equip['name'],
                                          isSelected,
                                          () {
                                            setState(() {
                                              if (isSelected) {
                                                _selectedEquipment.remove(equip['id']);
                                              } else {
                                                _selectedEquipment.add(equip['id']);
                                              }
                                            });
                                          },
                                        );
                                      }),
                                    ],
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),

                      const SizedBox(height: 40),

                      // 생성 버튼
                      GestureDetector(
                        onTap: _canGenerate ? _generateProgram : null,
                        child: Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: _canGenerate
                                ? AppTheme.primaryGradient
                                : null,
                            color: _canGenerate ? null : AppTheme.cardColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: _canGenerate
                                ? [
                                    BoxShadow(
                                      color: AppTheme.primaryBlue.withOpacity(0.4),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: _isGenerating
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.auto_awesome,
                                        size: 20,
                                        color: _canGenerate
                                            ? Colors.white
                                            : Colors.white.withOpacity(0.3),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '프로그램 생성하기',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: _canGenerate
                                              ? Colors.white
                                              : Colors.white.withOpacity(0.3),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 40), // 여백 추가
                    ],
                  ),
                );
  }

  bool get _canGenerate =>
      _trainingGoal != null &&
      _selectedStrokes.isNotEmpty &&
      !_isGenerating;

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.primaryGradient : null,
          color: isSelected ? null : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : AppTheme.primaryBlue.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Future<void> _generateProgram() async {
    if (!_canGenerate) return;

    setState(() => _isGenerating = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final request = ProgramRequest(
        trainingGoal: _trainingGoal!,
        strokes: _selectedStrokes.toList(),
        equipment: _useEquipment && _selectedEquipment.isNotEmpty
            ? _selectedEquipment.toList()
            : null,
        userId: user?.uid,
        purpose: _userPurpose,
      );

      final response = await _apiService.generateProgram(request);

      if (mounted) {
        // 3개 레벨 선택 화면으로 이동
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LevelSelectionScreen(
              programResponse: response,
              equipment: _useEquipment && _selectedEquipment.isNotEmpty
                  ? _selectedEquipment.toList()
                  : null,
              onProgramSaved: widget.onProgramSaved,
            ),
          ),
        );
        
        // 저장 완료 후 탭 이동
        if (result == 'saved' && widget.onProgramSaved != null) {
          widget.onProgramSaved!();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('생성 실패: $e'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }
}

// 3개 레벨 선택 화면
class LevelSelectionScreen extends StatelessWidget {
  final ProgramResponse programResponse;
  final List<String>? equipment;
  final VoidCallback? onProgramSaved;

  const LevelSelectionScreen({
    super.key,
    required this.programResponse,
    this.equipment,
    this.onProgramSaved,
  });

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
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '레벨 선택',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '자신에게 맞는 레벨을 선택하세요',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildLevelCard(
                      context,
                      '초급',
                      programResponse.beginner,
                      AppTheme.warmupOrange,
                      programResponse.trainingGoal,
                      programResponse.strokes,
                      onProgramSaved,
                    ),
                    const SizedBox(height: 16),
                    _buildLevelCard(
                      context,
                      '중급',
                      programResponse.intermediate,
                      AppTheme.primaryBlue,
                      programResponse.trainingGoal,
                      programResponse.strokes,
                      onProgramSaved,
                    ),
                    const SizedBox(height: 16),
                    _buildLevelCard(
                      context,
                      '고급',
                      programResponse.advanced,
                      AppTheme.mainsetRed,
                      programResponse.trainingGoal,
                      programResponse.strokes,
                      onProgramSaved,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelCard(
    BuildContext context,
    String levelLabel,
    ProgramLevel program,
    Color accentColor,
    String trainingGoal,
    List<String> strokes,
    VoidCallback? onProgramSaved,
  ) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProgramDetailScreen(
              program: program,
              levelLabel: levelLabel,
              accentColor: accentColor,
              trainingGoal: trainingGoal,
              strokes: strokes,
              equipment: equipment,
              onProgramSaved: onProgramSaved,
            ),
          ),
        );
        
        // 저장 완료 시 상위로 전달
        if (result == 'saved') {
          Navigator.pop(context, 'saved');
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              accentColor.withOpacity(0.2),
              accentColor.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  levelLabel,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: accentColor, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              program.description,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildInfoChip(
                  Icons.pool,
                  '${program.totalDistance}m',
                  accentColor,
                ),
                const SizedBox(width: 12),
                _buildInfoChip(
                  Icons.access_time,
                  '${program.estimatedMinutes}분',
                  accentColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// 생성된 프로그램 상세 화면
class ProgramDetailScreen extends StatefulWidget {
  final ProgramLevel program;
  final String levelLabel;
  final Color accentColor;
  final String trainingGoal;
  final List<String> strokes;
  final List<String>? equipment;
  final VoidCallback? onProgramSaved;

  const ProgramDetailScreen({
    super.key,
    required this.program,
    required this.levelLabel,
    required this.accentColor,
    required this.trainingGoal,
    required this.strokes,
    this.equipment,
    this.onProgramSaved,
  });

  @override
  State<ProgramDetailScreen> createState() => _ProgramDetailScreenState();
}

class _ProgramDetailScreenState extends State<ProgramDetailScreen> {
  bool _isSaving = false;

  Future<void> _saveProgram() async {
    setState(() => _isSaving = true);
    
    try {
      // 저장 다이얼로그 표시
      final result = await showDialog<Map<String, String>>(
        context: context,
        builder: (context) => const _SaveProgramDialog(),
      );
      
      if (result == null) {
        setState(() => _isSaving = false);
        return;
      }
      
      // 프로그램 저장
      final storageService = LocalStorageService();
      final savedProgram = SavedProgram(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: result['title']!,
        program: widget.program,
        originalProgram: widget.program, // 최초 원본 저장
        levelLabel: widget.levelLabel,
        savedAt: DateTime.now(),
        memo: result['memo'],
        trainingGoal: widget.trainingGoal,
        strokes: widget.strokes,
        equipment: widget.equipment,
      );
      
      await storageService.saveProgram(savedProgram);
      
      if (mounted) {
        // 저장 성공 다이얼로그 표시
        final action = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 체크 아이콘
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Colors.green.shade400, Colors.green.shade600],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 제목
                  const Text(
                    '저장 완료',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 메시지
                  Text(
                    '프로그램이 성공적으로 저장되었습니다',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // 버튼들
                  Row(
                    children: [
                      // 닫기 버튼
                      Expanded(
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.grey.shade700,
                                Colors.grey.shade800,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => Navigator.pop(context, 'close'),
                              borderRadius: BorderRadius.circular(12),
                              child: const Center(
                                child: Text(
                                  '닫기',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 내 프로그램 가기 버튼
                      Expanded(
                        flex: 2,
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primaryBlue,
                                AppTheme.primaryBlue.withOpacity(0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryBlue.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => Navigator.pop(context, 'go_to_saved'),
                              borderRadius: BorderRadius.circular(12),
                              child: const Center(
                                child: Text(
                                  '내 프로그램 가기',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
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
        
        if (action == 'go_to_saved') {
          // 저장 완료 신호 전달 후 모든 화면 닫기
          Navigator.of(context).pop('saved');
        }
      }
    } catch (e) {
      if (mounted) {
        // 저장 개수 제한 에러를 다이얼로그로 표시
        if (e.toString().contains('최대')) {
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
                    const Icon(Icons.error_outline, color: Colors.orange, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      '저장 공간 부족',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      e.toString().replaceAll('Exception: ', ''),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
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
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(12),
                          child: const Center(
                            child: Text(
                              '확인',
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
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('저장 실패: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
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
          child: Column(
            children: [
              // 헤더
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.levelLabel} 프로그램',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            widget.program.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.6),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // 저장 버튼
                    IconButton(
                      onPressed: _isSaving ? null : _saveProgram,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.bookmark_border, color: Colors.white),
                      tooltip: '프로그램 저장',
                    ),
                  ],
                ),
              ),

              // 프로그램 정보
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
                        '${widget.program.totalDistance}m',
                        '총 거리',
                      ),
                      _buildInfoItem(
                        Icons.access_time,
                        '${widget.program.estimatedMinutes}분',
                        '예상 시간',
                      ),
                      _buildInfoItem(
                        Icons.fitness_center,
                        widget.levelLabel,
                        '난이도',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 운동 목록
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildSectionHeader('워밍업', Icons.wb_sunny, Colors.orange),
                    const SizedBox(height: 12),
                    ...widget.program.warmup.map((e) => _buildExerciseCard(e)),
                    
                    const SizedBox(height: 24),
                    _buildSectionHeader('메인 세트', Icons.fitness_center, Colors.red),
                    const SizedBox(height: 12),
                    ...widget.program.mainSet.map((e) => _buildExerciseCard(e)),
                    
                    const SizedBox(height: 24),
                    _buildSectionHeader('쿨다운', Icons.ac_unit, Colors.blue),
                    const SizedBox(height: 12),
                    ...widget.program.cooldown.map((e) => _buildExerciseCard(e)),
                    
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              // 하단 저장 버튼
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: GestureDetector(
                  onTap: _isSaving ? null : _saveProgram,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: _isSaving ? null : AppTheme.primaryGradient,
                      color: _isSaving ? Colors.white.withOpacity(0.08) : null,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: _isSaving
                          ? null
                          : [
                              BoxShadow(
                                color: AppTheme.primaryBlue.withOpacity(0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: Center(
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bookmark_add_rounded, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  '내 프로그램에 저장하기',
                                  style: TextStyle(
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
              ),
            ],
          ),
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

  Widget _buildExerciseCard(Exercise exercise) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryBlue.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            exercise.description,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              _buildExerciseDetail(Icons.straighten, '${exercise.distance}m'),
              const SizedBox(width: 16),
              _buildExerciseDetail(Icons.repeat, '${exercise.repeat}회'),
              if (exercise.restSeconds > 0) ...[
                const SizedBox(width: 16),
                _buildExerciseDetail(Icons.access_time, '휴식 ${exercise.restSeconds}초'),
              ],
            ],
          ),

          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '총 ${exercise.totalDistance}m',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlue,
              ),
            ),
          ),

          if (exercise.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.amber.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    color: Colors.amber,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      exercise.notes,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.8),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExerciseDetail(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryBlue, size: 16),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}

// 프로그램 저장 다이얼로그
class _SaveProgramDialog extends StatefulWidget {
  const _SaveProgramDialog({super.key});

  @override
  State<_SaveProgramDialog> createState() => _SaveProgramDialogState();
}

class _SaveProgramDialogState extends State<_SaveProgramDialog> {
  final _titleController = TextEditingController();
  final _memoController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.bookmark_rounded,
                    color: AppTheme.primaryBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '프로그램 저장',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // 제목 입력
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                labelText: '제목',
                labelStyle: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                ),
                hintText: '예: 월요일 스프린트 훈련',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
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
                    width: 1,
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
            ),
            const SizedBox(height: 16),
            // 메모 입력
            TextField(
              controller: _memoController,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: '메모 (선택)',
                labelStyle: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                ),
                hintText: '오늘의 목표, 느낀 점 등',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
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
                    width: 1,
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
            ),
            const SizedBox(height: 24),
            // 버튼들
            Row(
              children: [
                // 취소 버튼
                Expanded(
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.grey.shade700,
                          Colors.grey.shade800,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
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
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 저장 버튼
                Expanded(
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryBlue,
                          AppTheme.primaryBlue.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          if (_titleController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('제목을 입력해주세요')),
                            );
                            return;
                          }
                          Navigator.pop(context, {
                            'title': _titleController.text.trim(),
                            'memo': _memoController.text.trim(),
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: const Center(
                          child: Text(
                            '저장',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
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
    );
  }
}
