import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../services/app_prefs.dart';
import '../services/family_api.dart';
import 'family_alerts_screen.dart';
import 'family_flow.dart';
import 'ward_logs_screen.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});
  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

/// 가족 한 명. 표시 이름은 서버가 보관하는 관계(relationship)를 쓴다.
class _MemberVM {
  final FamilyMember member;
  const _MemberVM(this.member);

  /// 관계 → 피보호자 닉네임 → 전화번호 순. 셋 다 없으면 '가족'.
  String get title => member.displayName ?? '가족';

  /// 이름을 아직 정하지 않은 상태(관계 미설정)인지.
  bool get unnamed => (member.relationship?.trim().isEmpty ?? true);
}

class _FamilyScreenState extends State<FamilyScreen> {
  Future<List<_MemberVM>>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    // 블록 본문으로 둔다: 화살표(`=> _future = _load()`)는 대입식의 값인
    // Future를 반환해 "setState callback returned a Future" 오류를 낸다.
    setState(() {
      _future = _load();
    });
  }

  Future<List<_MemberVM>> _load() async {
    var members = await FamilyApi.getMembers();
    // null은 조회 실패(네트워크 등) → 에러 상태로. 빈 목록은 정상(연결 없음).
    if (members == null) {
      throw Exception('가족 목록을 불러오지 못했어요');
    }
    if (await _migrateLocalNames(members)) {
      // 올린 관계가 반영된 목록으로 다시 읽는다. 재조회가 실패하면 방금 읽은
      // 목록을 그대로 쓴다(이름만 다음 새로고침까지 예전 상태로 보임).
      members = await FamilyApi.getMembers() ?? members;
    }
    return members.map(_MemberVM.new).toList();
  }

  /// 서버 저장 전(로컬 별명 시절)에 지어둔 이름을 한 번만 서버로 올린다.
  /// 서버에 관계가 이미 있으면 서버 값이 원본이므로 건드리지 않고 로컬만 지운다.
  /// 하나라도 올렸으면 true(목록 재조회 필요).
  Future<bool> _migrateLocalNames(List<FamilyMember> members) async {
    var uploaded = false;
    for (final m in members) {
      final local = await AppPrefs.familyName(m.linkId);
      if (local == null || local.trim().isEmpty) continue;
      final hasServerName = (m.relationship?.trim().isNotEmpty ?? false);
      if (!hasServerName) {
        // 실패하면 로컬 값을 남겨 다음 새로고침에서 다시 시도한다.
        if (!await FamilyApi.updateRelationship(m.linkId, local)) continue;
        uploaded = true;
      }
      await AppPrefs.removeFamilyName(m.linkId);
    }
    return uploaded;
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

  /// 피보호자 탐지 이력(원격 모니터링) 화면으로. wardId가 없으면(방어) 무시.
  void _openLogs(_MemberVM vm) {
    final wardId = vm.member.wardId;
    if (wardId == null) return;
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => WardLogsScreen(wardId: wardId, title: vm.title)));
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

  Widget _memberRow(_MemberVM vm) {
    final canViewLogs = vm.member.wardId != null;
    // 이름을 정했으면 보조줄에 번호를, 아직이면 설정을 유도하는 문구를 쓴다.
    final sub = vm.unnamed ? '이름 설정 안 함' : (vm.member.wardPhone ?? '보호 중');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SfCard(
        child: Row(
          children: [
            const IconDisc(Icons.person_outline),
            const SizedBox(width: 12),
            Expanded(
              // 이름/번호 영역을 누르면 피보호자 탐지 이력으로 이동(원격 모니터링).
              child: InkWell(
                onTap: canViewLogs ? () => _openLogs(vm) : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vm.title,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                        canViewLogs ? '$sub · 탐지 이력 보기' : sub,
                        style: AppText.caption),
                  ],
                ),
              ),
            ),
            if (canViewLogs)
              const Icon(Icons.chevron_right, color: AppColors.t3, size: 22),
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
  }

  Widget _empty() => Column(
        mainAxisSize: MainAxisSize.min,
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
                  tooltip: '가족 안전 알림',
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const FamilyAlertsScreen())),
                  icon: const Icon(Icons.notifications_none, color: AppColors.t1)),
              IconButton(
                  tooltip: '초대 코드 만들기',
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
                // 남은 공간 정중앙이 아니라 상단 쪽(세로 -0.35)에 둔다.
                // 정중앙이면 본문 제목과 콘텐츠 사이가 크게 벌어져 떠 보인다.
                return Padding(
                  padding: const EdgeInsets.all(18),
                  child: Align(
                    alignment: const Alignment(0, -0.35),
                    child: _empty(),
                  ),
                );
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
