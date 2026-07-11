import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/auth.dart';

void main() => runApp(const SafeFamApp());

class SafeFamApp extends StatelessWidget {
  const SafeFamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '세이프팸',
      debugShowCheckedModeBanner: false,
      theme: buildSafeFamTheme(),
      home: const SplashScreen(),
    );
  }
}
