import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models.dart' show RiskLevel, RiskMeta;
import 'auth_api.dart' show AuthApi;

/// 문자 분석·탐지 이력·통계 서버 통신 담당.
///
/// 백엔드(SafeFam_BE) 확인된 계약 (develop 소스 대조, 2026-07-20 #30·#36·#37):
///  - 모두 보호된 API → 헤더 Authorization: Bearer <accessToken> (AuthApi.accessToken 재사용)
///  - 공통 응답 ApiResponse { status:"SUCCESS"|"ERROR", message, data }
///  - 목록은 PageResponse { content, page, size, totalElements, totalPages, last }
///
///  문자 분석 /api/v1/analyses
///   - POST                요청 { clientMessageId?, sender?, content(필수,≤5000),
///                               receivedAt(OffsetDateTime), source: AUTO|MANUAL } → AnalysisResponse
///   - GET                 이력 목록. 쿼리 page,size,riskLevel,category,from,to
///                               → PageResponse<AnalysisListItem>
///                               (maskedSender·messagePreview는 서버가 이미 마스킹)
///   - GET    /{id}        상세(AnalysisResponse)
///   - DELETE /{id}        204
///   - POST   /{id}/feedback  { type: CORRECT|FALSE_POSITIVE|FALSE_NEGATIVE, comment?(≤500) }
///
///  AnalysisResponse: { analysisId, riskScore(0~100), riskLevel: LOW|MEDIUM|HIGH,
///   category, explanation, scoreBreakdown{ llmScore, urlScore, patternScore },
///   indicators[{type,description}], urls[{originalUrl,resolvedUrl,suspicious}],
///   recommendedActions[{type,label,phoneNumber?,url?}], analyzedAt }
///   ※ scoreBreakdown은 3중 스코어 게이지(§4)와 대응. 현재 규칙 기반이라 llmScore=0.
///
///  통계 /api/v1/statistics/overview?period=LAST_7_DAYS|LAST_30_DAYS|LAST_90_DAYS|ALL
///   → { period, totalAnalysisCount, highRiskCount,
///        riskDistribution[{riskLevel,count}], categoryDistribution[{category,count}] }
///
/// 인증 관련(baseUrl·토큰·성공 판정)은 AuthApi와 동일 규약을 따른다.
class AnalysisApi {
  static const Duration _timeout = Duration(seconds: 10);

  static Uri _uri(String path, [Map<String, dynamic>? query]) {
    final qp = <String, String>{};
    query?.forEach((k, v) {
      if (v != null) qp[k] = '$v';
    });
    return Uri.parse('${AuthApi.baseUrl}$path')
        .replace(queryParameters: qp.isEmpty ? null : qp);
  }

  /// 모든 분석 API는 보호된 요청이라 항상 Bearer 토큰을 붙인다.
  static Map<String, String> _headers() {
    final h = {'Content-Type': 'application/json'};
    final token = AuthApi.accessToken;
    if (token != null) h['Authorization'] = 'Bearer $token';
    return h;
  }

  /// 2xx이면서 ApiResponse.status == "SUCCESS"일 때 성공(바디 없는 성공도 허용).
  static bool _isSuccess(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) return false;
    if (res.body.isEmpty) return true;
    try {
      final body = jsonDecode(res.body);
      return body is Map<String, dynamic> && body['status'] == 'SUCCESS';
    } catch (_) {
      return false;
    }
  }

  /// ApiResponse.data를 Map으로 꺼낸다. 실패 시 null.
  static Map<String, dynamic>? _data(http.Response res) {
    if (!_isSuccess(res) || res.body.isEmpty) return null;
    final data = jsonDecode(res.body)['data'];
    return data is Map<String, dynamic> ? data : null;
  }

  /// 문자 분석 요청. 성공 시 결과, 실패 시 null.
  /// [source]는 자동 탐지(AUTO)/수동 입력(MANUAL) 구분.
  static Future<AnalysisResult?> analyze({
    required String content,
    required DateTime receivedAt,
    required AnalysisSource source,
    String? sender,
    String? clientMessageId,
  }) async {
    try {
      final res = await http
          .post(_uri('/api/v1/analyses'),
              headers: _headers(),
              body: jsonEncode({
                if (clientMessageId != null) 'clientMessageId': clientMessageId,
                if (sender != null) 'sender': sender,
                'content': content,
                // OffsetDateTime 계약 → UTC ISO8601('...Z')로 전송.
                'receivedAt': receivedAt.toUtc().toIso8601String(),
                'source': source.wire,
              }))
          .timeout(_timeout);
      final data = _data(res);
      return data == null ? null : AnalysisResult.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// 탐지 이력 목록(최신순, 페이지). 필터는 모두 선택. 실패 시 null.
  static Future<AnalysisPage?> getHistory({
    int page = 0,
    int size = 20,
    RiskLevel? riskLevel,
    PhishingCategory? category,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final res = await http
          .get(
              _uri('/api/v1/analyses', {
                'page': page,
                'size': size,
                'riskLevel': riskLevel?.wire,
                'category': category?.wire,
                'from': from == null ? null : _isoDate(from),
                'to': to == null ? null : _isoDate(to),
              }),
              headers: _headers())
          .timeout(_timeout);
      final data = _data(res);
      return data == null ? null : AnalysisPage.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// 탐지 이력 상세. 실패 시 null.
  static Future<AnalysisResult?> getAnalysis(int analysisId) async {
    try {
      final res = await http
          .get(_uri('/api/v1/analyses/$analysisId'), headers: _headers())
          .timeout(_timeout);
      final data = _data(res);
      return data == null ? null : AnalysisResult.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// 탐지 이력 삭제. 성공(204) 여부.
  static Future<bool> deleteAnalysis(int analysisId) async {
    try {
      final res = await http
          .delete(_uri('/api/v1/analyses/$analysisId'), headers: _headers())
          .timeout(_timeout);
      return res.statusCode == 204 || _isSuccess(res);
    } catch (_) {
      return false;
    }
  }

  /// 분석 결과 피드백(정탐/오탐/미탐). 성공 여부.
  static Future<bool> submitFeedback(
    int analysisId, {
    required FeedbackType type,
    String? comment,
  }) async {
    try {
      final res = await http
          .post(_uri('/api/v1/analyses/$analysisId/feedback'),
              headers: _headers(),
              body: jsonEncode({
                'type': type.wire,
                if (comment != null && comment.isNotEmpty) 'comment': comment,
              }))
          .timeout(_timeout);
      return _isSuccess(res);
    } catch (_) {
      return false;
    }
  }

  /// 개인 탐지 통계. 실패 시 null.
  static Future<StatisticsOverview?> getStatistics({
    StatisticsPeriod period = StatisticsPeriod.last30Days,
  }) async {
    try {
      final res = await http
          .get(_uri('/api/v1/statistics/overview', {'period': period.wire}),
              headers: _headers())
          .timeout(_timeout);
      final data = _data(res);
      return data == null ? null : StatisticsOverview.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// LocalDate 쿼리(from/to)는 날짜만(YYYY-MM-DD) 보낸다.
  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

// ─────────────────────────── enums (백엔드 계약 매핑) ───────────────────────────

/// 분석 출처. AUTO=자동 탐지, MANUAL=수동 입력.
enum AnalysisSource {
  auto('AUTO'),
  manual('MANUAL');

  final String wire;
  const AnalysisSource(this.wire);
}

/// 분석 결과 피드백 유형.
enum FeedbackType {
  correct('CORRECT'),
  falsePositive('FALSE_POSITIVE'),
  falseNegative('FALSE_NEGATIVE');

  final String wire;
  const FeedbackType(this.wire);
}

/// 통계 조회 기간.
enum StatisticsPeriod {
  last7Days('LAST_7_DAYS'),
  last30Days('LAST_30_DAYS'),
  last90Days('LAST_90_DAYS'),
  all('ALL');

  final String wire;
  const StatisticsPeriod(this.wire);
}

/// 피싱 유형(백엔드 PhishingCategory). label은 UI 표기용.
enum PhishingCategory {
  financialInstitution('FINANCIAL_INSTITUTION', '금융기관 사칭'),
  governmentAgency('GOVERNMENT_AGENCY', '기관 사칭'),
  loan('LOAN', '대출 사기'),
  job('JOB', '일자리 사기'),
  delivery('DELIVERY', '택배 사칭'),
  messenger('MESSENGER', '메신저 사칭'),
  other('OTHER', '기타');

  final String wire;
  final String label;
  const PhishingCategory(this.wire, this.label);

  static PhishingCategory? fromWire(String? v) {
    if (v == null) return null;
    for (final c in values) {
      if (c.wire == v) return c;
    }
    return null;
  }
}

/// 위험 근거 유형(백엔드 IndicatorType). label은 UI 표기용.
enum IndicatorType {
  impersonation('IMPERSONATION', '기관 사칭'),
  financialAction('FINANCIAL_ACTION', '금전 요구'),
  sensitiveInformation('SENSITIVE_INFORMATION', '개인정보 요구'),
  urgency('URGENCY', '긴급성 압박'),
  shortenedUrl('SHORTENED_URL', '단축 URL'),
  maliciousUrl('MALICIOUS_URL', '악성 URL');

  final String wire;
  final String label;
  const IndicatorType(this.wire, this.label);

  static IndicatorType? fromWire(String? v) {
    if (v == null) return null;
    for (final t in values) {
      if (t.wire == v) return t;
    }
    return null;
  }
}

/// 백엔드 RiskLevel(HIGH/MEDIUM/LOW) → 프론트 [RiskLevel](high/med/low) 매핑.
/// 알 수 없는/손상된 값은 과소평가보다 과대평가가 안전하므로 high로 수렴시킨다
/// (fail-secure — 피싱 경고를 놓치지 않게).
RiskLevel riskLevelFromWire(String? v) {
  switch (v) {
    case 'HIGH':
      return RiskLevel.high;
    case 'MEDIUM':
      return RiskLevel.med;
    case 'LOW':
      return RiskLevel.low;
    default:
      return RiskLevel.high;
  }
}

/// 프론트 RiskLevel → 백엔드 쿼리 문자열.
extension RiskLevelWire on RiskLevel {
  String get wire => switch (this) {
        RiskLevel.high => 'HIGH',
        RiskLevel.med => 'MEDIUM',
        RiskLevel.low => 'LOW',
      };
}

// ─────────────────────────── 응답 모델 ───────────────────────────

/// JSON의 [key] 배열을 방어적으로 파싱한다. 배열이 아니거나 없으면 빈 리스트,
/// Map이 아닌 원소는 걸러낸다. 여러 fromJson에서 공유.
List<T> _parseList<T>(
  Map<String, dynamic> j,
  String key,
  T Function(Map<String, dynamic>) f,
) {
  final raw = j[key];
  if (raw is! List) return const [];
  return raw.whereType<Map<String, dynamic>>().map(f).toList(growable: false);
}

/// 탐지 계층별 점수(3중 스코어 게이지 breakdown용). 규칙 기반 현재 llm=0.
class ScoreBreakdown {
  final int llmScore; // 문맥 분석(LLM) 50%
  final int urlScore; // 링크 보안(VirusTotal) 30%
  final int patternScore; // 글자 패턴(규칙) 20%
  const ScoreBreakdown({
    required this.llmScore,
    required this.urlScore,
    required this.patternScore,
  });

  factory ScoreBreakdown.fromJson(Map<String, dynamic> j) => ScoreBreakdown(
        llmScore: (j['llmScore'] as num?)?.toInt() ?? 0,
        urlScore: (j['urlScore'] as num?)?.toInt() ?? 0,
        patternScore: (j['patternScore'] as num?)?.toInt() ?? 0,
      );
}

/// 판단에 사용된 위험 근거.
class Indicator {
  final IndicatorType? type;
  final String description;
  const Indicator({this.type, required this.description});

  factory Indicator.fromJson(Map<String, dynamic> j) => Indicator(
        type: IndicatorType.fromWire(j['type'] as String?),
        description: (j['description'] as String?) ?? '',
      );
}

/// 문자에 포함된 URL 검사 결과.
class UrlThreat {
  final String originalUrl;
  final String? resolvedUrl;
  final bool suspicious;
  const UrlThreat({
    required this.originalUrl,
    this.resolvedUrl,
    required this.suspicious,
  });

  factory UrlThreat.fromJson(Map<String, dynamic> j) => UrlThreat(
        originalUrl: (j['originalUrl'] as String?) ?? '',
        resolvedUrl: j['resolvedUrl'] as String?,
        // 누락/손상 시 안전하게 '의심'으로 간주(fail-secure).
        suspicious: j['suspicious'] as bool? ?? true,
      );
}

/// 사용자가 즉시 수행할 수 있는 대응 방법.
class RecommendedAction {
  final String type;
  final String label;
  final String? phoneNumber;
  final String? url;
  const RecommendedAction({
    required this.type,
    required this.label,
    this.phoneNumber,
    this.url,
  });

  factory RecommendedAction.fromJson(Map<String, dynamic> j) =>
      RecommendedAction(
        type: (j['type'] as String?) ?? '',
        label: (j['label'] as String?) ?? '',
        phoneNumber: j['phoneNumber'] as String?,
        url: j['url'] as String?,
      );
}

/// 문자 분석 상세 결과(AnalysisResponse).
class AnalysisResult {
  final int analysisId;
  final int riskScore; // 0~100
  final RiskLevel riskLevel;
  final PhishingCategory? category;
  final String explanation;
  final ScoreBreakdown scoreBreakdown;
  final List<Indicator> indicators;
  final List<UrlThreat> urls;
  final List<RecommendedAction> recommendedActions;
  final DateTime? analyzedAt;

  const AnalysisResult({
    required this.analysisId,
    required this.riskScore,
    required this.riskLevel,
    this.category,
    required this.explanation,
    required this.scoreBreakdown,
    required this.indicators,
    required this.urls,
    required this.recommendedActions,
    this.analyzedAt,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> j) {
    final breakdown = j['scoreBreakdown'];
    final analyzed = j['analyzedAt'];
    return AnalysisResult(
      analysisId: (j['analysisId'] as num?)?.toInt() ?? 0,
      riskScore: (j['riskScore'] as num?)?.toInt() ?? 0,
      riskLevel: riskLevelFromWire(j['riskLevel'] as String?),
      category: PhishingCategory.fromWire(j['category'] as String?),
      explanation: (j['explanation'] as String?) ?? '',
      scoreBreakdown: breakdown is Map<String, dynamic>
          ? ScoreBreakdown.fromJson(breakdown)
          : const ScoreBreakdown(llmScore: 0, urlScore: 0, patternScore: 0),
      indicators: _parseList(j, 'indicators', Indicator.fromJson),
      urls: _parseList(j, 'urls', UrlThreat.fromJson),
      recommendedActions:
          _parseList(j, 'recommendedActions', RecommendedAction.fromJson),
      analyzedAt: analyzed is String ? DateTime.tryParse(analyzed) : null,
    );
  }

  /// 가족·지인에게 공유할 요약 텍스트.
  /// ★원문(문자 내용)은 담지 않는다 — 위험도·유형·설명만 넣어 개인정보 노출을 피함.
  /// explanation은 마스킹된 입력으로 생성되지만, 만약 번호·계좌·링크가 섞여 있어도
  /// 외부(문자·시스템 공유)로 새지 않도록 공유 직전 한 번 더 마스킹한다(프론트 1차 마스킹 책임).
  String get shareSummary {
    final b = StringBuffer('[세이프팸] 문자 분석 결과\n');
    b.writeln('위험도: ${riskLevel.label} ($riskScore점)');
    if (category != null) b.writeln('유형: ${category!.label}');
    final ex = _redactPii(explanation.trim());
    if (ex.isNotEmpty) b.writeln('\n$ex');
    b.write('\n\n※ 세이프팸이 분석한 결과예요. 의심되면 링크·전화에 응하지 마세요.');
    return b.toString();
  }
}

/// 공유 텍스트 방어용 PII 마스킹. 이미 마스킹된 입력을 가정하되, 혹시 남아 있을
/// URL·전화번호·계좌/카드 같은 숫자열을 라벨로 치환해 외부 유출을 막는다(defense-in-depth).
String _redactPii(String s) {
  return s
      // URL: http(s):// 또는 www. 로 시작하는 토큰
      .replaceAll(RegExp(r'https?://\S+', caseSensitive: false), '[링크]')
      .replaceAll(RegExp(r'\bwww\.\S+', caseSensitive: false), '[링크]')
      // 전화번호: 02/010 등 하이픈·점·공백 구분 (예 010-1234-5678, 02.123.4567)
      .replaceAll(RegExp(r'\b\d{2,4}[-.\s]\d{3,4}[-.\s]\d{4}\b'), '[번호]')
      // 대표번호류 (예 1588-1234, 15881234)
      .replaceAll(RegExp(r'\b1\d{3}[-.\s]?\d{4}\b'), '[번호]')
      // 계좌·카드 등 긴 숫자열(하이픈 포함 9자리 이상 / 순수 숫자 10자리 이상)
      .replaceAll(RegExp(r'\b\d[\d-]{7,}\d\b'), '[번호]')
      .replaceAll(RegExp(r'\b\d{10,}\b'), '[번호]');
}

/// 탐지 이력 목록 항목(AnalysisListItem). sender/preview는 서버가 마스킹해 내려줌.
class AnalysisListItem {
  final int analysisId;
  final String maskedSender;
  final String messagePreview;
  final int riskScore;
  final RiskLevel riskLevel;
  final PhishingCategory? category;
  final DateTime? analyzedAt;

  const AnalysisListItem({
    required this.analysisId,
    required this.maskedSender,
    required this.messagePreview,
    required this.riskScore,
    required this.riskLevel,
    this.category,
    this.analyzedAt,
  });

  factory AnalysisListItem.fromJson(Map<String, dynamic> j) {
    final analyzed = j['analyzedAt'];
    return AnalysisListItem(
      analysisId: (j['analysisId'] as num?)?.toInt() ?? 0,
      maskedSender: (j['maskedSender'] as String?) ?? '',
      messagePreview: (j['messagePreview'] as String?) ?? '',
      riskScore: (j['riskScore'] as num?)?.toInt() ?? 0,
      riskLevel: riskLevelFromWire(j['riskLevel'] as String?),
      category: PhishingCategory.fromWire(j['category'] as String?),
      analyzedAt: analyzed is String ? DateTime.tryParse(analyzed) : null,
    );
  }
}

/// 탐지 이력 페이지(PageResponse<AnalysisListItem>).
class AnalysisPage {
  final List<AnalysisListItem> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool last;

  const AnalysisPage({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.last,
  });

  factory AnalysisPage.fromJson(Map<String, dynamic> j) {
    final items = _parseList(j, 'content', AnalysisListItem.fromJson);
    return AnalysisPage(
      content: items,
      page: (j['page'] as num?)?.toInt() ?? 0,
      size: (j['size'] as num?)?.toInt() ?? items.length,
      totalElements: (j['totalElements'] as num?)?.toInt() ?? items.length,
      totalPages: (j['totalPages'] as num?)?.toInt() ?? 1,
      last: j['last'] as bool? ?? true,
    );
  }
}

/// 위험 등급별 탐지 건수.
class RiskBucket {
  final RiskLevel riskLevel;
  final int count;
  const RiskBucket({required this.riskLevel, required this.count});

  factory RiskBucket.fromJson(Map<String, dynamic> j) => RiskBucket(
        riskLevel: riskLevelFromWire(j['riskLevel'] as String?),
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

/// 피싱 유형별 탐지 건수.
class CategoryBucket {
  final PhishingCategory? category;
  final int count;
  const CategoryBucket({this.category, required this.count});

  factory CategoryBucket.fromJson(Map<String, dynamic> j) => CategoryBucket(
        category: PhishingCategory.fromWire(j['category'] as String?),
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

/// 개인 탐지 통계(StatisticsOverviewResponse).
class StatisticsOverview {
  final int totalAnalysisCount;
  final int highRiskCount;
  final List<RiskBucket> riskDistribution;
  final List<CategoryBucket> categoryDistribution;

  const StatisticsOverview({
    required this.totalAnalysisCount,
    required this.highRiskCount,
    required this.riskDistribution,
    required this.categoryDistribution,
  });

  factory StatisticsOverview.fromJson(Map<String, dynamic> j) {
    return StatisticsOverview(
      totalAnalysisCount: (j['totalAnalysisCount'] as num?)?.toInt() ?? 0,
      highRiskCount: (j['highRiskCount'] as num?)?.toInt() ?? 0,
      riskDistribution: _parseList(j, 'riskDistribution', RiskBucket.fromJson),
      categoryDistribution:
          _parseList(j, 'categoryDistribution', CategoryBucket.fromJson),
    );
  }
}
