import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../services/auth_api.dart';

/// 비밀번호 재설정 — 휴대폰 인증(요청→검증) 후 새 비밀번호로 변경.
/// (로그인 화면의 '비밀번호를 잊으셨나요?'로 진입)
/// 인증번호 발송·검증은 회원가입과 동일 API 재사용.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _requested = false; // 인증번호 발송 여부
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
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

  Future<void> _reset() => _run(() async {
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
        final pwError = AuthApi.passwordError(_password.text);
        if (pwError != null) {
          _toast(pwError);
          return;
        }
        final ok = await AuthApi.resetPassword(
          phone: _phone.text.trim(),
          code: _code.text.trim(),
          newPassword: _password.text,
        );
        if (!ok) {
          _toast('비밀번호 재설정에 실패했어요. 잠시 후 다시 시도해 주세요');
          return;
        }
        _toast('비밀번호를 바꿨어요. 새 비밀번호로 로그인해 주세요');
        if (mounted) Navigator.pop(context); // 로그인 화면으로 복귀
      });

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
        title: const Text('비밀번호 재설정', style: AppText.titleScreen),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            children: [
              const SizedBox(height: 6),
              const Text('휴대폰 인증 후 새 비밀번호를 설정해요', style: AppText.caption),
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
                _label('새 비밀번호'),
                _field(
                    _password, '영문·숫자 포함 8자 이상', TextInputType.visiblePassword,
                    obscure: _obscure,
                    toggleObscure: () => setState(() => _obscure = !_obscure)),
                const SizedBox(height: 20),
                SfButton('비밀번호 재설정', onTap: _loading ? null : _reset),
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
}
