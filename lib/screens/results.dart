import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/score_gauge.dart';
import '../models.dart';
import '../services/analysis_api.dart';
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

/// IndicatorType별 아이콘 매핑(위험 근거 리스트 좌측).
IconData _indicatorIcon(IndicatorType? t) => switch (t) {
      IndicatorType.impersonation => Icons.account_balance,
      IndicatorType.financialAction => Icons.credit_card,
      IndicatorType.sensitiveInformation => Icons.badge_outlined,
      IndicatorType.urgency => Icons.notifications_active,
      IndicatorType.shortenedUrl => Icons.link,
      IndicatorType.maliciousUrl => Icons.dangerous_outlined,
      null => Icons.info_outline,
    };

/// 결과 제목. 위험도·피싱 유형으로 문장을 만든다.
String _resultTitle(AnalysisResult r) {
  if (r.riskLevel == RiskLevel.low) return '안전한 문자예요';
  final cat = r.category?.label;
  if (cat != null) return '$cat 문자예요';
  return r.riskLevel == RiskLevel.high ? '위험한 문자예요' : '주의가 필요한 문자예요';
}

/// result 미지정(오버레이 dev 프리뷰) 시 쓰는 데모 결과.
final AnalysisResult _demoResult = AnalysisResult(
  analysisId: 0,
  riskScore: 92,
  riskLevel: RiskLevel.high,
  category: PhishingCategory.governmentAgency,
  explanation: '기관을 사칭해 겁을 주고, 안전계좌로 송금을 유도하는 수법이에요. 절대 응하지 마세요.',
  scoreBreakdown:
      const ScoreBreakdown(llmScore: 0, urlScore: 100, patternScore: 85),
  indicators: const [
    Indicator(type: IndicatorType.impersonation, description: '"검찰·수사관" 등 기관을 사칭'),
    Indicator(type: IndicatorType.financialAction, description: '"안전계좌로 이체" 표현 감지'),
    Indicator(type: IndicatorType.urgency, description: '"즉시·정지" 등 불안 유도'),
  ],
  urls: const [],
  recommendedActions: const [],
  analyzedAt: null,
);

/// 5 · 문자 탐지 결과 (3중 스코어 게이지).
class ResultScreen extends StatefulWidget {
  /// 분석 결과. null이면 데모 데이터로 렌더(오버레이 dev 프리뷰 호환).
  final AnalysisResult? result;

  /// 검사한 원문(수동 분석). 있으면 "받은 문자" 카드에 표시.
  final String? messageText;

  const ResultScreen({super.key, this.result, this.messageText});
  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _open = true;

  AnalysisResult get _r => widget.result ?? _demoResult;

  @override
  Widget build(BuildContext context) {
    final r = _r;
    final level = r.riskLevel;
    return Scaffold(
      appBar: _resultBar(context, '분석 결과'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        children: [
          Column(children: [
            const CharacterDisc(142),
            const SizedBox(height: 12),
            RiskBadge(level),
            const SizedBox(height: 12),
            Text(_resultTitle(r), style: AppText.titleResult),
          ]),
          const SizedBox(height: 16),
          // 3중 스코어 게이지
          Center(child: ScoreGauge(r.riskScore, level)),
          const SizedBox(height: 8),
          if (r.explanation.isNotEmpty) ...[
            SfCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('왜 이렇게 판단했나요?'),
                  Text(r.explanation, style: AppText.body),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          // 3중 스코어 breakdown (문맥·링크·글자 패턴)
          Container(
            decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                InkWell(
                  onTap: () => setState(() => _open = !_open),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('점수는 이렇게 나왔어요',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      Icon(_open ? Icons.expand_less : Icons.expand_more,
                          color: AppColors.t2),
                    ],
                  ),
                ),
                if (_open) ...[
                  const SizedBox(height: 14),
                  BreakdownBar('문맥 분석 (AI)', r.scoreBreakdown.llmScore),
                  BreakdownBar('링크 보안', r.scoreBreakdown.urlScore),
                  BreakdownBar('글자 패턴', r.scoreBreakdown.patternScore),
                  const Divider(color: AppColors.line, height: 12),
                  const Text('세 가지 분석을 합쳐 종합 위험 점수를 계산했어요.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.t3, height: 1.5)),
                ],
              ],
            ),
          ),
          // 위험 근거
          if (r.indicators.isNotEmpty) ...[
            const SizedBox(height: 12),
            SfCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('이런 신호가 잡혔어요'),
                  for (final ind in r.indicators)
                    Padding(
                      padding: const EdgeInsets.only(top: 9),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(_indicatorIcon(ind.type),
                              color: level.color, size: 20),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (ind.type != null)
                                  Text(ind.type!.label,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600)),
                                Text(ind.description,
                                    style: const TextStyle(
                                        fontSize: 13, color: AppColors.t2)),
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
          // 문자에 포함된 URL
          if (r.urls.isNotEmpty) ...[
            const SizedBox(height: 12),
            SfCard(
              kind: CardKind.danger,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('문자 속 링크'),
                  for (final u in r.urls)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Icon(
                              u.suspicious
                                  ? Icons.gpp_bad_outlined
                                  : Icons.link,
                              color: u.suspicious
                                  ? AppColors.high
                                  : AppColors.t2,
                              size: 20),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(u.resolvedUrl ?? u.originalUrl,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: u.suspicious
                                        ? AppColors.highText
                                        : AppColors.t1)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          // 받은 문자(수동 검사 시 원문)
          if (widget.messageText != null &&
              widget.messageText!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            SfCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('받은 문자'),
                  Text(widget.messageText!.trim(),
                      style: const TextStyle(
                          fontSize: 15, color: AppColors.t2, height: 1.55)),
                ],
              ),
            ),
          ],
          if (level != RiskLevel.low) ...[
            const SizedBox(height: 12),
            _helpCard(context),
          ],
          const SizedBox(height: 12),
          SfButton('대응 방법 물어보기',
              icon: Icons.smart_toy_outlined,
              onTap: () => showChatbotSheet(context)),
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
