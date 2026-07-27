import 'package:flutter_test/flutter_test.dart';
import 'package:safefam/util/masking.dart';

/// 전송 전 1차 마스킹 회귀 테스트.
///
/// 개인정보(계좌·카드·주민·전화)가 어떤 형태로 와도 [Pii.redacted]로 가려지고,
/// URL만 원형으로 보존되는지 확인한다. 특히 CodeRabbit이 지적한 두 누수 경로
/// (URL이 뒤 PII를 삼키는 경우 / 4-4-4가 아닌 카드 표기)를 회귀로 고정한다.
void main() {
  const redacted = Pii.redacted;

  group('숫자 PII 마스킹', () {
    test('전화번호(하이픈/공백/붙임)', () {
      expect(Pii.mask('연락처 010-1234-5678'), contains(redacted));
      expect(Pii.mask('연락처 010 1234 5678'), contains(redacted));
      expect(Pii.mask('연락처 01012345678'), contains(redacted));
      expect(Pii.mask('전화 02-123-4567'), contains(redacted));
    });

    test('계좌번호(하이픈 그룹 / 연속 긴 숫자)', () {
      expect(Pii.mask('국민 123-45-678901'), contains(redacted));
      expect(Pii.mask('입금 1002123456789'), contains(redacted));
    });

    test('주민등록번호', () {
      expect(Pii.mask('900101-1234567'), contains(redacted));
      expect(Pii.mask('9001011234567'), contains(redacted));
    });
  });

  group('카드번호 마스킹', () {
    test('4-4-4-4 (Visa/MC, 하이픈·공백)', () {
      expect(Pii.mask('카드 1234-5678-9012-3456'), contains(redacted));
      expect(Pii.mask('카드 1234 5678 9012 3456'), contains(redacted));
    });

    // CodeRabbit #2: 4-4-4가 아닌 Amex식 4-6-5(15자리)가 raw로 새던 회귀.
    test('4-6-5 (Amex, 공백/하이픈)', () {
      expect(Pii.mask('카드 3782 822463 10005'), contains(redacted));
      expect(Pii.mask('카드 3782-822463-10005'), contains(redacted));
      expect(Pii.mask('카드 3782 822463 10005'), isNot(contains('822463')));
    });
  });

  group('URL 경계', () {
    test('일반 URL은 원형 보존(마스킹 안 함)', () {
      const url = 'https://safe.example/path?q=1';
      expect(Pii.mask('여기 확인 $url'), contains(url));
      expect(Pii.mask('www.safe.example/abc'), contains('www.safe.example/abc'));
    });

    // CodeRabbit #1: URL이 콤마로 붙은 뒤 PII를 통째로 삼켜 전화번호가
    // 마스킹 없이 전송되던 회귀. URL은 콤마에서 끊기고 전화번호는 가려져야 한다.
    test('URL 뒤 콤마로 붙은 전화번호는 마스킹된다', () {
      final out = Pii.mask('https://safe.example,010-1234-5678');
      expect(out, contains('https://safe.example'));
      expect(out, contains(redacted));
      expect(out, isNot(contains('010-1234-5678')));
    });

    test('URL 뒤 한글이 붙어도 뒤 PII는 마스킹된다', () {
      final out = Pii.mask('https://safe.example안내010-1234-5678');
      expect(out, contains(redacted));
      expect(out, isNot(contains('010-1234-5678')));
    });
  });
}
