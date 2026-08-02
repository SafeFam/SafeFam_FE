import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../services/whitelist_api.dart';

/// 신뢰 발신자(화이트리스트) 관리 화면.
///
/// 등록해 둔 발신자는 자동 탐지 시 분석을 프리패스한다. 여기서 목록 조회·추가·
/// 삭제만 한다(프리패스 확인 `/check`는 자동 탐지 흐름 담당이라 여기선 안 쓴다).
class WhitelistScreen extends StatefulWidget {
  const WhitelistScreen({super.key});
  @override
  State<WhitelistScreen> createState() => _WhitelistScreenState();
}

class _WhitelistScreenState extends State<WhitelistScreen> {
  Future<List<WhitelistEntry>>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    // 블록 본문: 화살표는 대입식의 값(Future)을 반환해
    // "setState callback returned a Future" 오류를 낸다.
    setState(() {
      _future = _load();
    });
  }

  Future<List<WhitelistEntry>> _load() async {
    final items = await WhitelistApi.getAll();
    // null은 조회 실패(네트워크 등) → 에러 상태. 빈 목록은 정상(등록 없음).
    if (items == null) throw Exception('신뢰 발신자 목록을 불러오지 못했어요');
    return items;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _add() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddWhitelistSheet(),
    );
    if (added == true && mounted) _reload();
  }

  Future<void> _delete(WhitelistEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('신뢰 발신자에서 뺄까요?'),
        content: Text('${e.title} 님이 보낸 문자도 이제 자동으로 분석돼요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('삭제', style: TextStyle(color: AppColors.high))),
        ],
      ),
    );
    if (ok != true) return;
    final done = await WhitelistApi.delete(e.whitelistId);
    if (!mounted) return;
    if (done) {
      _reload();
    } else {
      _snack('삭제에 실패했어요. 잠시 후 다시 시도해 주세요');
    }
  }

  Widget _row(WhitelistEntry e) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SfCard(
          child: Row(
            children: [
              const IconDisc(Icons.verified_user_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.title,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600)),
                    if (e.label != null) ...[
                      const SizedBox(height: 2),
                      Text(e.sender, style: AppText.caption),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: '삭제',
                onPressed: () => _delete(e),
                icon: const Icon(Icons.delete_outline, color: AppColors.t3),
              ),
            ],
          ),
        ),
      );

  Widget _empty() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CharacterDisc(84),
          const SizedBox(height: 14),
          const Text('아직 신뢰 발신자가 없어요', style: AppText.titleScreen),
          const SizedBox(height: 6),
          const Text('은행·가족처럼 믿을 수 있는 번호를 등록하면\n그 번호의 문자는 분석을 건너뛰어요',
              textAlign: TextAlign.center, style: AppText.caption),
          const SizedBox(height: 18),
          SizedBox(
            width: 200,
            child: SfButton('발신자 추가', icon: Icons.add, onTap: _add),
          ),
        ],
      );

  Widget _error() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, color: AppColors.t3, size: 48),
          const SizedBox(height: 12),
          const Text('목록을 불러오지 못했어요', style: AppText.titleScreen),
          const SizedBox(height: 18),
          SizedBox(width: 160, child: SfButton('다시 시도', onTap: _reload)),
        ],
      );

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
        title: const Text('신뢰 발신자', style: AppText.titleScreen),
        actions: [
          IconButton(
              tooltip: '발신자 추가',
              onPressed: _add,
              icon: const Icon(Icons.add, color: AppColors.t1)),
        ],
      ),
      body: FutureBuilder<List<WhitelistEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Padding(padding: const EdgeInsets.all(18), child: _error());
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return Padding(padding: const EdgeInsets.all(18), child: _empty());
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              children: [
                const Text('이 발신자의 문자는 분석을 건너뛰어요',
                    style: AppText.caption),
                const SizedBox(height: 12),
                for (final e in items) _row(e),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 발신자 추가 바텀시트. 성공 시 true로 pop 한다.
class _AddWhitelistSheet extends StatefulWidget {
  const _AddWhitelistSheet();
  @override
  State<_AddWhitelistSheet> createState() => _AddWhitelistSheetState();
}

class _AddWhitelistSheetState extends State<_AddWhitelistSheet> {
  final _sender = TextEditingController();
  final _label = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _sender.dispose();
    _label.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final sender = _sender.text.trim();
    if (sender.isEmpty) {
      setState(() => _error = '번호나 발신자를 입력해 주세요.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await WhitelistApi.create(sender, label: _label.text);
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.t3),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: AppColors.line, width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: AppColors.blue, width: 1.5)),
      );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('신뢰 발신자 추가', style: AppText.titleScreen),
            const SizedBox(height: 6),
            const Text('은행 대표번호처럼 믿을 수 있는 발신자를 등록하세요.',
                style: AppText.caption),
            const SizedBox(height: 16),
            const SectionLabel('번호 또는 발신자'),
            const SizedBox(height: 6),
            TextField(
              controller: _sender,
              enabled: !_busy,
              keyboardType: TextInputType.text,
              maxLength: 100,
              style: const TextStyle(fontSize: 16),
              decoration: _dec('예: 1588-1234, 국민은행').copyWith(
                counterText: '',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 12),
            const SectionLabel('이름표 (선택)'),
            const SizedBox(height: 6),
            TextField(
              controller: _label,
              enabled: !_busy,
              maxLength: 50,
              style: const TextStyle(fontSize: 16),
              inputFormatters: [LengthLimitingTextInputFormatter(50)],
              decoration: _dec('예: 주거래 은행').copyWith(counterText: ''),
            ),
            const SizedBox(height: 16),
            SfButton(_busy ? '등록 중…' : '추가하기',
                icon: Icons.add, onTap: _busy ? null : _submit),
          ],
        ),
      ),
    );
  }
}
