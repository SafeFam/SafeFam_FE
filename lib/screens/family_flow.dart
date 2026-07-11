import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/main_scaffold.dart';

PreferredSizeWidget _bar(BuildContext c, String title) => AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.t1),
          onPressed: () => Navigator.maybePop(c)),
      title: Text(title, style: AppText.titleScreen),
    );

void _toMain(BuildContext c) => Navigator.pushAndRemoveUntil(
    c, MaterialPageRoute(builder: (_) => const MainScaffold()), (r) => false);

/// 가족 등록 — 인증 완료 후 역할 선택.
class FamilyRegisterScreen extends StatelessWidget {
  const FamilyRegisterScreen({super.key});

  Widget _option(BuildContext c, IconData icon, String title, String desc, Widget next) => InkWell(
        onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => next)),
        child: SfCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: AppColors.blue, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(desc, style: AppText.caption),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.t3),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white, surfaceTintColor: Colors.white, elevation: 0,
        title: const Text('가족 등록', style: AppText.titleScreen),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
              children: [
                const SizedBox(height: 8),
                const Center(child: CharacterDisc(100)),
                const SizedBox(height: 12),
                const Center(child: Text('가입이 끝났어요!', style: AppText.titleLarge)),
                const SizedBox(height: 6),
                const Center(child: Text('가족과 어떻게 함께할지 골라주세요', style: AppText.caption)),
                const SizedBox(height: 20),
                _option(context, Icons.shield_outlined, '보호자로 시작하기',
                    '부모님·가족의 폰을 대신 지켜드려요. 초대 코드를 만들어 보내요.', const InviteCodeScreen()),
                const SizedBox(height: 12),
                _option(context, Icons.people_outline, '보호받는 가족으로 연결',
                    '자녀가 보내준 초대 코드나 QR로 연결해요.', const GuardianLinkScreen()),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: TextButton(
              onPressed: () => _toMain(context),
              child: const Text('나중에 하기', style: TextStyle(color: AppColors.t2, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

/// 보호자 초대 코드 발급.
class InviteCodeScreen extends StatelessWidget {
  const InviteCodeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _bar(context, '초대 코드'),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: Column(
          children: [
            const Text('가족에게 코드를 보내세요', style: AppText.titleResult, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            const Text('보호할 가족의 폰 세이프팸에\n이 코드를 입력하면 연결돼요',
                textAlign: TextAlign.center, style: AppText.caption),
            const SizedBox(height: 18),
            SfCard(
              kind: CardKind.tint,
              padding: const EdgeInsets.all(20),
              child: Column(children: const [
                Text('초대 코드', style: AppText.section),
                SizedBox(height: 8),
                Text('8 2 4 1 5 9',
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: 8, color: AppColors.t1)),
                SizedBox(height: 10),
                Text('09:32 후 만료', style: TextStyle(fontSize: 13, color: AppColors.t3)),
              ]),
            ),
            const SizedBox(height: 18),
            Row(children: const [
              Expanded(child: SfButton('코드 복사', icon: Icons.copy, variant: SfBtn.ghost, compact: true)),
              SizedBox(width: 9),
              Expanded(child: SfButton('공유하기', icon: Icons.send, compact: true)),
            ]),
            const Spacer(),
            const Text('가족이 코드를 입력하면 자동으로 연결돼요',
                style: TextStyle(fontSize: 13, color: AppColors.t3)),
            const SizedBox(height: 12),
            // 데모: 연결됨 시뮬레이션
            SfButton('연결됨 (데모) → 이름 설정',
                variant: SfBtn.ghost,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ConnectNamingScreen()))),
          ],
        ),
      ),
    );
  }
}

/// 연결 후 이름 설정 (전화번호 표시 + 관계 칩).
class ConnectNamingScreen extends StatefulWidget {
  const ConnectNamingScreen({super.key});
  @override
  State<ConnectNamingScreen> createState() => _ConnectNamingScreenState();
}

class _ConnectNamingScreenState extends State<ConnectNamingScreen> {
  int _sel = 0;
  final _rel = const ['어머니', '아버지', '할머니', '할아버지', '기타'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Icon(Icons.check_circle, color: AppColors.low, size: 56)),
              const SizedBox(height: 12),
              const Center(child: Text('연결됐어요!', style: AppText.titleResult)),
              const SizedBox(height: 6),
              const Center(child: Text('이분을 뭐라고 부를까요?', style: AppText.caption)),
              const SizedBox(height: 14),
              SfCard(
                kind: CardKind.tint,
                child: Column(children: const [
                  Text('연결된 번호', style: AppText.caption),
                  SizedBox(height: 4),
                  Text('010-2345-6789',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.t1)),
                ]),
              ),
              const SizedBox(height: 18),
              const SectionLabel('관계'),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  for (var i = 0; i < _rel.length; i++)
                    GestureDetector(
                      onTap: () => setState(() => _sel = i),
                      child: SfChip(_rel[i], selected: _sel == i),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              const SectionLabel('표시 이름'),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                decoration: BoxDecoration(
                    border: Border.all(color: AppColors.line, width: 1.5),
                    borderRadius: BorderRadius.circular(13)),
                child: Text(_rel[_sel], style: const TextStyle(fontSize: 17)),
              ),
              const SizedBox(height: 8),
              const Text('관계를 고르면 자동으로 채워져요. 바꿔도 돼요.',
                  style: TextStyle(fontSize: 13, color: AppColors.t3)),
              const Spacer(),
              SfButton('저장하고 시작하기',
                  onTap: () => Navigator.pushAndRemoveUntil(context,
                      MaterialPageRoute(builder: (_) => const MainScaffold(initialIndex: 2)), (r) => false)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 피보호자: 코드 입력.
class GuardianLinkScreen extends StatelessWidget {
  const GuardianLinkScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _bar(context, '가족 연결'),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: Column(
          children: [
            const SizedBox(height: 12),
            const CharacterDisc(100),
            const SizedBox(height: 10),
            const Text('자녀와 연결해요', style: AppText.titleScreen),
            const SizedBox(height: 8),
            const Text('자녀가 보내준 코드를 넣거나\nQR을 비추면 끝나요',
                textAlign: TextAlign.center, style: AppText.caption),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                  border: Border.all(color: AppColors.line, width: 1.5),
                  borderRadius: BorderRadius.circular(13)),
              child: const Text('· · · · · ·',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 6, color: AppColors.t3)),
            ),
            const SizedBox(height: 11),
            SfButton('코드로 연결하기',
                onTap: () => Navigator.pushAndRemoveUntil(context,
                    MaterialPageRoute(builder: (_) => const MainScaffold()), (r) => false)),
            const SizedBox(height: 18),
            Row(children: const [
              Expanded(child: Divider(color: AppColors.line)),
              Padding(padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('또는', style: TextStyle(color: AppColors.t3))),
              Expanded(child: Divider(color: AppColors.line)),
            ]),
            const SizedBox(height: 18),
            const SfButton('QR 코드 비추기', icon: Icons.qr_code, variant: SfBtn.ghost),
          ],
        ),
      ),
    );
  }
}
