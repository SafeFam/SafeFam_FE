import 'dart:async';

/// 인증 관련 서버 통신 담당(껍데기).
///
/// 지금은 화면 흐름 확인용으로 가짜 값을 돌려줍니다.
/// 3단계(진용 API 완성)에서 아래 각 메서드 안의 TODO만 실제 http 호출로 바꾸면
/// 화면 코드는 그대로 두고 연동됩니다.
///
/// 합의 필요(진용·초은):
///  - baseUrl
///  - 공통 응답 포맷(ApiResponse): { success, data, error } 형태 여부
///  - 토큰: accessToken / refreshToken 이 응답 바디로 오는지, 헤더로 오는지
class AuthApi {
  // TODO(3단계): 실제 서버 주소로 교체
  static const String baseUrl = 'https://api.safefam.example';

  // TODO(3단계): 로그인 후 받은 토큰 저장(예: flutter_secure_storage)
  static String? accessToken;
  static String? refreshToken;

  /// 인증번호 요청. 성공 여부만 반환.
  static Future<bool> requestCode(String phone) async {
    await Future.delayed(const Duration(milliseconds: 400)); // 네트워크 흉내
    // TODO(3단계): POST $baseUrl/auth/sms/request  body: { phone }
    return true;
  }

  /// 인증번호 확인 → 로그인/회원가입. 성공 시 토큰 저장.
  ///
  /// 휴대폰 가입은 인증번호 확인과 함께 닉네임·비밀번호를 함께 받는다.
  /// (기존 회원은 서버가 phone으로 식별해 nickname/password 없이도 로그인 가능)
  static Future<AuthResult> verifyCode(
    String phone,
    String code, {
    String? nickname,
    String? password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    // TODO(3단계): POST $baseUrl/auth/sms/verify
    //  body: { phone, code, nickname, password }
    //  → 응답에서 accessToken/refreshToken 저장, isNewUser 판별
    accessToken = 'dummy_access';
    refreshToken = 'dummy_refresh';
    return const AuthResult(success: true, isNewUser: true);
  }

  /// 소셜 로그인(카카오/구글). provider: 'kakao' | 'google'
  static Future<AuthResult> socialLogin(String provider) async {
    await Future.delayed(const Duration(milliseconds: 500));
    // TODO(3단계): 소셜 SDK 토큰 → 서버 검증 → 우리 토큰 발급
    accessToken = 'dummy_access';
    return const AuthResult(success: true, isNewUser: true);
  }

  /// 내 정보 조회(마이페이지).
  static Future<UserProfile> myProfile() async {
    await Future.delayed(const Duration(milliseconds: 300));
    // TODO(3단계): GET $baseUrl/users/me  (헤더: Authorization: Bearer $accessToken)
    return const UserProfile(name: '이건', phoneMasked: '010-****-0000', role: '보호자');
  }

  /// 로그아웃. 토큰 폐기.
  static Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 300));
    // TODO(3단계): POST $baseUrl/auth/logout  → 서버 토큰 무효화
    accessToken = null;
    refreshToken = null;
  }
}

class AuthResult {
  final bool success;
  final bool isNewUser; // 신규면 가족 등록으로, 기존이면 홈으로
  final String? message;
  const AuthResult({required this.success, this.isNewUser = false, this.message});
}

class UserProfile {
  final String name;
  final String phoneMasked;
  final String role; // 보호자 | 피보호자
  const UserProfile({required this.name, required this.phoneMasked, required this.role});
}
