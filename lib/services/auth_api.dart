import 'dart:async';

/// 인증 관련 서버 통신 담당(껍데기).
///
/// 지금은 화면 흐름 확인용으로 가짜 값을 돌려줍니다.
/// 3단계(진용 API 완성)에서 아래 각 메서드 안의 TODO만 실제 http 호출로 바꾸면
/// 화면 코드는 그대로 두고 연동됩니다.
///
/// 백엔드(SafeFam_BE) 확인된 계약 (휴대폰 기반 확정, 2026-07-17 #26):
///  - baseUrl: http://localhost:8080  (context-path 없음)
///  - 공통 응답 포맷 ApiResponse: { status: "SUCCESS"|"ERROR", message, data }
///  - 토큰은 응답 바디로 옴(TokenResponse):
///      { tokenType:"Bearer", accessToken, refreshToken, expiresIn(초) }
///  - 인증 필요한 요청은 헤더 Authorization: Bearer <accessToken>
///  - 로그인: { phoneNumber, password } → TokenResponse
///  - 회원가입: { phoneNumber, password, name } → 201만(토큰 없음) → 이어서 로그인
///  - 비밀번호 정책: 영문+숫자 포함, 특수문자 없음, 8~64자
///  - 로그인 응답에 신규회원 플래그 없음 → 신규/기존은 프론트 흐름으로 판단
///    (회원가입 흐름=신규→가족등록 / 로그인 흐름=기존→홈)
///  ※ GET /api/v1/users/me(마이페이지)는 아직 501 미구현 → myProfile은 껍데기 유지.
class AuthApi {
  // TODO(3단계): 실제 서버 주소로 교체(로컬 개발은 http://localhost:8080)
  static const String baseUrl = 'http://localhost:8080';

  // TODO(3단계): 로그인 후 받은 토큰 저장(예: flutter_secure_storage)
  static String? accessToken;
  static String? refreshToken;

  /// 회원가입용 인증번호 발송. 성공 여부만 반환.
  static Future<bool> requestCode(String phone) async {
    await Future.delayed(const Duration(milliseconds: 400)); // 네트워크 흉내
    // TODO(3단계): POST $baseUrl/api/v1/auth/phone-verifications/send
    //  body: { phoneNumber: phone }
    return true;
  }

  /// 인증번호 검증(회원가입 사전 단계). 성공 여부만 반환.
  static Future<bool> verifyCode(String phone, String code) async {
    await Future.delayed(const Duration(milliseconds: 500));
    // TODO(3단계): POST $baseUrl/api/v1/auth/phone-verifications/verify
    //  body: { phoneNumber: phone, code }
    return true;
  }

  /// 회원가입. 휴대폰 인증 완료 후 이름(닉네임)·비밀번호로 계정 생성.
  /// 백엔드는 201만 반환(토큰 없음) → 가입 후 [login]으로 토큰을 발급받는다.
  /// 비밀번호 정책: 영문+숫자 포함, 특수문자 없음, 8자 이상.
  static Future<bool> signup({
    required String phone,
    required String name,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    // TODO(3단계): POST $baseUrl/api/v1/auth/signup
    //  body: { phoneNumber: phone, password, name }  → 201 (토큰 없음)
    return true;
  }

  /// 로그인. 휴대폰 번호 + 비밀번호. 성공 시 토큰 저장.
  static Future<AuthResult> login({
    required String phone,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    // TODO(3단계): POST $baseUrl/api/v1/auth/login
    //  body: { phoneNumber: phone, password }
    //  → 응답 data(TokenResponse)에서 accessToken/refreshToken 저장
    accessToken = 'dummy_access';
    refreshToken = 'dummy_refresh';
    return const AuthResult(success: true, isNewUser: false);
  }

  /// 소셜 로그인(카카오/구글). provider: 'kakao' | 'google'
  static Future<AuthResult> socialLogin(String provider) async {
    await Future.delayed(const Duration(milliseconds: 500));
    // TODO(3단계): 소셜 SDK 토큰 → 서버 검증 → 우리 토큰 발급
    accessToken = 'dummy_access';
    refreshToken = 'dummy_refresh';
    return const AuthResult(success: true, isNewUser: true);
  }

  /// 내 정보 조회(마이페이지).
  static Future<UserProfile> myProfile() async {
    await Future.delayed(const Duration(milliseconds: 300));
    // TODO(3단계): GET $baseUrl/api/v1/users/me  (헤더: Authorization: Bearer $accessToken)
    //  ※ 백엔드 현재 501(미구현) — 구현 후 연동
    return const UserProfile(
        name: '이건', phoneMasked: '010-****-0000', role: '보호자');
  }

  /// 로그아웃. 토큰 폐기.
  static Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 300));
    // TODO(3단계): POST $baseUrl/api/v1/auth/logout
    //  body: { refreshToken }  헤더: Authorization: Bearer $accessToken
    accessToken = null;
    refreshToken = null;
  }
}

class AuthResult {
  final bool success;
  final bool isNewUser; // 신규면 가족 등록으로, 기존이면 홈으로
  final String? message;
  const AuthResult(
      {required this.success, this.isNewUser = false, this.message});
}

class UserProfile {
  final String name;
  final String phoneMasked;
  final String role; // 보호자 | 피보호자
  const UserProfile(
      {required this.name, required this.phoneMasked, required this.role});
}
