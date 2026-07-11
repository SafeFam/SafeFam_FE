import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../services/auth_api.dart';
import 'family_flow.dart';
import '../widgets/main_scaffold.dart';

/// 회원가입/로그인 — 휴대폰 인증 + 소셜. 결과는 AuthApi를 통해 처리(지금은 껍데기).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _nickname = TextEditingController();
  final _password = TextEditingController();
  bool _requested = false;
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _nickname.dispose();
    _password.dispose();
    super.dispose();
  }

  void _goNext(AuthResult r) {
    if (!mounted) return;
    final next = r.isNewUser
        ? const FamilyRegisterScreen() // 신규 → 가족 등록
        : const MainScaffold();        // 기존 → 홈
    Navigator.pushAndRemoveUntil(
        context, MaterialPageRoute(builder: (_) => next), (route) => false);
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _loading = true);
    try {
      await action();
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

  Future<void> _onPrimary() => _run(() async {
        if (!_requested) {
          final ok = await AuthApi.requestCode(_phone.text);
          if (ok && mounted) setState(() => _requested = true);
        } else {
          if (_nickname.text.trim().isEmpty) {
            _toast('닉네임을 입력해 주세요');
            return;
          }
          if (_password.text.length < 4) {
            _toast('비밀번호는 4자 이상 입력해 주세요');
            return;
          }
          final r = await AuthApi.verifyCode(
            _phone.text,
            _code.text,
            nickname: _nickname.text.trim(),
            password: _password.text,
          );
          if (r.success) _goNext(r);
        }
      });

  Future<void> _social(String provider) =>
      _run(() async => _goNext(await AuthApi.socialLogin(provider)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
              child: Column(
                children: [
                  const SizedBox(height: 48),
                  const CharacterDisc(100),
                  const SizedBox(height: 14),
                  const Text('시작하기', style: AppText.titleResult),
                  const SizedBox(height: 6),
                  const Text('휴대폰 번호만 있으면 돼요', style: AppText.caption),
                  const SizedBox(height: 22),
                  _label('휴대전화 번호'),
                  _field(_phone, '010-0000-0000', TextInputType.phone),
                  if (_requested) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('인증번호', style: AppText.section),
                        GestureDetector(
                          onTap: () => AuthApi.requestCode(_phone.text),
                          child: const Text('재요청', style: TextStyle(fontSize: 13, color: AppColors.t3)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _field(_code, '인증번호 입력', TextInputType.number, trailing: '2:48'),
                    const SizedBox(height: 12),
                    _label('닉네임'),
                    _field(_nickname, '가족에게 보일 이름', TextInputType.text),
                    const SizedBox(height: 12),
                    _label('비밀번호'),
                    _field(_password, '4자 이상 입력', TextInputType.visiblePassword,
                        obscure: _obscure,
                        toggleObscure: () => setState(() => _obscure = !_obscure)),
                  ],
                  const SizedBox(height: 18),
                  SfButton(_requested ? '확인' : '인증번호 요청', onTap: _loading ? null : _onPrimary),
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
            if (_loading)
              Container(
                color: Colors.black.withOpacity(0.05),
                child: const Center(child: CircularProgressIndicator(color: AppColors.blue)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Align(
        alignment: Alignment.centerLeft,
        child: Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t, style: AppText.section)),
      );

  Widget _field(TextEditingController c, String hint, TextInputType type,
      {String? trailing, bool obscure = false, VoidCallback? toggleObscure}) {
    return TextField(
      controller: c,
      keyboardType: type,
      obscureText: obscure,
      style: const TextStyle(fontSize: 17),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.t3),
        suffixText: trailing,
        suffixStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.blue),
        suffixIcon: toggleObscure == null
            ? null
            : IconButton(
                icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.t3, size: 22),
                onPressed: toggleObscure,
              ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
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
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF3B1E1E))),
              ],
            ),
          ),
        ),
      );
}
