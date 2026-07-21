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

const sampleTrends = <(String, RiskLevel, String)>[
  ('택배·배송 사칭', RiskLevel.high, '많음'),
  ('검찰·금감원 사칭', RiskLevel.med, '주의'),
  ('저금리 대출 사기', RiskLevel.med, '주의'),
];
