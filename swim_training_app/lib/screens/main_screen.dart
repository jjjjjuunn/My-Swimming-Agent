import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'program_screen.dart';
import 'my_page_screen.dart';
import 'chat_screen.dart';
import '../services/notification_service.dart';

class MainScreen extends StatefulWidget {
  final int initialTab;
  final String? initialChatMessage;
  const MainScreen({super.key, this.initialTab = 0, this.initialChatMessage});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;
  final _programTabNotifier = ValueNotifier<int>(0);

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _screens = [
      HomeScreen(
        onNavigateToProgram: () {
          setState(() => _currentIndex = 3);
        },
        onNavigateToMyProgram: () {
          _programTabNotifier.value = 0;
          setState(() => _currentIndex = 3);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _programTabNotifier.value = 1;
          });
        },
        onNavigateToCoach: () {
          setState(() => _currentIndex = 2);
        },
      ),
      const SearchScreen(),
      ChatScreen(initialMessage: widget.initialChatMessage),
      ProgramScreen(
        tabNotifier: _programTabNotifier,
        onNavigateToHome: () => setState(() => _currentIndex = 0),
      ),
      const MyPageScreen(),
    ];

    // FCM 알림 초기화 — 알림 탭 시 적절한 화면으로 이동
    NotificationService().initialize(
      onNotificationTap: _handleNotificationAction,
    );
  }

  void _handleNotificationAction(String action) {
    switch (action) {
      case 'condition_check':
      case 'workout_memo':
      case 'weekly_report':
        // 알림 탭 → 채팅 화면(코치)으로 이동
        setState(() => _currentIndex = 2);
    }
  }

  @override
  void dispose() {
    _programTabNotifier.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildNavItem(icon: Icons.home_rounded, label: 'Home', index: 0),
                _buildNavItem(icon: Icons.search, label: 'Search', index: 1),
                _buildNavItem(icon: Icons.pool, label: 'Coach', index: 2),
                _buildNavItem(icon: Icons.fitness_center, label: 'Program', index: 3),
                _buildNavItem(icon: Icons.person, label: 'My Page', index: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabTapped(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            gradient: isSelected ? AppTheme.primaryGradient : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.5),
                size: 22,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
