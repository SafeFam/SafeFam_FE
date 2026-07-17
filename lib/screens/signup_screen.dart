import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../services/auth_api.dart';
import 'family_flow.dart';

/// 회원가입 — 휴대폰 인증(요청→확인) 후 닉네임·비밀번호로 계정 생성.
/// (로그인 화면의 '회원가입' 버튼으로 진입)
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _nickname = TextEditingController();
  final _password = TextEditingController();
  bool _requested = false; // 인증번호 발송 여부
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

  Future<void> _requestCode() => _run(() async {
        if (_phone.text.trim().isEmpty) {
          _toast('휴대폰 번호를 입력해 주세요');
          return;
        }
        final ok = await AuthApi.requestCode(_phone.text.trim());
        if (!ok) {
          _toast('인증번호 발송에 실패했어요. 잠시 후 다시 시도해 주세요');
          return;
        }
        if (mounted) {
          setState(() => _requested = true);
          _toast('인증번호를 보냈어요');
        }
      });

  Future<void> _signup() => _run(() async {
        if (_code.text.trim().isEmpty) {
          _toast('인증번호를 입력해 주세요');
          return;
        }
        final verified =
            await AuthApi.verifyCode(_phone.text.trim(), _code.text.trim());
        if (!verified) {
          _toast('인증번호가 올바르지 않아요');
          return;
        }
        if (_nickname.text.trim().isEmpty) {
          _toast('닉네임을 입력해 주세요');
          return;
        }
        final pwError = _passwordError(_password.text);
        if (pwError != null) {
          _toast(pwError);
          return;
        }
        final created = await AuthApi.signup(
          phone: _phone.text.trim(),
          name: _nickname.text.trim(),
          password: _password.text,
        );
        if (!created) {
          _toast('가입에 실패했어요. 잠시 후 다시 시도해 주세요');
          return;
        }
        // 백엔드 회원가입은 토큰을 주지 않으므로, 이어서 로그인해 토큰을 발급받는다.
        final r = await AuthApi.login(
            phone: _phone.text.trim(), password: _password.text);
        if (!r.success) {
          _toast('가입은 됐어요. 로그인 화면에서 다시 로그인해 주세요');
          return;
        }
        if (mounted) {
          // 가입 흐름 = 신규 회원 → 가족 등록으로
          Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const FamilyRegisterScreen()),
              (route) => false);
        }
      });

  /// 비밀번호 정책: 영문+숫자 포함, 특수문자 없음, 8자 이상.
  String? _passwordError(String pw) {
    if (pw.length < 8) return '비밀번호는 8자 이상이어야 해요';
    if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(pw)) {
      return '비밀번호는 영문과 숫자만 사용할 수 있어요';
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(pw) || !RegExp(r'[0-9]').hasMatch(pw)) {
      return '비밀번호는 영문과 숫자를 모두 포함해야 해요';
    }
    return null;
  }

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
        title: const Text('회원가입', style: AppText.titleScreen),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            children: [
              const SizedBox(height: 6),
              const Text('휴대폰 인증 후 가입해요', style: AppText.caption),
              const SizedBox(height: 20),
              _label('휴대전화 번호'),
              _field(_phone, '010-0000-0000', TextInputType.phone),
              if (!_requested) ...[
                const SizedBox(height: 14),
                SfButton('인증번호 요청', onTap: _loading ? null : _requestCode),
              ],
              if (_requested) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('인증번호', style: AppText.section),
                    GestureDetector(
                      onTap: _loading ? null : _requestCode,
                      child: const Text('재요청',
                          style: TextStyle(fontSize: 13, color: AppColors.t3)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _field(_code, '인증번호 입력', TextInputType.number),
                const SizedBox(height: 12),
                _label('닉네임'),
                _field(_nickname, '가족에게 보일 이름', TextInputType.text),
                const SizedBox(height: 12),
                _label('비밀번호'),
                _field(
                    _password, '영문·숫자 포함 8자 이상', TextInputType.visiblePassword,
                    obscure: _obscure,
                    toggleObscure: () => setState(() => _obscure = !_obscure)),
                const SizedBox(height: 20),
                SfButton('가입하기', onTap: _loading ? null : _signup),
              ],
            ],
          ),
          if (_loading)
            Container(
              color: Colors.black.withOpacity(0.05),
              child: const Center(
                  child: CircularProgressIndicator(color: AppColors.blue)),
            ),
        ],
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
        suffixStyle: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.blue),
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
}
