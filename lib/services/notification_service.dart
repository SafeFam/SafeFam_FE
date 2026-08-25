import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../screens/family_alerts_screen.dart';
import '../screens/results.dart';
import 'device_api.dart';

class NotificationService {
  /// 가족 위험 알림 푸시의 `data.type`(SafeFam_BE `FcmService`).
  ///
  /// 이 푸시의 `analysisId`는 **피보호자의 분석**이라 보호자 토큰으로
  /// `/analyses/{id}`를 부르면 남의 자료라 막힌다. 보호자가 열 수 있는 것은
  /// `familySafetyCaseId`로 조회하는 공동 대응 케이스뿐이다.
  static const String _familyAlertType = 'FAMILY_HIGH_RISK_ALERT';
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static Future<void> initialize() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (details) {
        _routePayload(details.payload);
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
          // 어느 화면으로 갈지는 [_route]가 정한다. analysisId만 실어 보내면
          // 가족 알림인지 알 수 없게 되므로 데이터를 통째로 넘긴다.
          payload: jsonEncode(message.data),
        );
      }
    });

    // 백그라운드에서 알림 탭
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _route(message.data);
    });

    // cold start — 앱 종료 상태에서 알림 탭
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        _route(initial.data);
      }
    });
  }

  /// 앱이 떠 있을 때 띄운 로컬 알림의 payload를 다시 데이터로 되돌린다.
  static void _routePayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        _route(decoded);
        return;
      }
    } catch (_) {
      // JSON이 아니면 아래 폴백으로 흘린다.
    }
    // 이 코드가 나오기 전 빌드가 만들어 둔 알림은 payload가 analysisId 하나뿐이다.
    _route({'analysisId': payload});
  }

  /// 푸시 데이터가 가리키는 화면으로 이동한다.
  ///
  /// 가족 위험 알림은 **보호자에게** 오지만 그 안의 `analysisId`는 피보호자
  /// 것이라, 분석 상세로 보내면 열람 권한이 없어 실패한다. 보호자 몫인
  /// 공동 대응 케이스 화면으로 보내야 한다.
  static void _route(Map<String, dynamic> data) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    final caseId = _intOf(data['familySafetyCaseId']);
    if (data['type'] == _familyAlertType || caseId != null) {
      nav.push(MaterialPageRoute(
        // 케이스 번호가 없으면 목록으로 보낸다. 알림을 눌렀는데 아무 일도
        // 일어나지 않는 것보다, 해당 건이 들어 있는 목록을 여는 편이 낫다.
        builder: (_) => caseId == null
            ? const FamilyAlertsScreen()
            : FamilyAlertDetailScreen(caseId: caseId),
      ));
      return;
    }

    final analysisId = _intOf(data['analysisId']);
    if (analysisId == null) return;
    nav.push(MaterialPageRoute(
      builder: (_) => AnalysisDetailScreen(analysisId: analysisId),
    ));
  }

  /// FCM 데이터 값은 항상 문자열로 오지만, 로컬 payload를 되돌린 경우엔
  /// 숫자일 수 있어 둘 다 받는다.
  static int? _intOf(Object? value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}