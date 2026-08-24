import 'dart:ui';

import 'package:another_telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';

import 'analysis_api.dart';
import 'app_prefs.dart';
import 'auth_api.dart';
import 'whitelist_api.dart';

/// 앱이 앞에 없을 때(백그라운드·종료 상태) 문자 수신 진입점.
///
/// 플러그인이 `PluginUtilities.getCallbackHandle`로 주소를 저장해 두었다가 나중에
/// 되살리기 때문에 **최상위 함수여야 하고**, release 빌드에서 tree shaking으로
/// 잘려나가지 않도록 `@pragma('vm:entry-point')`가 필요하다.
@pragma('vm:entry-point')
Future<void> safefamSmsBackgroundHandler(SmsMessage message) async {
  // 이 콜백은 메인 isolate가 아닌 새 isolate에서 실행돼 플러그인이 등록돼 있지
  // 않다. 보안 저장소(토큰)를 읽으려면 먼저 등록해 줘야 한다.
  DartPluginRegistrant.ensureInitialized();
  await SmsListenerService.handleIncoming(message, restoreSession: true);
}

/// 문자 수신 → 자동 분석 트리거.
///
/// 사용자가 문자를 직접 넣는 수동 분석(`check_screen.dart`)과 같은 서버 흐름을
/// 타되, [AnalysisSource.auto]로 접수한다는 점만 다르다. 접수(202) 이후 결과를
/// 기다리지 않는 이유는, 위험(HIGH)일 때 백엔드가 FCM으로 밀어주고
/// `NotificationService`가 그 알림을 결과 화면으로 연결하기 때문이다.
/// 수신 브로드캐스트 안에서 폴링까지 하면 시간 예산을 넘겨 잘린다.
class SmsListenerService {
  static final Telephony _telephony = Telephony.instance;

  /// 문자 수신 브로드캐스트는 시스템이 대략 10초만 살려둔다. 그 안에 못 끝내면
  /// 프로세스가 회수되면서 요청이 통째로 유실되므로, 각 호출에 짧은 타임아웃을
  /// 두고 남는 시간에 여유를 남긴다.
  static const Duration _callTimeout = Duration(seconds: 3);

  /// 이미 등록했는지. 로그인·설정 변경 등으로 여러 번 불려도 리스너는 하나만.
  static bool _listening = false;

  /// 자동 탐지에 필요한 권한(문자 수신)이 이미 있는지.
  static Future<bool> hasPermission() => Permission.sms.isGranted;

  /// 권한 요청. 이미 있으면 바로 true.
  ///
  /// 사용자가 '다시 묻지 않음'으로 거부했다면 시스템 대화상자가 더는 뜨지 않아
  /// 앱 안에서는 되돌릴 수 없다. 그 경우를 호출부가 구분해 설정으로 안내할 수
  /// 있도록 [SmsPermissionResult]로 돌려준다.
  static Future<SmsPermissionResult> requestPermission() async {
    if (await Permission.sms.isGranted) return SmsPermissionResult.granted;
    final status = await Permission.sms.request();
    if (status.isGranted) return SmsPermissionResult.granted;
    if (status.isPermanentlyDenied) {
      return SmsPermissionResult.permanentlyDenied;
    }
    return SmsPermissionResult.denied;
  }

  /// 권한을 영구 거부한 사용자를 앱 설정 화면으로 보낸다.
  static Future<bool> openSettings() => openAppSettings();

  /// 문자 수신 감시를 시작한다. 권한이 없거나 자동 탐지가 꺼져 있으면 아무것도
  /// 하지 않는다(설정을 켜는 시점에 다시 불린다).
  ///
  /// 앱 시작·로그인 직후처럼 여러 곳에서 불려도 안전하게 한 번만 등록한다.
  static Future<void> start() async {
    if (_listening) return;
    if (!await AppPrefs.autoAnalysisEnabled()) return;
    if (!await hasPermission()) return;
    _telephony.listenIncomingSms(
      onNewMessage: (message) => handleIncoming(message),
      onBackgroundMessage: safefamSmsBackgroundHandler,
    );
    _listening = true;
  }

  /// 수신 문자 한 통을 처리한다.
  ///
  /// [restoreSession]은 백그라운드 isolate에서만 true다. 그쪽은 [AuthApi]의
  /// 메모리 캐시가 비어 있어 저장소에서 토큰을 올려야 한다.
  static Future<void> handleIncoming(
    SmsMessage message, {
    bool restoreSession = false,
  }) async {
    final content = message.body?.trim() ?? '';
    if (content.isEmpty) return;

    // 서버가 켜져 있다고 본 게 아니라 기기에 적어둔 사본을 본다(더보기 토글이
    // 서버에 반영될 때 함께 기록된다). 꺼져 있으면 문자를 밖으로 내보내지 않는다.
    if (!await AppPrefs.autoAnalysisEnabled()) return;

    if (restoreSession && !await AuthApi.loadStoredTokens()) {
      return; // 로그인 세션이 없으면 분석을 요청할 수 없다.
    }
    if (AuthApi.accessToken == null) return;

    final sender = message.address?.trim();

    // 신뢰 발신자면 분석을 건너뛴다(1차 필터). 확인에 실패하면 검사하는 쪽으로
    // 기운다 — 프리패스는 검사를 생략하는 결정이라 모를 때 통과시키면 안 된다.
    if (sender != null && sender.isNotEmpty) {
      if (await WhitelistApi.check(sender, timeout: _callTimeout)) return;
    }

    final receivedAt = message.date != null
        ? DateTime.fromMillisecondsSinceEpoch(message.date!)
        : DateTime.now();

    await AnalysisApi.analyze(
      content: content.length > _maxContent
          ? content.substring(0, _maxContent)
          : content,
      sender: sender,
      receivedAt: receivedAt,
      source: AnalysisSource.auto,
      clientMessageId: _clientMessageId(sender, content, receivedAt),
      timeout: _callTimeout,
    );
    // 결과는 기다리지 않는다(위 클래스 주석). 실패해도 사용자를 방해하지 않도록
    // 조용히 넘긴다 — 수신함의 문자는 그대로 남아 있어 수동 검사로 다시 넣을 수 있다.
  }

  /// 백엔드 `content` 상한(@Size(max = 5000)).
  static const int _maxContent = 5000;

  /// 같은 문자를 두 번 분석하지 않기 위한 식별자(백엔드가 이 값으로 멱등 처리).
  ///
  /// 앱이 앞에 있는 짧은 순간에는 foreground/background 콜백이 겹쳐 같은 문자가
  /// 두 번 들어올 수 있어, **문자 내용만으로 결정되는 값**이어야 한다. 수신
  /// 시각과 발신자, 본문 길이를 묶으면 한 기기 안에서 충돌할 일이 없다.
  /// 백엔드 상한이 100자라 발신자는 잘라 쓴다.
  static String _clientMessageId(
      String? sender, String content, DateTime receivedAt) {
    final from = (sender == null || sender.isEmpty)
        ? 'unknown'
        : (sender.length > 40 ? sender.substring(0, 40) : sender);
    return 'sms:${receivedAt.millisecondsSinceEpoch}:$from:${content.length}';
  }
}

/// 문자 수신 권한 요청 결과.
enum SmsPermissionResult {
  granted,

  /// 이번에 거부. 다음에 다시 물어볼 수 있다.
  denied,

  /// '다시 묻지 않음'으로 거부 — 앱 설정에서 직접 켜야 한다.
  permanentlyDenied,
}
