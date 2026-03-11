import 'package:flutter/material.dart';

class AppTheme {
  // 주요 색상 - swim.com 스타일
  static const Color primaryDark = Color(0xFF0A1628);      // 진한 네이비
  static const Color primaryBlue = Color(0xFF00B4D8);      // 밝은 시안 블루
  static const Color accentBlue = Color(0xFF0077B6);       // 딥 블루
  static const Color surfaceColor = Color(0xFF1A2744);     // 카드 배경
  static const Color cardColor = Color(0xFF243B55);        // 카드 색상
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB0BEC5);
  static const Color success = Color(0xFF00E676);          // 녹색 강조
  
  // 운동 세트별 색상
  static const Color warmupOrange = Color(0xFFFF9800);     // 워밍업 - 오렌지
  static const Color mainsetRed = Color(0xFFE53935);       // 메인세트 - 레드
  static const Color cooldownBlue = Color(0xFF42A5F5);     // 쿨다운 - 블루
  
  // 그라디언트
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0077B6),
      Color(0xFF00B4D8),
    ],
  );
  
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF0A1628),
      Color(0xFF1A2744),
    ],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1A2744),
      Color(0xFF243B55),
    ],
  );

  // 테마 데이터
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: primaryDark,
      colorScheme: ColorScheme.dark(
        primary: primaryBlue,
        secondary: accentBlue,
        surface: surfaceColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: TextStyle(
          color: textPrimary,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: textSecondary,
          fontSize: 14,
        ),
      ),
    );
  }
}
