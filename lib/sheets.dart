import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'theme/app_theme.dart';
import 'widgets/common.dart';
import 'models.dart';
import 'services/analysis_api.dart';
import 'util/launchers.dart';

Future<void> _showSheet(BuildContext c, Widget child, {double? heightFactor}) {
  return showModalBottomSheet(
    context: c,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => DraggableableWrap(heightFactor: heightFactor, child: child),
  );
}

class DraggableableWrap extends StatelessWidget {
  final Widget child;
  final double? heightFactor;
  const DraggableableWrap({super.key, required this.child, this.heightFactor});
  @override
  Widget build(BuildContext context) {
    final content = Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      child: child,
    );
    return SafeArea(
      top: false,
      child: heightFactor == null
          ? content
          : FractionallySizedBox(heightFactor: heightFactor, child: content),
    );
  }
}

Widget _grab() => Center(
      child: Container(
        width: 40,
        height: 5,
        margin: const EdgeInsets.only(bottom: 16),
        decoration:
            BoxDecoration(color: AppColors.toggleOff, borderRadius: BorderRadius.circular(3)),
      ),
    );

/// 6 · 대응 챗봇 — 결과 위로 올라오는 시트.
/// [result]가 저장된 분석(analysisId>0)이면 우상단 신고 아이콘으로 익명 신고할 수 있다.
void showChatbotSheet(BuildContext c, {AnalysisResult? result}) {
  final canReport = (result?.analysisId ?? 0) > 0;
  _showSheet(
    c,
    heightFactor: 0.82,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _grab(),
        Row(children: [
          const CharacterDisc(38),
          const SizedBox(width: 10),
          const Text('대응 도우미', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const Spacer(),
          if (canReport)
            IconButton(
                tooltip: '이 문자 신고하기',
                onPressed: () => showReportSheet(c, result: result!),
                icon: const Icon(Icons.flag_outlined, color: AppColors.high)),
        ]),
        const Divider(color: AppColors.line),
        const SizedBox(height: 8),
        const _Bubble(bot: true, text: '방금 위험 문자(87점)가 왔어요. 링크는 누르지 마시고, 무엇이 궁금하세요?'),
        const SizedBox(height: 11),
        const Wrap(spacing: 8, children: [
          SfChip('이미 송금했어요', selected: true),
          SfChip('신고할래요'),
        ]),
        const SizedBox(height: 11),
        const _Bubble(bot: false, text: '돈을 보냈는데 어떡하죠?'),
        const SizedBox(height: 11),
        const _Bubble(bot: true, text: '바로 은행에 지급정지를 신청하세요. 도와드릴게요.'),
        const Spacer(),
        Row(children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                  border: Border.all(color: AppColors.line, width: 1.5),
                  borderRadius: BorderRadius.circular(24)),
              child: const Text('메시지 입력', style: TextStyle(color: AppColors.t3, fontSize: 16)),
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.arrow_circle_up, size: 38, color: AppColors.blue),
        ]),
      ],
    ),
  );
}

/// 9 · 신고 시트. 저장된 분석([result].analysisId>0)만 신고할 수 있다.
/// 신고 유형을 고르고 익명 접수한다. 최초 신고/이미 신고됨/실패를 토스트로 안내.
void showReportSheet(BuildContext c, {required AnalysisResult result}) {
  var selected = ReportType.phishing;
  var busy = false;

  void toast(String msg) {
    if (!c.mounted) return;
    ScaffoldMessenger.of(c)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  _showSheet(
    c,
    StatefulBuilder(
      builder: (ctx, setSheet) {
        Future<void> submit() async {
          setSheet(() => busy = true);
          final outcome =
              await AnalysisApi.report(result.analysisId, type: selected);
          if (!c.mounted) return;
          Navigator.pop(c); // 시트를 닫고 바깥 컨텍스트로 결과 안내
          toast(switch (outcome) {
            ReportOutcome.submitted => '익명으로 신고했어요. 고맙습니다.',
            ReportOutcome.alreadyReported => '이미 신고된 문자예요.',
            ReportOutcome.failed => '신고에 실패했어요. 잠시 후 다시 시도해 주세요.',
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _grab(),
            const Text('이 문자 신고하기', style: AppText.titleScreen),
            const SizedBox(height: 14),
            const SfCard(
              kind: CardKind.tint,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline, color: AppColors.blue, size: 22),
                  SizedBox(width: 9),
                  Expanded(
                      child: Text('이름·발신번호·원문 없이, 위험도와 유형만 익명으로 접수돼요.',
                          style: AppText.caption)),
                ],
              ),
            ),
            if (result.category != null) ...[
              const SizedBox(height: 11),
              SfCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('분석된 유형', style: TextStyle(fontSize: 16)),
                    Text(result.category!.label, style: AppText.caption),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            const SectionLabel('신고 유형'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in ReportType.values)
                  GestureDetector(
                    onTap: busy ? null : () => setSheet(() => selected = t),
                    child: SfChip(t.label, selected: selected == t),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SfButton(busy ? '신고 중…' : '익명으로 신고하기',
                icon: Icons.flag_outlined, onTap: busy ? null : submit),
          ],
        );
      },
    ),
  );
}

/// 13 · 결과 공유 시트.
/// [result]가 있으면 그 요약(원문 제외·개인정보 미포함)을 공유하고,
/// 없으면(개발용 미리보기 화면) 데모 텍스트를 쓴다.
void showShareSheet(BuildContext c, {AnalysisResult? result}) {
  final level = result?.riskLevel ?? RiskLevel.high;
  // 데모(미리보기) 경로만 예시 제목을 쓰고, 실제 결과인데 유형이 없으면 중립 제목.
  final title = result == null
      ? '검찰 사칭 문자'
      : result.category?.label ?? '문자 분석 결과';
  final text = result?.shareSummary ??
      '[세이프팸] 문자 분석 결과\n위험도: 위험\n의심되면 링크·전화에 응하지 마세요.';

  void toast(String msg) {
    if (!c.mounted) return;
    ScaffoldMessenger.of(c)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // 시트를 먼저 닫고 side-effect를 실행한다(시트 컨텍스트 소멸 후 바깥 c로 안내).
  Future<void> onSms() async {
    Navigator.pop(c);
    final ok = await shareBySms(text);
    if (!ok) toast('문자 앱을 열 수 없어요');
  }

  Future<void> onCopy() async {
    Navigator.pop(c);
    await Clipboard.setData(ClipboardData(text: text));
    toast('결과를 복사했어요');
  }

  Future<void> onShare() async {
    // iPad는 공유 시트를 띄울 앵커(sharePositionOrigin)가 필요하다.
    // 시트를 닫으면 컨텍스트의 RenderBox가 사라지므로 pop 전에 좌표를 캡처한다.
    final box = c.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    Navigator.pop(c);
    await Share.share(text, sharePositionOrigin: origin);
  }

  Widget item(IconData icon, String label, Color bg, VoidCallback onTap,
          [Color fg = Colors.white]) =>
      Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: [
              Container(
                width: 56,
                height: 56,
                decoration:
                    BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
                child: Icon(icon, color: fg, size: 26),
              ),
              const SizedBox(height: 8),
              Text(label, style: AppText.caption),
            ]),
          ),
        ),
      );

  _showSheet(
    c,
    Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _grab(),
        Container(
          padding: const EdgeInsets.all(16),
          decoration:
              BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                RiskBadge(level, large: false),
                const SizedBox(width: 8),
                Text(title, style: AppText.caption),
              ]),
              const CharacterDisc(42),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('이 결과를 가족에게 알려요', style: AppText.caption),
        const SizedBox(height: 16),
        Row(children: [
          item(Icons.sms_outlined, '문자', AppColors.low, onSms),
          item(Icons.copy, '복사', const Color(0xFF6B7280), onCopy),
          item(Icons.ios_share, '공유', AppColors.blue, onShare),
        ]),
      ],
    ),
  );
}

class _Bubble extends StatelessWidget {
  final bool bot;
  final String text;
  const _Bubble({required this.bot, required this.text});
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: bot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: bot ? AppColors.bg : AppColors.blue,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(bot ? 5 : 16),
            bottomRight: Radius.circular(bot ? 16 : 5),
          ),
        ),
        child: Text(text,
            style: TextStyle(fontSize: 16, height: 1.55, color: bot ? AppColors.t1 : Colors.white)),
      ),
    );
  }
}
