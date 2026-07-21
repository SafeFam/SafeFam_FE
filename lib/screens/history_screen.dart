import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../models.dart';
import '../services/analysis_api.dart';
import 'results.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // 통계(상단)
  StatisticsPeriod _period = StatisticsPeriod.last30Days;
  StatisticsOverview? _stats;
  bool _statsLoading = true;

  // 이력 목록
  PhishingCategory? _filter; // null = 전체
  AnalysisPage? _page;
  bool _historyLoading = true;
  bool _historyError = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadHistory();
  }

  Future<void> _loadStats() async {
    setState(() => _statsLoading = true);
    final s = await AnalysisApi.getStatistics(period: _period);
    if (!mounted) return;
    setState(() {
      _stats = s;
      _statsLoading = false;
    });
  }

  Future<void> _loadHistory() async {
    setState(() {
      _historyLoading = true;
      _historyError = false;
    });
    final page = await AnalysisApi.getHistory(category: _filter);
    if (!mounted) return;
    setState(() {
      _page = page;
      _historyError = page == null;
      _historyLoading = false;
    });
  }

  Future<void> _refresh() => Future.wait([_loadStats(), _loadHistory()]);

  void _selectPeriod(StatisticsPeriod p) {
    if (p == _period) return;
    setState(() => _period = p);
    _loadStats();
  }

  void _selectFilter(PhishingCategory? cat) {
    if (cat == _filter) return;
    setState(() => _filter = cat);
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 16, 18, 8),
          child: Text('탐지 이력', style: AppText.titleScreen),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              // 로딩·에러·빈 상태가 뷰포트보다 짧아도 당겨서 새로고침이 되도록.
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 18),
              children: [
                _statsCard(),
                const SizedBox(height: 12),
                _filterChips(),
                const SizedBox(height: 8),
                ..._listSection(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────── 통계 ───────────────────────────

  Widget _statsCard() {
    return SfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('탐지 통계'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final p in StatisticsPeriod.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: _chip(_periodLabel(p), _period == p,
                        () => _selectPeriod(p)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_statsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_stats == null)
            _statsError()
          else
            _statsContent(_stats!),
        ],
      ),
    );
  }

  Widget _statsError() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Expanded(
                child: Text('통계를 불러오지 못했어요', style: AppText.caption)),
            TextButton(onPressed: _loadStats, child: const Text('다시 시도')),
          ],
        ),
      );

  Widget _statsContent(StatisticsOverview s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('${s.totalAnalysisCount}',
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.blue)),
            const SizedBox(width: 4),
            const Text('건 탐지', style: AppText.caption),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _riskStat('위험', AppColors.high, _riskCount(RiskLevel.high)),
            const SizedBox(width: 8),
            _riskStat('주의', AppColors.med, _riskCount(RiskLevel.med)),
            const SizedBox(width: 8),
            _riskStat('안전', AppColors.low, _riskCount(RiskLevel.low)),
          ],
        ),
        ..._categoryBars(s),
      ],
    );
  }

  Widget _riskStat(String label, Color color, int count) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              Text('$count',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700, color: color)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.t2)),
            ],
          ),
        ),
      );

  List<Widget> _categoryBars(StatisticsOverview s) {
    final cats = s.categoryDistribution
        .where((c) => c.category != null && c.count > 0)
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    if (cats.isEmpty) return const [];
    final top = cats.take(5).toList();
    final maxCount = top.first.count;
    return [
      const SizedBox(height: 16),
      const SectionLabel('유형별'),
      for (final c in top)
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Row(
            children: [
              SizedBox(
                width: 82,
                child: Text(c.category!.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.t1)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: maxCount == 0 ? 0 : c.count / maxCount,
                    minHeight: 10,
                    backgroundColor: AppColors.track,
                    valueColor: const AlwaysStoppedAnimation(AppColors.blue),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${c.count}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
    ];
  }

  int _riskCount(RiskLevel level) {
    for (final b in _stats?.riskDistribution ?? const <RiskBucket>[]) {
      if (b.riskLevel == level) return b.count;
    }
    return 0;
  }

  String _periodLabel(StatisticsPeriod p) => switch (p) {
        StatisticsPeriod.last7Days => '7일',
        StatisticsPeriod.last30Days => '30일',
        StatisticsPeriod.last90Days => '90일',
        StatisticsPeriod.all => '전체',
      };

  // ─────────────────────────── 필터 ───────────────────────────

  Widget _filterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 7),
            child: _chip('전체', _filter == null, () => _selectFilter(null)),
          ),
          for (final cat in PhishingCategory.values)
            Padding(
              padding: const EdgeInsets.only(right: 7),
              child: _chip(cat.label, _filter == cat, () => _selectFilter(cat)),
            ),
        ],
      ),
    );
  }

  /// 기간·필터 공통 선택 칩.
  Widget _chip(String label, bool selected, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.blue : AppColors.surface,
            border: Border.all(color: selected ? AppColors.blue : AppColors.line),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? Colors.white : AppColors.t2)),
        ),
      );

  // ─────────────────────────── 목록 ───────────────────────────

  /// 목록 상태(로딩/에러/빈/데이터)에 따른 위젯들.
  List<Widget> _listSection() {
    if (_historyLoading) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_historyError) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Column(
            children: [
              const Icon(Icons.cloud_off_outlined, color: AppColors.t3, size: 40),
              const SizedBox(height: 10),
              const Text('이력을 불러오지 못했어요', style: AppText.body),
              const SizedBox(height: 12),
              SizedBox(
                width: 160,
                child: SfButton('다시 시도',
                    icon: Icons.refresh,
                    variant: SfBtn.ghost,
                    onTap: _loadHistory),
              ),
            ],
          ),
        ),
      ];
    }
    final items = _page?.content ?? const [];
    if (items.isEmpty) {
      final msg = _filter == null
          ? '아직 탐지 이력이 없어요'
          : '${_filter!.label} 유형 이력이 없어요';
      return [
        Padding(
          padding: const EdgeInsets.only(top: 48),
          child: Column(
            children: [
              const Icon(Icons.inbox_outlined, color: AppColors.t3, size: 40),
              const SizedBox(height: 10),
              Text(msg, style: AppText.body),
              if (_filter == null) ...[
                const SizedBox(height: 4),
                const Text('검사 탭에서 의심 문자를 확인해 보세요.',
                    style: AppText.caption),
              ],
            ],
          ),
        ),
      ];
    }
    return [for (final item in items) _historyTile(item)];
  }

  /// 항목 탭 → 상세로 이동. 상세에서 삭제하고 돌아오면 목록·통계를 새로고침한다.
  Future<void> _openDetail(AnalysisListItem item) async {
    final deleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => AnalysisDetailScreen(analysisId: item.analysisId)),
    );
    if (deleted == true && mounted) {
      _loadHistory();
      _loadStats();
    }
  }

  Widget _historyTile(AnalysisListItem item) {
    final level = item.riskLevel;
    final title = item.category?.label ?? '문자 분석';
    final metaParts = [
      if (item.maskedSender.isNotEmpty) item.maskedSender,
      if (item.analyzedAt != null) _formatDate(item.analyzedAt!),
    ];
    return InkWell(
      onTap: () => _openDetail(item),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.line))),
        child: Row(
          children: [
            IconDisc(level.icon,
                color: level.color, bg: level.color.withOpacity(0.12)),
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
                      RiskBadge(level, large: false),
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
                        style:
                            const TextStyle(fontSize: 12, color: AppColors.t3)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: AppColors.t3, size: 22),
          ],
        ),
      ),
    );
  }

  /// 분석 시각을 로컬 기준 'M월 D일'로 표시.
  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    return '${d.month}월 ${d.day}일';
  }
}
