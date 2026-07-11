import 'package:flutter/material.dart';
import 'theme/app_theme.dart';

/// 위험도 3단계.
enum RiskLevel { high, med, low }

extension RiskMeta on RiskLevel {
  Color get color => switch (this) {
        RiskLevel.high => AppColors.high,
        RiskLevel.med => AppColors.med,
        RiskLevel.low => AppColors.low,
      };
  Color get onColor => this == RiskLevel.med ? AppColors.medText : Colors.white;
  String get label => switch (this) {
        RiskLevel.high => '위험',
        RiskLevel.med => '주의',
        RiskLevel.low => '안전',
      };
  String get sentence => switch (this) {
        RiskLevel.high => '위험합니다',
        RiskLevel.med => '주의하세요',
        RiskLevel.low => '안전해요',
      };
  IconData get icon => switch (this) {
        RiskLevel.high => Icons.warning_amber_rounded,
        RiskLevel.med => Icons.error_outline_rounded,
        RiskLevel.low => Icons.check_circle_outline_rounded,
      };
}

/// NB 파이프라인이 탐지한 구조적 신호 (결과 근거).
class Signal {
  final IconData icon;
  final String title;
  final String desc;
  const Signal(this.icon, this.title, this.desc);
}

class DetectionItem {
  final String title;
  final String sub;
  final RiskLevel level;
  const DetectionItem(this.title, this.sub, this.level);
}

const sampleHistory = <DetectionItem>[
  DetectionItem('검찰 사칭', '10-****-2841', RiskLevel.high),
  DetectionItem('택배 사칭', '미수령 안내 링크', RiskLevel.med),
  DetectionItem('국민은행', '출금 알림', RiskLevel.low),
];

const sampleTrends = <(String, RiskLevel, String)>[
  ('택배·배송 사칭', RiskLevel.high, '많음'),
  ('검찰·금감원 사칭', RiskLevel.med, '주의'),
  ('저금리 대출 사기', RiskLevel.med, '주의'),
];

/// NB 파이프라인이 탐지한 구조적 신호(결과 화면 근거).
class DetectionSignal {
  final IconData icon;
  final String label;
  final String detail;
  const DetectionSignal(this.icon, this.label, this.detail);
}

const sampleSignals = <DetectionSignal>[
  DetectionSignal(Icons.account_balance, '기관 사칭 정황', '"검찰·수사관" 등 기관을 사칭'),
  DetectionSignal(Icons.credit_card, '안전계좌 언급', '"안전계좌로 이체" 표현 감지'),
  DetectionSignal(Icons.notifications_active, '긴급성 압박', '"즉시·정지" 등 불안 유도'),
];
