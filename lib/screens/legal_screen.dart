import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// 이용약관·개인정보처리방침 본문.
///
/// 개인정보를 다루는 앱이라 '준비 중' 토스트만 띄우고 있을 수는 없어(#119)
/// 앱 안에 정적으로 싣는다. 외부 링크가 아니라 앱 내 화면인 이유는, 링크가
/// 죽으면 약관이 통째로 사라지는 셈이 되기 때문이다.
///
/// ⚠️ **여기 적힌 내용은 실제 동작과 일치해야 한다.** 수집 항목이나 제3자 제공이
/// 바뀌면 코드와 함께 이 파일도 고쳐야 한다.
enum LegalDoc {
  terms('이용약관', _terms),
  privacy('개인정보처리방침', _privacy);

  final String title;
  final List<_Section> sections;
  const LegalDoc(this.title, this.sections);
}

class LegalScreen extends StatelessWidget {
  final LegalDoc doc;
  const LegalScreen(this.doc, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.t1),
            onPressed: () => Navigator.maybePop(context)),
        title: Text(doc.title, style: AppText.titleScreen),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          Text(_lastUpdated,
              style: AppText.caption.copyWith(color: AppColors.t3)),
          const SizedBox(height: 16),
          for (final s in doc.sections) ...[
            SectionLabel(s.heading),
            const SizedBox(height: 4),
            Text(s.body, style: AppText.body),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}

const String _lastUpdated = '최종 개정일 2026년 8월 24일';

class _Section {
  final String heading;
  final String body;
  const _Section(this.heading, this.body);
}

const List<_Section> _terms = [
  _Section(
    '제1조 (목적)',
    '이 약관은 세이프팸(이하 "회사")이 제공하는 SafeFam 앱(이하 "서비스")의 이용 조건과 절차, '
        '회사와 이용자의 권리·의무를 정하는 것을 목적으로 합니다.',
  ),
  _Section(
    '제2조 (서비스의 내용)',
    '서비스는 이용자가 받은 문자 메시지의 금융사기(스미싱·보이스피싱) 위험도를 분석해 알려주고, '
        '위험한 경우 대응 방법을 안내하며, 이용자가 연결한 가족에게 알림을 전달합니다.',
  ),
  _Section(
    '제3조 (분석 결과의 한계)',
    '위험도 분석은 인공지능과 규칙에 기반한 참고 정보이며, 사기 여부를 확정하는 판정이 아닙니다. '
        '"안전"으로 표시된 문자가 실제로는 사기일 수 있고 그 반대일 수도 있습니다.\n\n'
        '회사는 분석 결과에 오류가 없음을 보증하지 않으며, 이용자는 금전 이체나 개인정보 제공 전에 '
        '반드시 해당 기관의 공식 대표번호로 직접 확인해야 합니다.',
  ),
  _Section(
    '제4조 (이용자의 의무)',
    '이용자는 타인의 계정을 사용하거나, 서비스를 사기·불법 행위에 이용해서는 안 됩니다. '
        '가족 연결 기능은 상대방의 동의를 받아 사용해야 하며, 동의 없는 감시 목적으로 사용할 수 없습니다.',
  ),
  _Section(
    '제5조 (서비스의 중단)',
    '회사는 시스템 점검, 외부 분석 서비스 장애 등 부득이한 사유가 있는 경우 서비스의 전부 또는 '
        '일부를 일시적으로 중단할 수 있습니다. 일부 분석만 실패한 경우에는 어떤 분석이 빠졌는지 '
        '결과 화면에 함께 안내합니다.',
  ),
  _Section(
    '제6조 (계정 해지)',
    '이용자는 마이페이지에서 언제든지 회원 탈퇴를 할 수 있습니다. 탈퇴 시 계정과 분석 이력은 '
        '개인정보처리방침에서 정한 바에 따라 처리됩니다.',
  ),
];

const List<_Section> _privacy = [
  _Section(
    '1. 수집하는 개인정보',
    '· 회원 정보: 휴대전화번호, 이름, 비밀번호(암호화 저장)\n'
        '· 소셜 로그인 시: 카카오 계정 식별자\n'
        '· 분석 정보: 이용자가 검사를 요청한 문자의 내용과 발신번호, 분석 결과와 검사 시각\n'
        '· 기기 정보: 알림 전송을 위한 푸시 토큰\n\n'
        '주민등록번호 등 고유식별정보는 수집하지 않습니다.',
  ),
  _Section(
    '2. 개인정보의 이용 목적',
    '· 회원 식별과 로그인\n'
        '· 문자 위험도 분석과 결과·대응 안내 제공\n'
        '· 이용자가 연결한 가족에게 위험 알림 전달\n'
        '· 탐지 이력과 통계 제공',
  ),
  _Section(
    '3. 문자 내용의 처리',
    '분석을 위해 문자 내용은 회사 서버로 전송됩니다. 서버는 외부 인공지능 분석에 보내기 전에 '
        '이름·전화번호·계좌번호 등 개인정보를 가린 뒤 전달합니다. 즉 외부 분석 서비스는 '
        '가려지지 않은 원문을 보지 않습니다.\n\n'
        '자동 탐지를 켠 경우에도 신뢰 발신자로 등록한 번호의 문자는 서버로 보내지 않고 건너뜁니다. '
        '자동 탐지는 언제든 설정에서 끌 수 있습니다.',
  ),
  _Section(
    '4. 제3자 제공 및 처리 위탁',
    '회사는 개인정보를 제3자에게 판매하지 않습니다. 다만 서비스 제공에 필요한 범위에서 '
        '아래 업체에 처리를 위탁합니다.\n\n'
        '· Anthropic, Amazon Web Services: 문자 내용의 문맥 분석 (개인정보를 가린 상태로 전달)\n'
        '· VirusTotal: 문자에 포함된 링크의 안전성 검사 (링크 주소만 전달)\n'
        '· Google (Firebase): 푸시 알림 전송\n'
        '· Amazon Web Services: 서버 운영과 데이터 보관',
  ),
  _Section(
    '5. 보유 기간',
    '회원 정보는 탈퇴 시까지 보유하며, 탈퇴하면 지체 없이 파기합니다. '
        '분석 이력은 이용자가 개별 삭제하거나 탈퇴할 때까지 보관합니다. '
        '다만 관계 법령에서 보존을 요구하는 기록은 해당 기간 동안 보관합니다.',
  ),
  _Section(
    '6. 이용자의 권리',
    '이용자는 언제든지 자신의 개인정보를 조회·수정할 수 있고, 분석 이력을 개별 삭제하거나 '
        '회원 탈퇴로 전체 삭제를 요청할 수 있습니다. 마이페이지와 탐지 이력 화면에서 직접 처리할 수 있습니다.',
  ),
  _Section(
    '7. 문의',
    '개인정보 처리에 관한 문의는 앱 내 문의 경로 또는 회사 대표 연락처로 접수해 주세요.',
  ),
];
