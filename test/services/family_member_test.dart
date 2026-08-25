import 'package:flutter_test/flutter_test.dart';
import 'package:safefam/services/family_api.dart';

void main() {
  group('FamilyMember.fromJson', () {
    test('보호자 화면에서 피보호자를 상대 가족으로 파싱한다', () {
      final member = FamilyMember.fromJson({
        'linkId': 10,
        'memberId': 2,
        'memberName': '어머니',
        'memberPhone': '01033334444',
        'memberRole': 'WARD',
        'wardId': 2,
        'wardName': '피보호자',
        'wardPhone': '01033334444',
        'relationship': '어머니',
        'status': 'ACTIVE',
      });

      expect(member.memberId, 2);
      expect(member.memberRole, FamilyMemberRole.ward);
      expect(member.displayName, '어머니');
      expect(member.canViewWardLogs, true);
      expect(member.canManageRelationship, true);
    });

    test('피보호자 화면에서 보호자의 실제 이름을 표시한다', () {
      final member = FamilyMember.fromJson({
        'linkId': 10,
        'memberId': 1,
        'memberName': '보호자',
        'memberPhone': '01011112222',
        'memberRole': 'PROTECTOR',
        'wardId': 2,
        'wardName': '피보호자',
        'wardPhone': '01033334444',
        'relationship': '어머니',
        'status': 'ACTIVE',
      });

      expect(member.memberId, 1);
      expect(member.memberRole, FamilyMemberRole.protector);
      expect(member.displayName, '보호자');
      expect(member.canViewWardLogs, false);
      expect(member.canManageRelationship, false);
    });

    test('기존 ward 응답도 member 필드로 호환 파싱한다', () {
      final member = FamilyMember.fromJson({
        'linkId': 10,
        'wardId': 2,
        'wardName': '피보호자',
        'wardPhone': '01033334444',
        'status': 'ACTIVE',
      });

      expect(member.memberId, 2);
      expect(member.memberName, '피보호자');
      expect(member.memberPhone, '01033334444');
      expect(member.memberRole, FamilyMemberRole.ward);
    });

    test('알 수 없는 역할은 보호자 전용 기능을 허용하지 않는다', () {
      final member = FamilyMember.fromJson({
        'linkId': 10,
        'memberId': 3,
        'memberName': '가족',
        'memberRole': 'BROKEN_ROLE',
        'wardId': 3,
        'status': 'ACTIVE',
      });

      expect(member.memberRole, FamilyMemberRole.unknown);
      expect(member.canViewWardLogs, false);
      expect(member.canManageRelationship, false);
    });
  });
}
