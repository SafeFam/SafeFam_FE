import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'widgets/common.dart';
import 'models.dart';

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
void showChatbotSheet(BuildContext c) {
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
          IconButton(
              onPressed: () => showReportSheet(c),
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

/// 9 · 신고 시트.
void showReportSheet(BuildContext c) {
  _showSheet(
    c,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _grab(),
        const Text('이 문자 신고하기', style: AppText.titleScreen),
        const SizedBox(height: 14),
        SfCard(
          kind: CardKind.tint,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.lock_outline, color: AppColors.blue, size: 22),
              SizedBox(width: 9),
              Expanded(
                  child: Text('이름 없이 익명으로 접수돼요. 발신번호와 내용은 자동으로 담겨요.',
                      style: AppText.caption)),
            ],
          ),
        ),
        const SizedBox(height: 11),
        SfCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('발신번호', style: TextStyle(fontSize: 16)),
              Text('10-****-2841', style: AppText.caption),
            ],
          ),
        ),
        const SizedBox(height: 11),
        SfCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('유형', style: TextStyle(fontSize: 16)),
              Text('기관 사칭', style: AppText.caption),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SfButton('익명으로 신고하기',
            icon: Icons.flag_outlined, onTap: () => Navigator.pop(c)),
      ],
    ),
  );
}

/// 13 · 결과 공유 시트.
void showShareSheet(BuildContext c) {
  Widget item(IconData icon, String label, Color bg, [Color fg = Colors.white]) => Expanded(
        child: Column(children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: fg, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: AppText.caption),
        ]),
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
            children: const [
              Row(children: [
                RiskBadge(RiskLevel.high, large: false),
                SizedBox(width: 8),
                Text('검찰 사칭 문자', style: AppText.caption),
              ]),
              CharacterDisc(42),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('이 결과를 가족에게 알려요', style: AppText.caption),
        const SizedBox(height: 16),
        Row(children: [
          item(Icons.chat_bubble, '카카오톡', AppColors.kakao, const Color(0xFF3B1E1E)),
          item(Icons.sms_outlined, '문자', AppColors.low),
          item(Icons.groups, '가족', AppColors.blue),
          item(Icons.copy, '복사', const Color(0xFF6B7280)),
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
