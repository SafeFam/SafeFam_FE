import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../models.dart';
import 'results.dart';

/// HIGH 탐지 시 다른 앱 위에 뜨는 강제 경고(SYSTEM_ALERT_WINDOW).
/// 실제로는 오버레이 엔진으로 띄우지만, 디자인은 이 전체화면 팝업 기준.
class OverlayAlertScreen extends StatelessWidget {
  const OverlayAlertScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.55),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text('SafeFam 긴급 경고',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 22),
                decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(24)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CharacterDisc(120),
                    const SizedBox(height: 16),
                    const RiskBadge(RiskLevel.high),
                    const SizedBox(height: 16),
                    const Text('지금 받은 문자는\n금융사기예요',
                        textAlign: TextAlign.center, style: AppText.titleResult),
                    const SizedBox(height: 12),
                    const Text('검찰을 사칭해 계좌 정지를 빙자하고 있어요.\n링크를 누르거나 전화를 걸지 마세요.',
                        textAlign: TextAlign.center, style: AppText.body),
                    const SizedBox(height: 22),
                    const SfButton('금감원 1332 전화', icon: Icons.phone, variant: SfBtn.danger),
                    const SizedBox(height: 10),
                    SfButton('자세히 보기',
                        variant: SfBtn.ghost,
                        onTap: () => Navigator.pushReplacement(context,
                            MaterialPageRoute(builder: (_) => const ResultScreen()))),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => Navigator.maybePop(context),
                      child: const Text('안전하게 닫기',
                          style: TextStyle(color: AppColors.t2, fontSize: 15)),
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
