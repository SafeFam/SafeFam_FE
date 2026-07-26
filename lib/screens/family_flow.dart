import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/main_scaffold.dart';
import '../services/app_prefs.dart';
import '../services/family_api.dart';

PreferredSizeWidget _bar(BuildContext c, String title) => AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.t1),
          onPressed: () => Navigator.maybePop(c)),
      title: Text(title, style: AppText.titleScreen),
    );

void _toMain(BuildContext c, {int index = 0}) => Navigator.pushAndRemoveUntil(
    c,
    MaterialPageRoute(builder: (_) => MainScaffold(initialIndex: index)),
    (r) => false);

/// 가족 등록 — 인증 완료 후 역할 선택.
class FamilyRegisterScreen extends StatelessWidget {
  const FamilyRegisterScreen({super.key});

  Widget _option(BuildContext c, IconData icon, String title, String desc, Widget next) => InkWell(
        onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => next)),
        child: SfCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: AppColors.blue, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(desc, style: AppText.caption),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.t3),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white, surfaceTintColor: Colors.white, elevation: 0,
        title: const Text('가족 등록', style: AppText.titleScreen),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
              children: [
                const SizedBox(height: 8),
                const Center(child: CharacterDisc(100)),
                const SizedBox(height: 12),
                const Center(child: Text('가입이 끝났어요!', style: AppText.titleLarge)),
                const SizedBox(height: 6),
                const Center(child: Text('가족과 어떻게 함께할지 골라주세요', style: AppText.caption)),
                const SizedBox(height: 20),
                _option(context, Icons.shield_outlined, '보호자로 시작하기',
                    '부모님·가족의 폰을 대신 지켜드려요. 초대 코드를 만들어 보내요.', const InviteCodeScreen()),
                const SizedBox(height: 12),
                _option(context, Icons.people_outline, '보호받는 가족으로 연결',
                    '자녀가 보내준 초대 코드로 연결해요.', const GuardianLinkScreen()),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: TextButton(
              onPressed: () => _toMain(context),
              child: const Text('나중에 하기', style: TextStyle(color: AppColors.t2, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

/// 보호자 초대 코드 발급. 진입 시 서버에서 코드를 받아 만료까지 카운트다운한다.
class InviteCodeScreen extends StatefulWidget {
  const InviteCodeScreen({super.key});
  @override
  State<InviteCodeScreen> createState() => _InviteCodeScreenState();
}

class _InviteCodeScreenState extends State<InviteCodeScreen> {
  FamilyInvite? _invite;
  bool _loading = true;
  bool _failed = false;
  Timer? _ticker;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _issue();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _issue() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final invite = await FamilyApi.createInvite();
    if (!mounted) return;
    if (invite == null) {
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }
    setState(() {
      _invite = invite;
      _loading = false;
    });
    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    void tick() {
      final r = _invite!.expiresAt.difference(DateTime.now());
      setState(() => _remaining = r.isNegative ? Duration.zero : r);
    }

    tick();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  bool get _expired => _remaining == Duration.zero;

  String get _mmss {
    final s = _remaining.inSeconds;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _copy() async {
    final code = _invite?.inviteCode;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('초대 코드를 복사했어요')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _bar(context, '초대 코드'),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _failed
                ? _errorView()
                : _codeView(),
      ),
    );
  }

  Widget _errorView() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, color: AppColors.t3, size: 48),
          const SizedBox(height: 12),
          const Text('초대 코드를 만들지 못했어요', style: AppText.titleScreen),
          const SizedBox(height: 6),
          const Text('네트워크를 확인하고 다시 시도해 주세요',
              style: AppText.caption, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          SfButton('다시 시도', onTap: _issue),
        ],
      );

  Widget _codeView() {
    final invite = _invite!;
    final spaced = invite.inviteCode.split('').join(' ');
    return Column(
      children: [
        const Text('가족에게 코드를 보내세요', style: AppText.titleResult, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        const Text('보호할 가족의 폰 세이프팸에\n이 코드를 입력하면 연결돼요',
            textAlign: TextAlign.center, style: AppText.caption),
        const SizedBox(height: 18),
        SfCard(
          kind: CardKind.tint,
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            const Text('초대 코드', style: AppText.section),
            const SizedBox(height: 8),
            Text(
              _expired ? '- - - - - -' : spaced,
              style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 8,
                  color: _expired ? AppColors.t3 : AppColors.t1),
            ),
            const SizedBox(height: 10),
            Text(_expired ? '만료됐어요' : '$_mmss 후 만료',
                style: TextStyle(
                    fontSize: 13,
                    color: _expired ? AppColors.high : AppColors.t3)),
          ]),
        ),
        const SizedBox(height: 18),
        if (_expired)
          SfButton('새 코드 발급', icon: Icons.refresh, onTap: _issue)
        else
          SfButton('코드 복사', icon: Icons.copy, variant: SfBtn.ghost, onTap: _copy),
        const Spacer(),
        const Text('가족이 코드를 입력하면 자동으로 연결돼요',
            style: TextStyle(fontSize: 13, color: AppColors.t3)),
        const SizedBox(height: 12),
        SfButton('가족 목록에서 확인',
            variant: SfBtn.ghost,
            onTap: () => _toMain(context, index: 2)),
      ],
    );
  }
}

/// 연결된 가족의 별명(관계) 설정. 백엔드에 이름 필드가 없어 기기 로컬에 저장한다.
/// 저장하면 true를 반환하며 pop 한다(가족 목록이 새로고침되도록).
class ConnectNamingScreen extends StatefulWidget {
  final FamilyMember member;
  const ConnectNamingScreen({super.key, required this.member});
  @override
  State<ConnectNamingScreen> createState() => _ConnectNamingScreenState();
}

class _ConnectNamingScreenState extends State<ConnectNamingScreen> {
  static const _rel = ['어머니', '아버지', '할머니', '할아버지', '기타'];
  int _sel = 0;

  Future<void> _save() async {
    await AppPrefs.setFamilyName(widget.member.linkId, _rel[_sel]);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final phone = widget.member.wardPhone ?? '번호 없음';
    return Scaffold(
      appBar: _bar(context, '이름 설정'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                  child: Icon(Icons.check_circle, color: AppColors.low, size: 56)),
              const SizedBox(height: 12),
              const Center(child: Text('연결됐어요!', style: AppText.titleResult)),
              const SizedBox(height: 6),
              const Center(child: Text('이분을 뭐라고 부를까요?', style: AppText.caption)),
              const SizedBox(height: 14),
              SfCard(
                kind: CardKind.tint,
                child: Column(children: [
                  const Text('연결된 번호', style: AppText.caption),
                  const SizedBox(height: 4),
                  Text(phone,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.t1)),
                ]),
              ),
              const SizedBox(height: 18),
              const SectionLabel('관계'),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  for (var i = 0; i < _rel.length; i++)
                    GestureDetector(
                      onTap: () => setState(() => _sel = i),
                      child: SfChip(_rel[i], selected: _sel == i),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              const SectionLabel('표시 이름'),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                decoration: BoxDecoration(
                    border: Border.all(color: AppColors.line, width: 1.5),
                    borderRadius: BorderRadius.circular(13)),
                child: Text(_rel[_sel], style: const TextStyle(fontSize: 17)),
              ),
              const SizedBox(height: 8),
              const Text('관계를 고르면 그대로 표시돼요. 내 폰에만 저장돼요.',
                  style: TextStyle(fontSize: 13, color: AppColors.t3)),
              const Spacer(),
              SfButton('저장하기', onTap: _save),
            ],
          ),
        ),
      ),
    );
  }
}

/// 피보호자: 초대 코드 입력으로 연결.
class GuardianLinkScreen extends StatefulWidget {
  const GuardianLinkScreen({super.key});
  @override
  State<GuardianLinkScreen> createState() => _GuardianLinkScreenState();
}

class _GuardianLinkScreenState extends State<GuardianLinkScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = '숫자 6자리를 입력해 주세요.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await FamilyApi.linkByCode(code);
    if (!mounted) return;
    if (result.success) {
      _toMain(context);
    } else {
      setState(() {
        _loading = false;
        _error = result.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _bar(context, '가족 연결'),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: Column(
          children: [
            const SizedBox(height: 12),
            const CharacterDisc(100),
            const SizedBox(height: 10),
            const Text('자녀와 연결해요', style: AppText.titleScreen),
            const SizedBox(height: 8),
            const Text('자녀가 보내준 숫자 6자리 코드를 넣어주세요',
                textAlign: TextAlign.center, style: AppText.caption),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              enabled: !_loading,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 8, color: AppColors.t1),
              decoration: InputDecoration(
                counterText: '',
                hintText: '· · · · · ·',
                hintStyle: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 6, color: AppColors.t3),
                errorText: _error,
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(color: AppColors.line, width: 1.5)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(color: AppColors.blue, width: 1.5)),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 11),
            SfButton(_loading ? '연결 중…' : '코드로 연결하기',
                onTap: _loading ? null : _submit),
            const SizedBox(height: 18),
            const Row(children: [
              Expanded(child: Divider(color: AppColors.line)),
              Padding(padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('또는', style: TextStyle(color: AppColors.t3))),
              Expanded(child: Divider(color: AppColors.line)),
            ]),
            const SizedBox(height: 18),
            SfButton('QR 코드 비추기',
                icon: Icons.qr_code,
                variant: SfBtn.ghost,
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('QR 연결은 곧 제공돼요')))),
          ],
        ),
      ),
    );
  }
}
