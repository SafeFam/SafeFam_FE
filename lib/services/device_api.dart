import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'auth_api.dart';

class DeviceApi {
  static const Duration _timeout = Duration(seconds: 10);
  static Uri _uri(String path) => Uri.parse('${AuthApi.baseUrl}$path');

  /// 로그인 성공 후 FCM 토큰 발급하고 서버에 기기 등록
  static Future<void> registerDevice() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // 알림 권한 요청
      await messaging.requestPermission();

      // FCM 토큰 발급
      final token = await messaging.getToken();
      if (token == null) return;

      // 서버에 기기 등록(보호된 API → 401이면 재발급 후 재시도)
      await AuthApi.sendAuthorized((headers) => http
          .post(
        _uri('/api/v1/devices'),
        headers: headers,
        body: jsonEncode({
          'deviceToken': token,
          'platform': 'ANDROID',
        }),
      )
          .timeout(_timeout));
    } catch (_) {
      // 기기 등록 실패해도 앱 흐름에 영향 없음
    }
  }
}