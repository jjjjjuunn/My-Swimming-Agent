import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import 'main_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String? _selectedPurpose;
  bool _isLoading = false;
  int _currentStep = 0; // 0: 목적 선택, 1: 닉네임 입력
  final TextEditingController _nicknameController = TextEditingController();

  final _purposes = [
    {'value': 'competition', 'label': '대회 준비', 'desc': '아마추어/프로 대회 준비 및 기록 향상', 'icon': Icons.emoji_events},
    {'value': 'hobby', 'label': '취미 생활', 'desc': '즐거운 수영과 여가 활동', 'icon': Icons.pool},
    {'value': 'fitness', 'label': '체력 향상', 'desc': '건강과 체력 증진을 위한 운동', 'icon': Icons.fitness_center},
    {'value': 'diet', 'label': '다이어트', 'desc': '체중 감량과 몸매 관리', 'icon': Icons.monitor_weight},
  ];

  Future<void> _completeOnboarding() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw '로그인 정보를 찾을 수 없습니다';

      final nickname = _nicknameController.text.trim();
      final Map<String, dynamic> data = {
        'purpose': _selectedPurpose,
        'onboardingCompleted': true,
        'onboardingCompletedAt': DateTime.now().toIso8601String(),
      };
      if (nickname.isNotEmpty) data['nickname'] = nickname;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(data);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _skipOnboarding() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw '로그인 정보를 찾을 수 없습니다';

      final nickname = _nicknameController.text.trim();
      final Map<String, dynamic> data = {
        'onboardingCompleted': true,
        'onboardingCompletedAt': DateTime.now().toIso8601String(),
      };
      if (nickname.isNotEmpty) data['nickname'] = nickname;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(data);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _currentStep == 0
                    ? _buildPurposeSelection()
                    : _buildNicknameInput(),
              ),
              _buildBottomButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _isLoading ? null : _skipOnboarding,
            child: Text(
              '건너뛰기',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurposeSelection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '환영합니다! 👋',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '수영하는 목적을 선택해주세요\nAI가 맞춤형 프로그램을 만들어드립니다',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 40),
          ..._purposes.map((purpose) => _buildPurposeCard(purpose)),
        ],
      ),
    );
  }

  Widget _buildPurposeCard(Map<String, dynamic> purpose) {
    final isSelected = _selectedPurpose == purpose['value'];

    return GestureDetector(
      onTap: () => setState(() => _selectedPurpose = purpose['value'] as String),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.cardGradient : null,
          color: isSelected ? null : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryBlue.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryBlue.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                purpose['icon'] as IconData,
                color: isSelected ? AppTheme.primaryBlue : Colors.white54,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    purpose['label'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    purpose['desc'] as String,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNicknameInput() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '닉네임을 설정해주세요 ✨',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '커뮤니티에서 사용할 닉네임이에요\n나중에 언제든지 변경할 수 있어요',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 40),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: TextField(
              controller: _nicknameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '닉네임 (커뮤니티용)',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                prefixIcon: Icon(Icons.tag, color: Colors.white.withValues(alpha: 0.5)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryDark,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: ElevatedButton(
          onPressed: _isLoading
              ? null
              : _currentStep == 0
                  ? (_selectedPurpose == null ? null : () => setState(() => _currentStep = 1))
                  : _completeOnboarding,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            disabledBackgroundColor: Colors.white24,
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  _currentStep == 0
                      ? (_selectedPurpose == null ? '목적을 선택해주세요' : '다음')
                      : '완료',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
        ),
      ),
    );
  }
}
