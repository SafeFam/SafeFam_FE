import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 서버와 무관한 기기 로컬 설정.
///
/// 비밀값은 아니지만, 신규 네이티브 플러그인을 더하지 않으려고 [AuthApi]가
/// 이미 쓰는 flutter_secure_storage를 그대로 재사용한다.
class AppPrefs {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const String _kOnboardingSeen = 'onboardingSeen';

  /// 온보딩을 이미 마쳤는지. 기기 최초 1회만 노출하기 위한 플래그라
  /// 로그아웃해도 유지된다(앱을 지웠다 다시 깔아야 초기화).
  ///
  /// 저장소를 읽지 못하면 `null`(판단 불가)을 돌려준다. `false`는 **키가 없는
  /// 확실한 최초 실행**에만 쓴다 — 정상적인 최초 실행은 `read`가 예외 없이
  /// `null`을 주므로, 예외가 났다는 건 대개 신규 설치가 아니라 쓰던 기기의
  /// 저장소 손상이다. 둘을 `false`로 뭉개면 그런 기기에서 이미 온보딩을 본
  /// 사용자에게 매 실행마다 온보딩이 다시 뜬다.
  static Future<bool?> onboardingSeen() async {
    try {
      return await _storage.read(key: _kOnboardingSeen) == 'true';
    } catch (_) {
      return null;
    }
  }

  /// 온보딩 완료 기록. '시작하기'·'건너뛰기' 모두 완료로 본다.
  static Future<void> markOnboardingSeen() async {
    try {
      await _storage.write(key: _kOnboardingSeen, value: 'true');
    } catch (_) {
      // 기록에 실패해도 흐름은 그대로 진행한다(다음 실행에 한 번 더 보일 뿐).
    }
  }

  /// 가족 연결 별명(예: '어머니'). 백엔드에는 이름 필드가 없어 기기 로컬에만
  /// 둔다. 연결(linkId)마다 하나씩 저장한다.
  static String _familyNameKey(int linkId) => 'familyName:$linkId';

  /// 저장된 별명. 없거나 못 읽으면 null.
  static Future<String?> familyName(int linkId) async {
    try {
      final v = await _storage.read(key: _familyNameKey(linkId));
      return (v == null || v.isEmpty) ? null : v;
    } catch (_) {
      return null;
    }
  }

  /// 별명 저장.
  static Future<void> setFamilyName(int linkId, String name) async {
    try {
      await _storage.write(key: _familyNameKey(linkId), value: name);
    } catch (_) {
      // 저장 실패해도 연결 자체는 유효하다(번호로 표시될 뿐).
    }
  }

  /// 연결 해제 시 별명도 지운다.
  static Future<void> removeFamilyName(int linkId) async {
    try {
      await _storage.delete(key: _familyNameKey(linkId));
    } catch (_) {}
  }
}
