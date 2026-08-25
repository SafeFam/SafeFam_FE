import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../services/auth_api.dart';
import 'legal_screen.dart';
import 'login_screen.dart';

/// 마이페이지 — 내 정보 + 이름 수정 + 로그아웃 + 회원 탈퇴.
/// (더보기 > 내 정보에서 진입) users/me API와 연동.
class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  late Future<UserProfile> _future;

  @override
  void initState() {
    super.initState();
    _future = AuthApi.myProfile();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = AuthApi.myProfile();
    });
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('로그아웃',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: const Text('정말 로그아웃할까요?', style: TextStyle(fontSize: 15)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('로그아웃', style: TextStyle(color: AppColors.high))),
        ],
      ),
    );
    if (ok != true) return;
    await AuthApi.logout();
    _toLogin();
  }

  void _toLogin() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
  }

  /// 이름 수정 다이얼로그 → PATCH /users/me.
  Future<void> _editName(String current) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _TextPromptDialog(
        title: '이름 수정',
        hintText: '이름을 입력하세요',
        initialText: current,
        maxLength: 30,
        trim: true,
        emptyError: '이름을 입력해 주세요',
        confirmLabel: '저장',
      ),
    );
    if (newName == null || newName == current) return;
    final updated = await AuthApi.updateName(newName);
    if (updated == null) {
      _toast('이름을 수정하지 못했어요. 잠시 후 다시 시도해 주세요');
      return;
    }
    _toast('이름을 수정했어요');
    _reload();
  }

  /// 회원 탈퇴 — 본인 확인용 비밀번호 재입력 → DELETE /users/me.
  Future<void> _withdraw() async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _TextPromptDialog(
        title: '회원 탈퇴',
        description: '탈퇴하면 계정과 탐지 이력에 접근할 수 없어요.\n'
            '본인 확인을 위해 비밀번호를 입력해 주세요.',
        hintText: '비밀번호',
        obscureText: true,
        emptyError: '비밀번호를 입력해 주세요',
        confirmLabel: '탈퇴',
        confirmColor: AppColors.high,
      ),
    );
    if (password == null) return;
    final ok = await AuthApi.withdraw(password);
    if (!ok) {
      _toast('탈퇴에 실패했어요. 비밀번호를 확인해 주세요');
      return;
    }
    _toast('탈퇴가 완료되었어요');
    _toLogin();
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
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('정보를 불러오지 못했어요. 잠시 후 다시 시도해 주세요',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: AppColors.t2)),
                    const SizedBox(height: 16),
                    SfButton('다시 시도',
                        variant: SfBtn.ghost, onTap: _reload),
                  ],
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.blue));
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
                    if (u.createdAt != null) ...[
                      const SizedBox(height: 4),
                      Text('${_formatDate(u.createdAt!)} 가입',
                          style: AppText.caption),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SfCard(
                child: Column(
                  children: [
                    _editRow('이름', u.name, onTap: () => _editName(u.name)),
                    const Divider(color: AppColors.line, height: 22),
                    _row('휴대전화', u.phoneMasked),
                    if (u.createdAt != null) ...[
                      const Divider(color: AppColors.line, height: 22),
                      _row('가입일', _formatDate(u.createdAt!)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SfCard(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _link(Icons.description_outlined, '이용약관',
                        onTap: () => _showDoc(LegalDoc.terms)),
                    const Divider(color: AppColors.line, height: 1),
                    _link(Icons.shield_outlined, '개인정보처리방침',
                        onTap: () => _showDoc(LegalDoc.privacy)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SfButton('로그아웃',
                  icon: Icons.logout, variant: SfBtn.ghost, onTap: _logout),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _withdraw,
                child: const Text('회원 탈퇴',
                    style: TextStyle(
                        fontSize: 14,
                        color: AppColors.t3,
                        decoration: TextDecoration.underline)),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  Widget _row(String k, String v) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(fontSize: 16, color: AppColors.t2)),
          Text(v,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      );

  /// 값 옆에 수정 아이콘을 붙인 탭 가능한 행. 긴 이름은 줄여서(...) 넘침 방지.
  Widget _editRow(String k, String v, {required VoidCallback onTap}) => InkWell(
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: const TextStyle(fontSize: 16, color: AppColors.t2)),
            const SizedBox(width: 12),
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(v,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.edit_outlined,
                      size: 18, color: AppColors.t3),
                ],
              ),
            ),
          ],
        ),
      );

  void _showDoc(LegalDoc doc) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => LegalScreen(doc)));

  Widget _link(IconData icon, String label, {VoidCallback? onTap}) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Row(
            children: [
              Icon(icon, color: AppColors.t2, size: 22),
              const SizedBox(width: 13),
              Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
              const Icon(Icons.chevron_right, color: AppColors.t3),
            ],
          ),
        ),
      );
}

/// 글자 하나를 받아 돌려주는 확인 다이얼로그(이름 수정·탈퇴 비밀번호 확인).
///
/// ★ 컨트롤러를 **이 위젯이 직접 소유**하는 것이 핵심이다. 예전에는 호출부에서
/// [TextEditingController]를 만들고 `showDialog`가 반환되자마자 `dispose()`를
/// 불렀는데, `showDialog`는 [Navigator.pop] 시점에 반환되는 반면 다이얼로그
/// 라우트는 **퇴장 애니메이션이 끝날 때까지 살아 있다**. 그 사이 [TextField]가
/// 이미 버려진 컨트롤러를 건드려 "A TextEditingController was used after being
/// disposed"로 레드 스크린이 떴다. State가 소유하면 라우트가 완전히 사라진 뒤
/// [State.dispose]가 불리므로 이 경합이 생기지 않는다.
class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.hintText,
    required this.emptyError,
    required this.confirmLabel,
    this.description,
    this.initialText = '',
    this.obscureText = false,
    this.maxLength,
    this.trim = false,
    this.confirmColor,
  });

  final String title;
  final String hintText;

  /// 입력이 비었을 때 필드 아래에 띄울 문구.
  final String emptyError;
  final String confirmLabel;

  /// 제목과 입력 칸 사이에 들어갈 설명(없으면 생략).
  final String? description;
  final String initialText;
  final bool obscureText;
  final int? maxLength;

  /// 앞뒤 공백을 털어서 돌려줄지. 이름처럼 사람이 읽는 값에만 쓴다
  /// (비밀번호는 공백도 유효한 문자라 절대 손대지 않는다).
  final bool trim;

  /// 확인 버튼 색. 되돌릴 수 없는 동작(탈퇴)에 경고색을 준다.
  final Color? confirmColor;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialText);
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value =
        widget.trim ? _controller.text.trim() : _controller.text;
    if (value.isEmpty) {
      setState(() => _errorText = widget.emptyError);
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: _controller,
      autofocus: true,
      obscureText: widget.obscureText,
      maxLength: widget.maxLength,
      style: const TextStyle(fontSize: 16),
      onSubmitted: (_) => _submit(),
      decoration: InputDecoration(
        hintText: widget.hintText,
        errorText: _errorText,
      ),
    );

    return AlertDialog(
      title: Text(widget.title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      content: widget.description == null
          ? field
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.description!,
                    style: const TextStyle(fontSize: 15, color: AppColors.t2)),
                const SizedBox(height: 12),
                field,
              ],
            ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소')),
        TextButton(
          onPressed: _submit,
          child: Text(widget.confirmLabel,
              style: TextStyle(color: widget.confirmColor)),
        ),
      ],
    );
  }
}
