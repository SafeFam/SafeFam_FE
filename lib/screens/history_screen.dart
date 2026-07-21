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
  AnalysisPage? _page;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    final page = await AnalysisApi.getHistory();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = page == null;
      _page = page;
    });
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
            onRefresh: _load,
            child: ListView(
              // 로딩·에러·빈 상태가 뷰포트보다 짧아도 당겨서 새로고침이 되도록.
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 18),
              children: [
                _monthlyChart(),
                const SizedBox(height: 12),
                const SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    SfChip('전체', selected: true),
                    SizedBox(width: 7),
                    SfChip('금융'),
                    SizedBox(width: 7),
                    SfChip('택배'),
                    SizedBox(width: 7),
                    SfChip('기타'),
                  ]),
                ),
                const SizedBox(height: 8),
                ..._listSection(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 목록 상태(로딩/에러/빈/데이터)에 따른 위젯들.
  List<Widget> _listSection() {
    if (_loading) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_error) {
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
                    icon: Icons.refresh, variant: SfBtn.ghost, onTap: _load),
              ),
            ],
          ),
        ),
      ];
    }
    final items = _page?.content ?? const [];
    if (items.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 48),
          child: Column(
            children: [
              Icon(Icons.inbox_outlined, color: AppColors.t3, size: 40),
              SizedBox(height: 10),
              Text('아직 탐지 이력이 없어요', style: AppText.body),
              SizedBox(height: 4),
              Text('검사 탭에서 의심 문자를 확인해 보세요.', style: AppText.caption),
            ],
          ),
        ),
      ];
    }
    return [for (final item in items) _historyTile(item)];
  }

  /// 항목 탭 → 상세로 이동. 상세에서 삭제하고 돌아오면 목록을 새로고침한다.
  Future<void> _openDetail(AnalysisListItem item) async {
    final deleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => AnalysisDetailScreen(analysisId: item.analysisId)),
    );
    if (deleted == true && mounted) _load();
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

  /// 월별 탐지 건수 그래프(추후 통계 API 연동 예정 — 현재는 정적 표시).
  Widget _monthlyChart() {
    const months = ['2월', '3월', '4월', '5월', '6월'];
    const heights = [0.30, 0.46, 0.38, 0.62, 0.88];
    return SfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('월별 탐지 건수'),
          SizedBox(
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < months.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: 78 * heights[i],
                            decoration: BoxDecoration(
                                color: i == months.length - 1
                                    ? AppColors.blue
                                    : AppColors.blueLight,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6))),
                          ),
                          const SizedBox(height: 5),
                          Text(months[i],
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.t3)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 분석 시각을 로컬 기준 'M월 D일'로 표시.
  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    return '${d.month}월 ${d.day}일';
  }
}
