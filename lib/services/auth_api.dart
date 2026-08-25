import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'app_prefs.dart';

/// 인증 관련 서버 통신 담당.
///
/// 백엔드(SafeFam_BE) 확인된 계약 (휴대폰 기반 확정, 2026-07-17 #26):
///  - context-path 없음 (배포 `https://api.safefam.site`; 로컬 주소는 아래 [baseUrl] 안내 참조)
///  - 공통 응답 포맷 ApiResponse: { status: "SUCCESS"|"ERROR", message, data }
///  - 토큰은 응답 바디로 옴(TokenResponse):
///      { tokenType:"Bearer", accessToken, refreshToken, expiresIn(초) }
///  - 인증 필요한 요청은 헤더 Authorization: Bearer <accessToken>
///  - 로그인: { phoneNumber, password } → TokenResponse
///  - 회원가입: { phoneNumber, password, name } → 201만(토큰 없음) → 이어서 로그인
///  - 비밀번호 정책: 영문+숫자 포함, 특수문자 없음, 8~64자
///  - 로그인 응답에 신규회원 플래그 없음 → 신규/기존은 프론트 흐름으로 판단
///  - 계정 잠금(SafeFam_BE #42): 로그인 실패 누적 시 계정 잠김. 잠긴 계정 로그인
///    → HTTP 403 ACCOUNT_LOCKED(메시지 "…잠금을 해제해 주세요"). 해제는
///    POST /auth/unlock { phoneNumber } — 휴대폰 인증(verify) 선행 필요.
///    ※ 에러 응답 바디에 코드가 없어 403+메시지('잠금')로 판별한다.
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
  /// 서버 주소. 기본값은 **EC2에 배포된 운영 서버**라 별도 주입 없이 실기기에서
  /// 바로 붙는다. 로컬 백엔드로 바꿔 붙일 때만 빌드시 주입한다.
  /// - 로컬(에뮬레이터): `--dart-define=SAFEFAM_API_BASE_URL=http://10.0.2.2:8080`
  ///   (에뮬레이터의 `localhost`는 에뮬레이터 자신이라, 호스트 PC는 `10.0.2.2`로 접근)
  /// - 로컬(실기기): 같은 네트워크의 PC IP를 같은 방식으로 주입.
  /// ★API는 **`api.` 서브도메인**이다. 루트 `safefam.site`는 관리자 웹(SafeFam_Web,
  ///   Vercel 배포)이 점유해서, 거기로 API를 부르면 308로 `www.`에 리다이렉트되고
  ///   SPA 문서가 돌아온다(2026-08-10 이전). 앱·웹 모두 `api.safefam.site`를 쓴다.
  /// ※ 도메인으로만 접근한다 — nginx가 443에서 받아 넘기고 인증서가 `api.safefam.site`
  ///   발급이라, IP를 직접 넣으면 8080 미개방·443 인증서 불일치로 실패한다.
  static const String baseUrl = String.fromEnvironment(
    'SAFEFAM_API_BASE_URL',
    defaultValue: 'https://api.safefam.site',
  );

  /// 메모리 캐시(요청 헤더 구성용). 원본은 [_storage]에 보안 저장되며,
  /// 앱 시작 시 [restoreSession]으로 복구한다.
  static String? accessToken;
  static String? refreshToken;

  /// 토큰 보안 저장소(Android Keystore 기반). 앱을 꺼도 유지된다.
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const String _kAccess = 'accessToken';
  static const String _kRefresh = 'refreshToken';

  static const Duration _timeout = Duration(seconds: 10);

  static Uri _uri(String path) => Uri.parse('$baseUrl$path');

  /// 토큰을 메모리 캐시 + 보안 저장소에 함께 기록한다.
  static Future<void> _saveTokens(String access, String refresh) async {
    accessToken = access;
    refreshToken = refresh;
    // 새 세션이 생겼으니 만료 통보를 다시 받을 수 있게 푼다.
    _sessionExpiredNotified = false;
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kRefresh, value: refresh);
  }

  /// 메모리·저장소의 토큰을 모두 폐기한다(로그아웃/탈퇴/세션 만료).
  static Future<void> _clearTokens() async {
    // 세대를 올려, 진행 중인 재발급이 폐기 후 뒤늦게 세션을 되살리지 못하게 한다.
    _sessionGeneration++;
    accessToken = null;
    refreshToken = null;
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    // 자동 탐지 기기 사본도 같이 끈다. 이 값은 계정별이 아니라 기기당 하나라,
    // 남겨두면 **다음에 로그인한 사람이 물려받는다** — 켠 적도 없는 사용자의
    // 문자가 그 사람 계정으로 분석 접수되는 셈이다(#122).
    //
    // 계정별 키로 나누는 대신 세션이 끝날 때 끄는 쪽을 골랐다. 백그라운드
    // 수신 처리는 사용자 id를 모르는 상태로 시작하고, 그걸 알아내려면 문자
    // 한 통마다 서버 왕복이 하나 더 붙는다 — 브로드캐스트에 주어진 시간
    // 안에서 감당할 수 없다. 끄는 쪽은 틀려도 분석을 안 하는 방향이라 안전하다.
    // 다음 로그인 사용자의 진짜 설정은 더보기 화면이 서버에서 받아 되살린다.
    await AppPrefs.setAutoAnalysisEnabled(false);
  }

  /// 저장소의 토큰을 메모리 캐시로 올리기만 한다(재발급 없음).
  ///
  /// 문자 자동 탐지의 백그라운드 isolate는 메인 isolate와 static을 공유하지 않아
  /// [accessToken]이 비어 있는 채로 시작한다. 그렇다고 [restoreSession]을 쓰면
  /// refreshToken이 **1회용(회전)**이라 메인 isolate가 들고 있는 토큰이 죽는다
  /// (SafeFam_BE #56 — 재사용을 탈취로 간주). 그래서 여기서는 읽기만 하고,
  /// 액세스 토큰이 이미 만료됐을 때만 [sendAuthorized]의 401 경로가 한 번
  /// 재발급하도록 맡긴다.
  ///
  /// 쓸 만한 세션이 없으면 false.
  static Future<bool> loadStoredTokens() async {
    try {
      accessToken = await _storage.read(key: _kAccess);
      refreshToken = await _storage.read(key: _kRefresh);
    } catch (_) {
      return false;
    }
    return (accessToken?.isNotEmpty ?? false) &&
        (refreshToken?.isNotEmpty ?? false);
  }

  static Map<String, String> _headers({bool auth = false}) {
    final h = {'Content-Type': 'application/json'};
    if (auth && accessToken != null) {
      h['Authorization'] = 'Bearer $accessToken';
    }
    return h;
  }

  /// 세션이 완전히 끊겼을 때(재발급 실패) 한 번 통보된다.
  /// 서비스 계층이 화면 전환을 알 필요는 없으므로, `main.dart`가 로그인 화면으로
  /// 보내도록 연결한다.
  static void Function()? onSessionExpired;

  /// 명시적 로그아웃 직전(토큰이 아직 유효할 때) 호출된다. `main.dart`가
  /// FCM 기기 해제(`DeviceApi.unregisterDevice`)로 연결해, 로그아웃 후에도
  /// 이전 계정으로 푸시가 가지 않게 한다. auth가 기기 계층에 역의존하지 않도록
  /// (onSessionExpired와 동일하게) 훅으로 둔다.
  static Future<void> Function()? onBeforeLogout;

  /// 진행 중인 재발급. refreshToken은 1회용(회전)이라 동시에 두 번 호출하면
  /// 백엔드가 재사용을 탈취로 간주해 세션을 끊는다(SafeFam_BE #56).
  /// 그래서 동시에 401을 받은 요청들이 하나의 재발급 결과를 공유하게 한다.
  static Future<bool>? _refreshing;

  /// 세션 만료 통보는 한 번만. 동시에 여러 요청이 실패해도 로그인 화면이
  /// 여러 번 밀려 올라가지 않게 한다. 재로그인(=토큰 저장) 시 풀린다.
  static bool _sessionExpiredNotified = false;

  /// 세션 세대. 토큰을 폐기할 때마다 올라간다. 재발급이 저장소에서 토큰을 읽은
  /// 뒤 http 대기 중에 로그아웃/탈퇴가 끼어들면, 재발급이 끝나도 세대가 달라져
  /// 새 토큰을 저장하지 않는다(로그아웃이 재발급에 되돌려지는 것을 막는다).
  static int _sessionGeneration = 0;

  /// 재발급을 single-flight으로 실행한다. 이미 진행 중이면 그 결과를 기다린다
  /// (그 경우 [timeout]은 먼저 시작한 쪽의 값을 따른다).
  static Future<bool> _refreshOnce({Duration? timeout}) => _refreshing ??=
      reissue(timeout: timeout).whenComplete(() => _refreshing = null);

  /// 보호된 요청 공통 경로.
  ///
  /// [request]는 헤더를 받아 요청을 보내는 함수여야 한다(재시도 때 **새 토큰이
  /// 담긴 헤더**로 다시 불리기 때문에, 헤더를 미리 만들어 넘기면 안 된다).
  ///
  /// 401이면 토큰을 재발급하고 같은 요청을 한 번만 재시도한다. 재발급이
  /// 실패하면 세션을 폐기하고 [onSessionExpired]로 알린 뒤, 호출부가 기존
  /// 실패 경로를 타도록 마지막 401 응답을 그대로 돌려준다.
  ///
  /// 한 번의 호출이 **최초 요청 + 재발급 + 재시도** 세 구간으로 늘어날 수 있다.
  /// 문자 수신 브로드캐스트처럼 시스템이 주는 시간이 짧은 경로는 자기 요청만
  /// 짧게 잡아선 부족하고, 가운데 재발급도 함께 줄여야 예산 안에 들어온다.
  /// 그래서 [reissueTimeout]으로 그 구간을 좁힐 수 있게 열어둔다.
  /// (`Future.timeout`은 진행 중인 요청을 취소하지 못한다 — 기다리기를 그만둘 뿐이라,
  ///  프로세스가 회수되기 전에 **다음 단계를 시작하지 않는 것**이 목적이다.)
  static Future<http.Response> sendAuthorized(
    Future<http.Response> Function(Map<String, String> headers) request, {
    Duration? reissueTimeout,
  }) async {
    final sentToken = accessToken;
    final res = await request(_headers(auth: true));
    if (res.statusCode != 401) return res;

    // 요청을 보낸 사이 다른 요청이 이미 토큰을 갱신했다면(회전) 재발급 없이
    // 새 토큰으로 바로 한 번 재시도한다. 불필요한 추가 회전을 피한다.
    if (accessToken != null && accessToken != sentToken) {
      return request(_headers(auth: true));
    }

    if (await _refreshOnce(timeout: reissueTimeout)) {
      return request(_headers(auth: true));
    }

    await _clearTokens();
    if (!_sessionExpiredNotified) {
      _sessionExpiredNotified = true;
      onSessionExpired?.call();
    }
    return res;
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

  /// 로그인 실패 응답이 '계정 잠금'(ACCOUNT_LOCKED)인지 판별.
  /// 백엔드 GlobalExceptionHandler가 바디에 에러코드를 싣지 않으므로,
  /// HTTP 403 + 메시지 텍스트('잠금')로 잠금 상태를 구분한다.
  static bool _isLocked(http.Response res) {
    if (res.statusCode != 403 || res.body.isEmpty) return false;
    try {
      final body = jsonDecode(res.body);
      final msg = body is Map<String, dynamic> ? body['message'] : null;
      return msg is String && msg.contains('잠금');
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

  /// 계정 잠금 해제. 로그인 실패 누적으로 잠긴 계정을 휴대폰 인증으로 해제한다.
  /// 비밀번호 재설정과 동일하게, 호출 전 반드시 verifyCode로 서버측 인증(verified)
  /// 상태를 만들어야 한다(백엔드가 consumeVerified로 검증·소비). code는 바디에 없음.
  /// 백엔드 계약: POST /api/v1/auth/unlock { phoneNumber }.
  static Future<bool> unlock(String phone) async {
    final res = await http
        .post(_uri('/api/v1/auth/unlock'),
            headers: _headers(), body: jsonEncode({'phoneNumber': phone}))
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
      // 계정 잠금(ACCOUNT_LOCKED)은 휴대폰 인증으로 해제할 수 있으므로 구분한다.
      // 백엔드가 바디에 에러코드를 싣지 않으므로 403 + 메시지로 판별.
      return AuthResult(success: false, locked: _isLocked(res));
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
    await _saveTokens(nextAccessToken, nextRefreshToken);
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
        await _saveTokens(
            tokenData['accessToken'] as String, tokenData['refreshToken'] as String);
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
      await _saveTokens(
          data['accessToken'] as String, data['refreshToken'] as String);
      return const AuthResult(success: true);
    } catch (e) {
      return const AuthResult(success: false);
    }
  }

  /// 내 정보 조회(마이페이지). GET /api/v1/users/me (Bearer).
  /// 실패 시 예외를 던져 화면(FutureBuilder)이 에러 상태를 보이게 한다.
  static Future<UserProfile> myProfile() async {
    final res = await sendAuthorized((headers) =>
        http.get(_uri('/api/v1/users/me'), headers: headers).timeout(_timeout));
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
    final res = await sendAuthorized((headers) => http
        .patch(_uri('/api/v1/users/me'),
            headers: headers, body: jsonEncode({'name': name}))
        .timeout(_timeout));
    if (!_isSuccess(res) || res.body.isEmpty) return null;
    final data = jsonDecode(res.body)['data'];
    if (data is! Map<String, dynamic>) return null;
    return UserProfile.fromJson(data);
  }

  /// 회원 탈퇴. DELETE /api/v1/users/me { password } → 204 (soft delete).
  /// 본인 확인용 비밀번호 재입력 필요. 비번이 틀리면 실패(false).
  /// 성공 시 로컬 토큰을 폐기해 로그아웃 상태로 만든다.
  static Future<bool> withdraw(String password) async {
    final res = await sendAuthorized((headers) => http
        .delete(_uri('/api/v1/users/me'),
            headers: headers, body: jsonEncode({'password': password}))
        .timeout(_timeout));
    final ok = res.statusCode == 204 || _isSuccess(res);
    if (ok) {
      await _clearTokens();
    }
    return ok;
  }

  /// 탐지·알림 설정 조회. GET /api/v1/users/me/settings (Bearer).
  /// 실패 시 예외를 던져 화면이 에러 상태를 보이게 한다.
  static Future<UserSettings> getSettings() async {
    final res = await sendAuthorized((headers) => http
        .get(_uri('/api/v1/users/me/settings'), headers: headers)
        .timeout(_timeout));
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
      final res = await sendAuthorized((headers) => http
          .patch(_uri('/api/v1/users/me/settings'),
              headers: headers, body: jsonEncode(body))
          .timeout(_timeout));
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
    // 토큰이 아직 유효할 때 FCM 기기부터 해제한다(이후 이전 계정 푸시 차단).
    try {
      await onBeforeLogout?.call();
    } catch (_) {
      // 기기 해제 실패해도 로그아웃은 계속 진행한다.
    }
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
    await _clearTokens();
  }

  /// 토큰 재발급. 저장된 refreshToken으로 POST /api/v1/auth/reissue 호출.
  /// 백엔드는 TokenResponse(accessToken·refreshToken 모두 새로 발급, 리프레시 회전)를
  /// 반환한다. 성공 시 새 토큰을 저장하고 true, 실패 시 false.
  ///
  /// [timeout]은 시간 예산이 짧은 경로(문자 수신 처리)에서 줄여 쓴다.
  static Future<bool> reissue({Duration? timeout}) async {
    // 이 재발급이 시작된 시점의 세션 세대. 진행 중 로그아웃/탈퇴로 토큰이
    // 폐기되면 세대가 바뀌어, 완료돼도 새 세션을 저장하지 않는다.
    final generation = _sessionGeneration;
    // **저장소를 먼저 읽는다.** 메모리 캐시는 이 isolate 것이라, 문자 자동 탐지의
    // 백그라운드 isolate가 토큰을 회전시켜도 메인 isolate에는 옛 값이 남는다.
    // 그 옛 값을 보내면 백엔드가 재사용을 탈취로 보고 세션을 끊는다
    // (SafeFam_BE #56) — 문자 한 통 받았다고 로그아웃되는 셈이다.
    // 저장소는 항상 메모리와 같거나 더 새것이므로(_saveTokens가 둘 다 쓴다)
    // 저장소 우선이 손해 볼 일은 없다. 못 읽을 때만 메모리로 되돌아간다.
    String? stored;
    try {
      stored = await _storage.read(key: _kRefresh);
    } catch (_) {
      stored = null;
    }
    stored ??= refreshToken;
    if (stored == null || stored.isEmpty) return false;
    try {
      final res = await http
          .post(_uri('/api/v1/auth/reissue'),
              headers: _headers(), body: jsonEncode({'refreshToken': stored}))
          .timeout(timeout ?? _timeout);
      if (!_isSuccess(res) || res.body.isEmpty) return false;
      final data = jsonDecode(res.body)['data'];
      if (data is! Map<String, dynamic>) return false;
      // 계약상 reissue는 accessToken·refreshToken을 모두 새로 회전 발급한다.
      // 둘 중 하나라도 없으면 실패로 처리한다(옛 토큰으로 복구 불가능한 세션 방지).
      final nextAccess = data['accessToken'];
      final nextRefresh = data['refreshToken'];
      if (nextAccess is! String ||
          nextAccess.isEmpty ||
          nextRefresh is! String ||
          nextRefresh.isEmpty) {
        return false;
      }
      // 재발급이 끝나기 전에 세션이 폐기됐다면(로그아웃/탈퇴) 되살리지 않는다.
      if (generation != _sessionGeneration) return false;
      await _saveTokens(nextAccess, nextRefresh);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 세션 복구. 앱 시작 시 저장된 refreshToken을 reissue로 검증·갱신한다.
  /// 성공하면 토큰이 메모리·저장소에 최신화되어 true, 실패하면 남은 토큰을
  /// 폐기하고 false(→ 로그인 화면으로).
  static Future<bool> restoreSession() async {
    final ok = await reissue();
    if (!ok) await _clearTokens();
    return ok;
  }
}

class AuthResult {
  final bool success;
  final bool isNewUser; // 신규면 가족 등록으로, 기존이면 홈으로
  final bool locked; // 계정 잠김(ACCOUNT_LOCKED) → 휴대폰 인증으로 해제 안내
  final String? message;
  final String? kakaoId;
  final String? kakaoAccessToken;
  const AuthResult({
    required this.success,
    this.isNewUser = false,
    this.locked = false,
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
