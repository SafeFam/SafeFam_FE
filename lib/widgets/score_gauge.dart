import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models.dart';

/// 원형 점수 게이지. score 0~100, 색은 위험도.
class ScoreGauge extends StatelessWidget {
  final int score;
  final RiskLevel level;
  final double size;
  const ScoreGauge(this.score, this.level, {super.key, this.size = 170});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GaugePainter(score / 100, level.color),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$score',
                  style: const TextStyle(
                      fontSize: 46, fontWeight: FontWeight.w700, color: AppColors.t1)),
              const Text('/ 100', style: TextStyle(fontSize: 15, color: AppColors.t3)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double pct;
  final Color color;
  _GaugePainter(this.pct, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.track;
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, 0, 2 * math.pi, false, track);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * pct, false, fill);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.pct != pct || old.color != color;
}

/// 기여도 breakdown 한 줄.
class BreakdownBar extends StatelessWidget {
  final String label;

  /// 해당 계층의 원점수 0~100. **null이면 서버가 값을 안 준 것**이라
  /// 0점(안전)과 구분해 '—'로 비워 둔다. 못 돌린 분석을 0점으로 그리면
  /// 안전하다는 오해를 준다.
  final int? value;
  const BreakdownBar(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    final v = value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 14, color: AppColors.t1)),
              Text(v == null ? '—' : '$v',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: v == null ? AppColors.t3 : AppColors.t1,
                  )),
            ],
          ),
          const SizedBox(height: 5),
          // 값이 없으면 **막대 자체를 그리지 않는다.** 빈 막대를 남기면 0점짜리와
          // 똑같이 보여서, 숫자를 '—'로 비워둔 의미가 사라진다 — 못 돌린 검사가
          // '0점이라 안전'처럼 읽히는 게 바로 이 위젯이 막으려던 것이다.
          if (v != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: v / 100,
                minHeight: 10,
                backgroundColor: AppColors.track,
                valueColor: const AlwaysStoppedAnimation(AppColors.blue),
              ),
            )
          else
            // 자리는 유지해 세 줄의 높이가 흔들리지 않게 한다.
            const SizedBox(height: 10),
        ],
      ),
    );
  }
}
