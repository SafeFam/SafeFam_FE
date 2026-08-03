import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_api.dart' show AuthApi;

/// 가족 안전 대응 API — HIGH 위험 탐지 이후 보호자 공동 대응.
///
/// 백엔드 계약(SafeFam_BE #71 · `/api/v1/family/alerts` · 보호된 API → Bearer):
///  - `GET  /`                 목록(status? · page · size) → PageResponse<Case>
///  - `GET  /{caseId}`         상세(마스킹된 위험 근거 + 현재 처리 상태)
///  - `POST /{caseId}/call`    통화 시도 기록 → `{ phoneNumber }` (tel 딥링크용)
///  - `PATCH /{caseId}/status` `{ status: SAFE_CONFIRMED | TRANSFERRED }`
///  - 공통 응답 ApiResponse `{ status, message, data }`.
///
/// 원문은 오지 않고 서버가 마스킹한 미리보기/요약만 온다(#80). FCM 푸시 진입은
/// 타 멤버 담당(#33)이라 여기선 조회·처리 흐름만 다룬다.
class FamilySafetyApi {
  static const Duration _timeout = Duration(seconds: 10);

  static Uri _uri(String path, [Map<String, dynamic>? query]) {
    final qp = <String, String>{};
    query?.forEach((k, v) {
      if (v != null) qp[k] = '$v';
    });
    return Uri.parse('${AuthApi.baseUrl}$path')
        .replace(queryParameters: qp.isEmpty ? null : qp);
  }

  static Map<String, dynamic>? _data(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300 || res.body.isEmpty) {
      return null;
    }
    try {
      final body = jsonDecode(res.body);
      if (body is Map<String, dynamic> && body['status'] == 'SUCCESS') {
        final data = body['data'];
        return data is Map<String, dynamic> ? data : null;
      }
    } catch (_) {}
    return null;
  }

  /// 보호자에게 연결된 가족의 공동 대응 건 목록(최신 페이지). 실패 시 null.
  static Future<List<FamilySafetyCase>?> getCases({
    FamilySafetyStatus? status,
    int page = 0,
    int size = 20,
  }) async {
    try {
      final res = await AuthApi.sendAuthorized((headers) => http
          .get(
              _uri('/api/v1/family/alerts',
                  {'status': status?.wire, 'page': page, 'size': size}),
              headers: headers)
          .timeout(_timeout));
      final data = _data(res);
      final content = data?['content'];
      if (content is! List) return null;
      return content
          .whereType<Map<String, dynamic>>()
          .map(FamilySafetyCase.fromJson)
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// 공동 대응 건 상세. 실패 시 null.
  static Future<FamilySafetyCase?> getCase(int caseId) async {
    try {
      final res = await AuthApi.sendAuthorized((headers) => http
          .get(_uri('/api/v1/family/alerts/$caseId'), headers: headers)
          .timeout(_timeout));
      final data = _data(res);
      return data == null ? null : FamilySafetyCase.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// 통화 시도를 기록(상태 CONTACTING)하고 가족 전화번호를 반환한다.
  /// 앱은 이 번호로 tel 딥링크를 실행한다. 실패 시 null.
  static Future<String?> startCall(int caseId) async {
    try {
      final res = await AuthApi.sendAuthorized((headers) => http
          .post(_uri('/api/v1/family/alerts/$caseId/call'), headers: headers)
          .timeout(_timeout));
      final phone = _data(res)?['phoneNumber'];
      return phone is String && phone.isNotEmpty ? phone : null;
    } catch (_) {
      return null;
    }
  }

  /// 최종 처리(안전 확인 완료 / 이미 송금함). 성공 시 갱신된 건, 실패 시 null.
  static Future<FamilySafetyCase?> resolve(
    int caseId,
    FamilySafetyStatus status,
  ) async {
    try {
      final res = await AuthApi.sendAuthorized((headers) => http
          .patch(_uri('/api/v1/family/alerts/$caseId/status'),
              headers: headers, body: jsonEncode({'status': status.wire}))
          .timeout(_timeout));
      final data = _data(res);
      return data == null ? null : FamilySafetyCase.fromJson(data);
    } catch (_) {
      return null;
    }
  }
}

/// 공동 대응 진행 상태. PENDING·CONTACTING은 재알림 대상, 뒤 둘은 종료 상태.
enum FamilySafetyStatus {
  pending('PENDING'),
  contacting('CONTACTING'),
  safeConfirmed('SAFE_CONFIRMED'),
  transferred('TRANSFERRED');

  final String wire;
  const FamilySafetyStatus(this.wire);

  static FamilySafetyStatus fromWire(String? w) =>
      values.firstWhere((e) => e.wire == w, orElse: () => pending);

  bool get isResolved =>
      this == safeConfirmed || this == transferred;
}

/// 보호자 화면에 표시할 가족 공동 대응 건. 원문 대신 마스킹된 미리보기·요약만 온다.
class FamilySafetyCase {
  final int caseId;
  final int analysisId;
  final int wardId;
  final String? wardName;
  final FamilySafetyStatus status;
  final int riskScore;
  final String? suspectedInstitution;
  final String? riskyAction;
  final String? maskedMessagePreview;
  final String? riskSummary;
  final DateTime? detectedAt;
  final int reminderCount;
  final String? calledByName;
  final DateTime? calledAt;
  final String? handledByName;
  final DateTime? resolvedAt;

  const FamilySafetyCase({
    required this.caseId,
    required this.analysisId,
    required this.wardId,
    required this.status,
    required this.riskScore,
    this.wardName,
    this.suspectedInstitution,
    this.riskyAction,
    this.maskedMessagePreview,
    this.riskSummary,
    this.detectedAt,
    this.reminderCount = 0,
    this.calledByName,
    this.calledAt,
    this.handledByName,
    this.resolvedAt,
  });

  factory FamilySafetyCase.fromJson(Map<String, dynamic> json) {
    DateTime? at(String k) {
      final v = json[k];
      return v is String ? DateTime.tryParse(v) : null;
    }

    return FamilySafetyCase(
      caseId: (json['caseId'] as num).toInt(),
      analysisId: (json['analysisId'] as num).toInt(),
      wardId: (json['wardId'] as num).toInt(),
      wardName: json['wardName'] as String?,
      status: FamilySafetyStatus.fromWire(json['status'] as String?),
      riskScore: (json['riskScore'] as num?)?.toInt() ?? 0,
      suspectedInstitution: json['suspectedInstitution'] as String?,
      riskyAction: json['riskyAction'] as String?,
      maskedMessagePreview: json['maskedMessagePreview'] as String?,
      riskSummary: json['riskSummary'] as String?,
      detectedAt: at('detectedAt'),
      reminderCount: (json['reminderCount'] as num?)?.toInt() ?? 0,
      calledByName: json['calledByName'] as String?,
      calledAt: at('calledAt'),
      handledByName: json['handledByName'] as String?,
      resolvedAt: at('resolvedAt'),
    );
  }
}
