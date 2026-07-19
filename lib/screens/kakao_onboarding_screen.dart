import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../services/auth_api.dart';
import 'family_flow.dart';

/// 카카오 신규 회원 온보딩 — 카카오 로그인 후 휴대폰 인증·이름으로 가입 완료.
/// (카카오 로그인에서 신규 회원으로 판별되면 진입)
/// 인증번호 발송·검증은 회원가입과 동일 API 재사용.
class KakaoOnboardingScreen extends StatefulWidget {
  final String kakaoAccessToken;
  const KakaoOnboardingScreen({super.key, required this.kakaoAccessToken});

  @override
  State<KakaoOnboardingScreen> createState() => _KakaoOnboardingScreenState();
}

class _KakaoOnboardingScreenState extends State<KakaoOnboardingScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _name = TextEditingController();

  bool _requested = false; // 인증번호 발송 여부
  bool _verified = false; // 인증 완료 여부
  bool _loading = false;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _name.dispose();
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

  Future<void> _verifyCode() => _run(() async {
        if (_code.text.trim().isEmpty) {
          _toast('인증번호를 입력해 주세요');
          return;
        }
        final ok =
            await AuthApi.verifyCode(_phone.text.trim(), _code.text.trim());
        if (!ok) {
          _toast('인증번호가 올바르지 않아요');
          return;
        }
        if (mounted) {
          setState(() => _verified = true);
          _toast('휴대폰 인증이 완료됐어요');
        }
      });

  Future<void> _submit() => _run(() async {
        if (_name.text.trim().isEmpty) {
          _toast('이름을 입력해 주세요');
          return;
        }
        final r = await AuthApi.kakaoSignup(
          kakaoAccessToken: widget.kakaoAccessToken,
          phoneNumber: _phone.text.trim(),
          name: _name.text.trim(),
        );
        if (!r.success) {
          _toast('가입에 실패했어요. 잠시 후 다시 시도해 주세요');
          return;
        }
        if (mounted) {
          // 카카오 가입 완료 = 신규 회원 → 가족 등록으로
          Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const FamilyRegisterScreen()),
              (route) => false);
        }
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
        title: const Text('카카오 회원가입', style: AppText.titleScreen),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            children: [
              const SizedBox(height: 6),
              const Text('휴대폰 인증 후 가입을 완료해요', style: AppText.caption),
              const SizedBox(height: 20),
              _label('휴대전화 번호'),
              _field(_phone, '010-0000-0000', TextInputType.phone,
                  enabled: !_verified),
              if (!_requested) ...[
                const SizedBox(height: 14),
                SfButton('인증번호 요청', onTap: _loading ? null : _requestCode),
              ],
              if (_requested && !_verified) ...[
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
                const SizedBox(height: 14),
                SfButton('인증번호 확인', onTap: _loading ? null : _verifyCode),
              ],
              if (_verified) ...[
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.low, size: 20),
                    SizedBox(width: 6),
                    Text('휴대폰 인증 완료',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.low)),
                  ],
                ),
                const SizedBox(height: 16),
                _label('이름'),
                _field(_name, '가족에게 보일 이름', TextInputType.text),
                const SizedBox(height: 20),
                SfButton('가입 완료', onTap: _loading ? null : _submit),
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
      {bool enabled = true}) {
    return TextField(
      controller: c,
      keyboardType: type,
      enabled: enabled,
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
        disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: AppColors.line, width: 1.5)),
      ),
    );
  }
}
