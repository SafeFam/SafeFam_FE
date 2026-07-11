import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../services/auth_api.dart';
import 'login_screen.dart';

/// 마이페이지 — 내 정보 + 로그아웃. (더보기 > 내 정보에서 진입)
class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('로그아웃', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: const Text('정말 로그아웃할까요?', style: TextStyle(fontSize: 15)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('로그아웃', style: TextStyle(color: AppColors.high))),
        ],
      ),
    );
    if (ok != true) return;
    await AuthApi.logout();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
          context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
    }
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
        title: const Text('내 정보', style: AppText.titleScreen),
      ),
      body: FutureBuilder<UserProfile>(
        future: AuthApi.myProfile(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.blue));
          }
          final u = snap.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            children: [
              Center(
                child: Column(
                  children: [
                    const CharacterDisc(100),
                    const SizedBox(height: 12),
                    Text(u.name, style: AppText.titleResult),
                    const SizedBox(height: 4),
                    Text(u.role, style: AppText.caption),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SfCard(
                child: Column(
                  children: [
                    _row('이름', u.name),
                    const Divider(color: AppColors.line, height: 22),
                    _row('휴대전화', u.phoneMasked),
                    const Divider(color: AppColors.line, height: 22),
                    _row('역할', u.role),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SfCard(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _link(Icons.description_outlined, '이용약관'),
                    const Divider(color: AppColors.line, height: 1),
                    _link(Icons.shield_outlined, '개인정보처리방침'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SfButton('로그아웃',
                  icon: Icons.logout, variant: SfBtn.ghost, onTap: () => _logout(context)),
            ],
          );
        },
      ),
    );
  }

  Widget _row(String k, String v) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(fontSize: 16, color: AppColors.t2)),
          Text(v, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      );

  Widget _link(IconData icon, String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Row(
          children: [
            Icon(icon, color: AppColors.t2, size: 22),
            const SizedBox(width: 13),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
            const Icon(Icons.chevron_right, color: AppColors.t3),
          ],
        ),
      );
}
