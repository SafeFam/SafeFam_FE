import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../screens/results.dart';
import 'device_api.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static Future<void> initialize() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (details) {
        _navigateToDetail(details.payload);
      },
    );

    // FCM 토큰 갱신 시 서버에 재등록
    FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      DeviceApi.registerDevice();
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        _plugin.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'safefam_channel',
              'SafeFam 알림',
              channelDescription: 'SafeFam 피싱 탐지 알림',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          payload: message.data['analysisId'],
        );
      }
    });

    // 백그라운드에서 알림 탭
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _navigateToDetail(message.data['analysisId']);
    });

    // cold start — 앱 종료 상태에서 알림 탭
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        _navigateToDetail(initial.data['analysisId']);
      }
    });
  }

  static Future<void> _navigateToDetail(String? analysisIdStr) async {
    if (analysisIdStr == null) return;
    final analysisId = int.tryParse(analysisIdStr);
    if (analysisId == null) return;

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => AnalysisDetailScreen(analysisId: analysisId),
      ),
    );
  }
}