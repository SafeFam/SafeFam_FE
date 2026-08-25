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
///  문자 분석 /api/v1/analyses  (★2026-07-30 비동기 전환 — SafeFam_BE #68까지 머지)
///   - POST                요청 { clientMessageId?, sender?, content(필수,≤5000),
///                               receivedAt(OffsetDateTime), source: AUTO|MANUAL }
///                               → **202 Accepted**, data { analysisId, status }
///                               (완성 결과 아님! 접수만. 같은 clientMessageId면 기존 건을
///                                현재 status로 반환 — 멱등이라 항상 PENDING 가정 금지)
///                         ※ 유저 기준 10회/분 레이트리밋 → 초과 시 429
///                           (ERROR, message="분석 요청 한도를 초과했습니다…", Retry-After 없음)
///   - GET                 이력 목록. 쿼리 page,size,riskLevel,category,from,to
///                               → PageResponse<AnalysisListItem>
///                               (maskedSender·messagePreview는 서버가 이미 마스킹)
///   - GET    /{id}        상세(AnalysisResponse). ★접수 후 종료 상태까지 폴링 대상.
///   - DELETE /{id}        204
///   - POST   /{id}/feedback  { type: CORRECT|FALSE_POSITIVE|FALSE_NEGATIVE, comment?(≤500) }
///
///  AnalysisResponse: { analysisId, status: PENDING|PROCESSING|COMPLETED|PARTIAL_SUCCESS|FAILED,
///   riskScore(0~100), riskLevel: LOW|MEDIUM|HIGH, category, explanation, failureCode?,
///   failedTracks[]  ← 부분성공 시 못 돌린 트랙(SafeFam_BE #82, 2026-08-08 추가).
///                     값은 영어·내부 엔진명(`URL:VIRUSTOTAL`)이라 그대로 노출 금지.
///                     ※ BE 매퍼가 ANALYSIS_TRACK_FAILURE 지표 문자열을 파싱해 만드는
///                       구조라, 필드가 비면 지표에서 뽑는 폴백을 유지한다.
///   scoreBreakdown{ textScore, urlScore, rulesScore },  ← 셋 다 nullable
///                   ※ SafeFam_BE #101(2026-08-14)에서 이름·의미가 함께 바뀌었다.
///                     llmScore→textScore · patternScore→rulesScore,
///                     값은 가중 기여도(weightedContributions)→원점수(rawScores).
///   evidenceCards[{category,title,description}]  ← 같은 PR에서 추가(최대 5개). 아직 미사용.
///   indicators[{type,description}], urls[{originalUrl,resolvedUrl,suspicious}],
///   recommendedActions[{type,label,phoneNumber?,url?}], analyzedAt }
///   ※ 종료 전(PENDING/PROCESSING)·실패(FAILED)에는 riskScore·riskLevel·category·
///     analyzedAt·scoreBreakdown 값이 **null**. 완료(COMPLETED)/부분성공(PARTIAL_SUCCESS)
///     에서만 점수·등급을 신뢰. FAILED는 '안전'이 아니라 별도 실패 안내가 필요.
///   ※ scoreBreakdown은 3중 스코어 게이지(§4)와 대응. 각 계층 원점수 0~100.
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

  /// 모든 분석 API는 보호된 요청이라 [AuthApi.sendAuthorized]를 거친다.
  /// Bearer 토큰 부착은 물론, 401이면 재발급 후 1회 재시도까지 처리된다.

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

  /// 에러 응답에서 사용자에게 보여줄 message를 꺼낸다(없으면 null).
  static String? _errorMessage(http.Response res) {
    if (res.body.isEmpty) return null;
    try {
      final body = jsonDecode(res.body);
      if (body is Map<String, dynamic> && body['message'] is String) {
        final msg = (body['message'] as String).trim();
        return msg.isEmpty ? null : msg;
      }
    } catch (_) {}
    return null;
  }

  /// 문자 분석 **접수**. 서버가 비동기로 처리하므로 이 호출은 완성 결과가 아니라
  /// 접수 식별자(analysisId)와 현재 상태를 담은 [AnalysisRequestOutcome]로 돌려준다.
  /// 접수 뒤에는 [getAnalysis]를 종료 상태(COMPLETED/PARTIAL_SUCCESS/FAILED)까지
  /// 폴링해야 한다. [source]는 자동 탐지(AUTO)/수동 입력(MANUAL) 구분.
  ///
  /// 백엔드는 이 엔드포인트에 유저 기준 10회/분 레이트리밋을 걸어(초과 시 429,
  /// `ANALYSIS_RATE_LIMIT_EXCEEDED`) 일반 실패와 다른 안내가 필요하다.
  ///
  /// [timeout]은 문자 수신 브로드캐스트처럼 시스템이 주는 시간이 짧은 경로에서
  /// 기본값보다 줄여 쓴다.
  static Future<AnalysisRequestOutcome> analyze({
    required String content,
    required DateTime receivedAt,
    required AnalysisSource source,
    String? sender,
    String? clientMessageId,
    Duration? timeout,
  }) async {
    try {
      final res = await AuthApi.sendAuthorized((headers) => http
          .post(_uri('/api/v1/analyses'),
              headers: headers,
              body: jsonEncode({
                if (clientMessageId != null) 'clientMessageId': clientMessageId,
                if (sender != null) 'sender': sender,
                // 마스킹은 서버에서 처리하므로 content를 그대로 전송한다.
                // 발신번호는 화이트리스트 필터용으로만 사용된다.
                'content': content,
                // OffsetDateTime 계약 → UTC ISO8601('...Z')로 전송.
                'receivedAt': receivedAt.toUtc().toIso8601String(),
                'source': source.wire,
              }))
          .timeout(timeout ?? _timeout),
          // 401이 끼면 재발급 구간이 통째로 더 붙는다. 짧은 예산으로 부를 때는
          // 그 구간도 같이 줄여야 예산 안에서 끝난다.
          reissueTimeout: timeout);
      // 429: 분석 요청 한도 초과. 서버 안내 문구를 그대로 노출(단일 출처).
      if (res.statusCode == 429) {
        return AnalysisRequestOutcome.failure(
          _errorMessage(res) ?? '분석 요청이 잠시 제한됐어요. 잠시 후 다시 시도해 주세요.',
          rateLimited: true,
        );
      }
      // 정상 접수는 202지만, 성공 판정은 상태코드 대신 ApiResponse.status로 한다.
      final data = _data(res);
      final id = (data?['analysisId'] as num?)?.toInt();
      if (data == null || id == null) {
        return const AnalysisRequestOutcome.failure(
            '분석에 실패했어요. 잠시 후 다시 시도해 주세요.');
      }
      return AnalysisRequestOutcome.accepted(AnalysisAccepted(
        analysisId: id,
        status: AnalysisStatus.fromWire(data['status'] as String?),
      ));
    } catch (_) {
      return const AnalysisRequestOutcome.failure(
          '분석에 실패했어요. 잠시 후 다시 시도해 주세요.');
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
      final res = await AuthApi.sendAuthorized((headers) => http
          .get(
              _uri('/api/v1/analyses', {
                'page': page,
                'size': size,
                'riskLevel': riskLevel?.wire,
                'category': category?.wire,
                'from': from == null ? null : _isoDate(from),
                'to': to == null ? null : _isoDate(to),
              }),
              headers: headers)
          .timeout(_timeout));
      final data = _data(res);
      return data == null ? null : AnalysisPage.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// 탐지 이력 상세. 실패 시 null.
  static Future<AnalysisResult?> getAnalysis(int analysisId) async {
    try {
      final res = await AuthApi.sendAuthorized((headers) => http
          .get(_uri('/api/v1/analyses/$analysisId'), headers: headers)
          .timeout(_timeout));
      final data = _data(res);
      return data == null ? null : AnalysisResult.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// 탐지 이력 삭제. 성공(204) 여부.
  static Future<bool> deleteAnalysis(int analysisId) async {
    try {
      final res = await AuthApi.sendAuthorized((headers) => http
          .delete(_uri('/api/v1/analyses/$analysisId'), headers: headers)
          .timeout(_timeout));
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
      final res = await AuthApi.sendAuthorized((headers) => http
          .post(_uri('/api/v1/analyses/$analysisId/feedback'),
              headers: headers,
              body: jsonEncode({
                'type': type.wire,
                if (comment != null && comment.isNotEmpty) 'comment': comment,
              }))
          .timeout(_timeout));
      return _isSuccess(res);
    } catch (_) {
      return false;
    }
  }

  /// 탐지 이력 익명 신고. analysisId는 내 이력에 존재해야 한다(서버가 소유권 검증).
  /// 최초 신고는 201(submitted), 같은 분석 재신고는 200(alreadyReported·멱등).
  /// 원문·발신번호·userId는 담기지 않고 위험도·유형·비식별 스냅샷만 저장된다.
  static Future<ReportOutcome> report(
    int analysisId, {
    required ReportType type,
  }) async {
    try {
      final res = await AuthApi.sendAuthorized((headers) => http
          .post(_uri('/api/v1/analyses/$analysisId/report'),
              headers: headers, body: jsonEncode({'type': type.wire}))
          .timeout(_timeout));
      if (res.statusCode == 201) return ReportOutcome.submitted;
      if (_isSuccess(res)) return ReportOutcome.alreadyReported; // 200 멱등
      return ReportOutcome.failed;
    } catch (_) {
      return ReportOutcome.failed;
    }
  }

  /// 개인 탐지 통계. 실패 시 null.
  static Future<StatisticsOverview?> getStatistics({
    StatisticsPeriod period = StatisticsPeriod.last30Days,
  }) async {
    try {
      final res = await AuthApi.sendAuthorized((headers) => http
          .get(_uri('/api/v1/statistics/overview', {'period': period.wire}),
              headers: headers)
          .timeout(_timeout));
      final data = _data(res);
      return data == null ? null : StatisticsOverview.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// 월간 피싱 트렌드(전체 사용자 비식별 집계). [month]는 `YYYY-MM`(없으면 당월).
  /// 홈 트렌드 카드용. 실패 시 null.
  static Future<TrendOverview?> getTrends({String? month}) async {
    try {
      final res = await AuthApi.sendAuthorized((headers) => http
          .get(_uri('/api/v1/statistics/trends', {'month': month}),
              headers: headers)
          .timeout(_timeout));
      final data = _data(res);
      return data == null ? null : TrendOverview.fromJson(data);
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

/// 분석 **접수** 결과. 접수됐으면 [accepted](analysisId+status)가 채워지고,
/// 실패면 사용자에게 보여줄 [error] 문구가 담긴다. [rateLimited]는 429(요청 한도
/// 초과)를 일반 실패와 구분해, 화면이 필요하면 다르게 안내할 수 있게 한다.
class AnalysisRequestOutcome {
  final AnalysisAccepted? accepted;
  final String? error;
  final bool rateLimited;

  const AnalysisRequestOutcome.accepted(AnalysisAccepted this.accepted)
      : error = null,
        rateLimited = false;
  const AnalysisRequestOutcome.failure(this.error, {this.rateLimited = false})
      : accepted = null;

  /// 접수 성공 여부.
  bool get ok => accepted != null;
}

/// POST 접수 응답(AnalysisAcceptedResponse). 결과가 아니라 접수 식별자와 현재 상태.
class AnalysisAccepted {
  final int analysisId;
  final AnalysisStatus status;
  const AnalysisAccepted({required this.analysisId, required this.status});
}

// ─────────────────────────── enums (백엔드 계약 매핑) ───────────────────────────

/// 분석 처리 상태(백엔드 AnalysisStatus). 종료 상태는 completed·partialSuccess·failed.
enum AnalysisStatus {
  pending('PENDING'),
  processing('PROCESSING'),
  completed('COMPLETED'),
  partialSuccess('PARTIAL_SUCCESS'),
  failed('FAILED');

  final String wire;
  const AnalysisStatus(this.wire);

  /// 알 수 없는/누락 값은 아직 처리 전으로 보고 pending 취급(폴링 유도).
  static AnalysisStatus fromWire(String? v) {
    for (final s in values) {
      if (s.wire == v) return s;
    }
    return AnalysisStatus.pending;
  }

  /// 더 이상 상태가 바뀌지 않는 종료 상태(폴링 중단 기준).
  bool get isTerminal =>
      this == completed || this == partialSuccess || this == failed;

  /// 점수·등급 등 결과 필드를 신뢰할 수 있는 상태(완료/부분성공).
  bool get hasResult => this == completed || this == partialSuccess;

  /// 아직 처리 중(폴링 계속).
  bool get isPending => this == pending || this == processing;
}

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

/// 신고 유형(백엔드 ReportType). label은 UI 표기용.
enum ReportType {
  phishing('PHISHING', '피싱·사기'),
  spam('SPAM', '스팸·광고'),
  other('OTHER', '기타');

  final String wire;
  final String label;
  const ReportType(this.wire, this.label);
}

/// 신고 결과. 최초 신고(submitted)·이미 신고됨(alreadyReported·멱등)·실패(failed).
enum ReportOutcome { submitted, alreadyReported, failed }

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
  maliciousUrl('MALICIOUS_URL', '악성 URL'),
  aiEvidence('AI_EVIDENCE', 'AI 분석 근거'),
  // 위험 신호가 아니라 '일부 분석 미완료' 통지. 위험 근거 카드엔 노출하지 않고
  // 부분성공 배너로 어떤 레이어가 빠졌는지 안내하는 데 쓴다([failedTrackLayerLabel]).
  analysisTrackFailure('ANALYSIS_TRACK_FAILURE', '분석 일부 미완료');

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

/// 실패 트랙 토큰을 사용자에게 보여줄 **한국어 레이어명**으로 바꾼다.
///
/// 서버가 주는 토큰은 `TEXT`, `TEXT:GEMINI`, `URL`, `URL:VIRUSTOTAL`, `RULES`,
/// `PIPELINE` 형태로 **영어 + 내부 엔진명**이라 그대로 노출하지 않는다. 앞부분
/// (레이어군)만 취해 3중 스코어 레이어(문맥/링크/글자 패턴)로 환원하고, 모르는
/// 토큰이면 null을 돌려 배너에서 생략한다(내부 문구 유출 방지).
String? failedTrackLayerLabelOf(String track) {
  switch (track.split(':').first.trim().toUpperCase()) {
    case 'TEXT':
      return '문맥 분석';
    case 'URL':
      return '링크 보안 분석';
    case 'RULES':
      return '글자 패턴 분석';
    case 'PIPELINE':
      return '전체 분석';
    default:
      return null;
  }
}

/// ANALYSIS_TRACK_FAILURE 지표에서 한국어 레이어명을 뽑는다(구 경로).
///
/// 백엔드가 `AnalysisResponse.failedTracks`를 노출하기 전에는 실패 트랙이 이
/// 지표의 `"Analysis track unavailable: <TOKEN>"` 설명으로만 왔다. 지금은 전용
/// 필드를 우선 쓰고([AnalysisResult.failedLayerLabels]) 이 경로는 폴백으로 남긴다.
String? failedTrackLayerLabel(Indicator ind) {
  if (ind.type != IndicatorType.analysisTrackFailure) return null;
  const prefix = 'Analysis track unavailable:';
  var token = ind.description.trim();
  if (token.startsWith(prefix)) token = token.substring(prefix.length).trim();
  return failedTrackLayerLabelOf(token);
}

/// 백엔드 RiskLevel(HIGH/MEDIUM/LOW) → 프론트 [RiskLevel](high/med/low) 매핑.
/// 알 수 없는/손상된 값은 과소평가보다 과대평가가 안전하므로 high로 수렴시킨다
/// (fail-secure — 피싱 경고를 놓치지 않게). 값이 항상 존재하는 문맥(통계 버킷 등)용.
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

/// 비동기 결과용 nullable 매핑. 값이 **없으면**(아직 처리 전/실패) null을 준다 —
/// 이때 high로 강제하면 PENDING/FAILED가 '위험'으로 오표시되므로 null을 유지한다.
/// 단, 값이 있는데 알 수 없는 문자열이면 fail-secure로 high(손상 대비).
RiskLevel? riskLevelOrNull(String? v) {
  if (v == null) return null;
  return riskLevelFromWire(v);
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

/// 탐지 계층별 **원점수**(3중 스코어 게이지 breakdown용). 각 0~100.
///
/// 필드명·의미 모두 SafeFam_BE #101에서 바뀌었다.
/// `llmScore`→[textScore], `patternScore`→[rulesScore], 값은 가중 기여도→원점수.
/// (게이지는 원래부터 0~100 기준이라 표시 쪽은 손댈 게 없다.)
///
/// ★셋 다 **nullable**이다. 0은 '실제로 0점'(예: 링크가 없어 URL 점수 0)이고,
/// null은 '서버가 안 줬다'로 뜻이 다르다. 예전엔 없는 키를 `?? 0`으로 삼켜서,
/// 필드명이 바뀐 뒤에도 에러 없이 막대만 0으로 붙어 있었다.
class ScoreBreakdown {
  final int? textScore; // 문자 문맥 분석(LLM)
  final int? urlScore; // 링크 보안(VirusTotal)
  final int? rulesScore; // 금융 규칙(나이브베이즈·명칭 DB)
  const ScoreBreakdown({
    required this.textScore,
    required this.urlScore,
    required this.rulesScore,
  });

  factory ScoreBreakdown.fromJson(Map<String, dynamic> j) => ScoreBreakdown(
        textScore: (j['textScore'] as num?)?.toInt(),
        urlScore: (j['urlScore'] as num?)?.toInt(),
        rulesScore: (j['rulesScore'] as num?)?.toInt(),
      );
}

/// 사용자 언어로 정리한 위험 근거 카드(`evidenceCards`).
///
/// 서버가 `{category, title, description}`으로 내려준다. `title`·`description`은
/// **이미 한국어 완성 문장**이라 프론트에서 다시 문구를 만들지 않는다 —
/// 카테고리별 문구는 AI 쪽(`app/analysis/evidence.py`)이 정본이다.
///
/// 카테고리 5종: `INSTITUTION_IMPERSONATION`(기관 사칭)·`PERSONAL_INFO_REQUEST`
/// (개인정보 요구)·`DANGEROUS_URL`(위험 URL)·`URGENCY_PRESSURE`(행동 압박)·
/// `AI_JUDGMENT`(AI 판단).
class EvidenceCard {
  final String category;
  final String title;
  final String description;

  const EvidenceCard({
    required this.category,
    required this.title,
    required this.description,
  });

  factory EvidenceCard.fromJson(Map<String, dynamic> j) => EvidenceCard(
        category: ((j['category'] as String?) ?? '').trim(),
        title: ((j['title'] as String?) ?? '').trim(),
        description: ((j['description'] as String?) ?? '').trim(),
      );

  /// 사용자에게 내보내도 되는 카드인지.
  ///
  /// ★`AI_JUDGMENT` 카드의 설명은 AI 텍스트 분석의 `reason`을 **그대로** 옮긴
  /// 값이라, 분석기가 내부 상태를 적어 보낼 때가 있다 — "The confident stacking
  /// model decision was used." 같은 영어 문구가 실제로 온다(SafeFam_AI
  /// `hybrid_analyzer.py`, 미수정). 사용자 언어로 정리한 카드라는 계약을 못 지킨
  /// 값이므로 내보내지 않는다.
  ///
  /// 판별은 **한글이 한 글자라도 있는지**로 한다. 이 서비스의 카드 문구는 전부
  /// 한국어라, 영어 문구 목록을 쫓아다니는 것보다 이쪽이 덜 깨진다(AI가 새 내부
  /// 문구를 추가해도 자동으로 걸린다).
  bool get isPresentable =>
      title.isNotEmpty && description.isNotEmpty && _hasHangul(description);

  static final RegExp _hangul = RegExp(r'[가-힣]');
  static bool _hasHangul(String s) => _hangul.hasMatch(s);
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
///
/// 비동기라 상태에 따라 결과 필드가 비어 있을 수 있다. [status]가 완료/부분성공
/// ([AnalysisStatus.hasResult])일 때만 [riskScore]·[riskLevel]이 채워지고, 처리
/// 전(PENDING/PROCESSING)이나 실패(FAILED)에는 null이다. [failureCode]는 실패 원인.
class AnalysisResult {
  final int analysisId;
  final AnalysisStatus status;
  final int? riskScore; // 0~100 (완료/부분성공에서만)
  final RiskLevel? riskLevel; // 완료/부분성공에서만
  final PhishingCategory? category;
  final String explanation;
  final String? failureCode;

  /// 부분성공에서 수행하지 못한 분석 트랙(서버 원문 토큰, 예: `URL:VIRUSTOTAL`).
  /// 사용자에게 그대로 보여주지 않고 [failedLayerLabels]로 환원해 쓴다.
  final List<String> failedTracks;
  final ScoreBreakdown scoreBreakdown;

  /// 사용자 언어로 정리된 위험 근거(서버 `evidenceCards`, 최대 5개).
  ///
  /// [indicators]와는 **다른 엔티티**다. indicators는 내부 신호 타입이고,
  /// 이쪽은 그 신호를 사람이 읽을 문장으로 풀어 쓴 것이다.
  final List<EvidenceCard> evidenceCards;

  final List<Indicator> indicators;
  final List<UrlThreat> urls;
  final List<RecommendedAction> recommendedActions;
  final DateTime? analyzedAt;

  const AnalysisResult({
    required this.analysisId,
    required this.status,
    this.riskScore,
    this.riskLevel,
    this.category,
    required this.explanation,
    this.failureCode,
    this.failedTracks = const [],
    required this.scoreBreakdown,
    this.evidenceCards = const [],
    required this.indicators,
    required this.urls,
    required this.recommendedActions,
    this.analyzedAt,
  });

  /// 점수·등급을 신뢰할 수 있는 상태인지(완료/부분성공).
  bool get hasResult => status.hasResult;

  /// 부분성공 배너에 쓸 **한국어 레이어명** 목록(중복 제거).
  ///
  /// 전용 필드 [failedTracks]를 우선 쓰고, 비어 있으면 예전처럼
  /// ANALYSIS_TRACK_FAILURE 지표에서 뽑는다. 서버 배포 시차와, 접두사 문구가
  /// 바뀌어 파싱이 조용히 깨지는 경우를 둘 다 넘기기 위한 이중 경로다.
  List<String> get failedLayerLabels {
    final labels = <String>{
      for (final t in failedTracks)
        if (failedTrackLayerLabelOf(t) case final l?) l,
    };
    if (labels.isEmpty) {
      for (final i in indicators) {
        if (failedTrackLayerLabel(i) case final l?) labels.add(l);
      }
    }
    return labels.toList(growable: false);
  }

  factory AnalysisResult.fromJson(Map<String, dynamic> j) {
    final breakdown = j['scoreBreakdown'];
    final analyzed = j['analyzedAt'];
    return AnalysisResult(
      analysisId: (j['analysisId'] as num?)?.toInt() ?? 0,
      status: AnalysisStatus.fromWire(j['status'] as String?),
      riskScore: (j['riskScore'] as num?)?.toInt(),
      riskLevel: riskLevelOrNull(j['riskLevel'] as String?),
      category: PhishingCategory.fromWire(j['category'] as String?),
      explanation: (j['explanation'] as String?) ?? '',
      failureCode: j['failureCode'] as String?,
      failedTracks: switch (j['failedTracks']) {
        final List l => l.whereType<String>().toList(growable: false),
        _ => const <String>[],
      },
      scoreBreakdown: breakdown is Map<String, dynamic>
          ? ScoreBreakdown.fromJson(breakdown)
          // 분석이 끝나기 전엔 통째로 없다. 0점이 아니라 '아직 모른다'가 맞다.
          : const ScoreBreakdown(
              textScore: null, urlScore: null, rulesScore: null),
      evidenceCards: _parseList(j, 'evidenceCards', EvidenceCard.fromJson)
          .where((c) => c.isPresentable)
          .toList(growable: false),
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
    final b = StringBuffer('[SafeFam] 문자 분석 결과\n');
    final level = riskLevel;
    if (level != null) {
      final score = riskScore == null ? '' : ' ($riskScore점)';
      b.writeln('위험도: ${level.label}$score');
    }
    if (category != null) b.writeln('유형: ${category!.label}');
    final ex = _redactPii(explanation.trim());
    if (ex.isNotEmpty) b.writeln('\n$ex');
    b.write('\n\n※ SafeFam이 분석한 결과예요. 의심되면 링크·전화에 응하지 마세요.');
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
/// 비동기라 [status]가 완료/부분성공일 때만 [riskScore]·[riskLevel]이 채워진다.
class AnalysisListItem {
  final int analysisId;
  final AnalysisStatus status;
  final String maskedSender;
  final String messagePreview;
  final int? riskScore;
  final RiskLevel? riskLevel;
  final PhishingCategory? category;
  final DateTime? analyzedAt;

  const AnalysisListItem({
    required this.analysisId,
    required this.status,
    required this.maskedSender,
    required this.messagePreview,
    this.riskScore,
    this.riskLevel,
    this.category,
    this.analyzedAt,
  });

  factory AnalysisListItem.fromJson(Map<String, dynamic> j) {
    final analyzed = j['analyzedAt'];
    return AnalysisListItem(
      analysisId: (j['analysisId'] as num?)?.toInt() ?? 0,
      status: AnalysisStatus.fromWire(j['status'] as String?),
      maskedSender: (j['maskedSender'] as String?) ?? '',
      messagePreview: (j['messagePreview'] as String?) ?? '',
      riskScore: (j['riskScore'] as num?)?.toInt(),
      riskLevel: riskLevelOrNull(j['riskLevel'] as String?),
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

/// 피싱 유형별 월간 순위(트렌드).
class PhishingTypeTrend {
  final int rank;
  final PhishingCategory? category;
  final int count;
  const PhishingTypeTrend({
    required this.rank,
    this.category,
    required this.count,
  });

  factory PhishingTypeTrend.fromJson(Map<String, dynamic> j) =>
      PhishingTypeTrend(
        rank: (j['rank'] as num?)?.toInt() ?? 0,
        category: PhishingCategory.fromWire(j['category'] as String?),
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

/// 위험 키워드 월간 순위(비식별 표준 키워드).
class RiskKeywordTrend {
  final int rank;
  final String keyword;
  final int count;
  const RiskKeywordTrend({
    required this.rank,
    required this.keyword,
    required this.count,
  });

  factory RiskKeywordTrend.fromJson(Map<String, dynamic> j) => RiskKeywordTrend(
        rank: (j['rank'] as num?)?.toInt() ?? 0,
        keyword: (j['keyword'] as String?) ?? '',
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

/// 월간 피싱 트렌드 카드(TrendCardResponse). 전체 사용자 비식별 집계.
class TrendOverview {
  final String month; // YYYY-MM
  final int sampleSize;
  final List<PhishingTypeTrend> topPhishingTypes;
  final List<RiskKeywordTrend> topRiskKeywords;

  const TrendOverview({
    required this.month,
    required this.sampleSize,
    required this.topPhishingTypes,
    required this.topRiskKeywords,
  });

  factory TrendOverview.fromJson(Map<String, dynamic> j) => TrendOverview(
        month: (j['month'] as String?) ?? '',
        sampleSize: (j['sampleSize'] as num?)?.toInt() ?? 0,
        topPhishingTypes:
            _parseList(j, 'topPhishingTypes', PhishingTypeTrend.fromJson),
        topRiskKeywords:
            _parseList(j, 'topRiskKeywords', RiskKeywordTrend.fromJson),
      );
}
