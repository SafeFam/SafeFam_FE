import 'dart:convert';

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

  /// 상담 한 턴을 보낸다. [history]는 방금 사용자 발화까지 포함한 지금까지의
  /// 대화 전체(사용자/도우미 번갈아)이며, 서버가 [analysisId]로 위험도·근거를
  /// 자동으로 실어 준다. 성공 시 도우미 답변 문자열, 실패 시 null.
  static Future<String?> send({
    required int analysisId,
    required List<ChatMessage> history,
  }) async {
    try {
      final res = await AuthApi.sendAuthorized((headers) => http
          .post(Uri.parse('${AuthApi.baseUrl}/api/v1/chat'),
              headers: headers,
              body: jsonEncode({
                'analysisId': analysisId,
                'messages': history.map((m) => m.toJson()).toList(),
              }))
          .timeout(_timeout));
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final body = jsonDecode(res.body);
      if (body is! Map<String, dynamic> || body['status'] != 'SUCCESS') {
        return null;
      }
      final data = body['data'];
      final msg = data is Map<String, dynamic> ? data['message'] : null;
      return msg is String && msg.trim().isNotEmpty ? msg.trim() : null;
    } catch (_) {
      return null;
    }
  }
}
