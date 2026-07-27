import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'auth_api.dart';
import 'app_prefs.dart';

/// FCM 푸시 기기 등록·해제 담당.
///
/// 백엔드(SafeFam_BE) 확인된 계약 (develop 소스 대조):
///  - POST   /api/v1/devices { deviceToken, platform } → 201
///        ApiResponse<DeviceResponse { deviceId, platform }> — 동일 토큰은 갱신,
///        다른 계정 토큰이면 삭제 후 재생성(→ deviceId가 바뀔 수 있음)
///  - DELETE /api/v1/devices/{deviceId} → 204 (소유자 검증; 없으면 404·타인 403)
///  둘 다 보호된 API → AuthApi.sendAuthorized 경유.
class DeviceApi {
  static const Duration _timeout = Duration(seconds: 10);
  static Uri _uri(String path) => Uri.parse('${AuthApi.baseUrl}$path');

  /// 로그인 성공 후 FCM 토큰 발급하고 서버에 기기 등록.
  /// 등록 응답의 deviceId를 저장해 두어야 로그아웃 때 해제할 수 있다.
  static Future<void> registerDevice() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // 알림 권한 요청
      await messaging.requestPermission();

      // FCM 토큰 발급
      final token = await messaging.getToken();
      if (token == null) return;

      // 서버에 기기 등록(보호된 API → 401이면 재발급 후 재시도)
      final res = await AuthApi.sendAuthorized((headers) => http
          .post(
            _uri('/api/v1/devices'),
            headers: headers,
            body: jsonEncode({
              'deviceToken': token,
              'platform': 'ANDROID',
            }),
          )
          .timeout(_timeout));

      // 이후 로그아웃 시 해제에 쓰려고 deviceId를 보관한다.
      final id = _deviceId(res);
      if (id != null) await AppPrefs.setDeviceId(id);
    } catch (_) {
      // 기기 등록 실패해도 앱 흐름에 영향 없음
    }
  }

  /// 로그아웃 직전(토큰이 아직 유효할 때) 서버에서 이 기기를 해제한다.
  /// 저장된 deviceId가 없으면 아무것도 하지 않는다. 실패해도 로그아웃은
  /// 진행되며(서버가 오래된 기기를 정리한다), 로컬 id는 지워 재등록에 대비한다.
  static Future<void> unregisterDevice() async {
    final id = await AppPrefs.deviceId();
    if (id == null) return;
    try {
      await AuthApi.sendAuthorized((headers) => http
          .delete(_uri('/api/v1/devices/$id'), headers: headers)
          .timeout(_timeout));
    } catch (_) {
      // 해제 실패는 무시(다음 로그인에서 같은 토큰으로 재등록되며 서버가 정리).
    } finally {
      await AppPrefs.removeDeviceId();
    }
  }

  /// 등록 응답(ApiResponse<DeviceResponse>)에서 deviceId를 꺼낸다. 실패 시 null.
  static int? _deviceId(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300 || res.body.isEmpty) {
      return null;
    }
    try {
      final body = jsonDecode(res.body);
      if (body is Map<String, dynamic> && body['status'] == 'SUCCESS') {
        final data = body['data'];
        if (data is Map<String, dynamic>) {
          return (data['deviceId'] as num?)?.toInt();
        }
      }
    } catch (_) {}
    return null;
  }
}
