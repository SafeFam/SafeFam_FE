import 'dart:convert';

import 'package:http/http.dart' as http;

import 'analysis_api.dart' show AnalysisPage;
import 'auth_api.dart' show AuthApi;

/// 가족 보호 모드 서버 통신 담당.
///
/// 백엔드(SafeFam_BE) 확인된 계약 (develop 소스 대조, 2026-07-26):
///  - 모두 보호된 API → AuthApi.sendAuthorized 경유(401이면 토큰 재발급 후 재시도)
///  - 공통 응답 ApiResponse { status:"SUCCESS"|"ERROR", message, data }
///
///  /api/v1/family
///   - POST /invite      (보호자, 바디 없음) → 201
///        FamilyInviteResponse { inviteCode, qrToken, expiresAt(OffsetDateTime) }
///        ※ inviteCode는 숫자 6자리. 유효 10분. (Swagger의 "A1B2C3D4" 예시는 오기)
///   - POST /link/code   (피보호자) { inviteCode(\d{6}) } → 200
///   - POST /link/qr     (피보호자) { qrToken(≤64) } → 200   ※ QR은 후속 이슈
///   - DELETE /{linkId}  (양측)                        → 204 (ApiResponse 래핑 없음)
///   - GET  /members     (보호자)                      → List<FamilyMemberResponse>
///        { linkId, wardId, wardPhone, status(PENDING|ACTIVE|REVOKED), linkedAt }
///        ※ ACTIVE만 내려오며 wardPhone은 마스킹 없이 옴.
///
///  에러: 응답 바디에 에러코드는 없고 message만 있다(AuthApi와 동일 관례).
///   FA001 404(잘못된 코드)·FA002 422(만료)·FA003 404(링크 없음)·
///   FA004 403(권한 없음)·FA005 422(자기 연결). → status + 서버 message로 안내.
///
///  ※ 가족 연결에 별명(이름) 필드는 백엔드에 없다. 별명은 기기 로컬(AppPrefs)에만
///    저장한다. 피보호자가 '내 보호자'를 조회하는 엔드포인트도 없다.
class FamilyApi {
  static const Duration _timeout = Duration(seconds: 10);

  static Uri _uri(String path) => Uri.parse('${AuthApi.baseUrl}$path');

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

  /// 에러 응답에서 사용자에게 보여줄 message를 꺼낸다(없으면 null).
  static String? _errorMessage(http.Response res) {
    if (res.body.isEmpty) return null;
    try {
      final body = jsonDecode(res.body);
      if (body is Map<String, dynamic> && body['message'] is String) {
        return body['message'] as String;
      }
    } catch (_) {}
    return null;
  }

  /// 초대 코드/QR 토큰 발급(보호자). 실패 시 null.
  static Future<FamilyInvite?> createInvite() async {
    try {
      final res = await AuthApi.sendAuthorized((headers) => http
          .post(_uri('/api/v1/family/invite'), headers: headers)
          .timeout(_timeout));
      if (!_isSuccess(res) || res.body.isEmpty) return null;
      final data = jsonDecode(res.body)['data'];
      if (data is! Map<String, dynamic>) return null;
      return FamilyInvite.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// 초대 코드로 연결(피보호자). 성공/실패 사유를 함께 돌려준다.
  static Future<FamilyLinkResult> linkByCode(String inviteCode) async {
    try {
      final res = await AuthApi.sendAuthorized((headers) => http
          .post(_uri('/api/v1/family/link/code'),
              headers: headers, body: jsonEncode({'inviteCode': inviteCode}))
          .timeout(_timeout));
      if (_isSuccess(res)) return const FamilyLinkResult.ok();
      return FamilyLinkResult.fail(
          _errorMessage(res) ?? _fallbackLinkError(res.statusCode));
    } catch (_) {
      return const FamilyLinkResult.fail('연결하지 못했어요. 잠시 후 다시 시도해 주세요.');
    }
  }

  /// QR 토큰으로 연결(피보호자). 성공/실패 사유를 함께 돌려준다.
  /// 보호자 초대 화면의 QR을 스캔해 얻은 [qrToken]을 그대로 넘긴다.
  static Future<FamilyLinkResult> linkByQr(String qrToken) async {
    try {
      final res = await AuthApi.sendAuthorized((headers) => http
          .post(_uri('/api/v1/family/link/qr'),
              headers: headers, body: jsonEncode({'qrToken': qrToken}))
          .timeout(_timeout));
      if (_isSuccess(res)) return const FamilyLinkResult.ok();
      return FamilyLinkResult.fail(
          _errorMessage(res) ?? _fallbackLinkError(res.statusCode));
    } catch (_) {
      return const FamilyLinkResult.fail('연결하지 못했어요. 잠시 후 다시 시도해 주세요.');
    }
  }

  /// 연결된 가족(피보호자) 목록 조회(보호자). 실패 시 null, 없으면 빈 목록.
  static Future<List<FamilyMember>?> getMembers() async {
    try {
      final res = await AuthApi.sendAuthorized((headers) => http
          .get(_uri('/api/v1/family/members'), headers: headers)
          .timeout(_timeout));
      if (!_isSuccess(res) || res.body.isEmpty) return null;
      final data = jsonDecode(res.body)['data'];
      if (data is! List) return null;
      return data
          .whereType<Map<String, dynamic>>()
          .map(FamilyMember.fromJson)
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// 피보호자(ward)의 탐지 이력 조회(보호자 전용, 원격 모니터링). 최신순 페이지.
  /// 응답은 문자 분석 목록과 동일한 [AnalysisPage](status 포함). 실패 시 null.
  ///
  /// ※ 상세(`/analyses/{id}`)는 소유자(피보호자) 스코프라 보호자는 열 수 없어,
  ///   호출부는 목록만 읽기 전용으로 보여준다.
  static Future<AnalysisPage?> getWardLogs(
    int wardId, {
    int page = 0,
    int size = 20,
  }) async {
    try {
      final res = await AuthApi.sendAuthorized((headers) => http
          .get(
              _uri('/api/v1/family/ward/$wardId/logs?page=$page&size=$size'),
              headers: headers)
          .timeout(_timeout));
      if (!_isSuccess(res) || res.body.isEmpty) return null;
      final data = jsonDecode(res.body)['data'];
      if (data is! Map<String, dynamic>) return null;
      return AnalysisPage.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// 연결 해제. 성공(204) 여부.
  static Future<bool> revoke(int linkId) async {
    try {
      final res = await AuthApi.sendAuthorized((headers) => http
          .delete(_uri('/api/v1/family/$linkId'), headers: headers)
          .timeout(_timeout));
      return res.statusCode == 204 || _isSuccess(res);
    } catch (_) {
      return false;
    }
  }

  /// 서버 message가 없을 때 status로 안내 문구를 정한다.
  static String _fallbackLinkError(int status) => switch (status) {
        404 => '유효하지 않은 초대 코드예요.',
        422 => '만료됐거나 연결할 수 없는 코드예요.',
        403 => '연결 권한이 없어요.',
        _ => '연결하지 못했어요. 잠시 후 다시 시도해 주세요.',
      };
}

/// 가족 연결 상태.
enum FamilyLinkStatus {
  pending,
  active,
  revoked;

  static FamilyLinkStatus fromWire(String? v) => switch (v) {
        'ACTIVE' => FamilyLinkStatus.active,
        'REVOKED' => FamilyLinkStatus.revoked,
        _ => FamilyLinkStatus.pending,
      };
}

/// 초대 코드/QR 토큰 발급 결과.
class FamilyInvite {
  final String inviteCode;
  final String qrToken;
  final DateTime expiresAt;

  const FamilyInvite({
    required this.inviteCode,
    required this.qrToken,
    required this.expiresAt,
  });

  factory FamilyInvite.fromJson(Map<String, dynamic> json) => FamilyInvite(
        inviteCode: json['inviteCode'] as String? ?? '',
        qrToken: json['qrToken'] as String? ?? '',
        // 만료 시각을 못 읽으면 이미 만료된 것으로 보아 즉시 재발급을 유도한다.
        expiresAt: DateTime.tryParse('${json['expiresAt']}')?.toLocal() ??
            DateTime.now(),
      );
}

/// 연결된 가족 한 명.
class FamilyMember {
  final int linkId;
  final int? wardId;
  final String? wardPhone;
  final FamilyLinkStatus status;
  final DateTime? linkedAt;

  const FamilyMember({
    required this.linkId,
    required this.status,
    this.wardId,
    this.wardPhone,
    this.linkedAt,
  });

  factory FamilyMember.fromJson(Map<String, dynamic> json) => FamilyMember(
        linkId: (json['linkId'] as num?)?.toInt() ?? 0,
        wardId: (json['wardId'] as num?)?.toInt(),
        wardPhone: json['wardPhone'] as String?,
        status: FamilyLinkStatus.fromWire(json['status'] as String?),
        linkedAt: DateTime.tryParse('${json['linkedAt']}')?.toLocal(),
      );
}

/// 연결 수락 결과(성공 또는 사용자 노출용 실패 사유).
class FamilyLinkResult {
  final bool success;
  final String? error;

  const FamilyLinkResult.ok()
      : success = true,
        error = null;
  const FamilyLinkResult.fail(this.error) : success = false;
}
