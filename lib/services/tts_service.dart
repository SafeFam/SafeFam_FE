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
      // speak가 완료까지 대기하는 기기도 있으니 상태를 먼저 세워 UI가 바로 바뀌게
      // 한다. 완료·취소·오류는 핸들러가 다시 false로 되돌린다.
      speaking.value = true;
      await _tts.speak(text);
      return true;
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
