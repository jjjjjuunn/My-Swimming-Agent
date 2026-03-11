import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ProgramScreen extends StatefulWidget {
  const ProgramScreen({super.key});

  @override
  State<ProgramScreen> createState() => _ProgramScreenState();
}

class _ProgramScreenState extends State<ProgramScreen> {
  // 선택된 카테고리들
  final Set<String> _selectedCategories = {};
  
  // 운동 강도
  String _intensity = 'moderate';
  
  // 프로그램 생성 중 상태
  bool _isGenerating = false;
  
  // 카테고리 목록
  final List<Map<String, dynamic>> _categories = [
    {'id': 'IM', 'name': 'IM (개인혼영)', 'icon': Icons.pool},
    {'id': 'drill', 'name': '드릴 훈련', 'icon': Icons.fitness_center},
    {'id': 'butterfly', 'name': '접영', 'icon': Icons.waves},
    {'id': 'freestyle', 'name': '자유형', 'icon': Icons.directions_run},
    {'id': 'backstroke', 'name': '배영', 'icon': Icons.airline_seat_flat},
    {'id': 'breaststroke', 'name': '평영', 'icon': Icons.rowing},
  ];

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '맞춤 프로그램 생성',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'AI가 3가지 레벨의 프로그램을 제안해드려요',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                              BoxShadow(
                                color: AppTheme.primaryBlue.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.fitness_center,
                            color: Colors.white,
                            size: 64,
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          '🏊 Coming Soon!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '맞춤형 훈련 프로그램을\n준비하고 있어요!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.6),
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // 예정 기능 카드들
                        _buildFeaturePreview(
                          icon: Icons.calendar_today,
                          title: '주간 훈련 계획',
                          description: '체계적인 주간 훈련 스케줄',
                        ),
                        const SizedBox(height: 12),
                        _buildFeaturePreview(
                          icon: Icons.timer,
                          title: '인터벌 타이머',
                          description: '수영 전용 인터벌 훈련',
                        ),
                        const SizedBox(height: 12),
                        _buildFeaturePreview(
                          icon: Icons.trending_up,
                          title: '기록 추적',
                          description: '거리, 시간, 페이스 기록',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturePreview({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryBlue.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: AppTheme.primaryBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.lock_outline,
            color: Colors.white.withOpacity(0.3),
            size: 20,
          ),
        ],
      ),
    );
  }
}
