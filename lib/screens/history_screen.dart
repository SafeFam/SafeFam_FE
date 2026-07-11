import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../models.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const months = ['2월', '3월', '4월', '5월', '6월'];
    const heights = [0.30, 0.46, 0.38, 0.62, 0.88];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 16, 18, 8),
          child: Text('탐지 이력', style: AppText.titleScreen),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 18),
            children: [
              SfCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('월별 탐지 건수'),
                    SizedBox(
                      height: 96,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var i = 0; i < months.length; i++)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 5),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Container(
                                      height: 78 * heights[i],
                                      decoration: BoxDecoration(
                                          color: i == months.length - 1
                                              ? AppColors.blue
                                              : AppColors.blueLight,
                                          borderRadius: const BorderRadius.vertical(
                                              top: Radius.circular(6))),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(months[i],
                                        style: const TextStyle(fontSize: 11, color: AppColors.t3)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  SfChip('전체', selected: true),
                  SizedBox(width: 7),
                  SfChip('금융'),
                  SizedBox(width: 7),
                  SfChip('택배'),
                  SizedBox(width: 7),
                  SfChip('기타'),
                ]),
              ),
              const SizedBox(height: 8),
              for (final d in sampleHistory)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.line))),
                  child: Row(
                    children: [
                      IconDisc(d.level.icon,
                          color: d.level.color, bg: d.level.color.withOpacity(0.12)),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(d.title,
                                    style: const TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.w600)),
                                RiskBadge(d.level, large: false),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(d.sub, style: AppText.caption),
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
