import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../services/analysis_api.dart';
import 'family_alerts_screen.dart';
import 'more_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  TrendOverview? _trends;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadTrends();
  }

  Future<void> _loadTrends() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    final t = await AnalysisApi.getTrends();
    if (!mounted) return;
    setState(() {
      _trends = t;
      _error = t == null;
      _loading = false;
    });
  }

  /// 'YYYY-MM' → 'YYYY년 M월'. 형식이 안 맞으면 원문 그대로.
  String _monthLabel(String month) {
    final parts = month.split('-');
    if (parts.length != 2) return month;
    final y = parts[0];
    final m = int.tryParse(parts[1]);
    return m == null ? month : '$y년 $m월';
  }

  Widget _rankDisc(int rank) => Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.blue.withOpacity(0.12),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text('$rank',
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.blue)),
      );

  /// 트렌드 카드 본문 — 로딩/에러/빈/데이터 4상태.
  Widget _trendBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
            child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: AppColors.blue))),
      );
    }
    if (_error || _trends == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            const Expanded(
                child: Text('트렌드를 불러오지 못했어요', style: AppText.caption)),
            TextButton(onPressed: _loadTrends, child: const Text('다시 시도')),
          ],
        ),
      );
    }
    final t = _trends!;
    final types = t.topPhishingTypes;
    final keywords = t.topRiskKeywords;
    if (types.isEmpty && keywords.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('아직 집계된 트렌드가 없어요', style: AppText.caption),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final p in types)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                _rankDisc(p.rank),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(p.category?.label ?? '기타',
                        style: const TextStyle(fontSize: 16))),
                Text('${p.count}건',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.blue)),
              ],
            ),
          ),
        if (keywords.isNotEmpty) ...[
          const SizedBox(height: 10),
          const SectionLabel('이런 표현을 조심하세요'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final k in keywords) SfChip(k.keyword)],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final month = _trends?.month ?? '';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
          child: Row(
            children: [
              const Text('SafeFam',
                  style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppColors.blue)),
              const Spacer(),
              // 종은 '가족 안전 알림'으로 보낸다. 가족 탭 안쪽에만 있던 화면이라
              // 홈에서 바로 닿지 않았고, 종 자체는 아무 동작도 없었다(#119).
              IconButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const FamilyAlertsScreen())),
                  icon: const Icon(Icons.notifications_none,
                      color: AppColors.t1, size: 24)),
              IconButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const MoreScreen())),
                  icon: const Icon(Icons.settings_outlined,
                      color: AppColors.t1, size: 24)),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadTrends,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 18),
              children: [
                SfCard(
                  kind: CardKind.tint,
                  padding:
                      const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                  child: Column(children: const [
                    CharacterDisc(100),
                    SizedBox(height: 10),
                    Text('지금 안전해요', style: AppText.titleLarge),
                    SizedBox(height: 6),
                    Text('SafeFam이 자동으로 지키는 중', style: AppText.caption),
                  ]),
                ),
                const SizedBox(height: 16),
                SfCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SectionLabel('요즘 많은 사기 수법'),
                          if (month.isNotEmpty)
                            Text(_monthLabel(month),
                                style: AppText.caption),
                        ],
                      ),
                      _trendBody(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
