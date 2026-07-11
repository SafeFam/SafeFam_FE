import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'results.dart';
import 'family_flow.dart';
import 'mypage_screen.dart';

/// 더보기(설정) — 홈 톱니바퀴로 진입(pushed). 하단 탭 없음.
class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});
  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  bool _big = false;
  bool _voice = true;

  Widget _link(IconData icon, String label, {VoidCallback? onTap}) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Row(children: [
            Icon(icon, color: AppColors.t2, size: 22),
            const SizedBox(width: 13),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
            const Icon(Icons.chevron_right, color: AppColors.t3),
          ]),
        ),
      );

  Widget _toggle(IconData icon, String label, bool v, ValueChanged<bool> on) => Row(children: [
        Icon(icon, color: AppColors.blue, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
        Switch(
            value: v,
            activeColor: Colors.white,
            activeTrackColor: AppColors.blue,
            inactiveTrackColor: AppColors.toggleOff,
            onChanged: on),
      ]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.t1),
            onPressed: () => Navigator.maybePop(context)),
        title: const Text('더보기', style: AppText.titleScreen),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
        children: [
          const SectionLabel('보기 설정 · 누구나'),
          SfCard(
            child: Column(children: [
              _toggle(Icons.text_fields, '글씨 더 크게', _big, (v) => setState(() => _big = v)),
              const Divider(color: AppColors.line, height: 24),
              _toggle(Icons.volume_up_outlined, '음성으로 읽어주기', _voice, (v) => setState(() => _voice = v)),
            ]),
          ),
          const SizedBox(height: 16),
          const SectionLabel('기록'),
          SfCard(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
              _link(Icons.flag_outlined, '내 신고 내역'),
              const Divider(color: AppColors.line, height: 1),
              _link(Icons.smart_toy_outlined, '도움말 챗봇'),
            ]),
          ),
          const SizedBox(height: 16),
          const SectionLabel('가족'),
          SfCard(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _link(Icons.person_add_alt, '가족 추가·초대 코드',
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const InviteCodeScreen()))),
          ),
          const SizedBox(height: 16),
          const SectionLabel('계정'),
          SfCard(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
              _link(Icons.manage_accounts_outlined, '내 정보',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const MyPageScreen()))),
              const Divider(color: AppColors.line, height: 1),
              _link(Icons.logout, '로그아웃'),
            ]),
          ),
          const SizedBox(height: 16),
          const SectionLabel('화면 미리보기 · 개발용'),
          SfCard(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
              _link(Icons.phone_in_talk_outlined, '보이스피싱 결과',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const VoiceResultScreen()))),
              const Divider(color: AppColors.line, height: 1),
              _link(Icons.link, 'URL 검사 결과',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const UrlResultScreen()))),
            ]),
          ),
        ],
      ),
    );
  }
}
