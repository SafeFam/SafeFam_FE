import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// 앱 부팅 중 표시되는 스플래시.
///
/// 다음 화면으로 넘어가는 시점은 `main.dart`의 부팅 게이트가 정한다
/// (세션 복구 완료 + 최소 노출 시간). 여기서는 화면만 그린다.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

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
            const Text('SafeFam', style: AppText.logo),
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
