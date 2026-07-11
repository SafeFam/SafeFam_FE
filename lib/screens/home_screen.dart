import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../models.dart';
import 'more_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
          child: Row(
            children: [
              const Text('세이프팸',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.blue)),
              const Spacer(),
              IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.notifications_none, color: AppColors.t1, size: 24)),
              IconButton(
                  onPressed: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const MoreScreen())),
                  icon: const Icon(Icons.settings_outlined, color: AppColors.t1, size: 24)),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 18),
            children: [
              SfCard(
                kind: CardKind.tint,
                padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                child: Column(children: const [
                  CharacterDisc(100),
                  SizedBox(height: 10),
                  Text('지금 안전해요', style: AppText.titleLarge),
                  SizedBox(height: 6),
                  Text('세이프팸이 자동으로 지키는 중', style: AppText.caption),
                ]),
              ),
              const SizedBox(height: 16),
              SfCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('요즘 많은 사기 수법'),
                    for (final t in sampleTrends)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(t.$1, style: const TextStyle(fontSize: 16)),
                            RiskBadge(t.$2, large: false, text: t.$3),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
