import 'package:url_launcher/url_launcher.dart';

/// 전화·링크 등 외부 앱을 여는 side-effect 헬퍼.
/// 모두 성공 여부(bool)를 반환하고 예외는 내부에서 삼켜 false로 수렴시킨다.

/// 전화 걸기(tel:). 숫자와 `+`만 남겨 전화 앱을 연다.
Future<bool> callNumber(String number) async {
  final digits = number.replaceAll(RegExp(r'[^0-9+]'), '');
  if (digits.isEmpty) return false;
  try {
    return await launchUrl(Uri(scheme: 'tel', path: digits));
  } catch (_) {
    return false;
  }
}

/// 외부 링크를 브라우저 등 외부 앱으로 연다.
Future<bool> openLink(String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.scheme.isEmpty) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
