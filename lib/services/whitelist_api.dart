import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_api.dart' show AuthApi;

/// 화이트리스트(신뢰 발신자) 서버 통신 담당.
///
/// 신뢰 발신자를 등록해두면 자동 탐지 시 분석을 프리패스한다(프리패스 확인
/// `/check`는 자동 탐지 흐름용이라 관리 UI에는 쓰지 않는다).
///
/// 백엔드(SafeFam_BE) 확인된 계약 (develop 소스 대조):
///  - 모두 보호된 API → AuthApi.sendAuthorized 경유
///  - 공통 응답 ApiResponse { status:"SUCCESS"|"ERROR", message, data }
///
///  /api/v1/whitelists
///   - POST            { sender(필수,≤100), label?(≤50) } → 201
///        WhitelistResponse { whitelistId, sender(서버 정규화), label, createdAt }
///        ※ 이미 있으면 WHITELIST_DUPLICATE(409). 발신자는 서버가 정규화한다
///          (전화=숫자만·82→국내, 문자 발신자=대문자).
///   - GET             → List<WhitelistResponse> (최신 등록순)
///   - GET /check?sender={발신자} → WhitelistCheckResponse { sender, whitelisted }
///        ※ whitelisted가 true면 분석 API 호출을 생략해도 된다는 뜻.
///   - DELETE /{id}    → 204 (소유권 검증; 없으면 WHITELIST_NOT_FOUND 404)
///  에러 바디는 message만 있다(AuthApi와 동일 관례).
class WhitelistApi {
  static const Duration _timeout = Duration(seconds: 10);

  static Uri _uri(String path) => Uri.parse('${AuthApi.baseUrl}$path');

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

  /// 신뢰 발신자 목록(최신순). 실패 시 null, 없으면 빈 목록.
  static Future<List<WhitelistEntry>?> getAll() async {
    try {
      final res = await AuthApi.sendAuthorized((headers) => http
          .get(_uri('/api/v1/whitelists'), headers: headers)
          .timeout(_timeout));
      if (!_isSuccess(res) || res.body.isEmpty) return null;
      final data = jsonDecode(res.body)['data'];
      if (data is! List) return null;
      return data
          .whereType<Map<String, dynamic>>()
          .map(WhitelistEntry.fromJson)
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// 신뢰 발신자 등록. 성공하면 null, 실패하면 사용자에게 보여줄 사유를 돌려준다
  /// (중복 등은 서버 message를 그대로 노출).
  static Future<String?> create(String sender, {String? label}) async {
    try {
      final trimmedLabel = label?.trim();
      final res = await AuthApi.sendAuthorized((headers) => http
          .post(_uri('/api/v1/whitelists'),
              headers: headers,
              body: jsonEncode({
                'sender': sender.trim(),
                if (trimmedLabel != null && trimmedLabel.isNotEmpty)
                  'label': trimmedLabel,
              }))
          .timeout(_timeout));
      if (_isSuccess(res)) return null;
      return _errorMessage(res) ?? '등록하지 못했어요. 잠시 후 다시 시도해 주세요.';
    } catch (_) {
      return '등록하지 못했어요. 잠시 후 다시 시도해 주세요.';
    }
  }

  /// 발신자가 신뢰 목록에 있는지 확인한다(자동 탐지의 분석 프리패스 판단용).
  ///
  /// **확실히 등록된 경우에만 true.** 통신 실패·응답 손상이면 false를 돌려줘
  /// 분석을 그대로 진행시킨다 — 프리패스는 검사를 건너뛰는 결정이라, 모르면
  /// 검사하는 쪽이 안전하다.
  ///
  /// [timeout]은 백그라운드 수신 처리처럼 시간 예산이 빠듯한 경로에서 줄여 쓴다.
  static Future<bool> check(String sender, {Duration? timeout}) async {
    final trimmed = sender.trim();
    if (trimmed.isEmpty) return false;
    try {
      final res = await AuthApi.sendAuthorized((headers) => http
          .get(
              Uri.parse('${AuthApi.baseUrl}/api/v1/whitelists/check')
                  .replace(queryParameters: {'sender': trimmed}),
              headers: headers)
          .timeout(timeout ?? _timeout));
      if (!_isSuccess(res) || res.body.isEmpty) return false;
      final data = jsonDecode(res.body)['data'];
      return data is Map<String, dynamic> && data['whitelisted'] == true;
    } catch (_) {
      return false;
    }
  }

  /// 신뢰 발신자 삭제. 성공(204) 여부.
  static Future<bool> delete(int whitelistId) async {
    try {
      final res = await AuthApi.sendAuthorized((headers) => http
          .delete(_uri('/api/v1/whitelists/$whitelistId'), headers: headers)
          .timeout(_timeout));
      return res.statusCode == 204 || _isSuccess(res);
    } catch (_) {
      return false;
    }
  }
}

/// 신뢰 발신자 한 건(WhitelistResponse).
class WhitelistEntry {
  final int whitelistId;
  final String sender;
  final String? label;
  final DateTime? createdAt;

  const WhitelistEntry({
    required this.whitelistId,
    required this.sender,
    this.label,
    this.createdAt,
  });

  factory WhitelistEntry.fromJson(Map<String, dynamic> json) => WhitelistEntry(
        whitelistId: (json['whitelistId'] as num?)?.toInt() ?? 0,
        sender: (json['sender'] as String?) ?? '',
        label: (json['label'] as String?)?.trim().isEmpty ?? true
            ? null
            : (json['label'] as String).trim(),
        createdAt: DateTime.tryParse('${json['createdAt']}')?.toLocal(),
      );

  /// 목록에 보일 이름: 라벨이 있으면 라벨, 없으면 발신자.
  String get title => label ?? sender;
}
