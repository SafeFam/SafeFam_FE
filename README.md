# 세이프팸 (SafeFam) — Flutter UI 스캐폴드

온 가족 금융사기 지킴이 앱. 피그마 최종 시안을 Flutter로 옮긴 UI 껍데기 (Pixel 7 / Flutter 3.44 기준). 백엔드·API·권한은 미연결.

## 흐름
(스플래시 → 온보딩) → **로그인**(휴대폰 번호 + 비밀번호 · 카카오 · 구글) → 신규는 **회원가입**(휴대폰 인증 요청→확인 → 닉네임 + 비밀번호) → **가족 등록**(보호자/피보호자) → 보호자는 초대 코드 발급 → 연결 후 이름 설정 / 피보호자는 코드 입력 → 메인.
> 진입점은 현재 `LoginScreen`. 스플래시·온보딩은 아직 앞단에 연결 전(별도 작업 예정).

메인 하단 탭 **홈 · 이력 · 가족 · 검사** (설정=더보기는 홈 우상단 톱니바퀴로 진입).
검사 탭 → 결과(NB 신호 기반). 결과 → 대응 챗봇 시트 → 신고 시트 / 전화 / 공유.
보이스피싱·URL 결과·긴급 오버레이는 더보기 > 화면 미리보기(개발용)에서 확인.

## 실행 (Android Studio)
1. `flutter create safefam` (경로 공백·한글·OneDrive 금지)
2. 배포 `lib/`·`pubspec.yaml`·`assets/` 덮어쓰기
3. 폴더에서 `flutter create .` → `flutter pub get`
4. Pixel 7 에뮬레이터 → Run
> 폰트: 기본 시스템 폰트로 동작. Pretendard는 `assets/fonts/`에 넣고 pubspec 주석 해제.

## 구조
```
lib/
  main.dart / theme/app_theme.dart / models.dart(위험도·탐지신호)
  widgets/ (common · score_gauge · main_scaffold[홈·이력·가족·검사])
  screens/
    auth.dart          스플래시
    onboarding.dart    온보딩·권한
    login_screen.dart  로그인(휴대폰+비밀번호 · 회원가입 버튼 · 카카오 · 구글)
    signup_screen.dart 회원가입(휴대폰 인증 → 닉네임+비밀번호)
    mypage_screen.dart 마이페이지(내 정보·로그아웃)
    family_flow.dart   가족 등록 · 초대코드 · 연결 · 이름 설정
    home_screen.dart   홈(톱니→설정)
    check_screen.dart  검사 탭(수동 분석)
    results.dart       결과(NB 신호)·보이스피싱·URL
    overlay_alert.dart 강제 오버레이 경고
    history_screen.dart / family_screen.dart / more_screen.dart(설정)
  services/auth_api.dart  인증 API 껍데기(login/signup/verify 분리)
  sheets.dart          챗봇·신고·공유
assets/character.png
```

## 다음 (기능 연결)
- 결과를 NB 응답(핸드오프 v2 4-1: score·signals·maskedContent)에 바인딩
- 전화(`url_launcher`)·공유(`share_plus`)
- 권한·오버레이 실제 구현(검증 후) · FCM · 상태관리(Provider/Riverpod)
- 연결 예외(잘못된 코드·만료)는 시안엔 있으나 코드 미반영 → 추가 예정
