import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'results.dart';

/// 하단 탭 "검사" — 수동 분석 입력 (탭이라 뒤로가기 없음).
class CheckScreen extends StatelessWidget {
  const CheckScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 16, 18, 8),
          child: Text('검사',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.blue)),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('의심되는 문자를\n붙여넣으세요', style: AppText.titleResult),
                const SizedBox(height: 8),
                const Text('자동 탐지가 놓친 문자도 여기서 직접 확인할 수 있어요.',
                    style: AppText.caption),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        border: Border.all(color: AppColors.line, width: 1.5),
                        borderRadius: BorderRadius.circular(14)),
                    child: const TextField(
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: TextStyle(fontSize: 16, height: 1.5),
                      decoration: InputDecoration.collapsed(
                          hintText: '문자 내용을 여기에 붙여넣기',
                          hintStyle: TextStyle(color: AppColors.t3)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SfCard(
                  kind: CardKind.tint,
                  child: Row(
                    children: const [
                      Icon(Icons.lock_outline, color: AppColors.blue, size: 20),
                      SizedBox(width: 9),
                      Expanded(
                          child: Text('붙여넣은 내용은 이름·번호를 가린 뒤 안전하게 분석돼요.',
                              style: AppText.caption)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SfButton('검사하기',
                    icon: Icons.shield_outlined,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const ResultScreen()))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
