import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/app_prefs.dart';
import '../widgets/common.dart';
import 'login_screen.dart';

/// 첫 실행 온보딩. 문자·알림·오버레이 권한을 왜 받는지 설명(심사 통과율 직결)하고,
/// 마스킹·화이트리스트로 개인정보를 안전하게 처리한다는 신뢰 메시지를 전달.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _c = PageController();
  int _page = 0;

  static const _pages = <_OnbData>[
    _OnbData(
      character: true,
      icon: null,
      title: 'SafeFam이 가족을 지켜요',
      desc: '문자와 전화 속 금융사기를 자동으로 찾아내\n위험할 때 바로 알려드려요.',
    ),
    _OnbData(
      character: false,
      icon: Icons.sms_outlined,
      title: '문자와 알림을 확인해요',
      desc: '받은 문자에서 사기 패턴을 자동으로 찾기 위해\n문자·알림 접근 권한이 필요해요.',
    ),
    _OnbData(
      character: false,
      icon: Icons.open_in_full,
      title: '위험할 땐 화면 위에 크게 알려요',
      desc: '다른 앱을 쓰는 중에도 위험을 놓치지 않도록\n화면 위에 경고를 띄우는 권한이 필요해요.',
    ),
    _OnbData(
      character: true,
      icon: null,
      title: '개인정보는 안전해요',
      desc: '이름·번호 같은 정보는 분석 전에 가려서 처리하고,\n믿을 수 있는 번호는 검사 없이 통과시켜요.',
    ),
  ];

  bool get _last => _page == _pages.length - 1;

  void _next() {
    if (_last) {
      _finish();
    } else {
      _c.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    }
  }

  /// 온보딩 종료. '시작하기'·'건너뛰기' 둘 다 완료로 기록해
  /// 기기 최초 1회만 노출되게 한다.
  Future<void> _finish() async {
    await AppPrefs.markOnboardingSeen();
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('건너뛰기', style: TextStyle(color: AppColors.t3, fontSize: 15)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _c,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _OnbPage(_pages[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _page ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: i == _page ? AppColors.blue : AppColors.line,
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
              child: SfButton(_last ? '시작하기' : '다음', onTap: _next),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnbData {
  final bool character;
  final IconData? icon;
  final String title;
  final String desc;
  const _OnbData({required this.character, required this.icon, required this.title, required this.desc});
}

class _OnbPage extends StatelessWidget {
  final _OnbData d;
  const _OnbPage(this.d);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (d.character)
            const CharacterDisc(150)
          else
            Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(color: AppColors.bg, shape: BoxShape.circle),
              child: Icon(d.icon, size: 54, color: AppColors.blue),
            ),
          const SizedBox(height: 28),
          Text(d.title, textAlign: TextAlign.center, style: AppText.titleLarge),
          const SizedBox(height: 12),
          Text(d.desc, textAlign: TextAlign.center, style: AppText.caption.copyWith(fontSize: 15)),
        ],
      ),
    );
  }
}
