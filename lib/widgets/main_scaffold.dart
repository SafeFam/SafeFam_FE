import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../screens/home_screen.dart';
import '../screens/history_screen.dart';
import '../screens/family_screen.dart';
import '../screens/check_screen.dart';
import '../services/sms_listener_service.dart';

/// 하단 탭 4개: 홈 · 이력 · 가족 · 검사. (더보기는 홈 톱니바퀴로 이동)
class MainScaffold extends StatefulWidget {
  final int initialIndex;
  const MainScaffold({super.key, this.initialIndex = 0});
  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  late int _index = widget.initialIndex;

  @override
  void initState() {
    super.initState();
    // 문자 자동 탐지 감시 시작. 로그인·회원가입·세션 복구 어느 쪽으로 들어와도
    // 반드시 이 화면을 거치므로 여기 한 곳에서만 켠다. 설정이 꺼져 있거나 권한이
    // 없으면 내부에서 그냥 돌아오고, 여러 번 불려도 리스너는 하나만 등록된다.
    SmsListenerService.start();
  }

  static const _tabs = [
    HomeScreen(),
    HistoryScreen(),
    FamilyScreen(),
    CheckScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(bottom: false, child: IndexedStack(index: _index, children: _tabs)),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.blue,
          unselectedItemColor: AppColors.t3,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          iconSize: 27,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: '홈'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: '이력'),
            BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: '가족'),
            BottomNavigationBarItem(icon: Icon(Icons.search), label: '검사'),
          ],
        ),
      ),
    );
  }
}
