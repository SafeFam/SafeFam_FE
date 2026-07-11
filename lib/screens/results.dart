import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../models.dart';
import '../sheets.dart';

PreferredSizeWidget _resultBar(BuildContext c, String title, {bool share = true}) {
  return AppBar(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.white,
    elevation: 0,
    leading: IconButton(
        icon: const Icon(Icons.home_outlined, color: AppColors.t1, size: 24),
        onPressed: () => Navigator.maybePop(c)),
    title: Text(title, style: AppText.titleScreen),
    actions: [
      if (share)
        IconButton(
            onPressed: () => showShareSheet(c),
            icon: const Icon(Icons.ios_share, color: AppColors.t1, size: 22)),
    ],
  );
}

Widget _listenBtn() =>
    const SfButton('다시 들려주기', icon: Icons.volume_up_outlined, variant: SfBtn.ghost);

Widget _helpCard(BuildContext c) => SfCard(
      kind: CardKind.danger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('바로 도움받기',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.highText)),
          const SizedBox(height: 11),
          Row(children: const [
            Expanded(child: SfButton('금감원 1332', icon: Icons.phone, variant: SfBtn.primary, compact: true)),
            SizedBox(width: 9),
            Expanded(child: SfButton('경찰 112', icon: Icons.phone, variant: SfBtn.ghost, compact: true)),
          ]),
        ],
      ),
    );

/// 5 · 문자 탐지 결과 (NB 신호 기반).
class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});
  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _resultBar(context, '분석 결과'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        children: [
          Column(children: const [
            CharacterDisc(142),
            SizedBox(height: 12),
            RiskBadge(RiskLevel.high),
            SizedBox(height: 12),
            Text('검찰 사칭 문자예요', style: AppText.titleResult),
          ]),
          const SizedBox(height: 12),
          _listenBtn(),
          const SizedBox(height: 16),
          SfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SectionLabel('왜 위험한가요?'),
                Text('기관을 사칭해 겁을 주고, 안전계좌로 송금을 유도하는 수법이에요. 절대 응하지 마세요.',
                    style: AppText.body),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SectionLabel('받은 문자 · 개인정보 가림'),
                Text('[성명] 님, 귀하의 계좌가 정지되었습니다. 확인: http://****',
                    style: TextStyle(fontSize: 15, color: AppColors.t2, height: 1.55)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 점수 + 탐지 신호 (3막대 대체)
          Container(
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                InkWell(
                  onTap: () => setState(() => _open = !_open),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Container(
                          width: 44, height: 44,
                          decoration: const BoxDecoration(color: Color(0xFFFBE3E3), shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: const Text('92',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.high)),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('위험 점수 92', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            Text('AI가 잡아낸 신호 3가지', style: TextStyle(fontSize: 13, color: AppColors.t2)),
                          ],
                        ),
                      ]),
                      Icon(_open ? Icons.expand_less : Icons.expand_more, color: AppColors.t2),
                    ],
                  ),
                ),
                if (_open) ...[
                  const SizedBox(height: 14),
                  for (final s in sampleSignals)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(s.icon, color: AppColors.high, size: 20),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                Text(s.detail, style: const TextStyle(fontSize: 12, color: AppColors.t2)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Divider(color: AppColors.line, height: 20),
                  const Text('세이프팸 자체 분류 모델(나이브베이즈)이 문맥과 신호를 함께 분석했어요.',
                      style: TextStyle(fontSize: 12, color: AppColors.t3, height: 1.5)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _helpCard(context),
          const SizedBox(height: 12),
          SfButton('대응 방법 물어보기',
              icon: Icons.smart_toy_outlined, onTap: () => showChatbotSheet(context)),
        ],
      ),
    );
  }
}

/// 7 · 보이스피싱 결과.
class VoiceResultScreen extends StatelessWidget {
  const VoiceResultScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _resultBar(context, '통화 분석'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        children: [
          Column(children: const [
            CharacterDisc(142),
            SizedBox(height: 12),
            RiskBadge(RiskLevel.high),
            SizedBox(height: 12),
            Text('보이스피싱이에요', style: AppText.titleResult),
          ]),
          const SizedBox(height: 12),
          _listenBtn(),
          const SizedBox(height: 16),
          SfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SectionLabel('방금 통화에서'),
                Text('"검찰 수사관"을 사칭하며 안전계좌로 돈을 옮기라고 했어요. 진짜 수사기관은 이렇게 하지 않아요.',
                    style: AppText.body),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SfCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Row(children: [
                  Icon(Icons.phone_in_talk_outlined, color: AppColors.blue, size: 22),
                  SizedBox(width: 10),
                  Text('02-****-9930', style: AppText.bodyStrong),
                ]),
                Text('4분 12초', style: AppText.caption),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _helpCard(context),
        ],
      ),
    );
  }
}

/// 8 · URL 검사 결과 (빨강 축소).
class UrlResultScreen extends StatelessWidget {
  const UrlResultScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _resultBar(context, '링크 검사', share: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        children: [
          Column(children: const [
            CharacterDisc(142),
            SizedBox(height: 12),
            RiskBadge(RiskLevel.high, text: '위험 사이트'),
          ]),
          const SizedBox(height: 12),
          _listenBtn(),
          const SizedBox(height: 16),
          SfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SectionLabel('검사한 링크'),
                Text('cj-delivery-check.top',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.high)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('검사 결과', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    Text('90곳 중 12곳 위험',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.high)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: const LinearProgressIndicator(
                      value: 0.13, minHeight: 11,
                      backgroundColor: AppColors.track,
                      valueColor: AlwaysStoppedAnimation(AppColors.high)),
                ),
                const SizedBox(height: 14),
                const Text('택배사를 흉내 낸 가짜 결제 페이지예요. 접속하거나 정보를 넣지 마세요.',
                    style: AppText.body),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const SfButton('접속 차단하기', icon: Icons.block, variant: SfBtn.primary),
        ],
      ),
    );
  }
}
