import 'package:flutter/material.dart';

/// 세이프팸 디자인 토큰 — Figma 스펙 시트와 1:1 대응.
class AppColors {
  static const blue = Color(0xFF3F77DB);
  static const blueLight = Color(0xFF7B9BE8);
  static const bg = Color(0xFFEEF3FC);
  static const surface = Color(0xFFF4F7FB);

  static const high = Color(0xFFE53935);
  static const med = Color(0xFFF59E0B);
  static const low = Color(0xFF16A36A);

  static const highBg = Color(0xFFFFF1F1);
  static const highLine = Color(0xFFF3C9C9);
  static const highText = Color(0xFFA32D2D);
  static const medText = Color(0xFF3D2A02);

  static const t1 = Color(0xFF1B2640); // 본문·제목
  static const t2 = Color(0xFF5B6B82); // 보조
  static const t3 = Color(0xFF9AA4B2); // placeholder·비활성
  static const line = Color(0xFFE2E6EE);

  static const charDisc = Color(0xFFCFE0F7);
  static const tintLine = Color(0xFFD6E2F5);
  static const track = Color(0xFFEEF0F4);
  static const toggleOff = Color(0xFFD3D9E2);
  static const kakao = Color(0xFFFAE100);
}

/// 텍스트 스타일. fontFamily는 pubspec의 Pretendard를 따름.
class AppText {
  static const logo =
      TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.t1, letterSpacing: -0.5);
  static const titleLarge =
      TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.t1, height: 1.35);
  static const titleResult =
      TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.t1, height: 1.35);
  static const titleScreen =
      TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.t1);
  static const bodyStrong =
      TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.t1, height: 1.5);
  static const body =
      TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.t1, height: 1.6);
  static const section =
      TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.t2);
  static const button =
      TextStyle(fontSize: 17, fontWeight: FontWeight.w700);
  static const caption =
      TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.t2, height: 1.5);
}

ThemeData buildSafeFamTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.white,
    fontFamily: 'Pretendard',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.blue,
      primary: AppColors.blue,
      surface: Colors.white,
    ),
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
  );
}
