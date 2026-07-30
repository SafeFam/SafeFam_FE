import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// 결과 음성 안내(TTS) 래퍼. 한국어로, 고령층을 배려해 조금 느리게 읽어준다.
///
/// 재생 상태는 [speaking]으로 노출해 버튼이 '들려주기/멈춤'을 토글할 수 있게 한다.
/// TTS 엔진이 없는 기기도 있으므로 모든 호출은 실패해도 앱을 멈추지 않는다.
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();

  /// 현재 읽는 중인지. 완료·취소·오류 시 자동으로 false가 된다.
  final ValueNotifier<bool> speaking = ValueNotifier(false);

  bool _ready = false;

  Future<void> _ensureInit() async {
    if (_ready) return;
    await _tts.setLanguage('ko-KR');
    await _tts.setSpeechRate(0.45); // 0~1, 기본보다 느리게
    _tts.setCompletionHandler(() => speaking.value = false);
    _tts.setCancelHandler(() => speaking.value = false);
    _tts.setErrorHandler((_) => speaking.value = false);
    _ready = true;
  }

  /// [text]를 읽어준다. 엔진이 없거나 실패하면 false.
  Future<bool> speak(String text) async {
    if (text.trim().isEmpty) return false;
    try {
      await _ensureInit();
      await _tts.stop();
      // flutter_tts는 요청이 정상 접수되면 1을 준다. 1이 아니면 실제로 재생이
      // 시작되지 않은 것이므로 실패로 처리한다(완료·취소·오류는 핸들러가 정리).
      final result = await _tts.speak(text);
      final ok = result == 1;
      speaking.value = ok;
      return ok;
    } catch (_) {
      speaking.value = false;
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
    speaking.value = false;
  }
}
