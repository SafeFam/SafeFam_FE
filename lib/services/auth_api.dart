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
///
/// 마이페이지 users/me (SafeFam_BE #39 구현 완료, 2026-07-20 소스 대조):
///  - GET    /api/v1/users/me → UserResponse
///      { userId, phoneNumber(★서버 마스킹 "010-****-0000"), name, role, createdAt }
///  - PATCH  /api/v1/users/me { name } → 수정된 UserResponse (현재 이름만 수정)
///  - DELETE /api/v1/users/me { password } → 204 (soft delete). 비번 틀리면 실패.
///  - 셋 다 보호된 API → Authorization: Bearer 필수.
///  - role은 시스템 role(USER/ADMIN)이며 가족 role(보호자/피보호자)이 아니다.
///
/// 탐지·알림 설정 users/me/settings (SafeFam_BE 구현 완료, 소스 대조):
///  - GET   /api/v1/users/me/settings → UserSettings
///      { autoAnalysisEnabled, pushEnabled } (기본값 둘 다 true)
///  - PATCH /api/v1/users/me/settings { autoAnalysisEnabled?, pushEnabled? }
///      → 변경된 UserSettings. ★전달한 필드만 변경(null은 무시하는 부분 수정).
///  - 둘 다 보호된 API → Authorization: Bearer 필수.
///  ※ 구글 소셜 로그인은 백엔드 엔드포인트 미정 → 해당 분기만 껍데기 유지.
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
  /// 보안: OTP 검증·소비는 백엔드가 서버측 인증 상태(verifyCode로 만들어진
  /// verified 상태)를 consume하는 방식으로 처리한다. 따라서 재설정 요청 전에
  /// 반드시 verifyCode를 호출해 서버측 인증을 통과시켜야 한다.
  /// 백엔드 계약: POST /api/v1/auth/password/reset { phoneNumber, newPassword }.
  static Future<bool> resetPassword({
    required String phone,
    required String newPassword,
  }) async {
    final res = await http
        .post(_uri('/api/v1/auth/password/reset'),
            headers: _headers(),
            body: jsonEncode({
              'phoneNumber': phone,
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
  /// 구글은 백엔드 엔드포인트 미정 → 현재 실패 반환(껍데기).
  static Future<AuthResult> socialLogin(String provider) async {
    if (provider == 'kakao') {
      return _kakaoLogin();
    }
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
    } catch (_) {
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

  /// 내 정보 조회(마이페이지). GET /api/v1/users/me (Bearer).
  /// 실패 시 예외를 던져 화면(FutureBuilder)이 에러 상태를 보이게 한다.
  static Future<UserProfile> myProfile() async {
    final res = await http
        .get(_uri('/api/v1/users/me'), headers: _headers(auth: true))
        .timeout(_timeout);
    if (!_isSuccess(res) || res.body.isEmpty) {
      throw Exception('프로필을 불러오지 못했습니다');
    }
    final data = jsonDecode(res.body)['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('프로필을 불러오지 못했습니다');
    }
    return UserProfile.fromJson(data);
  }

  /// 내 정보(이름) 수정. PATCH /api/v1/users/me { name } (Bearer).
  /// 성공 시 수정된 프로필을 반환, 실패 시 null.
  static Future<UserProfile?> updateName(String name) async {
    final res = await http
        .patch(_uri('/api/v1/users/me'),
            headers: _headers(auth: true), body: jsonEncode({'name': name}))
        .timeout(_timeout);
    if (!_isSuccess(res) || res.body.isEmpty) return null;
    final data = jsonDecode(res.body)['data'];
    if (data is! Map<String, dynamic>) return null;
    return UserProfile.fromJson(data);
  }

  /// 회원 탈퇴. DELETE /api/v1/users/me { password } → 204 (soft delete).
  /// 본인 확인용 비밀번호 재입력 필요. 비번이 틀리면 실패(false).
  /// 성공 시 로컬 토큰을 폐기해 로그아웃 상태로 만든다.
  static Future<bool> withdraw(String password) async {
    final res = await http
        .delete(_uri('/api/v1/users/me'),
            headers: _headers(auth: true),
            body: jsonEncode({'password': password}))
        .timeout(_timeout);
    final ok = res.statusCode == 204 || _isSuccess(res);
    if (ok) {
      accessToken = null;
      refreshToken = null;
    }
    return ok;
  }

  /// 탐지·알림 설정 조회. GET /api/v1/users/me/settings (Bearer).
  /// 실패 시 예외를 던져 화면이 에러 상태를 보이게 한다.
  static Future<UserSettings> getSettings() async {
    final res = await http
        .get(_uri('/api/v1/users/me/settings'), headers: _headers(auth: true))
        .timeout(_timeout);
    if (!_isSuccess(res) || res.body.isEmpty) {
      throw Exception('설정을 불러오지 못했습니다');
    }
    final data = jsonDecode(res.body)['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('설정을 불러오지 못했습니다');
    }
    return UserSettings.fromJson(data);
  }

  /// 탐지·알림 설정 변경. PATCH /api/v1/users/me/settings (Bearer).
  /// 전달한 필드만 변경되므로, 바꾸려는 값만 넘긴다(나머지는 null → 서버가 무시).
  /// 성공 시 서버가 반영한 최신 설정을 반환, 실패 시 null.
  static Future<UserSettings?> updateSettings({
    bool? autoAnalysisEnabled,
    bool? pushEnabled,
  }) async {
    final body = <String, dynamic>{};
    if (autoAnalysisEnabled != null) {
      body['autoAnalysisEnabled'] = autoAnalysisEnabled;
    }
    if (pushEnabled != null) body['pushEnabled'] = pushEnabled;
    try {
      final res = await http
          .patch(_uri('/api/v1/users/me/settings'),
              headers: _headers(auth: true), body: jsonEncode(body))
          .timeout(_timeout);
      if (!_isSuccess(res) || res.body.isEmpty) return null;
      final data = jsonDecode(res.body)['data'];
      if (data is! Map<String, dynamic>) return null;
      return UserSettings.fromJson(data);
    } catch (_) {
      // 타임아웃·연결 실패 등 전송 계층 예외도 null로 수렴시켜, 호출부(UI)가
      // 예외 없이 실패 경로(원복+안내)를 타게 한다.
      return null;
    }
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

/// 백엔드 UserResponse 매핑. phoneMasked는 서버가 이미 "010-****-0000"으로 마스킹.
/// role은 시스템 role(USER/ADMIN) — 가족 role(보호자/피보호자)이 아님.
class UserProfile {
  final int? userId;
  final String name;
  final String phoneMasked; // 서버 마스킹된 phoneNumber
  final String role; // USER | ADMIN
  final DateTime? createdAt;
  const UserProfile({
    this.userId,
    required this.name,
    required this.phoneMasked,
    required this.role,
    this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final created = json['createdAt'];
    return UserProfile(
      userId: json['userId'] is int ? json['userId'] as int : null,
      name: (json['name'] as String?) ?? '',
      phoneMasked: (json['phoneNumber'] as String?) ?? '',
      role: (json['role'] as String?) ?? 'USER',
      createdAt: created is String ? DateTime.tryParse(created) : null,
    );
  }
}

/// 백엔드 UserSettingsResponse 매핑 — 탐지·알림 설정.
/// autoAnalysisEnabled: 문자 자동 탐지 · pushEnabled: 푸시 알림. 기본값 둘 다 true.
class UserSettings {
  final bool autoAnalysisEnabled;
  final bool pushEnabled;
  const UserSettings({
    required this.autoAnalysisEnabled,
    required this.pushEnabled,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) => UserSettings(
        autoAnalysisEnabled: json['autoAnalysisEnabled'] as bool? ?? true,
        pushEnabled: json['pushEnabled'] as bool? ?? true,
      );

  UserSettings copyWith({bool? autoAnalysisEnabled, bool? pushEnabled}) =>
      UserSettings(
        autoAnalysisEnabled: autoAnalysisEnabled ?? this.autoAnalysisEnabled,
        pushEnabled: pushEnabled ?? this.pushEnabled,
      );
}
