import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'family_flow.dart';

/// 소셜 로그인 진입 (스플래시·온보딩 다음).
class SocialLoginScreen extends StatelessWidget {
  const SocialLoginScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          child: Column(
            children: [
              const Spacer(),
              const CharacterDisc(142),
              const SizedBox(height: 16),
              const Text('세이프팸', style: AppText.logo),
              const SizedBox(height: 8),
              const Text('간편하게 시작하기', style: AppText.caption),
              const Spacer(),
              _KakaoButton(onTap: () => _toRegister(context)),
              const SizedBox(height: 12),
              SfButton('구글로 계속하기',
                  icon: Icons.g_mobiledata, variant: SfBtn.ghost,
                  onTap: () => _toRegister(context)),
              const SizedBox(height: 12),
              SfButton('휴대폰 번호로 시작하기',
                  icon: Icons.phone_iphone, variant: SfBtn.ghost,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const PhoneAuthScreen()))),
              const SizedBox(height: 16),
              const Text('계속하면 이용약관과 개인정보처리방침에 동의하는 것으로 간주돼요',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.t3, height: 1.5)),
            ],
          ),
        ),
      ),
    );
  }

  void _toRegister(BuildContext c) => Navigator.push(
      c, MaterialPageRoute(builder: (_) => const FamilyRegisterScreen()));
}

class _KakaoButton extends StatelessWidget {
  final VoidCallback onTap;
  const _KakaoButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFAE100),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chat_bubble, size: 20, color: Color(0xFF3B1E1E)),
              SizedBox(width: 8),
              Text('카카오로 계속하기',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF3B1E1E))),
            ],
          ),
        ),
      ),
    );
  }
}

/// 휴대폰 인증 (번호 → 인증번호·타이머 → 확인).
class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});
  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  bool _requested = false;

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
        title: const Text('휴대폰 인증', style: AppText.titleScreen),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: CharacterDisc(100)),
              const SizedBox(height: 14),
              const Center(child: Text('시작하기', style: AppText.titleResult)),
              const SizedBox(height: 6),
              const Center(child: Text('휴대폰 번호만 있으면 돼요', style: AppText.caption)),
              const SizedBox(height: 22),
              const Text('휴대전화 번호', style: AppText.section),
              const SizedBox(height: 6),
              _field(hint: '010-0000-0000'),
              if (_requested) ...[
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('인증번호', style: AppText.section),
                    Text('재요청', style: TextStyle(fontSize: 13, color: AppColors.t3)),
                  ],
                ),
                const SizedBox(height: 6),
                _field(hint: '인증번호 입력', trailing: '2:48'),
              ],
              const SizedBox(height: 20),
              SfButton(_requested ? '확인' : '인증번호 받기', onTap: () {
                if (_requested) {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const FamilyRegisterScreen()));
                } else {
                  setState(() => _requested = true);
                }
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({required String hint, String? trailing}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
            border: Border.all(color: AppColors.line, width: 1.5),
            borderRadius: BorderRadius.circular(13)),
        child: Row(
          children: [
            Expanded(child: Text(hint, style: const TextStyle(fontSize: 17, color: AppColors.t3))),
            if (trailing != null)
              Text(trailing, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.blue)),
          ],
        ),
      );
}
