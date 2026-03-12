import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _isLogin = true;
  bool _isEmailLoading = false;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  bool _isKakaoLoading = false;
  bool _verificationEmailSent = false;
  String? _errorMessage;

  bool get _isAnyLoading =>
      _isEmailLoading || _isGoogleLoading || _isAppleLoading || _isKakaoLoading;

  Future<void> _handleEmailAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() { _errorMessage = '이메일과 비밀번호를 입력해주세요.'; });
      return;
    }
    if (!_isLogin && name.isEmpty) {
      setState(() { _errorMessage = '이름을 입력해주세요.'; });
      return;
    }
    setState(() { _isEmailLoading = true; _errorMessage = null; });

    try {
      if (_isLogin) {
        await _authService.signInWithEmail(email: email, password: password);
      } else {
        await _authService.signUpWithEmail(
          email: email,
          password: password,
          displayName: name,
        );
      }
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (msg == 'VERIFICATION_EMAIL_SENT') {
        setState(() {
          _isEmailLoading = false;
          _isLogin = true;
          _verificationEmailSent = true;
          _errorMessage = null;
        });
      } else if (msg == 'EMAIL_NOT_VERIFIED') {
        setState(() { _errorMessage = 'EMAIL_NOT_VERIFIED'; _isEmailLoading = false; });
      } else {
        setState(() { _errorMessage = msg; _isEmailLoading = false; });
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() { _isAppleLoading = true; _errorMessage = null; });
    try {
      final result = await _authService.signInWithApple();
      if (result == null) {
        setState(() { _isAppleLoading = false; });
        return;
      }
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Apple 로그인에 실패했습니다: $e';
        _isAppleLoading = false;
      });
    }
  }

  Future<void> _handleKakaoSignIn() async {
    setState(() { _isKakaoLoading = true; _errorMessage = null; });
    try {
      final result = await _authService.signInWithKakao();
      if (result == null) {
        setState(() { _isKakaoLoading = false; });
        return;
      }
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      String displayMsg;
      if (msg.contains('cancel') || msg.contains('Cancel') || msg.contains('canceled')) {
        displayMsg = '';  // 취소는 에러 표시 안 함
      } else if (msg.contains('ClientFailed') || msg.contains('misconfigured') || msg.contains('도메인')) {
        displayMsg = 'Kakao 앱 설정을 확인해주세요.';
      } else if (msg.contains('network') || msg.contains('Network') || msg.contains('SocketException')) {
        displayMsg = '네트워크 연결을 확인해주세요.';
      } else if (msg.contains('서버') || msg.contains('500') || msg.contains('Firebase')) {
        displayMsg = '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
      } else {
        displayMsg = 'Kakao 로그인에 실패했습니다.';
        // 디버그용 로그는 콘솔에만
        // ignore: avoid_print
        print('Kakao 로그인 오류 상세: $e');
      }
      setState(() {
        _errorMessage = displayMsg.isEmpty ? null : displayMsg;
        _isKakaoLoading = false;
      });
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() { _isGoogleLoading = true; _errorMessage = null; });

    try {
      final result = await _authService.signInWithGoogle();
      if (result == null) {
        // 사용자가 취소함
        setState(() { _isGoogleLoading = false; });
        return;
      }
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Google 로그인에 실패했습니다: $e';
        _isGoogleLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 로고
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.pool, size: 48, color: Colors.white),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'My Swimming Agent',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '당신만의 수영 코치',
                    style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(height: 24),

                  // 인증 메일 발송 성공 배너
                  if (_verificationEmailSent) ...[        
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.mark_email_read, color: Colors.green, size: 20),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              '인증 메일을 발송했습니다.\n이메일 확인 후 로그인해주세요.',
                              style: TextStyle(color: Colors.green, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 카드
                  Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: AppTheme.cardGradient,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 타이틀
                        Text(
                          _isLogin ? '로그인' : '회원가입',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 이름 (회원가입 첫 번째)
                        if (!_isLogin) ...[
                          _buildTextField(
                            controller: _nameController,
                            hint: '이름 (실명)',
                            icon: Icons.person,
                          ),
                          const SizedBox(height: 16),
                        ],

                        _buildTextField(
                          controller: _emailController,
                          hint: '이메일',
                          icon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _passwordController,
                          hint: '비밀번호',
                          icon: Icons.lock,
                          obscureText: true,
                          onSubmitted: _isLogin ? (_) => _handleEmailAuth() : null,
                        ),

                        const SizedBox(height: 24),

                        // 에러 메시지
                        if (_errorMessage != null) ...[
                          _errorMessage == 'EMAIL_NOT_VERIFIED'
                              ? _buildVerificationError()
                              : Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                                  ),
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: Colors.red, fontSize: 13),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                          const SizedBox(height: 16),
                        ],

                        // 이메일 버튼
                        _buildPrimaryButton(
                          label: _isLogin ? '로그인' : '회원가입',
                          isLoading: _isEmailLoading,
                          onPressed: _isAnyLoading ? null : _handleEmailAuth,
                        ),
                        const SizedBox(height: 16),

                        // 구분선
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.2))),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                '또는',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
                              ),
                            ),
                            Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.2))),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Google 버튼
                        _buildGoogleButton(),
                        const SizedBox(height: 8),

                        // Apple 버튼
                        _buildAppleButton(),
                        const SizedBox(height: 8),

                        // Kakao 버튼
                        _buildKakaoButton(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // 하단 전환 링크
                  GestureDetector(
                    onTap: _isAnyLoading
                        ? null
                        : () => setState(() {
                              _isLogin = !_isLogin;
                              _errorMessage = null;
                              _verificationEmailSent = false;
                            }),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6)),
                        children: [
                          TextSpan(text: _isLogin ? '계정이 없으신가요?  ' : '이미 계정이 있으신가요?  '),
                          TextSpan(
                            text: _isLogin ? 'Sign up' : '로그인',
                            style: const TextStyle(
                              color: AppTheme.primaryBlue,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                              decorationColor: AppTheme.primaryBlue,
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
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    void Function(String)? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        prefixIcon: Icon(icon, color: AppTheme.primaryBlue),
        filled: true,
        fillColor: AppTheme.cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primaryBlue.withValues(alpha: 0.6), width: 1),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required bool isLoading,
    required VoidCallback? onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: onPressed != null ? AppTheme.primaryGradient : null,
          color: onPressed == null ? Colors.grey.withValues(alpha: 0.3) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(
                label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return GestureDetector(
      onTap: _isAnyLoading ? null : _handleGoogleSignIn,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
        ),
        alignment: Alignment.center,
        child: _isGoogleLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.g_mobiledata, color: Colors.white, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    _isLogin ? 'Google로 로그인' : 'Google로 간편 회원가입',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildAppleButton() {
    return GestureDetector(
      onTap: _isAnyLoading ? null : _handleAppleSignIn,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
        ),
        alignment: Alignment.center,
        child: _isAppleLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.apple, color: Colors.white, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    _isLogin ? 'Apple로 로그인' : 'Apple로 간편 회원가입',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildKakaoButton() {
    return GestureDetector(
      onTap: _isAnyLoading ? null : _handleKakaoSignIn,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFFEE500),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: _isKakaoLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3C1E1E)),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/kakao_logo.png',
                    width: 22,
                    height: 22,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.chat_bubble, color: Color(0xFF3C1E1E), size: 22),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isLogin ? '카카오로 로그인' : '카카오로 간편 회원가입',
                    style: const TextStyle(
                      color: Color(0xFF3C1E1E),
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildVerificationError() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '이메일 인증이 필요합니다.\n받은 편지함을 확인해주세요.',
            style: TextStyle(color: Colors.orange, fontSize: 13),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _handleResendVerification,
            child: const Text(
              '인증 메일 재발송 →',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
                decorationColor: Colors.orange,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleResendVerification() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      setState(() { _errorMessage = '이메일과 비밀번호를 입력해주세요.'; });
      return;
    }
    try {
      await _authService.resendVerificationEmail(email: email, password: password);
      setState(() {
        _verificationEmailSent = true;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() { _errorMessage = e.toString(); });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }
}
