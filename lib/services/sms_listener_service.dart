import 'dart:ui';

import 'package:another_telephony/telephony.dart';
import 'package:flutter/foundation.dart';
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

  /// 지금 감시 중인지. 아직 한 번도 맞춰본 적이 없으면 null.
  ///
  /// null과 false를 구분하는 이유는 [start] 설명에 있다 — 꺼진 상태도 **한 번은
  /// 플러그인에 알려줘야** 하기 때문에, "꺼져 있다"와 "아직 안 알렸다"가 다르다.
  static bool? _listening;

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

  /// 설정·권한 상태에 맞춰 문자 수신 감시를 켜거나 끈다.
  ///
  /// **꺼진 상태도 반드시 플러그인에 알려야 한다.** 수신기는 매니페스트에 등록돼
  /// 있어서 앱을 한 번이라도 실행하고 나면 우리가 감시를 시작했는지와 무관하게
  /// 문자가 올 때마다 불린다. 이때 플러그인은 저장해 둔 콜백 주소로 백그라운드
  /// isolate를 띄우려 하는데, 한 번도 등록한 적이 없으면 그 주소가 0이라
  /// **앱 프로세스가 죽는다**(`FlutterCallbackInformation`이 null → NPE).
  /// 그래서 감시하지 않을 때는 백그라운드 처리를 명시적으로 꺼둔다.
  ///
  /// 단, **문자 수신 권한이 없으면 아무것도 하지 않는다.** 플러그인의 '꺼둠'
  /// 호출(`disableBackgroundService`)이 네이티브에서 권한 요청 경로를 타서
  /// (`SmsMethodCallHandler.checkOrRequestPermission`), 앱을 켜자마자 SMS 권한
  /// 팝업이 온보딩 위로 덮이기 때문이다(#132). 권한이 없으면 앱은 애초에
  /// `SMS_RECEIVED`를 받지 못해 매니페스트 수신기가 돌지 않으므로, 위에서 말한
  /// 크래시도 일어나지 않는다 — 꺼둘 것이 없다. 권한 요청은 사용자가 더보기에서
  /// 토글을 켤 때만 [requestPermission]으로 한다.
  ///
  /// 앱 시작·로그인·설정 변경 등 여러 곳에서 불려도 안전하다 — 상태가 그대로면
  /// 아무것도 하지 않는다. 앱 시작 경로에서도 불리므로 **예외를 밖으로 내보내지
  /// 않는다**. 여기서 터지면 문자 감시가 아니라 앱 자체가 안 뜬다.
  static Future<void> start() async {
    try {
      if (!await hasPermission()) {
        // 권한이 없으면 수신 자체가 오지 않으니 꺼둘 것도 없다. 여기서
        // [_listening]을 건드리지 않는 것이 중요하다 — false로 굳히면 나중에
        // 권한이 생겨도 아래 조기 반환에 걸려 '꺼둠' 동기화를 영영 건너뛰고,
        // 플러그인 기본값이 '백그라운드 실행 허용'이라 #118 크래시가 되살아난다.
        _log('문자 수신 권한이 없어 플러그인을 건드리지 않는다(수신 자체가 없음)');
        return;
      }

      final wanted = await AppPrefs.autoAnalysisEnabled();
      if (_listening == wanted) return;

      if (wanted) {
        _telephony.listenIncomingSms(
          onNewMessage: (message) => handleIncoming(message),
          onBackgroundMessage: safefamSmsBackgroundHandler,
        );
        _log('문자 수신 감시 시작');
      } else {
        // listenInBackground: false → 플러그인이 백그라운드 처리를 끈다.
        // 앞에 있는 동안 오는 문자는 아무것도 하지 않는 콜백으로 흘려보낸다.
        _telephony.listenIncomingSms(
          onNewMessage: _ignore,
          listenInBackground: false,
        );
        _log('문자 수신 감시 꺼둠(백그라운드 처리 비활성)');
      }
      _listening = wanted;
    } catch (e) {
      _log('감시 상태를 맞추지 못했다: $e');
    }
  }

  static void _ignore(SmsMessage _) {}

  /// 서버 설정을 받아 기기 사본과 감시 상태를 맞춘다. **로그인·자동 로그인
  /// 직후**에 부른다.
  ///
  /// 세션이 끝날 때 기기 사본을 꺼버리기 때문에(#122 — 다음 사람이 물려받지
  /// 못하게), 다시 로그인한 사용자에게는 그 사람의 설정을 서버에서 되살려 줘야
  /// 한다. 그러지 않으면 더보기 화면에 들어가기 전까지 자동 탐지가 켜져 있다고
  /// 표시되면서 실제로는 아무 문자도 검사되지 않는다.
  ///
  /// 화면을 막지 않도록 기다리지 않고 던져두는 용도이므로 실패해도 조용히
  /// 넘어간다(다음 더보기 방문이 어차피 다시 맞춘다).
  static Future<void> syncFromServer() async {
    try {
      final settings = await AuthApi.getSettings();
      await AppPrefs.setAutoAnalysisEnabled(settings.autoAnalysisEnabled);
      await start();
    } catch (e) {
      _log('서버 설정을 못 받아 감시 상태를 그대로 둔다: $e');
    }
  }

  /// 수신 문자 한 통을 처리한다.
  ///
  /// [restoreSession]은 백그라운드 isolate에서만 true다. 그쪽은 [AuthApi]의
  /// 메모리 캐시가 비어 있어 저장소에서 토큰을 올려야 한다.
  static Future<void> handleIncoming(
    SmsMessage message, {
    bool restoreSession = false,
  }) async {
    _log('문자 수신 — 처리 시작(background=$restoreSession)');
    final content = message.body?.trim() ?? '';
    if (content.isEmpty) return _log('본문이 비어 건너뜀');

    // 서버가 켜져 있다고 본 게 아니라 기기에 적어둔 사본을 본다(더보기 토글이
    // 서버에 반영될 때 함께 기록된다). 꺼져 있으면 문자를 밖으로 내보내지 않는다.
    if (!await AppPrefs.autoAnalysisEnabled()) {
      return _log('자동 탐지가 꺼져 있어 건너뜀');
    }

    if (restoreSession && !await AuthApi.loadStoredTokens()) {
      return _log('저장된 세션이 없어 건너뜀'); // 로그인해야 분석을 요청할 수 있다.
    }
    if (AuthApi.accessToken == null) return _log('토큰이 없어 건너뜀');

    final sender = message.address?.trim();

    // 신뢰 발신자면 분석을 건너뛴다(1차 필터). 확인에 실패하면 검사하는 쪽으로
    // 기운다 — 프리패스는 검사를 생략하는 결정이라 모를 때 통과시키면 안 된다.
    if (sender != null && sender.isNotEmpty) {
      if (await WhitelistApi.check(sender, timeout: _callTimeout)) {
        return _log('신뢰 발신자라 분석을 건너뜀');
      }
    }

    // 기기가 준 수신 시각. 없으면 서버에 보낼 값은 지금으로 채우되, 멱등키에는
    // 쓰지 않는다(아래 [_clientMessageId] 설명).
    final deviceTime = message.date == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(message.date!);

    await AnalysisApi.analyze(
      content: content.length > _maxContent
          ? content.substring(0, _maxContent)
          : content,
      sender: sender,
      receivedAt: deviceTime ?? DateTime.now(),
      source: AnalysisSource.auto,
      clientMessageId: _clientMessageId(sender, content, deviceTime),
      timeout: _callTimeout,
    );
    // 결과는 기다리지 않는다(위 클래스 주석). 실패해도 사용자를 방해하지 않도록
    // 조용히 넘긴다 — 수신함의 문자는 그대로 남아 있어 수동 검사로 다시 넣을 수 있다.
    _log('분석 접수 요청을 보냈다');
  }

  /// 디버그 빌드에서만 남기는 진행 로그.
  ///
  /// 이 경로는 화면이 없어(백그라운드 수신) 눈으로 확인할 방법이 없다. 어디서
  /// 멈췄는지 `adb logcat`으로 볼 수 있어야 손을 댈 수 있다.
  /// **문자 본문·발신번호는 절대 남기지 않는다** — 로그는 다른 앱도 읽을 수 있고,
  /// 개인정보를 기기에 흘리는 순간 서버 마스킹이 무의미해진다.
  static void _log(String message) {
    if (kDebugMode) debugPrint('[SafeFam SMS] $message');
  }

  /// 백엔드 `content` 상한(@Size(max = 5000)).
  static const int _maxContent = 5000;

  /// 같은 문자를 두 번 분석하지 않기 위한 식별자(백엔드가 이 값으로 멱등 처리).
  ///
  /// 앱이 앞에 있는 짧은 순간에는 foreground/background 콜백이 겹쳐 같은 문자가
  /// 두 번 들어올 수 있어, **문자에서만 결정되는 값**이어야 한다.
  ///
  /// 그래서 [deviceTime]이 없을 때 `DateTime.now()`로 채우면 안 된다 — 두 콜백이
  /// 서로 다른 시각을 얻어 서로 다른 키가 되고, 백엔드는 같은 문자인 줄 몰라
  /// 두 번 분석한다(분당 10회 한도도 그만큼 깎이고 알림도 두 번 간다).
  /// 시각이 없으면 발신자·본문의 지문만으로 만든다.
  ///
  /// 백엔드 상한은 100자이고, 이 값은 40자 안쪽이다.
  static String _clientMessageId(
      String? sender, String content, DateTime? deviceTime) {
    final stamp = deviceTime?.millisecondsSinceEpoch.toString() ?? 'nodate';
    return 'sms:$stamp:${_fingerprint('${sender ?? ''}|$content')}';
  }

  /// 문자 내용을 짧은 문자열로 접는다(FNV-1a 32비트).
  ///
  /// 암호용이 아니라 **같은 문자를 항상 같은 값으로** 만들기 위한 것이다.
  /// `String.hashCode`를 쓰지 않는 이유는 그 값이 실행·플랫폼에 걸쳐 같다는
  /// 보장이 없어서다 — 여기서는 isolate가 달라도 같아야 한다.
  static String _fingerprint(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
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
