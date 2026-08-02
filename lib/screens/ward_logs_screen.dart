import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../models.dart';
import '../services/analysis_api.dart';
import '../services/family_api.dart';

/// 보호자가 피보호자(ward)의 탐지 이력을 원격으로 보는 화면(읽기 전용).
///
/// 목록은 문자 분석 이력과 같은 [AnalysisListItem]이다. 단 상세(`/analyses/{id}`)는
/// 피보호자 소유 스코프라 보호자가 열 수 없으므로 여기선 **목록만** 보여준다.
class WardLogsScreen extends StatefulWidget {
  final int wardId;

  /// 화면 제목에 쓸 표시 이름(별명 또는 번호).
  final String title;

  const WardLogsScreen({super.key, required this.wardId, required this.title});
  @override
  State<WardLogsScreen> createState() => _WardLogsScreenState();
}

class _WardLogsScreenState extends State<WardLogsScreen> {
  Future<AnalysisPage>? _future;

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

  Future<AnalysisPage> _load() async {
    final page = await FamilyApi.getWardLogs(widget.wardId);
    // null은 조회 실패(네트워크·권한 등) → 에러 상태. 빈 목록은 정상(이력 없음).
    if (page == null) throw Exception('이력을 불러오지 못했어요');
    return page;
  }

  // ── 결과 없는 항목(처리 중/실패)의 상태 표시 ──
  String _statusLabel(AnalysisStatus s) =>
      s == AnalysisStatus.failed ? '분석 실패' : '분석 중';
  Color _statusColor(AnalysisStatus s) =>
      s == AnalysisStatus.failed ? AppColors.t3 : AppColors.blue;
  IconData _statusIcon(AnalysisStatus s) =>
      s == AnalysisStatus.failed ? Icons.error_outline : Icons.hourglass_empty;

  Widget _statusChip(AnalysisStatus s) {
    final c = _statusColor(s);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(11)),
      child: Text(_statusLabel(s),
          style:
              TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c)),
    );
  }

  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    return '${d.month}월 ${d.day}일';
  }

  /// 읽기 전용 이력 항목(탭 없음 — 보호자는 상세 조회 권한이 없다).
  Widget _logTile(AnalysisListItem item) {
    final level = item.riskLevel;
    final title = item.category?.label ?? '문자 분석';
    final iconColor = level?.color ?? _statusColor(item.status);
    final iconData = level?.icon ?? _statusIcon(item.status);
    final metaParts = [
      if (item.maskedSender.isNotEmpty) item.maskedSender,
      if (item.analyzedAt != null) _formatDate(item.analyzedAt!),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line))),
      child: Row(
        children: [
          IconDisc(iconData,
              color: iconColor, bg: iconColor.withOpacity(0.12)),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    if (level != null)
                      RiskBadge(level, large: false)
                    else
                      _statusChip(item.status),
                  ],
                ),
                if (item.messagePreview.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(item.messagePreview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption),
                ],
                if (metaParts.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(metaParts.join(' · '),
                      style: const TextStyle(fontSize: 12, color: AppColors.t3)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CharacterDisc(84),
          const SizedBox(height: 14),
          const Text('아직 탐지 이력이 없어요', style: AppText.titleScreen),
          const SizedBox(height: 6),
          Text('${widget.title} 님에게 온 위험 문자가 없어요.',
              textAlign: TextAlign.center, style: AppText.caption),
        ],
      );

  Widget _error() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, color: AppColors.t3, size: 48),
          const SizedBox(height: 12),
          const Text('이력을 불러오지 못했어요', style: AppText.titleScreen),
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
        title: Text('${widget.title} 님 탐지 이력', style: AppText.titleScreen),
      ),
      body: FutureBuilder<AnalysisPage>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Padding(padding: const EdgeInsets.all(18), child: _error());
          }
          final items = snapshot.data?.content ?? const [];
          if (items.isEmpty) {
            return Padding(padding: const EdgeInsets.all(18), child: _empty());
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
              children: [
                const Text('가족의 위험 문자 탐지 내역이에요. 내용은 안전하게 가려져 있어요.',
                    style: AppText.caption),
                const SizedBox(height: 8),
                for (final item in items) _logTile(item),
              ],
            ),
          );
        },
      ),
    );
  }
}
