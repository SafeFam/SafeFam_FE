import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' hide AuthApi;
import 'package:safefam/services/notification_service.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'services/auth_api.dart';
import 'services/device_api.dart';
import 'widgets/main_scaffold.dart';
import 'screens/login_screen.dart';

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
      home: const _Bootstrap(),
    );
  }
}

/// 앱 시작 게이트: 저장된 세션(refreshToken)을 복구해 홈/로그인으로 분기한다.
/// 복구 중엔 최소 로딩 화면만 보인다(스플래시·온보딩 연결은 이후 별도 작업).
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();
  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late final Future<bool> _restore = _boot();

  Future<bool> _boot() async {
    final ok = await AuthApi.restoreSession();
    // 자동 로그인 성공 시 FCM 기기 재등록(백그라운드, 실패해도 무방).
    if (ok) DeviceApi.registerDevice();
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _restore,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
                child: CircularProgressIndicator(color: AppColors.blue)),
          );
        }
        return snapshot.data == true
            ? const MainScaffold()
            : const LoginScreen();
      },
    );
  }
}
