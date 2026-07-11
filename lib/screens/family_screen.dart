import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});
  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  bool _big = true;
  bool _voice = true;

  Widget _familyRow(String name, String sub) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SfCard(
          child: Row(
            children: [
              const IconDisc(Icons.person_outline),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(sub, style: AppText.caption),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.t3),
            ],
          ),
        ),
      );

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 16)),
            Switch(
                value: value,
                activeColor: Colors.white,
                activeTrackColor: AppColors.blue,
                inactiveTrackColor: AppColors.toggleOff,
                onChanged: onChanged),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
          child: Row(
            children: [
              const Text('가족 보호', style: AppText.titleScreen),
              const Spacer(),
              IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.person_add_alt, color: AppColors.t1)),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 18),
            children: [
              SfCard(
                kind: CardKind.danger,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.notifications_active_outlined, color: AppColors.high, size: 24),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('아버님 폰에 위험 문자',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.highText)),
                          SizedBox(height: 2),
                          Text('검찰 사칭 · 방금 전', style: AppText.caption),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const SectionLabel('보호 중인 가족'),
              _familyRow('아버지', '이번 달 3건 차단'),
              _familyRow('어머니', '위험 없음'),
              const SizedBox(height: 16),
              const SectionLabel('아버지 폰 원격 설정'),
              SfCard(
                child: Column(
                  children: [
                    _toggleRow('큰 글씨', _big, (v) => setState(() => _big = v)),
                    _toggleRow('음성 안내', _voice, (v) => setState(() => _voice = v)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
