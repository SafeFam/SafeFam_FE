import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../services/app_prefs.dart';
import '../services/family_api.dart';
import 'family_flow.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});
  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

/// 가족 한 명 + 로컬 별명(백엔드에 이름 필드가 없어 기기 로컬에서 붙인다).
class _MemberVM {
  final FamilyMember member;
  final String? nickname;
  const _MemberVM(this.member, this.nickname);

  /// 표시 이름: 별명이 있으면 별명, 없으면 전화번호.
  String get title => nickname ?? member.wardPhone ?? '가족';
}

class _FamilyScreenState extends State<FamilyScreen> {
  Future<List<_MemberVM>>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() => _future = _load());
  }

  Future<List<_MemberVM>> _load() async {
    final members = await FamilyApi.getMembers();
    // null은 조회 실패(네트워크 등) → 에러 상태로. 빈 목록은 정상(연결 없음).
    if (members == null) {
      throw Exception('가족 목록을 불러오지 못했어요');
    }
    final vms = <_MemberVM>[];
    for (final m in members) {
      vms.add(_MemberVM(m, await AppPrefs.familyName(m.linkId)));
    }
    return vms;
  }

  Future<void> _invite() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const InviteCodeScreen()));
    if (mounted) _reload();
  }

  Future<void> _rename(_MemberVM vm) async {
    final changed = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => ConnectNamingScreen(member: vm.member)));
    if (changed == true && mounted) _reload();
  }

  Future<void> _revoke(_MemberVM vm) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('연결을 해제할까요?'),
        content: Text('${vm.title} 님과의 가족 연결이 끊겨요. 위험 문자 알림도 더 이상 오지 않아요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('연결 해제', style: TextStyle(color: AppColors.high))),
        ],
      ),
    );
    if (ok != true) return;
    final success = await FamilyApi.revoke(vm.member.linkId);
    if (!mounted) return;
    if (success) {
      await AppPrefs.removeFamilyName(vm.member.linkId);
      if (!mounted) return;
      _reload();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('연결 해제에 실패했어요. 잠시 후 다시 시도해 주세요')));
    }
  }

  Widget _memberRow(_MemberVM vm) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SfCard(
          child: Row(
            children: [
              const IconDisc(Icons.person_outline),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vm.title,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(vm.nickname == null ? '보호 중' : (vm.member.wardPhone ?? '보호 중'),
                        style: AppText.caption),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.t3),
                onSelected: (v) {
                  if (v == 'rename') _rename(vm);
                  if (v == 'revoke') _revoke(vm);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('이름 설정')),
                  PopupMenuItem(value: 'revoke', child: Text('연결 해제')),
                ],
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
          const Text('아직 연결된 가족이 없어요', style: AppText.titleScreen),
          const SizedBox(height: 6),
          const Text('초대 코드를 만들어 가족의 폰에 입력하면\n위험 문자를 함께 지킬 수 있어요',
              textAlign: TextAlign.center, style: AppText.caption),
          const SizedBox(height: 18),
          SizedBox(
            width: 200,
            child: SfButton('초대 코드 만들기', icon: Icons.person_add_alt, onTap: _invite),
          ),
        ],
      );

  Widget _error() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, color: AppColors.t3, size: 48),
          const SizedBox(height: 12),
          const Text('가족 목록을 불러오지 못했어요', style: AppText.titleScreen),
          const SizedBox(height: 18),
          SizedBox(width: 160, child: SfButton('다시 시도', onTap: _reload)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
          child: Row(
            children: [
              const Text('가족 보호', style: AppText.titleScreen),
              const Spacer(),
              IconButton(
                  onPressed: _invite,
                  icon: const Icon(Icons.person_add_alt, color: AppColors.t1)),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<_MemberVM>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Padding(
                    padding: const EdgeInsets.all(18), child: _error());
              }
              final members = snapshot.data ?? const [];
              if (members.isEmpty) {
                return Padding(
                    padding: const EdgeInsets.all(18), child: _empty());
              }
              return RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 2, 18, 18),
                  children: [
                    const SectionLabel('보호 중인 가족'),
                    for (final vm in members) _memberRow(vm),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
