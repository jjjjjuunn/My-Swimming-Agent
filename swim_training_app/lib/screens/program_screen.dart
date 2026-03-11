import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'program_create_tab.dart';
import 'saved_programs_screen.dart';

class ProgramScreen extends StatefulWidget {
  final ValueNotifier<int>? tabNotifier;
  final VoidCallback? onNavigateToHome;

  const ProgramScreen({super.key, this.tabNotifier, this.onNavigateToHome});

  @override
  State<ProgramScreen> createState() => _ProgramScreenState();
}

class _ProgramScreenState extends State<ProgramScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    widget.tabNotifier?.addListener(_onTabNotified);
  }

  void _onTabNotified() {
    final idx = widget.tabNotifier?.value ?? 0;
    if (_tabController.index != idx) {
      _tabController.animateTo(idx);
    }
  }

  @override
  void dispose() {
    widget.tabNotifier?.removeListener(_onTabNotified);
    _tabController.dispose();
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
              // 탭 바
              Container(
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withOpacity(0.5),
                  labelStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.normal,
                  ),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.auto_awesome),
                      text: '프로그램 생성',
                    ),
                    Tab(
                      icon: Icon(Icons.bookmark),
                      text: '내 프로그램',
                    ),
                  ],
                ),
              ),
              
              // 탭 뷰
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    ProgramCreateTab(
                      onProgramSaved: () {
                        // 저장 완료 후 "내 프로그램" 탭으로 이동
                        _tabController.animateTo(1);
                      },
                    ),
                    SavedProgramsScreen(onWorkoutCompleted: widget.onNavigateToHome),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
