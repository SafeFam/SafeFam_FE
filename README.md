# 세이프팸 (SafeFam) — Flutter UI 스캐폴드

온 가족 금융사기 지킴이 앱. 피그마 최종 시안을 Flutter로 옮긴 앱 (Pixel 7 / Flutter 3.44 기준). **인증·마이페이지·문자 분석(수동 검사)까지 백엔드와 http 연동 완료**. 자동 탐지 권한·오버레이·FCM은 미연결(FCM은 타 멤버 담당).

## 흐름
(스플래시 → 온보딩) → **로그인**(휴대폰 번호 + 비밀번호 · 카카오 · 구글) → 신규는 **회원가입**(휴대폰 인증 요청→확인 → 닉네임 + 비밀번호) → **가족 등록**(보호자/피보호자) → 보호자는 초대 코드 발급 → 연결 후 이름 설정 / 피보호자는 코드 입력 → 메인.
> 진입점은 현재 `LoginScreen`. 로그인 화면의 '비밀번호를 잊으셨나요?' → **비밀번호 재설정**(휴대폰 인증 → 새 비밀번호). **카카오로 계속하기** → 카카오 로그인, 신규회원이면 **카카오 온보딩**(휴대폰 인증 → 이름)으로 가입 후 가족 등록. 스플래시·온보딩은 아직 앞단에 연결 전(별도 작업 예정).
> 카카오 로그인은 빌드 시 앱 키 주입 필요: `flutter run --dart-define=KAKAO_NATIVE_APP_KEY=<네이티브 앱 키>` (AndroidManifest의 리다이렉트 스킴 값과 동일해야 함).

메인 하단 탭 **홈 · 이력 · 가족 · 검사** (설정=더보기는 홈 우상단 톱니바퀴로 진입).
검사 탭 → 입력한 문자를 실제 분석 API(`POST /api/v1/analyses`, source=MANUAL)로 검사 → 결과(**3중 스코어 게이지 + breakdown**). 결과 → 대응 챗봇 시트 → 신고 시트 / 전화 / 공유.
보이스피싱·URL 결과·긴급 오버레이는 더보기 > 화면 미리보기(개발용)에서 확인.

## 실행 (Android Studio)
1. `flutter create safefam` (경로 공백·한글·OneDrive 금지)
2. 배포 `lib/`·`pubspec.yaml`·`assets/` 덮어쓰기
3. 폴더에서 `flutter create .` → `flutter pub get`
4. Pixel 7 에뮬레이터 → Run
> 폰트: 기본 시스템 폰트로 동작. Pretendard는 `assets/fonts/`에 넣고 pubspec 주석 해제.

## 서버 연동
- **baseUrl**: 기본값 `http://10.0.2.2:8080` (Android 에뮬레이터에서 호스트 PC의 localhost). 실기기/배포는 빌드 시 주입:
  `flutter run --dart-define=SAFEFAM_API_BASE_URL=https://<도메인>`
- 인증 계약: 공통 응답 `ApiResponse{status,message,data}`, 토큰은 바디(`TokenResponse`). 인증이 필요한(보호된) API 요청에만 `Authorization: Bearer <accessToken>`을 붙임 — 가입·로그인처럼 토큰 없는 요청엔 미적용.
- 문자 분석: `POST /api/v1/analyses`(생성)·`GET`(이력, page·필터)·`GET|DELETE /{id}`·`POST /{id}/feedback`. 응답은 `AnalysisResponse{riskScore, riskLevel(HIGH/MEDIUM/LOW), category, scoreBreakdown{llmScore,urlScore,patternScore}, indicators, urls, recommendedActions}`. 통계는 `GET /api/v1/statistics/overview?period=`. (전부 보호된 API)
- 개발용 http 평문 통신은 **디버그 빌드에만** 허용(`android/app/src/debug` network security config). 릴리스는 https 강제.

## 구조
```
lib/
  main.dart / theme/app_theme.dart / models.dart(위험도)
  widgets/ (common · score_gauge · main_scaffold[홈·이력·가족·검사])
  screens/
    auth.dart          스플래시
    onboarding.dart    온보딩·권한
    login_screen.dart  로그인(휴대폰+비밀번호 · 회원가입 · 비밀번호 재설정 · 카카오 · 구글)
    signup_screen.dart 회원가입(휴대폰 인증 → 닉네임+비밀번호)
    reset_password_screen.dart 비밀번호 재설정(휴대폰 인증 → 새 비밀번호)
    kakao_onboarding_screen.dart 카카오 신규회원 온보딩(카카오 로그인 → 휴대폰 인증+이름)
    mypage_screen.dart 마이페이지(내 정보 조회·이름 수정·로그아웃·회원 탈퇴)
    family_flow.dart   가족 등록 · 초대코드 · 연결 · 이름 설정
    home_screen.dart   홈(톱니→설정)
    check_screen.dart  검사 탭(수동 분석 → analyses API 호출)
    results.dart       결과(3중 스코어 게이지)·보이스피싱·URL
    overlay_alert.dart 강제 오버레이 경고
    history_screen.dart / family_screen.dart / more_screen.dart(설정)
  services/
    auth_api.dart      인증 API — 가입·로그인·로그아웃 + 마이페이지 users/me·설정 users/me/settings
    analysis_api.dart  문자 분석 API — 분석·이력·상세·삭제·피드백·통계(analyses·statistics)
  sheets.dart          챗봇·신고·공유
assets/character.png
```

## 다음 (기능 연결)
- ✅ 인증 API(가입·로그인·로그아웃) http 연동 완료 — 로그인 E2E 검증됨
- ✅ 카카오 소셜 로그인 연동 완료 (`/auth/kakao`·`/auth/kakao/signup`) — 신규회원은 카카오 온보딩으로
- ✅ 비밀번호 재설정 백엔드 구현됨 — `POST /auth/password/reset` {phoneNumber, newPassword} (OTP는 서버측 인증 상태를 consume해 검증)
- ✅ 마이페이지 `users/me` 연동 완료 — `GET`(조회)·`PATCH`(이름 수정)·`DELETE`(회원 탈퇴, 비밀번호 재확인)
- ✅ 탐지·알림 설정 `users/me/settings` 연동 완료 — `GET`·`PATCH`(`autoAnalysisEnabled`·`pushEnabled` 토글, 전달한 필드만 부분 수정)
- ✅ 문자 분석 API 연동 완료 — 검사 탭 수동 분석 → `analyses` 호출 → 결과 화면 **3중 스코어 게이지**(`AnalysisResult`) 바인딩 (`analysis_api.dart`)
- 이력 화면(`history_screen`)에 `getHistory()`·통계 그래프에 `getStatistics()` 바인딩 (백엔드 준비 완료 — 다음 작업)
- 회원가입/재설정 인증문자는 실제 SMS(Solapi) 발송이라 서버 SMS 설정 + 실제 수신 가능한 번호 필요
- 전화(`url_launcher`)·공유(`share_plus`)
- 자동 탐지 권한·오버레이 실제 구현(검증 후) · FCM(타 멤버 담당) · 상태관리(Provider/Riverpod)
- 연결 예외(잘못된 코드·만료)는 시안엔 있으나 코드 미반영 → 추가 예정
