import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../services/auth_api.dart';

/// 계정 잠금 해제 — 로그인 실패 누적으로 잠긴 계정을 휴대폰 인증으로 해제.
/// (로그인 화면에서 잠금 감지 시 안내로 진입. 휴대폰 번호는 미리 채워 넘길 수 있음)
/// 인증번호 발송·검증은 회원가입/재설정과 동일 API 재사용.
class UnlockAccountScreen extends StatefulWidget {
  /// 로그인 화면에서 입력한 번호를 넘겨받아 미리 채운다(선택).
  final String? initialPhone;
  const UnlockAccountScreen({super.key, this.initialPhone});
  @override
  State<UnlockAccountScreen> createState() => _UnlockAccountScreenState();
}

class _UnlockAccountScreenState extends State<UnlockAccountScreen> {
  late final TextEditingController _phone =
      TextEditingController(text: widget.initialPhone ?? '');
  final _code = TextEditingController();
  bool _requested = false; // 인증번호 발송 여부
  bool _loading = false;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
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

  Future<void> _unlock() => _run(() async {
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
        // verifyCode로 서버측 인증(verified) 상태를 만든 뒤 해제를 요청한다.
        // 백엔드가 이 상태를 consume해 OTP 소유를 검증하므로 code는 바디에 없다.
        final ok = await AuthApi.unlock(_phone.text.trim());
        if (!ok) {
          _toast('잠금 해제에 실패했어요. 잠시 후 다시 시도해 주세요');
          return;
        }
        _toast('계정 잠금을 해제했어요. 다시 로그인해 주세요');
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
        title: const Text('계정 잠금 해제', style: AppText.titleScreen),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            children: [
              const SizedBox(height: 6),
              const Text('비밀번호를 여러 번 틀려 계정이 잠겼어요.\n휴대폰 인증으로 잠금을 해제할 수 있어요',
                  style: AppText.caption),
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
                const SizedBox(height: 20),
                SfButton('잠금 해제', onTap: _loading ? null : _unlock),
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

  Widget _field(TextEditingController c, String hint, TextInputType type) {
    return TextField(
      controller: c,
      keyboardType: type,
      style: const TextStyle(fontSize: 17),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.t3),
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
