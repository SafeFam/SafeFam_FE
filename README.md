# 세이프팸 (SafeFam) — Flutter UI 스캐폴드

온 가족 금융사기 지킴이 앱. 피그마 최종 시안을 Flutter로 옮긴 앱 (Pixel 7 / Flutter 3.44 기준). **인증·마이페이지·문자 분석(수동 검사, 비동기 폴링)·가족 보호(초대코드+QR 연결)·가족 공동 대응(HIGH 알림 → 전화·안전 확인·이미 송금)·신고·신뢰 발신자(화이트리스트)까지 백엔드와 http 연동 완료**. 문자 분석 결과는 **3중 스코어 게이지 + 위험 근거 카드**로 렌더하며, 외부 AI 일부 장애 시 **부분성공 안전모드**(어떤 분석이 빠졌는지 안내 + 보수적 대응 안내)로 표시한다. 개인정보 마스킹은 **서버에서 처리**(프론트 클라이언트 마스킹 제거, #80)하며, FCM은 **기기 등록/해제까지 연동**(알림 수신 처리는 타 멤버 담당). 가족 QR은 **실기기 카메라 스캔까지 검증 완료**(2026-08-25).
문자 검사는 두 경로다 — 사용자가 직접 넣는 **수동 분석**(검사 탭)과, 받은 문자를 감지해 자동으로 접수하는 **자동 탐지**(더보기 > 탐지·알림에서 켜고 끔, #118).
> **범위 제외(2026-08-10)**: 강제 오버레이 경고(다른 앱 위에 표시)는 팀 착수 합의가 없어 계획에서 제외했다.

## 흐름
(스플래시 → 온보딩) → **로그인**(휴대폰 번호 + 비밀번호 · 카카오) → 신규는 **회원가입**(휴대폰 인증 요청→확인 → 닉네임 + 비밀번호) → **가족 등록**(보호자/피보호자) → 보호자는 초대 코드 발급 → 연결 후 이름 설정 / 피보호자는 코드 입력 → 메인.
> 진입점은 `main.dart`의 `_Bootstrap` — 저장된 세션과 온보딩 이력을 보고 **스플래시(판정 중) → 온보딩(최초 실행) / 로그인(미로그인) / 메인(세션 복원)**으로 분기한다. 로그인 화면의 '비밀번호를 잊으셨나요?' → **비밀번호 재설정**(휴대폰 인증 → 새 비밀번호). 로그인 실패 누적으로 **계정이 잠기면** 안내 후 **계정 잠금 해제**(휴대폰 인증 → `POST /auth/unlock`)로 풀 수 있음. **카카오로 계속하기** → 카카오 로그인, 신규회원이면 **카카오 온보딩**(휴대폰 인증 → 이름)으로 가입 후 가족 등록.
> 구글 로그인은 **버튼을 내렸다** — 백엔드 엔드포인트가 없어 누르면 반드시 실패했다(#119). `AuthApi.socialLogin`의 `'google'` 분기는 서버가 생길 때를 위해 남겨뒀다.
> 카카오 앱 키는 소스에 있어 그냥 `flutter run`으로 동작한다. 키를 바꿀 땐 `lib/main.dart`의 `nativeAppKey`와 `AndroidManifest.xml`의 `com.kakao.sdk.AppKey`·리다이렉트 스킴(`kakao<앱키>://oauth`)을 **함께** 고쳐야 한다(한쪽만 바꾸면 로그인 콜백이 안 돌아온다).

메인 하단 탭 **홈 · 이력 · 가족 · 검사** (설정=더보기는 홈 우상단 톱니바퀴로 진입).
검사 탭 → 입력한 문자를 분석 API(`POST /api/v1/analyses`, source=MANUAL)로 접수(개인정보 마스킹은 서버가 처리) → 결과(**3중 스코어 게이지 + breakdown**). 분석은 **비동기**라 접수(202) 후 상세를 **종료 상태까지 폴링**하며 "분석 중"을 보여주고, 완료/부분 성공/실패에 따라 화면을 다르게 렌더한다(실패는 '안전'이 아니라 별도 안내). 요청 한도(분당) 초과 시 429 안내를 구분해 노출. 결과 → 대응 챗봇 시트 → 신고 시트 / 전화 / 공유.
마이페이지에서 **이용약관·개인정보처리방침**을 앱 안에서 읽을 수 있다(`legal_screen.dart`, 정적 문서).
> 더보기의 '화면 미리보기 · 개발용' 섹션과 그 안의 보이스피싱·URL 결과 화면은 **지웠다**(#119). 하드코딩된 예시 데이터를 진짜 결과와 똑같은 UI로 보여주던 화면이라, 데모나 심사 중 진짜 결과로 오인될 여지가 있었다.

## 실행 (Android Studio)
1. `flutter create safefam` (경로 공백·한글·OneDrive 금지)
2. 배포 `lib/`·`pubspec.yaml`·`assets/` 덮어쓰기
3. 폴더에서 `flutter create .` → `flutter pub get`
4. Pixel 7 에뮬레이터 → Run
> 폰트: 기본 시스템 폰트로 동작. Pretendard는 `assets/fonts/`에 넣고 pubspec 주석 해제.

## 서버 연동
- **baseUrl**: 기본값 `https://api.safefam.site` (EC2 배포 API). 별도 주입 없이 `flutter run`만으로 실기기에서 바로 붙는다.
  로컬 백엔드로 붙일 때만 빌드 시 주입: `flutter run --dart-define=SAFEFAM_API_BASE_URL=http://10.0.2.2:8080`
  (에뮬레이터의 `localhost`는 에뮬레이터 자신이라 호스트 PC는 `10.0.2.2`. 실기기면 같은 네트워크의 PC IP)
  > ★**API는 `api.` 서브도메인**이다. 루트 `safefam.site`는 관리자 웹(SafeFam_Web, Vercel)이 쓰고 있어 API를 부르면 308로 `www.`에 리다이렉트되고 SPA 문서가 돌아온다. 앱·웹 모두 `api.safefam.site`를 쓴다.
  > 도메인으로만 접근한다 — nginx가 443에서 받아 넘기고 인증서가 `api.safefam.site` 발급이라, IP를 직접 넣으면 붙지 않는다.
- 인증 계약: 공통 응답 `ApiResponse{status,message,data}`, 토큰은 바디(`TokenResponse`). 인증이 필요한(보호된) API 요청에만 `Authorization: Bearer <accessToken>`을 붙임 — 가입·로그인처럼 토큰 없는 요청엔 미적용.
- 문자 분석(**비동기**): `POST /api/v1/analyses`(접수 → **202 `{analysisId, status}`**, 완성 결과 아님)·`GET`(이력, page·필터)·`GET /{id}`(상세, **종료 상태까지 폴링**)·`DELETE /{id}`·`POST /{id}/feedback`. `status`=`PENDING·PROCESSING·COMPLETED·PARTIAL_SUCCESS·FAILED`. 응답 `AnalysisResponse{status, riskScore?, riskLevel?(HIGH/MEDIUM/LOW), category?, failureCode?, scoreBreakdown{textScore?,urlScore?,rulesScore?}, indicators, urls, recommendedActions, analyzedAt?}` — **처리 전·실패엔 점수·등급이 null**(완료/부분 성공에서만 신뢰). 통계는 `GET /api/v1/statistics/overview?period=`. (전부 보호된 API)
  - **마스킹은 서버 담당**(#80): 프론트 클라이언트 마스킹(`util/masking.dart`)은 제거됨 — `content`를 그대로 보내고 서버가 개인정보를 마스킹한다. 단 결과 공유(카톡·문자) 직전에는 유출 방어용 마스킹(`analysis_api.dart` `_redactPii`)을 한 번 더 적용.
  - **레이트리밋**: `POST /analyses`는 유저 기준 분당 제한이 있어 초과 시 429가 오며, 프론트는 일반 실패와 구분해 서버 안내 문구를 노출.
  - **신고**: `POST /api/v1/analyses/{id}/report {type:PHISHING|SPAM|OTHER}` — 저장된 분석을 익명 접수(원문·발신번호·userId 제외, 최초 201·재신고 200 멱등). 결과 화면 → 대응 도우미 → 신고.
- 가족 보호: `POST /api/v1/family/invite`(초대코드/QR 토큰 발급)·`POST /link/code`(코드로 연결)·`POST /link/qr`(QR로 연결)·`GET /members`·`PATCH /{linkId}`(관계 설정)·`DELETE /{linkId}`. **표시 이름(관계)은 서버에 저장**(`relationship`, 최대 20자) — 기기를 바꿔도 유지된다. 예전 기기 로컬(AppPrefs) 별명은 목록을 처음 열 때 서버로 한 번 올리고 로컬에서 지운다. 표시 우선순위는 `relationship` → `wardName` → 전화번호(`wardName`은 SafeFam_BE #97에서 옛 `wardNickname`을 대체한 필드로, 피보호자 가입 이름이 실제로 채워진다). QR은 보호자 화면이 `qrToken`을 QR로 표시(`qr_flutter`)하고 피보호자가 스캔(`mobile_scanner`)해 연결 — **실기기(갤럭시 S23 FE) 카메라 디코딩까지 확인**(2026-08-25). 자기 초대 QR을 스캔해 서버가 '자기 자신과 연결할 수 없습니다'를 돌려주는 것까지 확인했다. (전부 보호된 API)
- 신뢰 발신자(화이트리스트): `POST /api/v1/whitelists`·`GET`·`GET /check?sender=`·`DELETE /{id}`. 등록한 발신자는 자동 탐지 시 분석을 건너뛴다(`/check` → `{sender, whitelisted}`). 더보기 > 탐지·알림에서 관리.
- 문자 자동 탐지(#118): `RECEIVE_SMS` 권한 + 매니페스트 수신기(`another_telephony`) → 자동 탐지 설정 확인 → 화이트리스트 프리패스 확인 → `POST /analyses`(source=**AUTO**). 앱이 꺼져 있어도 백그라운드 콜백으로 접수된다. **결과는 폴링하지 않는다** — HIGH면 백엔드가 FCM으로 밀어주고 알림을 누르면 상세로 간다. 수신 브로드캐스트는 시간이 짧아 호출 타임아웃을 3초로 줄이고, `clientMessageId`를 문자 내용으로 결정해 중복 접수를 백엔드가 멱등 처리하게 한다.
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
    login_screen.dart  로그인(휴대폰+비밀번호 · 회원가입 · 비밀번호 재설정 · 카카오)
    signup_screen.dart 회원가입(휴대폰 인증 → 닉네임+비밀번호)
    reset_password_screen.dart 비밀번호 재설정(휴대폰 인증 → 새 비밀번호)
    unlock_account_screen.dart 계정 잠금 해제(휴대폰 인증 → auth/unlock)
    kakao_onboarding_screen.dart 카카오 신규회원 온보딩(카카오 로그인 → 휴대폰 인증+이름)
    mypage_screen.dart 마이페이지(내 정보 조회·이름 수정·로그아웃·회원 탈퇴·약관)
    legal_screen.dart  이용약관·개인정보처리방침(앱 내 정적 문서)
    family_flow.dart   가족 등록 · 초대코드 · QR 표시 · 연결 · 이름 설정
    qr_scan_screen.dart 가족 QR 스캔(mobile_scanner) → qrToken 반환
    whitelist_screen.dart 신뢰 발신자 관리(목록·추가·삭제)
    home_screen.dart   홈(월간 트렌드 카드·톱니→설정)
    ward_logs_screen.dart 가족 원격 모니터링(피보호자 탐지 이력, 읽기 전용)
    check_screen.dart  검사 탭(수동 분석 → analyses API 호출; 마스킹은 서버)
    results.dart       결과(3중 스코어 게이지) + AnalysisDetailScreen(이력 상세·폴링·삭제·피드백)
    history_screen.dart 이력(목록·통계·유형 필터·상세 이동)
    family_screen.dart 가족 목록(getMembers·연결 해제·관계 설정)
    family_alerts_screen.dart 가족 공동 대응(HIGH 알림·전화·안전 확인·이미 송금)
    more_screen.dart   설정
  services/
    auth_api.dart      인증 API — 가입·로그인·로그아웃·잠금해제 + 마이페이지 users/me·설정 users/me/settings (401 자동 재발급)
    analysis_api.dart  문자 분석 API — 분석·이력·상세·삭제·피드백·통계·신고(analyses·statistics)
    family_api.dart    가족 보호 API — 초대·코드/QR 연결·목록·해제(family)
    whitelist_api.dart 신뢰 발신자 API — 목록·등록·삭제(whitelists)
    chat_api.dart      대응 챗봇 API — `POST /chat`(analysisId 선택)
    family_safety_api.dart 가족 공동 대응 — 케이스 조회·전화·안전확인/이미송금
    device_api.dart    FCM 기기 등록/해제(devices)
    sms_listener_service.dart 문자 수신 감지 → 화이트리스트 프리패스 → 자동 분석 접수(#118)
    app_prefs.dart     기기 로컬 저장(온보딩·deviceId·접근성·자동 탐지 사본, flutter_secure_storage)
    app_settings.dart  접근성 전역 설정(큰 글씨·음성, ValueNotifier)
    tts_service.dart   음성 안내(flutter_tts, 한국어·재생/멈춤)
    notification_service.dart FCM 수신·알림 라우팅(포그라운드/백그라운드/콜드스타트)
  util/launchers.dart  전화(tel)·링크 딥링크 헬퍼(url_launcher)
  sheets.dart          챗봇·신고(analyses/report)·공유
assets/character.png
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
- ↩️ 전송 전 클라이언트 마스킹 제거 — 서버가 마스킹을 담당하기로 방침 변경, `util/masking.dart` 삭제 (PR #61 도입 → PR #81/#80 제거). 공유 유출 방어용 `_redactPii`는 유지
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
- ✅ 위험 근거 카드(`evidenceCards`) 연동 완료 — 결과 화면 '이렇게 판단했어요'에 서버가 사용자 언어로 정리해 보낸 근거를 그대로 렌더(기관 사칭·개인정보 요구·위험 URL·행동 압박·AI 판단). ★`AI_JUDGMENT` 카드엔 AI 분석기의 내부 영어 문구가 실려 오는 일이 있어(`hybrid_analyzer.py`, AI 쪽 미수정) **한글이 없는 설명은 노출하지 않는다** (이슈 #126)
- ✅ 위험 신호 목록(`indicators`)의 영어 문구도 차단 — 내부 접두사(`Matched rule: `, Spring이 붙임)를 벗기고 한글 없는 설명은 제외(`Indicator.displayDescription`). **로컬 풀스택으로 실제 분석을 돌려 발견** — 목 서버로는 잡히지 않던 버그다 (이슈 #130)
- ✅ AI 영어 내부 문구 차단 완료 — 증거 카드는 숨기고(`EvidenceCard.isPresentable`), 결과 설명은 한국어 안내로 대체(`AnalysisResult.displayExplanation`). 설명은 **TTS로도 읽히던** 자리라 한국어 음성 엔진이 영어를 읽고 있었다 (이슈 #128)
- ✅ 재발급 실패와 네트워크 장애 구분 완료 — `reissue()`가 타임아웃까지 `false` 하나로 뭉개 세션을 폐기해, 토큰이 만료된 상태에서 **문자 한 통에 로그아웃**되던 문제. 이제 서버가 거절했을 때만 토큰을 버린다(`ReissueOutcome`). single-flight 예약도 실제 요청이 끝날 때까지 유지해, 같은 토큰으로 두 번째 재발급이 나가지 않는다 (이슈 #124)
- ✅ 자동 탐지 설정이 세션 밖으로 새지 않게 정리 — 자동 탐지 기기 사본은 **계정별이 아니라 기기당 하나**라 로그아웃해도 남아 다음 로그인 사용자가 물려받았다(켠 적 없는 사람의 문자가 그 사람 계정으로 접수됨). 세션이 끝날 때 사본을 끄고, 로그인·자동 로그인 직후 서버 설정으로 되살린다(`SmsListenerService.syncFromServer`). 권한 설정에서 돌아올 때 권한을 다시 읽도록 보강 (이슈 #122)
- ✅ 대응 챗봇 연동 완료 — `POST /api/v1/chat`(`chat_api.dart`). `analysisId`는 **선택**이라 분석 없이도 상담할 수 있고(더보기 > 대응 도우미), 결과 화면에서 열면 그 분석의 위험도·근거가 함께 실린다
- ✅ 가족 공동 대응 연동 완료 — 피보호자 HIGH 케이스 조회 → 전화·안전 확인·이미 송금(`family_safety_api.dart`, `family_alerts_screen`). 홈 우상단 **종 아이콘**으로도 바로 들어간다(#119)
- ✅ 이용약관·개인정보처리방침 추가 — '준비 중' 토스트만 뜨던 자리를 앱 내 정적 문서로 교체(`legal_screen.dart`, #119)
- ✅ 문자 자동 탐지 연동 완료 — `RECEIVE_SMS` 권한 + 매니페스트 수신기 + 백그라운드 콜백 → 화이트리스트 프리패스 → `source=AUTO` 접수. 더보기 토글이 권한을 먼저 받고, 권한이 없으면 그 자리에서 알린다 (`sms_listener_service.dart`, 이슈 #118)
- 회원가입/재설정/잠금해제 인증문자는 실제 SMS(Solapi) 발송이라 서버 SMS 설정 + 실제 수신 가능한 번호 필요

### 남은 작업
- **백엔드 준비됨 · 미연동** — 없음. 컨트롤러 10개 전수 대조 기준으로 응답 필드까지 전부 소진했다(마지막 미사용 필드였던 `evidenceCards`도 연동 완료 — 이슈 #126).
- **검증 범위** — 목 서버 + 에뮬레이터/브라우저로 확인한 범위는 `docs/mock-verification-log.md`, **로컬 풀스택(Spring+FastAPI+RabbitMQ+PostgreSQL+Redis)으로 실제 분석까지 돌린 결과**와 출품 보고서 대조는 `docs/report-vs-reality.md`에 있다.
- ⚠️ **BE 통계 API가 특정 기간에서 터진다** — `GET /statistics/overview?period=LAST_7_DAYS|LAST_30_DAYS`가 NPE로 실패하고 401 '인증이 필요합니다'로 뭉개져 나온다(`period=ALL`만 정상). **앱 기본값이 30일이라 이력 화면 통계가 항상 깨진다.** 프론트가 아니라 BE 수정 사항.
- **온디바이스/실기기 필요** — 최근 머지분 E2E 검증(배포 서버 연결·가족 관계 저장·초대 코드 입력·챗봇) · 가족 QR 실기기 카메라 검증 · TTS 실제 음성 출력 검증 · 자동 탐지의 **실기기 Doze/절전 환경** 확인(에뮬레이터 수신 E2E는 통과 — 아래)
  - ✅ **실기기 첫 실행 검증 완료**(갤럭시 S23 FE · SM-S711N · Android 16 · arm64, 2026-08-25) — 설치·부팅·온보딩 분기까지 정상. 여기서 **권한 팝업 두 개가 온보딩을 덮는 버그**를 찾아 고쳤다(이슈 #132 · PR #133): ①#118의 크래시 방지 호출이 타는 플러그인 메서드 `disableBackgroundService`가 네이티브 권한 요청 경로를 타서, 자동 탐지가 꺼져 있어도 첫 실행에 SMS 권한을 요구했다 ②신규 설치 때 FCM 첫 토큰 발급으로 `onTokenRefresh`가 불려 **로그인 전에** `registerDevice()`가 알림 권한을 요구하고 인증 없는 등록 요청을 보냈다. 둘 다 목 서버·에뮬레이터로는 드러나지 않던 것이다.
  - ✅ **로그인 후 실서버 E2E 완료**(2026-08-25) — 수동 분석(시연 문자 **HIGH 71**·증거 카드 2장·3분할 점수 전부 채워짐) · 이력/상세 · **가족 초대 코드 발급 + QR 스캔 실카메라 디코딩** · 신뢰 발신자 등록/삭제 · 마이페이지 · 약관 · 큰 글씨 · **TTS 한국어 실재생**(`ko-KR`) · 대응 챗봇 · 공유 시트 · 가족 안전 알림. 여기서 **챗봇 마크다운이 글자로 보이던 버그**를 찾아 고쳤다(#134 · PR #135).
  - 남은 것: **FCM 푸시 도달**(보호자 계정이 따로 필요) · **카카오 로그인 콜백** · 실기기 Doze/절전. 신고·삭제·피드백은 서버에 기록이 남아 **의도적으로 실행하지 않았다**(UI 렌더까지만 확인).
  - 이 기기는 **유심이 없어**(SIM `ABSENT`) 실제 문자 수신은 불가하다. 실기기에서 `SMS_RECEIVED`는 시스템 전용 보호 브로드캐스트라 `adb`로 쏠 수 없고(`adb emu sms send`는 에뮬레이터 전용), 자동 탐지 수신 검증은 **쓰는 유심을 꽂아야** 가능하다.
- ⚠️ **`flutter test` 실행 불가(환경)** — Dart VM의 FFI 변환기가 크래시해(`ffi/use_sites.dart`) 테스트 스위트 로딩이 실패한다. 한글 경로와 무관하며 **앱 빌드·실행은 정상**. `test/services/analysis_status_test.dart`가 그동안 돌지 못한 상태다.
- **범위 제외** — 강제 오버레이 경고(`SYSTEM_ALERT_WINDOW`). 팀 착수 합의가 없어 계획에서 뺐다(2026-08-10). 관련 코드·화면은 남아 있지 않다.
- **백엔드 없음** — 보이스피싱 음성 자동 탐지(Android 통화 녹음 API 제한) · URL 검사 전용 엔드포인트. 목업 화면으로 자리만 잡아두던 것을 지웠으므로(#119), 만들 때 화면부터 새로 붙인다.
- **프론트 코드 품질(무백엔드)** — 상태 칩·이력 타일 공용 위젯 추출(history↔ward_logs 중복) · 상태관리(Provider/Riverpod) · 테스트 확대
- **타 멤버/백엔드 미존재** — FCM 알림 수신 로직(타 멤버 담당) · **URL 검사 전용 백엔드는 아직 없다** — 링크 위험도는 분석 결과 안의 URL 카드로 대신 보여준다(별도 URL 검사 화면은 없다 — #119에서 목업을 삭제했다)
- **AI 서버 영어 문구**(타팀, 근본 수정은 AI 몫) — `hybrid_analyzer.py`의 폴백 `reason`이 영어라 `explanation`·`AI_JUDGMENT` 증거 카드로 흘러든다. **프론트는 막아뒀다**(#126·#128 — 한글 없는 설명은 증거 카드는 숨기고 설명은 한국어 안내로 대체). 다만 그건 가리는 것이라, AI가 문구를 한국어로 바꿔야 원래 보여줘야 할 판단 근거가 살아난다(`docs/backend-ai-fix-list.md`)

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