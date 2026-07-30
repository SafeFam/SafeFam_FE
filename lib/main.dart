import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' hide AuthApi;
import 'package:safefam/services/notification_service.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'services/app_prefs.dart';
import 'services/app_settings.dart';
import 'services/auth_api.dart';
import 'services/device_api.dart';
import 'widgets/main_scaffold.dart';
import 'screens/auth.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const nativeAppKey = String.fromEnvironment('KAKAO_NATIVE_APP_KEY');
  await KakaoSdk.init(nativeAppKey: nativeAppKey);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await NotificationService.initialize();

  // 토큰 재발급까지 실패해 세션이 끊기면 로그인 화면으로 되돌린다.
  // 쌓인 화면을 모두 걷어내, 뒤로가기로 만료된 화면에 돌아가지 못하게 한다.
  AuthApi.onSessionExpired = () {
    NotificationService.navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  };

  // 로그아웃 시 이 기기의 FCM 등록을 서버에서 해제한다(토큰이 유효할 때 실행됨).
  AuthApi.onBeforeLogout = DeviceApi.unregisterDevice;

  // 접근성 설정(큰 글씨·음성)을 미리 복구해 첫 프레임부터 반영되게 한다.
  await AppSettings.instance.load();

  runApp(const SafeFamApp());
}

class SafeFamApp extends StatelessWidget {
  const SafeFamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '세이프팸',
      debugShowCheckedModeBanner: false,
      theme: buildSafeFamTheme(),
      navigatorKey: NotificationService.navigatorKey,
      // 큰 글씨 토글을 앱 전체에 적용한다. 켜면 고정 배율로 확대하고, 끄면
      // 시스템 글꼴 크기 설정을 그대로 존중한다(임의로 1.0으로 덮지 않음).
      builder: (context, child) => ValueListenableBuilder<bool>(
        valueListenable: AppSettings.instance.bigText,
        builder: (context, big, _) {
          if (!big || child == null) return child ?? const SizedBox.shrink();
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler:
                    const TextScaler.linear(AppSettings.bigTextScale)),
            child: child,
          );
        },
      ),
      home: const _Bootstrap(),
    );
  }
}

/// 부팅 후 진입할 첫 화면.
enum _Entry { home, onboarding, login }

/// 앱 시작 게이트: 저장된 세션(refreshToken)을 복구하고 온보딩 이력을 확인해
/// 홈/온보딩/로그인으로 분기한다. 판단이 끝날 때까지는 스플래시를 띄운다.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();
  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  /// 스플래시가 스쳐 지나가지 않도록 보장하는 최소 노출 시간.
  static const Duration _minimumSplash = Duration(milliseconds: 1200);

  late final Future<_Entry> _entry = _boot();

  Future<_Entry> _boot() async {
    // 세션 복구(네트워크)와 함께 흘려보내, 둘 중 더 늦은 쪽에 맞춰 전환한다.
    final splash = Future<void>.delayed(_minimumSplash);
    _Entry entry;
    try {
      final restored = await AuthApi.restoreSession();
      // 자동 로그인 성공 시 FCM 기기 재등록(백그라운드, 실패해도 무방).
      if (restored) DeviceApi.registerDevice();
      // 자동 로그인된 사용자는 이미 가입을 마친 상태라 온보딩을 다시 묻지 않는다.
      // 그 외에는 '확실한 최초 실행'(false)일 때만 온보딩을 띄우고, 저장소를
      // 못 읽어 판단이 불가능하면(null) 로그인으로 보낸다.
      entry = restored
          ? _Entry.home
          : (await AppPrefs.onboardingSeen() == false
              ? _Entry.onboarding
              : _Entry.login);
    } catch (_) {
      // 보안 저장소 접근 실패 등으로 판단이 불가능해도 스플래시에 갇히지 않도록,
      // 직접 로그인할 수 있는 화면으로 내보낸다.
      entry = _Entry.login;
    }
    await splash;
    return entry;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Entry>(
      future: _entry,
      builder: (context, snapshot) {
        // 판단이 끝나기 전(그리고 예외로 값이 없을 때)은 스플래시를 유지한다.
        return switch (snapshot.data) {
          _Entry.home => const MainScaffold(),
          _Entry.onboarding => const OnboardingScreen(),
          _Entry.login => const LoginScreen(),
          null => const SplashScreen(),
        };
      },
    );
  }
}
