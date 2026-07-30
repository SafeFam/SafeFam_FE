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

  /// FCM 기기 등록 id. 로그아웃 때 이 id로 서버 기기를 해제하려면 등록 응답의
  /// deviceId를 보관해 둬야 한다. 동일 기기라도 다른 계정으로 로그인하면
  /// 서버가 새 id를 발급하므로, 등록 때마다 최신값으로 덮어쓴다.
  static const String _kDeviceId = 'fcmDeviceId';

  /// 저장된 기기 id. 없거나 못 읽으면 null.
  static Future<int?> deviceId() async {
    try {
      final v = await _storage.read(key: _kDeviceId);
      return (v == null || v.isEmpty) ? null : int.tryParse(v);
    } catch (_) {
      return null;
    }
  }

  /// 기기 id 저장(등록 성공 시).
  static Future<void> setDeviceId(int id) async {
    try {
      await _storage.write(key: _kDeviceId, value: '$id');
    } catch (_) {
      // 저장 실패 시 다음 로그아웃에서 해제를 못 할 뿐, 등록 자체는 유효하다.
    }
  }

  /// 기기 id 삭제(해제 후).
  static Future<void> removeDeviceId() async {
    try {
      await _storage.delete(key: _kDeviceId);
    } catch (_) {}
  }

  // ── 접근성 설정(큰 글씨·음성 안내). 기기 로컬에만 둔다. ──
  static const String _kBigText = 'bigText';
  static const String _kVoiceEnabled = 'voiceEnabled';

  /// 큰 글씨 사용 여부(기본 off). 못 읽으면 off로 본다.
  static Future<bool> bigText() async {
    try {
      return await _storage.read(key: _kBigText) == 'true';
    } catch (_) {
      return false;
    }
  }

  static Future<void> setBigText(bool v) async {
    try {
      await _storage.write(key: _kBigText, value: '$v');
    } catch (_) {}
  }

  /// 음성 안내(TTS) 사용 여부(**기본 on** — 고령층 배려). 키가 없으면 on.
  static Future<bool> voiceEnabled() async {
    try {
      final v = await _storage.read(key: _kVoiceEnabled);
      return v == null ? true : v == 'true';
    } catch (_) {
      return true;
    }
  }

  static Future<void> setVoiceEnabled(bool v) async {
    try {
      await _storage.write(key: _kVoiceEnabled, value: '$v');
    } catch (_) {}
  }
}
