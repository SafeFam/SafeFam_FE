import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/score_gauge.dart';
import '../models.dart';
import '../services/analysis_api.dart';
import '../services/app_settings.dart';
import '../services/tts_service.dart';
import '../util/launchers.dart';
import '../sheets.dart';

/// 전화 걸기 side-effect. 실패 시 안내 스낵바.
Future<void> _dial(BuildContext c, String number) async {
  final ok = await callNumber(number);
  if (!ok && c.mounted) {
    ScaffoldMessenger.of(c)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('전화를 걸 수 없어요 ($number)')));
  }
}

/// 링크 열기 side-effect. 실패 시 안내 스낵바.
Future<void> _open(BuildContext c, String url) async {
  final ok = await openLink(url);
  if (!ok && c.mounted) {
    ScaffoldMessenger.of(c)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('링크를 열 수 없어요')));
  }
}

PreferredSizeWidget _resultBar(BuildContext c, String title,
    {bool share = true, VoidCallback? onDelete, AnalysisResult? result}) {
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
            onPressed: () => showShareSheet(c, result: result),
            icon: const Icon(Icons.ios_share, color: AppColors.t1, size: 22)),
      if (onDelete != null)
        IconButton(
            tooltip: '이력 삭제',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: AppColors.t1, size: 22)),
    ],
  );
}

/// 음성 안내 설정이 켜져 있을 때만 '들려주기' 버튼을 노출한다. 설정을 반응형으로
/// 관찰해, 더보기에서 토글하면 결과 화면에도 즉시 반영된다.
class _VoiceListenSection extends StatelessWidget {
  final String text;
  const _VoiceListenSection(this.text);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppSettings.instance.voice,
      builder: (context, on, _) => on
          ? Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _ListenButton(text))
          : const SizedBox.shrink(),
    );
  }
}

/// 결과를 소리로 읽어주는 버튼. TTS 재생 상태에 따라 '다시 들려주기'/'멈춤'을
/// 토글한다. 이 버튼이 화면에서 사라지면(라우트 이탈·음성 설정 off) 재생을 멈춘다.
class _ListenButton extends StatefulWidget {
  final String text;
  const _ListenButton(this.text);
  @override
  State<_ListenButton> createState() => _ListenButtonState();
}

class _ListenButtonState extends State<_ListenButton> {
  @override
  void dispose() {
    TtsService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: TtsService.instance.speaking,
      builder: (context, speaking, _) => SfButton(
        speaking ? '멈춤' : '다시 들려주기',
        icon: speaking ? Icons.stop : Icons.volume_up_outlined,
        variant: SfBtn.ghost,
        onTap: () async {
          if (speaking) {
            await TtsService.instance.stop();
            return;
          }
          final ok = await TtsService.instance.speak(widget.text);
          if (!ok && context.mounted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(
                  content: Text('이 기기에서 음성 안내를 쓸 수 없어요')));
          }
        },
      ),
    );
  }
}

/// 결과를 음성으로 읽어줄 때 쓰는 문장(제목 + 설명).
String _spokenResult(AnalysisResult r, RiskLevel level) {
  final b = StringBuffer(_resultTitle(r, level));
  final ex = r.explanation.trim();
  if (ex.isNotEmpty) b.write('. $ex');
  return b.toString();
}

Widget _helpCard(BuildContext c) => SfCard(
      kind: CardKind.danger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('바로 도움받기',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.highText)),
          const SizedBox(height: 11),
          Row(children: [
            Expanded(
                child: SfButton('금감원 1332',
                    icon: Icons.phone,
                    variant: SfBtn.primary,
                    compact: true,
                    onTap: () => _dial(c, '1332'))),
            const SizedBox(width: 9),
            Expanded(
                child: SfButton('경찰 112',
                    icon: Icons.phone,
                    variant: SfBtn.ghost,
                    compact: true,
                    onTap: () => _dial(c, '112'))),
          ]),
        ],
      ),
    );

/// 백엔드가 준 대응 액션(recommendedActions)을 전화/링크 버튼으로 렌더.
Widget _actionsCard(BuildContext c, List<RecommendedAction> actions) => SfCard(
      kind: CardKind.danger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('이렇게 대응하세요',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.highText)),
          for (final a in actions)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _actionTile(c, a),
            ),
        ],
      ),
    );

Widget _actionTile(BuildContext c, RecommendedAction a) {
  // 공백만 있는 백엔드 값은 없는 것으로 간주(트림 후 판단).
  final phone = a.phoneNumber?.trim() ?? '';
  final url = a.url?.trim() ?? '';
  if (phone.isNotEmpty) {
    return SfButton(a.label,
        icon: Icons.phone, compact: true, onTap: () => _dial(c, phone));
  }
  if (url.isNotEmpty) {
    return SfButton(a.label,
        icon: Icons.open_in_new,
        variant: SfBtn.ghost,
        compact: true,
        onTap: () => _open(c, url));
  }
  // 연락처·링크 없는 안내성 항목은 텍스트로.
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Icon(Icons.check_circle_outline, size: 20, color: AppColors.highText),
      const SizedBox(width: 8),
      Expanded(
          child: Text(a.label,
              style: const TextStyle(fontSize: 15, color: AppColors.t1))),
    ],
  );
}

/// IndicatorType별 아이콘 매핑(위험 근거 리스트 좌측).
IconData _indicatorIcon(IndicatorType? t) => switch (t) {
      IndicatorType.impersonation => Icons.account_balance,
      IndicatorType.financialAction => Icons.credit_card,
      IndicatorType.sensitiveInformation => Icons.badge_outlined,
      IndicatorType.urgency => Icons.notifications_active,
      IndicatorType.shortenedUrl => Icons.link,
      IndicatorType.maliciousUrl => Icons.dangerous_outlined,
      IndicatorType.aiEvidence => Icons.psychology_outlined,
      // 위험 근거 카드엔 노출하지 않지만(build에서 제외) switch 완전성을 위해 둔다.
      IndicatorType.analysisTrackFailure => Icons.info_outline,
      null => Icons.info_outline,
    };

/// 결과 제목. 위험도·피싱 유형으로 문장을 만든다(결과가 있는 상태에서만 호출).
String _resultTitle(AnalysisResult r, RiskLevel level) {
  if (level == RiskLevel.low) return '안전한 문자예요';
  final cat = r.category?.label;
  if (cat != null) return '$cat 문자예요';
  return level == RiskLevel.high ? '위험한 문자예요' : '주의가 필요한 문자예요';
}

/// result 미지정(오버레이 dev 프리뷰) 시 쓰는 데모 결과.
final AnalysisResult _demoResult = AnalysisResult(
  analysisId: 0,
  status: AnalysisStatus.completed,
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
  FeedbackType? _feedback; // 사용자가 남긴 피드백(선택 강조용)
  bool _busy = false; // 삭제/피드백 전송 중

  AnalysisResult get _r => widget.result ?? _demoResult;

  /// 서버에 저장된 이력(analysisId>0)이면 삭제·피드백을 노출한다.
  bool get _isSaved => (widget.result?.analysisId ?? 0) > 0;

  @override
  void dispose() {
    // 화면을 벗어나면 읽어주던 음성을 멈춘다(뒤 화면까지 따라 읽지 않게).
    TtsService.instance.stop();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: const Text('이력을 삭제할까요?'),
        content: const Text('삭제하면 이 분석 결과를 다시 볼 수 없어요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dc, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(dc, true),
              child: const Text('삭제', style: TextStyle(color: AppColors.high))),
        ],
      ),
    );
    if (ok != true || _busy || !mounted) return;
    setState(() => _busy = true);
    final done = await AnalysisApi.deleteAnalysis(_r.analysisId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (done) {
      Navigator.pop(context, true); // 호출부(이력)에 삭제됨을 알림
    } else {
      _snack('삭제에 실패했어요. 잠시 후 다시 시도해 주세요.');
    }
  }

  Future<void> _sendFeedback(FeedbackType type) async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await AnalysisApi.submitFeedback(_r.analysisId, type: type);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _feedback = type;
    });
    _snack(ok ? '피드백 고마워요. 탐지 정확도를 높이는 데 쓸게요.' : '피드백 전송에 실패했어요.');
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    // 실패는 '안전'이 아니라 별도 실패 안내(§전달사항 5).
    if (r.status == AnalysisStatus.failed) return _failureScaffold(context);
    // 아직 처리 중이면 결과가 없다. 정상 흐름에선 상세 화면이 폴링해 종료 상태만
    // 넘겨주지만, 직접 진입 대비 방어적으로 분석 중 화면을 보여준다.
    if (!r.hasResult) return _pendingScaffold(context);

    // 여기부터는 완료/부분성공 — 등급·점수를 신뢰할 수 있다. 값이 있는데 손상된
    // 경우만 fail-secure로 high/0.
    final level = r.riskLevel ?? RiskLevel.high;
    final score = r.riskScore ?? 0;
    final partial = r.status == AnalysisStatus.partialSuccess;
    // 위험 근거 카드엔 실패 통지(ANALYSIS_TRACK_FAILURE)를 섞지 않는다. 실패한 레이어는
    // 한국어로 환원해 부분성공 배너로만 안내한다(내부 엔진명·영어 원문 노출 방지).
    final riskSignals = r.indicators
        .where((i) => i.type != IndicatorType.analysisTrackFailure)
        .toList(growable: false);
    final failedLayers = r.failedLayerLabels;
    return Scaffold(
      appBar: _resultBar(context, '분석 결과',
          result: r, onDelete: _isSaved && !_busy ? _confirmDelete : null),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        children: [
          Column(children: [
            const CharacterDisc(142),
            const SizedBox(height: 12),
            RiskBadge(level),
            const SizedBox(height: 12),
            Text(_resultTitle(r, level), style: AppText.titleResult),
          ]),
          // 음성 안내 설정이 켜져 있으면 결과를 소리로 들려주는 버튼을 노출한다(반응형).
          _VoiceListenSection(_spokenResult(r, level)),
          if (partial) ...[
            const SizedBox(height: 12),
            _partialBanner(failedLayers),
          ],
          const SizedBox(height: 16),
          // 3중 스코어 게이지
          Center(child: ScoreGauge(score, level)),
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
          if (riskSignals.isNotEmpty) ...[
            const SizedBox(height: 12),
            SfCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('이런 신호가 잡혔어요'),
                  for (final ind in riskSignals)
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
          if (r.recommendedActions.isNotEmpty) ...[
            const SizedBox(height: 12),
            _actionsCard(context, r.recommendedActions),
          ] else if (level != RiskLevel.low) ...[
            const SizedBox(height: 12),
            _helpCard(context),
          ],
          if (_isSaved) ...[
            const SizedBox(height: 12),
            _feedbackCard(),
          ],
          const SizedBox(height: 12),
          SfButton('대응 방법 물어보기',
              icon: Icons.smart_toy_outlined,
              onTap: () => showChatbotSheet(context, result: _r)),
        ],
      ),
    );
  }

  /// 부분 성공 안내 배너(외부 AI 장애 시 안전모드) — 점수·등급은 보여주되, 어떤 분석이
  /// 빠졌는지 한국어 레이어명으로 알리고, 보수적으로 대응하도록 안내한다.
  Widget _partialBanner(List<String> failedLayers) {
    final which = failedLayers.isEmpty
        ? '일부 분석을 완료하지 못했어요.'
        : '${failedLayers.join(' · ')}을(를) 완료하지 못했어요.';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: AppColors.med.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.med, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
                '$which 아래 결과는 가능한 분석만으로 계산했어요. '
                '안전하다는 뜻은 아니니, 의심되면 링크·전화에 응하지 말고 공식 앱·대표번호로 확인하세요.',
                style: const TextStyle(
                    fontSize: 14, color: AppColors.t1, height: 1.45)),
          ),
        ],
      ),
    );
  }

  /// 분석 실패 화면 — '안전'으로 오인하지 않도록 별도 안내.
  Widget _failureScaffold(BuildContext context) => Scaffold(
        appBar: _resultBar(context, '분석 결과', share: false),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CharacterDisc(120),
                const SizedBox(height: 16),
                const Text('분석을 완료하지 못했어요', style: AppText.titleResult),
                const SizedBox(height: 8),
                const Text('잠시 후 다시 시도해 주세요.\n안전하다는 뜻이 아니니, 의심되면 링크·전화에 응하지 마세요.',
                    textAlign: TextAlign.center, style: AppText.body),
                const SizedBox(height: 20),
                if (_isSaved && !_busy)
                  SizedBox(
                    width: 200,
                    child: SfButton('이력에서 삭제',
                        icon: Icons.delete_outline,
                        variant: SfBtn.ghost,
                        onTap: _confirmDelete),
                  ),
              ],
            ),
          ),
        ),
      );

  /// 처리 중 화면(방어용) — 상세 화면 폴링이 정상 동작하면 거의 보이지 않는다.
  Widget _pendingScaffold(BuildContext context) => Scaffold(
        appBar: _resultBar(context, '분석 결과', share: false),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CharacterDisc(120),
              SizedBox(height: 18),
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('문자를 분석하고 있어요', style: AppText.titleScreen),
              SizedBox(height: 6),
              Text('잠시만 기다려 주세요', style: AppText.caption),
            ],
          ),
        ),
      );

  /// 정탐/오탐/미탐 피드백 카드(저장된 이력에서만 표시).
  Widget _feedbackCard() {
    return SfCard(
      kind: CardKind.tint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('이 분석이 정확했나요?'),
          const Text('알려주시면 탐지 정확도를 높이는 데 써요.',
              style: AppText.caption),
          const SizedBox(height: 11),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _feedbackOption('정확해요', FeedbackType.correct),
              _feedbackOption('실제로는 안전했어요', FeedbackType.falsePositive),
              _feedbackOption('실제로는 위험했어요', FeedbackType.falseNegative),
            ],
          ),
        ],
      ),
    );
  }

  Widget _feedbackOption(String label, FeedbackType type) {
    final selected = _feedback == type;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: _busy ? null : () => _sendFeedback(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.blue : Colors.white,
          border: Border.all(
              color: selected ? AppColors.blue : AppColors.line, width: 1.5),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 16, color: Colors.white),
              const SizedBox(width: 5),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.t2)),
          ],
        ),
      ),
    );
  }
}

/// 6 · 탐지 이력 상세 — id로 분석 결과를 불러와 [ResultScreen]으로 렌더한다.
///
/// 분석이 비동기라 접수 직후엔 아직 PENDING/PROCESSING일 수 있다. 그래서 종료
/// 상태(COMPLETED/PARTIAL_SUCCESS/FAILED)가 될 때까지 상세를 폴링한다. 폴링은
/// 화면이 사라지면(dispose) 중단되고, 최대 대기 시간을 넘기면 안내로 전환한다.
class AnalysisDetailScreen extends StatefulWidget {
  final int analysisId;

  /// 수동 검사 원문(있으면 결과의 '받은 문자' 카드에 표시).
  final String? messageText;

  const AnalysisDetailScreen({
    super.key,
    required this.analysisId,
    this.messageText,
  });
  @override
  State<AnalysisDetailScreen> createState() => _AnalysisDetailScreenState();
}

class _AnalysisDetailScreenState extends State<AnalysisDetailScreen> {
  static const _pollInterval = Duration(seconds: 2);
  static const _maxWait = Duration(seconds: 30);
  static const _maxConsecutiveErrors = 3;

  AnalysisResult? _result; // 종료 상태로 확정된 결과
  bool _loading = true; // 첫 로드 또는 처리 중(폴링 진행)
  bool _timedOut = false; // 최대 대기 초과했는데 아직 처리 중(false면 조회 실패)
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    // 화면이 사라진 뒤 폴링 루프가 setState를 호출하지 않도록 취소 플래그를 세운다.
    _disposed = true;
    super.dispose();
  }

  /// 종료 상태가 될 때까지 상세를 주기적으로 조회한다. 일시적 네트워크 오류 한 번으로
  /// 실패 처리하지 않도록 연속 실패가 임계치를 넘을 때만 에러로 전환한다.
  Future<void> _startPolling() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _timedOut = false;
    });
    final deadline = DateTime.now().add(_maxWait);
    var consecutiveErrors = 0;
    while (true) {
      final r = await AnalysisApi.getAnalysis(widget.analysisId);
      if (_disposed || !mounted) return;
      if (r != null) {
        consecutiveErrors = 0;
        if (r.status.isTerminal) {
          setState(() {
            _result = r;
            _loading = false;
          });
          return; // 폴링 중단
        }
        // 아직 처리 중 → 계속 폴링
      } else {
        consecutiveErrors++;
        if (consecutiveErrors >= _maxConsecutiveErrors) {
          // _timedOut=false로 두면 build가 조회 실패 안내로 분기한다.
          setState(() => _loading = false);
          return;
        }
      }
      if (!DateTime.now().isBefore(deadline)) {
        setState(() {
          _loading = false;
          _timedOut = true;
        });
        return;
      }
      await Future.delayed(_pollInterval);
      if (_disposed || !mounted) return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    if (r != null && r.status.isTerminal) {
      return ResultScreen(result: r, messageText: widget.messageText);
    }
    return Scaffold(
      appBar: _resultBar(context, '분석 결과', share: false),
      body: Center(
        child: _loading ? _analyzingBody() : _retryBody(),
      ),
    );
  }

  Widget _analyzingBody() => Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          CharacterDisc(120),
          SizedBox(height: 18),
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('문자를 분석하고 있어요', style: AppText.titleScreen),
          SizedBox(height: 6),
          Text('잠시만 기다려 주세요', style: AppText.caption),
        ],
      );

  Widget _retryBody() {
    // 지연(timeout)과 조회 실패를 구분해 안내한다.
    final msg = _timedOut ? '분석이 조금 오래 걸리고 있어요' : '결과를 불러오지 못했어요';
    final sub = _timedOut ? '잠시 후 다시 확인해 주세요.' : null;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_timedOut ? Icons.hourglass_empty : Icons.cloud_off_outlined,
              color: AppColors.t3, size: 40),
          const SizedBox(height: 10),
          Text(msg, style: AppText.body),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(sub, style: AppText.caption),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: 180,
            child: SfButton('다시 확인',
                icon: Icons.refresh,
                variant: SfBtn.ghost,
                onTap: _startPolling),
          ),
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
          const _VoiceListenSection(
              '보이스피싱이에요. 검찰 수사관을 사칭하며 안전계좌로 돈을 옮기라고 했어요. 진짜 수사기관은 이렇게 하지 않아요.'),
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
          const _VoiceListenSection(
              '위험한 사이트예요. 택배사를 흉내 낸 가짜 결제 페이지예요. 접속하거나 정보를 넣지 마세요.'),
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
