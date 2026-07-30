# 세이프팸 (SafeFam) — Flutter UI 스캐폴드

온 가족 금융사기 지킴이 앱. 피그마 최종 시안을 Flutter로 옮긴 앱 (Pixel 7 / Flutter 3.44 기준). **인증·마이페이지·문자 분석(수동 검사)·가족 보호(초대코드+QR 연결)·신고·신뢰 발신자(화이트리스트)까지 백엔드와 http 연동 완료**. 분석 요청은 **전송 전 개인정보 1차 마스킹**을 거치며, FCM은 **기기 등록/해제까지 연동**(알림 수신 처리는 타 멤버 담당). 자동 탐지 권한·오버레이는 미연결이며, 가족 QR은 코드 연동 완료·실기기 카메라 검증만 남음.

## 흐름
(스플래시 → 온보딩) → **로그인**(휴대폰 번호 + 비밀번호 · 카카오 · 구글) → 신규는 **회원가입**(휴대폰 인증 요청→확인 → 닉네임 + 비밀번호) → **가족 등록**(보호자/피보호자) → 보호자는 초대 코드 발급 → 연결 후 이름 설정 / 피보호자는 코드 입력 → 메인.
> 진입점은 현재 `LoginScreen`. 로그인 화면의 '비밀번호를 잊으셨나요?' → **비밀번호 재설정**(휴대폰 인증 → 새 비밀번호). 로그인 실패 누적으로 **계정이 잠기면** 안내 후 **계정 잠금 해제**(휴대폰 인증 → `POST /auth/unlock`)로 풀 수 있음. **카카오로 계속하기** → 카카오 로그인, 신규회원이면 **카카오 온보딩**(휴대폰 인증 → 이름)으로 가입 후 가족 등록. 스플래시·온보딩은 아직 앞단에 연결 전(별도 작업 예정).
> 카카오 로그인은 빌드 시 앱 키 주입 필요: `flutter run --dart-define=KAKAO_NATIVE_APP_KEY=<네이티브 앱 키>` (AndroidManifest의 리다이렉트 스킴 값과 동일해야 함).

메인 하단 탭 **홈 · 이력 · 가족 · 검사** (설정=더보기는 홈 우상단 톱니바퀴로 진입).
검사 탭 → 입력한 문자를 **계좌·카드·주민·전화번호 등 개인정보를 `[REDACTED]`로 1차 마스킹**한 뒤 분석 API(`POST /api/v1/analyses`, source=MANUAL)로 접수 → 결과(**3중 스코어 게이지 + breakdown**). 분석은 **비동기**라 접수(202) 후 상세를 **종료 상태까지 폴링**하며 "분석 중"을 보여주고, 완료/부분 성공/실패에 따라 화면을 다르게 렌더한다(실패는 '안전'이 아니라 별도 안내). 요청 한도(분당) 초과 시 429 안내를 구분해 노출. 결과 → 대응 챗봇 시트 → 신고 시트 / 전화 / 공유.
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
- 문자 분석(**비동기**): `POST /api/v1/analyses`(접수 → **202 `{analysisId, status}`**, 완성 결과 아님)·`GET`(이력, page·필터)·`GET /{id}`(상세, **종료 상태까지 폴링**)·`DELETE /{id}`·`POST /{id}/feedback`. `status`=`PENDING·PROCESSING·COMPLETED·PARTIAL_SUCCESS·FAILED`. 응답 `AnalysisResponse{status, riskScore?, riskLevel?(HIGH/MEDIUM/LOW), category?, failureCode?, scoreBreakdown{llmScore,urlScore,patternScore}, indicators, urls, recommendedActions, analyzedAt?}` — **처리 전·실패엔 점수·등급이 null**(완료/부분 성공에서만 신뢰). 통계는 `GET /api/v1/statistics/overview?period=`. (전부 보호된 API)
  - **전송 전 마스킹**(`util/masking.dart`): 개인정보보호법상 원문을 그대로 보내지 않도록 `content`의 계좌·카드·주민·전화번호를 `[REDACTED]`로 가림(URL은 링크 분석 위해 보존). 발신번호는 화이트리스트 필터가 쓰므로 마스킹 안 함.
  - **레이트리밋**: `POST /analyses`는 유저 기준 분당 제한이 있어 초과 시 429가 오며, 프론트는 일반 실패와 구분해 서버 안내 문구를 노출.
  - **신고**: `POST /api/v1/analyses/{id}/report {type:PHISHING|SPAM|OTHER}` — 저장된 분석을 익명 접수(원문·발신번호·userId 제외, 최초 201·재신고 200 멱등). 결과 화면 → 대응 도우미 → 신고.
- 가족 보호: `POST /api/v1/family/invite`(초대코드/QR 토큰 발급)·`POST /link/code`(코드로 연결)·`POST /link/qr`(QR로 연결)·`GET /members`·`DELETE /{linkId}`. 별명은 백엔드에 필드가 없어 기기 로컬(AppPrefs)에 저장. QR은 보호자 화면이 `qrToken`을 QR로 표시(`qr_flutter`)하고 피보호자가 스캔(`mobile_scanner`)해 연결 — 실기기 카메라 검증은 후속. (전부 보호된 API)
- 신뢰 발신자(화이트리스트): `POST /api/v1/whitelists`·`GET`·`DELETE /{id}`. 등록한 발신자는 자동 탐지 시 분석 프리패스. 더보기 > 탐지·알림에서 관리. (프리패스 확인 `/check`는 자동 탐지 흐름 담당)
- FCM 기기: 로그인/자동로그인 시 `POST /api/v1/devices`로 등록(응답 `deviceId` 보관), **로그아웃 시 `DELETE /api/v1/devices/{deviceId}`로 해제**해 이전 계정 푸시를 끊음. 알림 수신·표시 로직은 타 멤버 담당.
- 인증 만료 대응: 보호된 요청이 401이면 `refreshToken`으로 **자동 재발급 후 1회 재시도**(single-flight, 회전 토큰). 재발급까지 실패하면 세션을 폐기하고 로그인 화면으로 되돌림.
- 개발용 http 평문 통신은 **디버그 빌드에만** 허용(`android/app/src/debug` network security config). 릴리스는 https 강제.

## 구조
```text
lib/
  main.dart / theme/app_theme.dart / models.dart(위험도)
  widgets/ (common · score_gauge · main_scaffold[홈·이력·가족·검사])
  screens/
    auth.dart          스플래시
    onboarding.dart    온보딩·권한
    login_screen.dart  로그인(휴대폰+비밀번호 · 회원가입 · 비밀번호 재설정 · 카카오 · 구글)
    signup_screen.dart 회원가입(휴대폰 인증 → 닉네임+비밀번호)
    reset_password_screen.dart 비밀번호 재설정(휴대폰 인증 → 새 비밀번호)
    unlock_account_screen.dart 계정 잠금 해제(휴대폰 인증 → auth/unlock)
    kakao_onboarding_screen.dart 카카오 신규회원 온보딩(카카오 로그인 → 휴대폰 인증+이름)
    mypage_screen.dart 마이페이지(내 정보 조회·이름 수정·로그아웃·회원 탈퇴)
    family_flow.dart   가족 등록 · 초대코드 · QR 표시 · 연결 · 이름 설정
    qr_scan_screen.dart 가족 QR 스캔(mobile_scanner) → qrToken 반환
    whitelist_screen.dart 신뢰 발신자 관리(목록·추가·삭제)
    home_screen.dart   홈(월간 트렌드 카드·톱니→설정)
    ward_logs_screen.dart 가족 원격 모니터링(피보호자 탐지 이력, 읽기 전용)
    check_screen.dart  검사 탭(수동 분석 → 마스킹 → analyses API 호출)
    results.dart       결과(3중 스코어 게이지)·보이스피싱·URL + AnalysisDetailScreen(이력 상세·삭제·피드백)
    overlay_alert.dart 강제 오버레이 경고
    history_screen.dart 이력(목록·통계·유형 필터·상세 이동)
    family_screen.dart 가족 목록(getMembers·연결 해제·별명) / more_screen.dart(설정)
  services/
    auth_api.dart      인증 API — 가입·로그인·로그아웃·잠금해제 + 마이페이지 users/me·설정 users/me/settings (401 자동 재발급)
    analysis_api.dart  문자 분석 API — 분석·이력·상세·삭제·피드백·통계·신고(analyses·statistics)
    family_api.dart    가족 보호 API — 초대·코드/QR 연결·목록·해제(family)
    whitelist_api.dart 신뢰 발신자 API — 목록·등록·삭제(whitelists)
    device_api.dart    FCM 기기 등록/해제(devices)
    app_prefs.dart     기기 로컬 저장(온보딩·가족 별명·deviceId·접근성, flutter_secure_storage)
    app_settings.dart  접근성 전역 설정(큰 글씨·음성, ValueNotifier)
    tts_service.dart   음성 안내(flutter_tts, 한국어·재생/멈춤)
    notification_service.dart FCM 수신·알림 라우팅(포그라운드/백그라운드/콜드스타트)
  util/launchers.dart  전화(tel)·링크 딥링크 헬퍼(url_launcher)
  util/masking.dart    전송 전 개인정보 1차 마스킹(계좌·카드·주민·전화 → [REDACTED])
  sheets.dart          챗봇·신고(analyses/report)·공유
assets/character.png
test/util/masking_test.dart         마스킹 회귀 테스트
test/services/analysis_status_test.dart  분석 상태 파싱 회귀 테스트(처리 전·실패 null 처리)
```

## 다음 (기능 연결)
- ✅ 인증 API(가입·로그인·로그아웃) http 연동 완료 — 로그인 E2E 검증됨
- ✅ 카카오 소셜 로그인 연동 완료 (`/auth/kakao`·`/auth/kakao/signup`) — 신규회원은 카카오 온보딩으로
- ✅ 비밀번호 재설정 백엔드 구현됨 — `POST /auth/password/reset` {phoneNumber, newPassword} (OTP는 서버측 인증 상태를 consume해 검증)
- ✅ 마이페이지 `users/me` 연동 완료 — `GET`(조회)·`PATCH`(이름 수정)·`DELETE`(회원 탈퇴, 비밀번호 재확인)
- ✅ 탐지·알림 설정 `users/me/settings` 연동 완료 — `GET`·`PATCH`(`autoAnalysisEnabled`·`pushEnabled` 토글, 전달한 필드만 부분 수정)
- ✅ 문자 분석 API 연동 완료 — 검사 탭 수동 분석 → `analyses` 호출 → 결과 화면 **3중 스코어 게이지**(`AnalysisResult`) 바인딩 (`analysis_api.dart`)
- ✅ 이력 화면(`history_screen`) `getHistory()` 바인딩 완료 — 로딩·빈·에러·당겨서 새로고침 (PR #40)
- ✅ 이력 상세·삭제·피드백 완료 — 항목 탭 → `AnalysisDetailScreen`(`getAnalysis`) → 결과 화면 재사용, 삭제·정탐/오탐/미탐 피드백 (PR #42)
- ✅ 탐지 통계 + 이력 필터 완료 — `getStatistics(period)` 기간별 총계·위험등급/유형 분포, `PhishingCategory` 필터 칩 (PR #44)
- ✅ 전화·링크 딥링크 완료 — `url_launcher`로 `tel:`/외부 링크, 결과 화면 `recommendedActions`·긴급 연락처 버튼 연결 (PR #46)
- ✅ 계정 잠금 해제 연동 완료 — 로그인 시 `ACCOUNT_LOCKED`(403) 감지 → 휴대폰 인증 후 `POST /auth/unlock` (PR #48)
- ✅ 401 토큰 자동 재발급 완료 — 보호 API 공통 경로에서 401→재발급→1회 재시도(single-flight), 실패 시 세션 폐기·로그인 이동 (PR #57)
- ✅ 가족 보호(초대코드) 연동 완료 — 초대 발급·코드 연결·목록·해제, 별명 로컬 저장 (`family_api.dart`, PR #59)
- ✅ 전송 전 개인정보 1차 마스킹 완료 — `util/masking.dart`(계좌·카드·주민·전화 → `[REDACTED]`, URL 보존) (PR #61)
- ✅ 분석 요청 한도(429) 안내 구분 완료 — 서버 안내 문구를 일반 실패와 구분해 노출 (PR #63)
- ✅ 로그아웃 시 FCM 기기 해제 완료 — 등록 `deviceId` 보관 → 로그아웃 시 `DELETE /devices/{id}` (PR #65)
- ✅ 탐지 이력 익명 신고 연동 완료 — `POST /analyses/{id}/report`(PHISHING/SPAM/OTHER), 결과 화면 → 대응 도우미 → 신고 (PR #67)
- ✅ 가족 QR 연결 완료 — 보호자 QR 표시(`qr_flutter`) + 피보호자 스캔(`mobile_scanner`) → `/family/link/qr` (PR #69, ⚠️ 실기기 카메라 검증 후속)
- ✅ 신뢰 발신자(화이트리스트) 관리 완료 — 목록·등록·삭제 UI + 더보기 진입점 (`whitelist_api.dart`, PR #71)
- ✅ 문자 분석 비동기(폴링) 전환 완료 — `POST` 202 접수 → `AnalysisDetailScreen`이 종료 상태까지 폴링(2초·최대 30s·dispose 취소), 결과 화면 status 분기(완료/부분 성공 배너/실패 화면), 이력 목록 status 칩. **처리 전·실패를 '위험/안전'으로 오표시하던 문제 해소**(riskScore·riskLevel nullable화) (이슈 #72)
- ✅ 월간 피싱 트렌드 카드 연동 완료 — 홈 '요즘 많은 사기 수법'을 `GET /statistics/trends` 실데이터로(유형 순위+위험 키워드), 목업 제거 (이슈 #74)
- ✅ 가족 원격 모니터링 완료 — 보호자가 피보호자 탐지 이력 조회(`GET /family/ward/{id}/logs`), 가족 멤버 탭 → 읽기 전용 이력(`ward_logs_screen`) (이슈 #75)
- ✅ 고령층 접근성 실동작 완료 — '글씨 더 크게'(앱 전체 `MediaQuery.textScaler`)·'음성으로 읽어주기'/'다시 들려주기'(TTS, `flutter_tts`) 실제 동작, `AppSettings`로 기기 저장 (이슈 #78)
- ✅ 분석 결과 공유 — `share_plus`로 결과 요약 공유(원문·개인정보 제외), 결과 화면 공유 시트
- 회원가입/재설정/잠금해제 인증문자는 실제 SMS(Solapi) 발송이라 서버 SMS 설정 + 실제 수신 가능한 번호 필요

### 남은 작업
- **백엔드 준비됨 · 미연동** — 없음. 백엔드 구현분 중 프론트가 붙일 실사용 엔드포인트는 전부 소진(컨트롤러 8개 전수 대조 기준).
- **온디바이스/실기기 필요** — 자동 탐지(문자 수신 리스너)·긴급 오버레이 실제 구현 · 가족 QR 실기기 카메라 검증 · TTS 실제 음성 출력 검증
- **프론트 코드 품질(무백엔드)** — 상태 칩·이력 타일 공용 위젯 추출(history↔ward_logs 중복) · 상태관리(Provider/Riverpod) · 테스트 확대
- **타 멤버/백엔드 미존재** — FCM 알림 수신 로직(타 멤버 담당) · URL 검사 전용 백엔드·AI 대응 챗봇(FastAPI)은 아직 없어 해당 화면은 UI 목업 유지

## Firebase 설정 (FCM)
FCM 관련 파일은 보안상 `.gitignore`로 관리합니다. 로컬에서 직접 생성이 필요합니다.

1. [Firebase 콘솔](https://console.firebase.google.com)에서 SafeFam 프로젝트 접속
2. 프로젝트 설정 → Android 앱 → `google-services.json` 다운로드 → `android/app/` 에 추가
3. FlutterFire CLI 설치 및 설정:
```bash
   dart pub global activate flutterfire_cli
   flutterfire configure --project=safefam-55bff
```
4. `lib/firebase_options.dart` 자동 생성 확인