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
  static Future<bool> onboardingSeen() async {
    try {
      return await _storage.read(key: _kOnboardingSeen) == 'true';
    } catch (_) {
      // 저장소 접근 실패는 '아직 안 봄'으로 수렴시킨다.
      // 권한 안내를 건너뛰는 쪽보다 한 번 더 보여주는 쪽이 안전하다.
      return false;
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
}
