import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/main_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const SwimTrainingApp());
}

class SwimTrainingApp extends StatelessWidget {
  const SwimTrainingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Swim Training',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // 로딩 중
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          
          // 로그인 상태 확인
          if (snapshot.hasData) {
            final user = snapshot.data!;

            // 이메일 미인증 차단 (Google 로그인은 항상 인증됨)
            final isEmailProvider = user.providerData.any((p) => p.providerId == 'password');
            if (isEmailProvider && !user.emailVerified) {
              // signOut은 auth_service가 처리하므로 여기선 화면만 유지
              return const LoginScreen();
            }

            // 온보딩 완료 여부 확인
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                // 온보딩 완료 여부 체크
                final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                final onboardingCompleted = userData?['onboardingCompleted'] ?? false;

                if (onboardingCompleted) {
                  return const MainScreen();
                } else {
                  return const OnboardingScreen();
                }
              },
            );
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}