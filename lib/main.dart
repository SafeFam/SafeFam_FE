import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const nativeAppKey = String.fromEnvironment('KAKAO_NATIVE_APP_KEY');
  KakaoSdk.init(nativeAppKey: nativeAppKey);
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
      home: const LoginScreen(),
    );
  }
}
