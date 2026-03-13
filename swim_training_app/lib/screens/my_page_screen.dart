import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _nickname;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _nickname = doc.data()?['nickname'];
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await _showConfirmDialog(
      title: '로그아웃',
      message: '정말 로그아웃 하시겠습니까?',
    );

    if (confirm == true) {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _handleDeleteAccount() async {
    final confirm = await _showConfirmDialog(
      title: '계정 삭제',
      message: '정말 계정을 삭제하시겠습니까?\n모든 데이터가 삭제되며 복구할 수 없습니다.',
      isDestructive: true,
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      
      try {
        await _authService.deleteAccount();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('계정 삭제 실패: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          message,
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              '취소',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              '확인',
              style: TextStyle(
                color: isDestructive ? Colors.red : AppTheme.primaryBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.backgroundGradient,
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 헤더
                    const Text(
                      'My Page',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // 프로필 카드
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: AppTheme.cardGradient,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.primaryBlue.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          // 프로필 이미지
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(40),
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // 닉네임
                          Text(
                            _nickname ?? '닉네임 없음',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          
                          // 이름
                          Text(
                            user?.displayName ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 8),
                          
                          // 이메일
                          Text(
                            user?.email ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // 메뉴 섹션
                    Text(
                      '계정 설정',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // 메뉴 항목들
                    _buildMenuItem(
                      icon: Icons.edit,
                      title: '프로필 수정',
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EditProfileScreen(),
                          ),
                        );
                        // 프로필이 수정되면 다시 로드
                        if (result == true) {
                          _loadUserData();
                        }
                      },
                    ),
                    _buildMenuItem(
                      icon: Icons.notifications_outlined,
                      title: '알림 설정',
                      onTap: () => _showNotificationSettings(context),
                    ),
                    _buildMenuItem(
                      icon: Icons.calendar_today,
                      title: '수영 스케줄',
                      onTap: () => _showScheduleSettings(context),
                    ),
                    _buildMenuItem(
                      icon: Icons.pool,
                      title: '수영장 길이 설정',
                      onTap: () => _showPoolLengthSettings(context),
                    ),
                    _buildMenuItem(
                      icon: Icons.logout,
                      title: '로그아웃',
                      onTap: _handleLogout,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // 위험 구역
                    Text(
                      '위험 구역',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    _buildMenuItem(
                      icon: Icons.delete_forever,
                      title: '계정 삭제',
                      onTap: _handleDeleteAccount,
                      isDestructive: true,
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // 앱 정보
                    Center(
                      child: Text(
                        'Swim Training App v1.0.0',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // 로딩 오버레이
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryBlue,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: AppTheme.primaryBlue,
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }


  void _showNotificationSettings(BuildContext context) async {
    final notifService = NotificationService();
    final prefs = await notifService.getPreferences();

    bool morningEnabled = prefs['morning_enabled'] ?? true;
    String morningTime = prefs['morning_time'] ?? '07:00';
    bool postWorkoutEnabled = prefs['post_workout_enabled'] ?? true;
    bool weeklyReportEnabled = prefs['weekly_report_enabled'] ?? true;

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '알림 설정',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text('아침 컨디션 체크', style: TextStyle(color: Colors.white)),
                subtitle: Text('매일 $morningTime에 컨디션을 물어봐요', style: const TextStyle(color: Colors.white54)),
                value: morningEnabled,
                activeColor: const Color(0xFF00D2FF),
                onChanged: (v) => setModalState(() => morningEnabled = v),
              ),
              if (morningEnabled)
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: GestureDetector(
                    onTap: () async {
                      final parts = morningTime.split(':');
                      final picked = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay(
                          hour: int.parse(parts[0]),
                          minute: int.parse(parts[1]),
                        ),
                      );
                      if (picked != null) {
                        setModalState(() {
                          morningTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                        });
                      }
                    },
                    child: Row(
                      children: [
                        Icon(Icons.access_time, size: 18, color: const Color(0xFF00D2FF)),
                        const SizedBox(width: 8),
                        Text(
                          morningTime,
                          style: const TextStyle(
                            color: Color(0xFF00D2FF),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '변경',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              SwitchListTile(
                title: const Text('운동 후 메모 알림', style: TextStyle(color: Colors.white)),
                subtitle: const Text('운동이 끝나면 메모를 남길 수 있어요', style: TextStyle(color: Colors.white54)),
                value: postWorkoutEnabled,
                activeColor: const Color(0xFF00D2FF),
                onChanged: (v) => setModalState(() => postWorkoutEnabled = v),
              ),
              SwitchListTile(
                title: const Text('주간 리포트', style: TextStyle(color: Colors.white)),
                subtitle: const Text('매주 훈련 요약을 보내드려요', style: TextStyle(color: Colors.white54)),
                value: weeklyReportEnabled,
                activeColor: const Color(0xFF00D2FF),
                onChanged: (v) => setModalState(() => weeklyReportEnabled = v),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D2FF),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final success = await notifService.savePreferences(
                      morningEnabled: morningEnabled,
                      morningTime: morningTime,
                      postWorkoutEnabled: postWorkoutEnabled,
                      weeklyReportEnabled: weeklyReportEnabled,
                    );
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(success ? '알림 설정이 저장되었습니다' : '저장에 실패했습니다')),
                      );
                    }
                  },
                  child: const Text('저장', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPoolLengthSettings(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    int currentLength = doc.data()?['pool_length'] ?? 25;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        int selected = currentLength;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '수영장 길이 설정',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '주로 수영하는 수영장의 길이를 선택해주세요',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  ...([25, 50]).map((len) {
                    final isActive = selected == len;
                    return GestureDetector(
                      onTap: () => setModalState(() => selected = len),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppTheme.primaryBlue.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isActive
                                ? AppTheme.primaryBlue.withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isActive ? Icons.check_circle : Icons.circle_outlined,
                              color: isActive ? AppTheme.primaryBlue : Colors.white38,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              len == 25 ? '25m (숏코스)' : '50m (롱코스)',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .update({'pool_length': selected, 'pool_unit': 'm'});
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('수영장 길이가 ${selected}m로 설정되었습니다')),
                          );
                        }
                      },
                      child: const Text('저장', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: isDestructive 
              ? Border.all(color: Colors.red.withOpacity(0.3))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Colors.red : Colors.white,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: isDestructive ? Colors.red : Colors.white,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }

  void _showScheduleSettings(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users').doc(user.uid).get();
    final rawSchedule =
        doc.data()?['swim_schedule'] as Map<String, dynamic>? ?? {};

    const weekdayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    const weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

    Map<String, TimeOfDay?> scheduleMap = {};
    for (final entry in rawSchedule.entries) {
      final parts = (entry.value as String).split(':');
      scheduleMap[entry.key] =
          TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '수영 스케줄',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '수영하는 요일과 시간을 설정하세요',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5), fontSize: 14),
              ),
              const SizedBox(height: 20),
              ...List.generate(7, (i) {
                final dayKey = weekdayKeys[i];
                final isSelected = scheduleMap.containsKey(dayKey);
                final time = scheduleMap[dayKey];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.cardColor
                        : Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryBlue.withOpacity(0.3)
                          : Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          setModalState(() {
                            if (isSelected) {
                              scheduleMap.remove(dayKey);
                            } else {
                              scheduleMap[dayKey] =
                                  const TimeOfDay(hour: 6, minute: 0);
                            }
                          });
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryBlue.withOpacity(0.2)
                                : Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              weekdayLabels[i],
                              style: TextStyle(
                                color: isSelected
                                    ? AppTheme.primaryBlue
                                    : Colors.white38,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (isSelected)
                        GestureDetector(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime:
                                  time ?? const TimeOfDay(hour: 6, minute: 0),
                              builder: (context, child) {
                                return Theme(
                                  data: ThemeData.dark().copyWith(
                                    colorScheme: const ColorScheme.dark(
                                      primary: AppTheme.primaryBlue,
                                      surface: AppTheme.primaryDark,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setModalState(
                                  () => scheduleMap[dayKey] = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.access_time,
                                    color: Colors.white70, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  time != null
                                      ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                                      : '06:00',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Text(
                          '탭하여 추가',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D2FF),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final schedule = <String, String>{};
                    for (final entry in scheduleMap.entries) {
                      if (entry.value != null) {
                        final t = entry.value!;
                        schedule[entry.key] =
                            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                      }
                    }
                    try {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .update({
                        'swim_schedule': schedule.isEmpty
                            ? FieldValue.delete()
                            : schedule,
                      });
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('수영 스케줄이 저장되었습니다')),
                        );
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('저장에 실패했습니다')),
                        );
                      }
                    }
                  },
                  child: const Text('저장',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
