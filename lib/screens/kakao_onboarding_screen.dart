import 'package:flutter/material.dart';

import '../services/auth_api.dart';
import 'family_flow.dart';

class KakaoOnboardingScreen extends StatefulWidget {
  final String kakaoAccessToken;
  const KakaoOnboardingScreen({super.key, required this.kakaoAccessToken});

  @override
  State<KakaoOnboardingScreen> createState() => _KakaoOnboardingScreenState();
}

class _KakaoOnboardingScreenState extends State<KakaoOnboardingScreen> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  bool _codeSent = false;
  bool _codeVerified = false;
  bool _loading = false;
  String? _error;

  Future<void> _requestCode() async {
    setState(() { _loading = true; _error = null; });
    final ok = await AuthApi.requestCode(_phoneCtrl.text.trim());
    setState(() {
      _loading = false;
      _codeSent = ok;
      if (!ok) _error = '인증번호 발송에 실패했습니다.';
    });
  }

  Future<void> _verifyCode() async {
    setState(() { _loading = true; _error = null; });
    final ok = await AuthApi.verifyCode(_phoneCtrl.text.trim(), _codeCtrl.text.trim());
    setState(() {
      _loading = false;
      _codeVerified = ok;
      if (!ok) _error = '인증번호가 올바르지 않습니다.';
    });
  }

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    final result = await AuthApi.kakaoSignup(
      kakaoAccessToken: widget.kakaoAccessToken,
      phoneNumber: _phoneCtrl.text.trim(),
      name: _nameCtrl.text.trim(),
    );
    setState(() => _loading = false);

    if (!mounted) return;
    if (result.success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const FamilyRegisterScreen()),
      );
    } else {
      setState(() => _error = '가입에 실패했습니다. 다시 시도해 주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('카카오 회원가입')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            TextField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(labelText: '전화번호'),
              keyboardType: TextInputType.phone,
              enabled: !_codeVerified,
            ),
            const SizedBox(height: 8),
            if (!_codeVerified)
              ElevatedButton(
                onPressed: _loading ? null : _requestCode,
                child: Text(_codeSent ? '인증번호 재발송' : '인증번호 발송'),
              ),
            if (_codeSent && !_codeVerified) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _codeCtrl,
                decoration: const InputDecoration(labelText: '인증번호'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _loading ? null : _verifyCode,
                child: const Text('인증번호 확인'),
              ),
            ],
            if (_codeVerified) ...[
              const SizedBox(height: 16),
              const Text('✓ 인증 완료', style: TextStyle(color: Colors.green)),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: '이름'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: const Text('가입 완료'),
              ),
            ],
            if (_loading)
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}