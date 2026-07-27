/// 개인정보 1차 마스킹.
///
/// 서버(→ 백엔드 → FastAPI → Claude API)로 문자 원문을 보내기 전에 계좌·카드·
/// 주민등록·전화번호 같은 개인정보 숫자열을 `[REDACTED]`로 가린다.
/// CLAUDE.md §3-1·§11 및 개인정보보호법상 마스킹 안 된 원문은 절대 전송하지 않는다.
///
/// 설계 근거(백엔드 소스 확인, 무수정):
///  - 백엔드 위험 탐지(MessagePatternDetector·RiskKeywordExtractor)는 전부 한글
///    키워드 기반("계좌·카드번호"라는 단어, 이체·송금 등)이라 실제 숫자열을
///    매칭하지 않는다 → 숫자를 가려도 탐지 손실이 없다.
///  - URL은 링크 위험 분석(VirusTotal)에 필요하므로 가리지 않는다.
///  - 발신번호(sender)는 화이트리스트 1차 필터가 쓰므로 [content]만 마스킹한다.
///
/// 정밀 식별이 아니라 '전송 전 1차 차단'이 목적이라, 애매하면 가리는 쪽으로
/// 기운다(개인정보 노출 < 과마스킹).
class Pii {
  Pii._();

  static const String redacted = '[REDACTED]';

  /// URL은 마스킹에서 제외한다(scheme·www 형태). splitMapJoin으로 이 구간만 건너뛴다.
  ///
  /// 본문은 URL에 실제로 쓰이는 ASCII 문자만 허용한다(RFC 3986 unreserved+reserved
  /// +percent). `\S+`로 잡으면 URL 뒤에 붙은 구분자·프로즈까지 통째로 삼켜
  /// `https://a.com,010-1234-5678`의 전화번호가 마스킹을 건너뛰고 전송된다.
  /// 그래서 **콤마와 비ASCII(한글 등)를 문자셋에서 제외**해 URL이 거기서 끊기고,
  /// 뒤따르는 PII는 다시 [_maskNumbers]로 넘어가게 한다. 콤마를 쓰는 쿼리스트링은
  /// 잘릴 수 있으나 '개인정보 노출 < 과마스킹' 원칙상 감수한다.
  static final RegExp _url = RegExp(
    r"(?:https?://|www\.)[A-Za-z0-9\-._~:/?#\[\]@!$&'()*+;=%]+",
    caseSensitive: false,
  );

  /// 주민등록번호: 6자리-7자리(구분자 optional). 가장 구체적이라 먼저 적용.
  static final RegExp _rrn = RegExp(r'\b\d{6}[- ]?\d{7}\b');

  /// 카드번호: 그룹 표기(공백/하이픈 구분 허용).
  ///  - 4-4-4-(1~4): 일반 13~16자리(Visa·MC 등)
  ///  - 4-6-5     : Amex식 15자리(`3782 822463 10005`)
  /// 하이픈·공백 없이 붙은 연속 숫자는 [_accountLong](10~16)이 함께 잡는다.
  static final RegExp _card = RegExp(
    r'\b(?:'
    r'\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{1,4}'
    r'|\d{4}[- ]?\d{6}[- ]?\d{5}'
    r')\b',
  );

  /// 계좌번호(하이픈 그룹): 은행별로 자리수가 달라 2~6자리 그룹을 하이픈으로 잇는다.
  static final RegExp _accountHyphen =
      RegExp(r'\b\d{2,6}-\d{2,6}-\d{2,6}(?:-\d{1,6})?\b');

  /// 계좌번호(연속): 하이픈 없는 10~16자리 긴 숫자열.
  static final RegExp _accountLong = RegExp(r'\b\d{10,16}\b');

  /// 전화번호: (지역/이동통신 국번-)국번-번호. 010-1234-5678, 02-123-4567 등.
  static final RegExp _phone =
      RegExp(r'\b(?:0\d{1,2}[- ]?)?\d{3,4}[- ]?\d{4}\b');

  /// [content]에서 개인정보 숫자열을 [redacted]로 치환해 돌려준다.
  /// URL 구간은 건너뛰어 그대로 보존한다.
  static String mask(String content) {
    return content.splitMapJoin(
      _url,
      onMatch: (m) => m[0]!, // URL은 원형 유지
      onNonMatch: _maskNumbers, // URL 밖 텍스트만 마스킹
    );
  }

  /// 구체적인 것부터 순서대로 치환한다(주민 → 카드 → 계좌 → 전화).
  static String _maskNumbers(String text) => text
      .replaceAll(_rrn, redacted)
      .replaceAll(_card, redacted)
      .replaceAll(_accountHyphen, redacted)
      .replaceAll(_accountLong, redacted)
      .replaceAll(_phone, redacted);
}
