import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSaving = false;
  UserModel? _userData;
  String? _errorMessage;
  String? _selectedPurpose;

  final _purposes = [
    {'value': 'competition', 'label': '대회 준비'},
    {'value': 'hobby', 'label': '취미 생활'},
    {'value': 'fitness', 'label': '체력 향상'},
    {'value': 'diet', 'label': '다이어트'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userData = await _authService.getUserData(user.uid);
      if (mounted) {
        setState(() {
          _userData = userData;
          _nameController.text = userData?.displayName ?? '';
          _nicknameController.text = userData?.nickname ?? '';
          _selectedPurpose = userData?.purpose;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveChanges() async {
    final newName = _nameController.text.trim();
    final newNickname = _nicknameController.text.trim();

    if (newName.isEmpty) {
      setState(() => _errorMessage = '이름을 입력해주세요.');
      return;
    }

    if (newNickname.isEmpty) {
      setState(() => _errorMessage = '닉네임을 입력해주세요.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw '로그인 정보를 찾을 수 없습니다';

      // 이름 변경 (항상 가능)
      if (newName != _userData?.displayName) {
        await _authService.updateDisplayName(newName);
      }

      // 닉네임 변경 (4주 제한)
      if (newNickname != _userData?.nickname) {
        await _authService.updateNickname(newNickname);
      }

      // 목적 변경 (항상 가능)
      final updateData = <String, dynamic>{};
      if (_selectedPurpose != _userData?.purpose) {
        updateData['purpose'] = _selectedPurpose;
      }

      if (updateData.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update(updateData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('프로필이 수정되었습니다!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // 변경됨을 알림
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isSaving = false;
      });
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
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue))
              : Column(
                  children: [
                    // 헤더
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.cardColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            '프로필 수정',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 폼
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 프로필 이미지
                            Center(
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 50,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),

                            // 이름 필드
                            Text(
                              '이름 (실명)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _nameController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: '이름을 입력하세요',
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                prefixIcon: const Icon(Icons.person, color: AppTheme.primaryBlue),
                                filled: true,
                                fillColor: AppTheme.cardColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '언제든지 변경할 수 있습니다.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // 닉네임 필드
                            Row(
                              children: [
                                Text(
                                  '닉네임 (커뮤니티용)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                                const Spacer(),
                                if (_userData != null && !_userData!.canChangeNickname)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${_userData!.daysUntilNicknameChange}일 후 변경 가능',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _nicknameController,
                              style: const TextStyle(color: Colors.white),
                              enabled: _userData?.canChangeNickname ?? true,
                              decoration: InputDecoration(
                                hintText: '닉네임을 입력하세요',
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                prefixIcon: const Icon(Icons.tag, color: AppTheme.primaryBlue),
                                filled: true,
                                fillColor: _userData?.canChangeNickname ?? true
                                    ? AppTheme.cardColor
                                    : AppTheme.cardColor.withOpacity(0.5),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '닉네임은 4주에 한 번만 변경할 수 있습니다.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // 수영 목적
                            Text(
                              '수영 목적',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _purposes.map((purpose) {
                                final isSelected = _selectedPurpose == purpose['value'];
                                return GestureDetector(
                                  onTap: () => setState(() => _selectedPurpose = purpose['value'] as String?),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppTheme.primaryBlue.withOpacity(0.2)
                                          : AppTheme.cardColor,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppTheme.primaryBlue
                                            : Colors.white.withOpacity(0.2),
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: Text(
                                      purpose['label'] as String,
                                      style: TextStyle(
                                        color: isSelected ? AppTheme.primaryBlue : Colors.white,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 32),

                            // 에러 메시지
                            if (_errorMessage != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.withOpacity(0.5)),
                                ),
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.red, fontSize: 13),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // 저장 버튼
                            GestureDetector(
                              onTap: _isSaving ? null : _saveChanges,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  gradient: _isSaving ? null : AppTheme.primaryGradient,
                                  color: _isSaving ? Colors.grey : null,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: _isSaving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          '저장하기',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ),
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
}
