import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import 'auth_api.dart';

/// 대응 챗봇 API — 분석 결과 기반 멀티턴 상담.
///
/// 백엔드 계약(SafeFam_BE #76 · `POST /api/v1/chat` · 보호된 API → Bearer):
///  - 요청 `{ analysisId, messages:[{ role:"USER"|"ASSISTANT", content }] }`
///    (messages 1~50개, content ≤2000자)
///  - 응답 `data { message }` — 위험도·판단 근거는 서버가 analysisId로 **자동 주입**한다
///    (클라이언트는 대화 이력만 매 요청에 함께 보냄).
///  - 공통 응답 ApiResponse `{ status:"SUCCESS"|"ERROR", message, data }`.
///
/// 인증 규약(baseUrl·토큰·401 재시도)은 [AuthApi]를 그대로 재사용한다.
enum ChatRole {
  user('USER'),
  assistant('ASSISTANT');

  final String wire;
  const ChatRole(this.wire);
}

/// 멀티턴 대화 한 줄(작성자 + 내용).
class ChatMessage {
  final ChatRole role;
  final String content;
  const ChatMessage(this.role, this.content);

  Map<String, dynamic> toJson() => {'role': role.wire, 'content': content};
}

class ChatApi {
  // 서버가 LLM 응답을 기다리므로(read timeout 60s) 여유 있게 잡는다.
  static const Duration _timeout = Duration(seconds: 65);

  // 백엔드 검증 한도(messages 1~50개, content ≤2000자)와 동일하게 맞춘다.
  static const int _maxMessages = 50;
  static const int _maxContentLength = 2000;

  /// 상담 한 턴을 보낸다. [history]는 방금 사용자 발화까지 포함한 지금까지의
  /// 대화 전체(사용자/도우미 번갈아)이며, 서버가 [analysisId]로 위험도·근거를
  /// 자동으로 실어 준다. 성공 시 도우미 답변 문자열, 실패 시 null.
  ///
  /// 서버 한도를 넘지 않도록 최근 [_maxMessages]개로 잘라 보내고, 한도를 넘는
  /// 내용은 애초에 보내지 않는다(400을 일반 실패로 흘리지 않기 위함).
  static Future<String?> send({
    required int analysisId,
    required List<ChatMessage> history,
  }) async {
    if (history.isEmpty) return null;
    final trimmed = history.length > _maxMessages
        ? history.sublist(history.length - _maxMessages)
        : history;
    if (trimmed.any((m) => m.content.length > _maxContentLength)) {
      developer.log('메시지가 $_maxContentLength자를 넘어 전송하지 않음', name: 'ChatApi');
      return null;
    }
    try {
      final res = await AuthApi.sendAuthorized((headers) => http
          .post(Uri.parse('${AuthApi.baseUrl}/api/v1/chat'),
              headers: headers,
              body: jsonEncode({
                'analysisId': analysisId,
                'messages': trimmed.map((m) => m.toJson()).toList(),
              }))
          .timeout(_timeout));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        developer.log('chat 실패: HTTP ${res.statusCode} ${_serverMessage(res.body)}',
            name: 'ChatApi');
        return null;
      }
      final body = jsonDecode(res.body);
      if (body is! Map<String, dynamic> || body['status'] != 'SUCCESS') {
        developer.log(
            'chat 오류 응답: ${body is Map ? body['message'] : ''}', name: 'ChatApi');
        return null;
      }
      final data = body['data'];
      final msg = data is Map<String, dynamic> ? data['message'] : null;
      return msg is String && msg.trim().isNotEmpty ? msg.trim() : null;
    } catch (e) {
      developer.log('chat 예외: $e', name: 'ChatApi');
      return null;
    }
  }

  /// 에러 응답 바디에서 서버 message만 추려 로그에 남긴다(사용자 노출 아님).
  static String _serverMessage(String responseBody) {
    if (responseBody.isEmpty) return '';
    try {
      final body = jsonDecode(responseBody);
      final msg = body is Map<String, dynamic> ? body['message'] : null;
      return msg is String ? msg : '';
    } catch (_) {
      return '';
    }
  }
}
