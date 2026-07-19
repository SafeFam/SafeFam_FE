import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

/// 인증 관련 서버 통신 담당.
///
/// 백엔드(SafeFam_BE) 확인된 계약 (휴대폰 기반 확정, 2026-07-17 #26):
///  - baseUrl: `http://localhost:8080` (context-path 없음)
///  - 공통 응답 포맷 ApiResponse: { status: "SUCCESS"|"ERROR", message, data }
///  - 토큰은 응답 바디로 옴(TokenResponse):
///      { tokenType:"Bearer", accessToken, refreshToken, expiresIn(초) }
///  - 인증 필요한 요청은 헤더 Authorization: Bearer <accessToken>
///  - 로그인: { phoneNumber, password } → TokenResponse
///  - 회원가입: { phoneNumber, password, name } → 201만(토큰 없음) → 이어서 로그인
///  - 비밀번호 정책: 영문+숫자 포함, 특수문자 없음, 8~64자
///  - 로그인 응답에 신규회원 플래그 없음 → 신규/기존은 프론트 흐름으로 판단
///  ※ GET /api/v1/users/me(마이페이지)는 아직 501 미구현 → myProfile은 껍데기 유지.
///  ※ 소셜 로그인(카카오/구글)은 백엔드 엔드포인트 미정 → socialLogin은 껍데기 유지.
class AuthApi {
  /// 서버 주소. 빌드시 `--dart-define=SAFEFAM_API_BASE_URL=...`로 주입하고,
  /// 없으면 개발 기본값(에뮬레이터→호스트 localhost)을 쓴다.
  /// - Android 에뮬레이터에서 호스트 PC의 localhost는 `10.0.2.2`로 접근한다
  ///   (에뮬레이터의 `localhost`는 에뮬레이터 자신을 가리킴).
  /// - 실기기: 같은 네트워크의 PC IP, 배포: `--dart-define`으로 실제 https 도메인.
  static const String baseUrl = String.fromEnvironment(
    'SAFEFAM_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  // TODO: 토큰을 앱 재시작에도 유지하려면 flutter_secure_storage로 저장.
  static String? accessToken;
  static String? refreshToken;

  static const Duration _timeout = Duration(seconds: 10);

  static Uri _uri(String path) => Uri.parse('$baseUrl$path');

  static Map<String, String> _headers({bool auth = false}) {
    final h = {'Content-Type': 'application/json'};
    if (auth && accessToken != null) {
      h['Authorization'] = 'Bearer $accessToken';
    }
    return h;
  }

  /// 2xx이면서 ApiResponse.status == "SUCCESS"일 때 성공.
  static bool _isSuccess(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) return false;
    if (res.body.isEmpty) return true; // 바디 없는 성공(예: 일부 201)
    try {
      final body = jsonDecode(res.body);
      return body is Map<String, dynamic> && body['status'] == 'SUCCESS';
    } catch (_) {
      return false;
    }
  }

  /// 회원가입용 인증번호 발송. 성공 여부만 반환.
  static Future<bool> requestCode(String phone) async {
    final res = await http
        .post(_uri('/api/v1/auth/phone-verifications/send'),
            headers: _headers(), body: jsonEncode({'phoneNumber': phone}))
        .timeout(_timeout);
    return _isSuccess(res);
  }

  /// 인증번호 검증(회원가입 사전 단계). 성공 여부만 반환.
  static Future<bool> verifyCode(String phone, String code) async {
    final res = await http
        .post(_uri('/api/v1/auth/phone-verifications/verify'),
            headers: _headers(),
            body: jsonEncode({'phoneNumber': phone, 'code': code}))
        .timeout(_timeout);
    return _isSuccess(res);
  }

  /// 회원가입. 휴대폰 인증 완료 후 이름(닉네임)·비밀번호로 계정 생성.
  /// 백엔드는 201만 반환(토큰 없음) → 가입 후 [login]으로 토큰을 발급받는다.
  /// 비밀번호 정책: 영문+숫자 포함, 특수문자 없음, 8~64자.
  static Future<bool> signup({
    required String phone,
    required String name,
    required String password,
  }) async {
    final res = await http
        .post(_uri('/api/v1/auth/signup'),
            headers: _headers(),
            body: jsonEncode(
                {'phoneNumber': phone, 'password': password, 'name': name}))
        .timeout(_timeout);
    return _isSuccess(res);
  }

  /// 비밀번호 재설정. 휴대폰 인증(요청→검증) 완료 후 새 비밀번호로 변경.
  /// 인증번호 발송·검증은 requestCode/verifyCode 재사용.
  /// 보안: 재설정 요청에 인증번호(code)를 함께 보내, 백엔드가 OTP 소유를
  /// 검증·소비하는 것과 비밀번호 변경을 원자적으로 처리하게 한다.
  /// (phone+newPassword만으로는 인증 없이 재설정될 수 있어 code 필수)
  static Future<bool> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    final res = await http
        .post(_uri('/api/v1/auth/password/reset'),
            headers: _headers(),
            body: jsonEncode({
              'phoneNumber': phone,
              'code': code,
              'newPassword': newPassword,
            }))
        .timeout(_timeout);
    return _isSuccess(res);
  }

  /// 비밀번호 정책(가입·재설정 공통): 영문+숫자 포함, 특수문자 없음, 8~64자.
  /// 통과하면 null, 위반하면 안내 메시지를 반환한다.
  static String? passwordError(String pw) {
    if (pw.length < 8 || pw.length > 64) {
      return '비밀번호는 8자 이상 64자 이하여야 해요';
    }
    if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(pw)) {
      return '비밀번호는 영문과 숫자만 사용할 수 있어요';
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(pw) || !RegExp(r'[0-9]').hasMatch(pw)) {
      return '비밀번호는 영문과 숫자를 모두 포함해야 해요';
    }
    return null;
  }

  /// 로그인. 휴대폰 번호 + 비밀번호. 성공 시 토큰 저장.
  static Future<AuthResult> login({
    required String phone,
    required String password,
  }) async {
    final res = await http
        .post(_uri('/api/v1/auth/login'),
            headers: _headers(),
            body: jsonEncode({'phoneNumber': phone, 'password': password}))
        .timeout(_timeout);
    if (!_isSuccess(res) || res.body.isEmpty) {
      return const AuthResult(success: false);
    }
    final data = jsonDecode(res.body)['data'];
    if (data is! Map<String, dynamic>) return const AuthResult(success: false);
    final nextAccessToken = data['accessToken'];
    final nextRefreshToken = data['refreshToken'];
    if (nextAccessToken is! String ||
        nextAccessToken.isEmpty ||
        nextRefreshToken is! String ||
        nextRefreshToken.isEmpty) {
      return const AuthResult(success: false);
    }
    accessToken = nextAccessToken;
    refreshToken = nextRefreshToken;
    return const AuthResult(success: true, isNewUser: false);
  }

  /// 소셜 로그인(카카오/구글). provider: 'kakao' | 'google'
  static Future<AuthResult> socialLogin(String provider) async {
    print('socialLogin 호출: $provider');
    if (provider == 'kakao') {
      return await _kakaoLogin();
    }
    // 구글은 나중에
    await Future.delayed(const Duration(milliseconds: 500));
    return const AuthResult(success: false);
  }

  static Future<AuthResult> _kakaoLogin() async {
    try {
      // 1. 카카오톡으로 로그인 (없으면 카카오 계정으로)
      OAuthToken token;
      if (await isKakaoTalkInstalled()) {
        token = await UserApi.instance.loginWithKakaoTalk();
      } else {
        token = await UserApi.instance.loginWithKakaoAccount();
      }

      // 2. Spring Boot로 카카오 액세스 토큰 전달
      final res = await http.post(
        _uri('/api/v1/auth/kakao'),
        headers: _headers(),
        body: jsonEncode({'kakaoAccessToken': token.accessToken}),
      ).timeout(_timeout);

      if (!_isSuccess(res)) return const AuthResult(success: false);

      final data = jsonDecode(res.body)['data'];
      final isNewUser = data['isNewUser'] as bool;

      if (!isNewUser) {
        // 기존 회원 → JWT 저장
        final tokenData = data['token'] as Map<String, dynamic>;
        accessToken = tokenData['accessToken'];
        refreshToken = tokenData['refreshToken'];
        return const AuthResult(success: true, isNewUser: false);
      } else {
        // 신규 회원 → kakaoId 저장해서 온보딩으로
        return AuthResult(
          success: true,
          isNewUser: true,
          kakaoAccessToken: token.accessToken,
        );
      }
    } catch (e) {
      print('카카오 로그인 에러: $e');
      return const AuthResult(success: false);
    }
  }

  static Future<AuthResult> kakaoSignup({
    required String kakaoAccessToken,
    required String phoneNumber,
    required String name,
  }) async {
    try {
      final res = await http.post(
        _uri('/api/v1/auth/kakao/signup'),
        headers: _headers(),
        body: jsonEncode({
          'kakaoAccessToken': kakaoAccessToken,
          'phoneNumber': phoneNumber,
          'name': name,
        }),
      ).timeout(_timeout);

      if (!_isSuccess(res)) return const AuthResult(success: false);

      final data = jsonDecode(res.body)['data'];
      accessToken = data['accessToken'];
      refreshToken = data['refreshToken'];
      return const AuthResult(success: true);
    } catch (e) {
      return const AuthResult(success: false);
    }
  }

  /// 내 정보 조회(마이페이지).
  /// TODO: GET $baseUrl/api/v1/users/me (헤더 Bearer) — 백엔드 현재 501, 구현 후 연동.
  static Future<UserProfile> myProfile() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const UserProfile(
        name: '이건', phoneMasked: '010-****-0000', role: '보호자');
  }

  /// 로그아웃. 서버 토큰 무효화 후 로컬 토큰 폐기.
  static Future<void> logout() async {
    try {
      if (refreshToken != null) {
        await http
            .post(_uri('/api/v1/auth/logout'),
                headers: _headers(auth: true),
                body: jsonEncode({'refreshToken': refreshToken}))
            .timeout(_timeout);
      }
    } catch (_) {
      // 서버 호출이 실패해도 로컬 토큰은 폐기해 로그아웃 상태로 만든다.
    }
    accessToken = null;
    refreshToken = null;
  }
}

class AuthResult {
  final bool success;
  final bool isNewUser; // 신규면 가족 등록으로, 기존이면 홈으로
  final String? message;
  final String? kakaoId;
  final String? kakaoAccessToken;
  const AuthResult({
    required this.success,
    this.isNewUser = false,
    this.message,
    this.kakaoId,
    this.kakaoAccessToken,
  });
}

class UserProfile {
  final String name;
  final String phoneMasked;
  final String role; // 보호자 | 피보호자
  const UserProfile(
      {required this.name, required this.phoneMasked, required this.role});
}
