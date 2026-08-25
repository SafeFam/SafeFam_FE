import 'dart:math';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../services/analysis_api.dart';
import 'results.dart';

/// 하단 탭 "검사" — 수동 분석 입력 (탭이라 뒤로가기 없음).
class CheckScreen extends StatefulWidget {
  const CheckScreen({super.key});
  @override
  State<CheckScreen> createState() => _CheckScreenState();
}

class _CheckScreenState extends State<CheckScreen> {
  final _controller = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _snack('검사할 문자를 입력해 주세요.');
      return;
    }
    setState(() => _loading = true);
    // 분석은 비동기 접수(202)라 여기선 analysisId만 받는다. 실제 결과는 상세 화면이
    // 종료 상태까지 폴링해 렌더한다.
    final outcome = await AnalysisApi.analyze(
      content: text,
      receivedAt: DateTime.now(),
      source: AnalysisSource.manual,
      // 백엔드가 clientMessageId를 필수(@NotBlank)로 요구한다. 수동 입력엔
      // 자연스러운 문자 id가 없으므로 매 검사마다 고유값을 만들어 보낸다.
      // 백엔드는 같은 clientMessageId를 멱등 처리(기존 건 반환)하므로, 타임스탬프
      // 단독 충돌을 막기 위해 랜덤 suffix를 붙여 사실상 유일성을 보장한다.
      clientMessageId:
          'manual-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(0x7fffffff)}',
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (!outcome.ok) {
      // 한도 초과(429)면 서버 안내 문구를, 그 외엔 일반 실패 문구를 그대로 노출.
      _snack(outcome.error ?? '분석에 실패했어요. 잠시 후 다시 시도해 주세요.');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnalysisDetailScreen(
          analysisId: outcome.accepted!.analysisId,
          messageText: text,
        ),
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

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
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(fontSize: 16, height: 1.5),
                      decoration: const InputDecoration.collapsed(
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
                          // 서버가 실제로 가리는 건 번호류(주민·카드·전화·계좌)와
                          // 이메일뿐이다. 이름은 안 가리고, 링크는 검사에 필요해
                          // 일부러 남긴다(SafeFam_BE PiiMaskingService). 가리지도
                          // 않는 걸 가린다고 적으면 그게 곧 거짓 약속이라 실제
                          // 동작대로 적는다(#119에서 방침도 같은 이유로 고쳤다).
                          child: Text('붙여넣은 내용은 전화·계좌·카드번호를 가린 뒤 분석돼요.',
                              style: AppText.caption)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SfButton(_loading ? '분석 중…' : '검사하기',
                    icon: Icons.shield_outlined,
                    onTap: _loading ? null : _analyze),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
