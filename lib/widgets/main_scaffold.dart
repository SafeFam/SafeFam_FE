import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../screens/home_screen.dart';
import '../screens/history_screen.dart';
import '../screens/family_screen.dart';
import '../screens/check_screen.dart';

/// 하단 탭 4개: 홈 · 이력 · 가족 · 검사. (더보기는 홈 톱니바퀴로 이동)
class MainScaffold extends StatefulWidget {
  final int initialIndex;
  const MainScaffold({super.key, this.initialIndex = 0});
  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  late int _index = widget.initialIndex;

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
