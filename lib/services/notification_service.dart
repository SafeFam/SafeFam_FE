import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../screens/results.dart';
import 'analysis_api.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static final GlobalKey<NavigatorState> navigatorKey =
  GlobalKey<NavigatorState>();

  static Future<void> initialize() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (details) {
        _navigateToDetail(details.payload);
      },
    );

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

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _navigateToDetail(message.data['analysisId']);
    });
  }

  static Future<void> _navigateToDetail(String? analysisIdStr) async {
    if (analysisIdStr == null) return;
    final analysisId = int.tryParse(analysisIdStr);
    if (analysisId == null) return;

    try {
      final analysis = await AnalysisApi.getAnalysis(analysisId);
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => AnalysisDetailScreen(analysisId: analysisId),
        ),
      );
    } catch (_) {}
  }
}