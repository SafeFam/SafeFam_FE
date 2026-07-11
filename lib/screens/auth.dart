import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'onboarding.dart';

/// 스플래시 → 온보딩.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const OnboardingScreen()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CharacterDisc(142),
            const SizedBox(height: 18),
            const Text('세이프팸', style: AppText.logo),
            const SizedBox(height: 8),
            const Text('우리 가족 금융 지킴이', style: AppText.caption),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                  3,
                  (i) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: [AppColors.blue, AppColors.blueLight, const Color(0xFFC9D6EF)][i]),
                      )),
            ),
          ],
        ),
      ),
    );
  }
}
