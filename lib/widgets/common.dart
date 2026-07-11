import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models.dart';

enum SfBtn { primary, ghost, danger }

/// 공통 버튼. 기본은 가로 꽉 채움. [expand]=false면 Row 안에서 Expanded로 감싸 사용.
class SfButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final SfBtn variant;
  final VoidCallback? onTap;
  final bool compact;
  const SfButton(this.label,
      {super.key, this.icon, this.variant = SfBtn.primary, this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (variant) {
      SfBtn.primary => (AppColors.blue, Colors.white, null),
      SfBtn.danger => (AppColors.high, Colors.white, null),
      SfBtn.ghost => (Colors.white, AppColors.t1, Border.all(color: AppColors.line, width: 1.5)),
    };
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(border: border, borderRadius: BorderRadius.circular(14)),
          padding: EdgeInsets.symmetric(vertical: compact ? 14 : 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, size: 21, color: fg), const SizedBox(width: 8)],
              Text(label,
                  style: AppText.button.copyWith(fontSize: compact ? 15 : 17, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 위험도 뱃지 — 색+아이콘+글자 3종 동반.
class RiskBadge extends StatelessWidget {
  final RiskLevel level;
  final bool large;
  final String? text;
  const RiskBadge(this.level, {super.key, this.large = true, this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: large ? 20 : 11, vertical: large ? 9 : 4),
      decoration: BoxDecoration(
          color: level.color, borderRadius: BorderRadius.circular(large ? 11 : 8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(level.icon, size: large ? 21 : 15, color: level.onColor),
          SizedBox(width: large ? 7 : 5),
          Text(text ?? (large ? level.sentence : level.label),
              style: TextStyle(
                  color: level.onColor,
                  fontWeight: large ? FontWeight.w700 : FontWeight.w600,
                  fontSize: large ? 17 : 13)),
        ],
      ),
    );
  }
}

enum CardKind { normal, tint, danger }

class SfCard extends StatelessWidget {
  final Widget child;
  final CardKind kind;
  final EdgeInsets padding;
  const SfCard(
      {super.key,
      required this.child,
      this.kind = CardKind.normal,
      this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    final (bg, line) = switch (kind) {
      CardKind.normal => (Colors.white, AppColors.line),
      CardKind.tint => (AppColors.bg, AppColors.tintLine),
      CardKind.danger => (AppColors.highBg, AppColors.highLine),
    };
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: line),
          borderRadius: BorderRadius.circular(16)),
      child: child,
    );
  }
}

class SfChip extends StatelessWidget {
  final String label;
  final bool selected;
  const SfChip(this.label, {super.key, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.blue : AppColors.surface,
        border: Border.all(color: selected ? AppColors.blue : AppColors.line),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 14, color: selected ? Colors.white : AppColors.t2)),
    );
  }
}

/// 원본 캐릭터를 원 안에 담음(표정 변형 없음 — 위험은 뱃지/색으로 표현).
class CharacterDisc extends StatelessWidget {
  final double size;
  const CharacterDisc(this.size, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: AppColors.charDisc, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: Image.asset('assets/character.png', fit: BoxFit.cover),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(bottom: 9), child: Text(text, style: AppText.section));
}

/// 아이콘 원(리스트 좌측).
class IconDisc extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  const IconDisc(this.icon, {super.key, this.color = AppColors.blue, this.bg = AppColors.bg});
  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 22),
      );
}
