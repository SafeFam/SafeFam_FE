import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../services/family_safety_api.dart';
import '../util/launchers.dart';

/// 보호자용 가족 안전 대응 목록. 피보호자 HIGH 위험 건을 확인하고
/// 상세로 들어가 [전화]·[안전 확인 완료]·[이미 송금함]을 처리한다.
/// (FCM 푸시 진입은 타 멤버 담당(#33) — 여기선 조회·처리 UI만.)
class FamilyAlertsScreen extends StatefulWidget {
  const FamilyAlertsScreen({super.key});
  @override
  State<FamilyAlertsScreen> createState() => _FamilyAlertsScreenState();
}

class _FamilyAlertsScreenState extends State<FamilyAlertsScreen> {
  Future<List<FamilySafetyCase>>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<List<FamilySafetyCase>> _load() async {
    final cases = await FamilySafetyApi.getCases();
    if (cases == null) throw Exception('안전 알림을 불러오지 못했어요');
    return cases;
  }

  Future<void> _openDetail(FamilySafetyCase c) async {
    final changed = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => FamilyAlertDetailScreen(caseId: c.caseId)));
    if (changed == true && mounted) _reload();
  }

  Widget _statusChip(FamilySafetyStatus s) {
    final (label, color) = switch (s) {
      FamilySafetyStatus.pending => ('확인 필요', AppColors.high),
      FamilySafetyStatus.contacting => ('통화 중', AppColors.med),
      FamilySafetyStatus.safeConfirmed => ('안전 확인됨', AppColors.low),
      FamilySafetyStatus.transferred => ('송금 확인됨', AppColors.high),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(11)),
      child: Text(label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _caseRow(FamilySafetyCase c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SfCard(
        kind: c.status.isResolved ? CardKind.normal : CardKind.danger,
        child: InkWell(
          onTap: () => _openDetail(c),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('${c.wardName ?? '가족'} · 위험 ${c.riskScore}점',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600)),
                  ),
                  _statusChip(c.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                  c.riskSummary ??
                      c.suspectedInstitution ??
                      c.maskedMessagePreview ??
                      '위험 문자가 탐지됐어요',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty() => const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CharacterDisc(84),
          SizedBox(height: 14),
          Text('안전 알림이 없어요', style: AppText.titleScreen),
          SizedBox(height: 6),
          Text('가족에게 위험 문자가 오면\n여기서 함께 확인하고 대응할 수 있어요',
              textAlign: TextAlign.center, style: AppText.caption),
        ],
      );

  Widget _error() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, color: AppColors.t3, size: 48),
          const SizedBox(height: 12),
          const Text('안전 알림을 불러오지 못했어요', style: AppText.titleScreen),
          const SizedBox(height: 18),
          SizedBox(width: 160, child: SfButton('다시 시도', onTap: _reload)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('가족 안전 알림')),
      body: FutureBuilder<List<FamilySafetyCase>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Padding(padding: const EdgeInsets.all(18), child: _error());
          }
          final cases = snapshot.data ?? const [];
          if (cases.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(18),
              child: Align(alignment: const Alignment(0, -0.35), child: _empty()),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              children: [for (final c in cases) _caseRow(c)],
            ),
          );
        },
      ),
    );
  }
}

/// 가족 안전 대응 상세 + 액션. pop 시 true를 돌려주면 목록이 새로고침된다.
class FamilyAlertDetailScreen extends StatefulWidget {
  final int caseId;
  const FamilyAlertDetailScreen({super.key, required this.caseId});
  @override
  State<FamilyAlertDetailScreen> createState() =>
      _FamilyAlertDetailScreenState();
}

class _FamilyAlertDetailScreenState extends State<FamilyAlertDetailScreen> {
  FamilySafetyCase? _case;
  bool _loading = true;
  bool _busy = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await FamilySafetyApi.getCase(widget.caseId);
    if (!mounted) return;
    setState(() {
      _case = c;
      _loading = false;
    });
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _call() async {
    if (_busy) return;
    setState(() => _busy = true);
    final phone = await FamilySafetyApi.startCall(widget.caseId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (phone == null) {
      _toast('통화를 시작하지 못했어요. 잠시 후 다시 시도해 주세요');
      return;
    }
    _changed = true;
    final ok = await callNumber(phone);
    if (!ok) _toast('전화 앱을 열 수 없어요');
    if (mounted) _load();
  }

  Future<void> _resolve(FamilySafetyStatus status) async {
    if (_busy) return;
    setState(() => _busy = true);
    final updated = await FamilySafetyApi.resolve(widget.caseId, status);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (updated != null) _case = updated;
    });
    if (updated == null) {
      _toast('처리에 실패했어요. 잠시 후 다시 시도해 주세요');
      return;
    }
    _changed = true;
    if (status == FamilySafetyStatus.transferred) {
      _showTransferGuide();
    } else {
      _toast('안전 확인으로 처리했어요');
    }
  }

  /// '이미 송금함' 처리 후 지급정지 안내(금감원 1332).
  void _showTransferGuide() {
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('바로 지급정지를 신청하세요'),
        content: const Text(
            '송금했다면 즉시 은행 고객센터나 금융감독원 1332로 전화해 계좌 지급정지를 요청하세요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('닫기')),
          TextButton(
              onPressed: () {
                Navigator.pop(c);
                callNumber('1332');
              },
              child: const Text('1332 전화')),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 92, child: Text(label, style: AppText.caption)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _case;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(title: const Text('안전 대응')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : c == null
                ? Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off,
                            color: AppColors.t3, size: 48),
                        const SizedBox(height: 12),
                        const Text('내용을 불러오지 못했어요',
                            style: AppText.titleScreen),
                        const SizedBox(height: 18),
                        SizedBox(
                            width: 160,
                            child: SfButton('다시 시도', onTap: () {
                              setState(() => _loading = true);
                              _load();
                            })),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                    children: [
                      SfCard(
                        kind: CardKind.danger,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${c.wardName ?? '가족'} 님에게 위험 문자',
                                style: const TextStyle(
                                    fontSize: 19, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text('위험도 ${c.riskScore}점',
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.high)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _infoRow('의심 기관', c.suspectedInstitution),
                      _infoRow('위험 행동', c.riskyAction),
                      _infoRow('문자 요약', c.riskSummary),
                      _infoRow('탐지 문자', c.maskedMessagePreview),
                      if (c.calledByName != null)
                        _infoRow('통화 시도', '${c.calledByName} 님'),
                      if (c.status.isResolved && c.handledByName != null)
                        _infoRow(
                            '처리',
                            '${c.handledByName} 님 · '
                                '${c.status == FamilySafetyStatus.safeConfirmed ? '안전 확인' : '송금 확인'}'),
                      const SizedBox(height: 8),
                      if (!c.status.isResolved) ...[
                        SfButton(
                          _busy ? '처리 중…' : '${c.wardName ?? '가족'}에게 전화',
                          icon: Icons.call,
                          onTap: _busy ? null : _call,
                        ),
                        const SizedBox(height: 10),
                        SfButton(
                          '안전 확인 완료',
                          variant: SfBtn.ghost,
                          onTap: _busy
                              ? null
                              : () => _resolve(FamilySafetyStatus.safeConfirmed),
                        ),
                        const SizedBox(height: 10),
                        SfButton(
                          '이미 송금함',
                          variant: SfBtn.danger,
                          onTap: _busy
                              ? null
                              : () => _resolve(FamilySafetyStatus.transferred),
                        ),
                      ] else
                        SfCard(
                          kind: CardKind.tint,
                          child: Text(
                              c.status == FamilySafetyStatus.safeConfirmed
                                  ? '안전 확인이 완료된 건이에요.'
                                  : '송금 확인으로 처리된 건이에요.',
                              style: AppText.caption),
                        ),
                    ],
                  ),
      ),
    );
  }
}
