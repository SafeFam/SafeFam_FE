import 'package:flutter/foundation.dart';
import 'app_prefs.dart';

/// 앱 전역 접근성 설정(큰 글씨·음성 안내).
///
/// 화면 어디서 바꿔도 즉시 반영되도록 [ValueNotifier]로 들고, 값은 기기 로컬
/// ([AppPrefs])에 저장한다. 앱 시작 시 [load]로 한 번 복구한다.
class AppSettings {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  /// 큰 글씨(앱 전체 글자 확대). 기본 off.
  final ValueNotifier<bool> bigText = ValueNotifier(false);

  /// 음성 안내(TTS로 결과 읽어주기). 기본 on(고령층 배려).
  final ValueNotifier<bool> voice = ValueNotifier(true);

  /// 큰 글씨일 때 적용할 배율. 디자인 원칙상 과하지 않게(본문 16 → 약 21).
  static const double bigTextScale = 1.3;

  /// 저장된 값 로드(앱 시작 시 1회).
  Future<void> load() async {
    bigText.value = await AppPrefs.bigText();
    voice.value = await AppPrefs.voiceEnabled();
  }

  Future<void> setBigText(bool v) async {
    bigText.value = v;
    await AppPrefs.setBigText(v);
  }

  Future<void> setVoice(bool v) async {
    voice.value = v;
    await AppPrefs.setVoiceEnabled(v);
  }
}
