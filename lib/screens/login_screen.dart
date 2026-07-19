import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../services/auth_api.dart';
import '../widgets/main_scaffold.dart';
import 'family_flow.dart';
import 'kakao_onboarding_screen.dart';
import 'signup_screen.dart';
import 'reset_password_screen.dart';

/// 로그인 — 휴대폰 번호 + 비밀번호. 신규는 회원가입 화면으로 이동.
/// 결과는 AuthApi를 통해 처리(지금은 껍데기).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  void _goNext(AuthResult r) {
    if (!mounted) return;
    final Widget next;
    if (r.isNewUser && r.kakaoAccessToken != null) {
      next = KakaoOnboardingScreen(kakaoAccessToken: r.kakaoAccessToken!);
    } else if (r.isNewUser) {
      next = const FamilyRegisterScreen();
    } else {
      next = const MainScaffold();
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => next));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _loading = true);
    try {
      await action();
    } catch (_) {
      _toast('문제가 발생했어요. 잠시 후 다시 시도해 주세요');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _login() => _run(() async {
        if (_phone.text.trim().isEmpty) {
          _toast('휴대폰 번호를 입력해 주세요');
          return;
        }
        if (_password.text.isEmpty) {
          _toast('비밀번호를 입력해 주세요');
          return;
        }
        final r = await AuthApi.login(
            phone: _phone.text.trim(), password: _password.text);
        if (r.success) {
          _goNext(r);
        } else {
          _toast('로그인에 실패했어요. 번호와 비밀번호를 확인해 주세요');
        }
      });

  Future<void> _social(String provider) => _run(() async {
        final r = await AuthApi.socialLogin(provider);
        if (r.success) {
          _goNext(r);
        } else {
          _toast('로그인에 실패했어요. 다시 시도해 주세요');
        }
      });

  void _goSignup() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const SignupScreen()));
  }

  void _goResetPassword() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const ResetPasswordScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                      child: Column(
                        children: [
                          const SizedBox(height: 48),
                          const CharacterDisc(100),
                          const SizedBox(height: 14),
                          const Text('로그인', style: AppText.titleResult),
                          const SizedBox(height: 6),
                          const Text('휴대폰 번호로 로그인하세요', style: AppText.caption),
                          const SizedBox(height: 22),
                          _label('휴대전화 번호'),
                          _field(_phone, '010-0000-0000', TextInputType.phone),
                          const SizedBox(height: 12),
                          _label('비밀번호'),
                          _field(_password, '비밀번호 입력',
                              TextInputType.visiblePassword,
                              obscure: _obscure,
                              toggleObscure: () =>
                                  setState(() => _obscure = !_obscure)),
                          const SizedBox(height: 18),
                          SfButton('로그인', onTap: _loading ? null : _login),
                          const SizedBox(height: 10),
                          SfButton('회원가입',
                              variant: SfBtn.ghost,
                              onTap: _loading ? null : _goSignup),
                          const SizedBox(height: 14),
                          GestureDetector(
                            onTap: _loading ? null : _goResetPassword,
                            child: const Text('비밀번호를 잊으셨나요?',
                                style: TextStyle(
                                    fontSize: 14, color: AppColors.t2)),
                          ),
                          const Spacer(),
                          _kakao(),
                          const SizedBox(height: 12),
                          SfButton('구글로 계속하기',
                              icon: Icons.g_mobiledata,
                              variant: SfBtn.ghost,
                              onTap: _loading ? null : () => _social('google')),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_loading)
              Container(
                color: Colors.black.withOpacity(0.05),
                child: const Center(
                    child: CircularProgressIndicator(color: AppColors.blue)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Align(
        alignment: Alignment.centerLeft,
        child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(t, style: AppText.section)),
      );

  Widget _field(TextEditingController c, String hint, TextInputType type,
      {bool obscure = false, VoidCallback? toggleObscure}) {
    return TextField(
      controller: c,
      keyboardType: type,
      obscureText: obscure,
      style: const TextStyle(fontSize: 17),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.t3),
        suffixIcon: toggleObscure == null
            ? null
            : IconButton(
                icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.t3, size: 22),
                onPressed: toggleObscure,
              ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: AppColors.line, width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: AppColors.blue, width: 1.5)),
      ),
    );
  }

  Widget _kakao() => Material(
        color: const Color(0xFFFAE100),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _loading ? null : () => _social('kakao'),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble, size: 20, color: Color(0xFF3B1E1E)),
                SizedBox(width: 8),
                Text('카카오로 계속하기',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3B1E1E))),
              ],
            ),
          ),
        ),
      );
}
