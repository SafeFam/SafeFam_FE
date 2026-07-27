import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// 가족 QR 스캔 화면.
///
/// 카메라로 보호자의 초대 QR을 읽어 **qrToken 문자열만** 돌려준다(Navigator.pop).
/// 실제 연결(linkByQr)·에러 안내는 호출부([GuardianLinkScreen])가 코드 연결과
/// 동일한 흐름으로 처리한다. 스캔은 첫 인식 한 번만 처리한다.
///
/// ⚠️ 네이티브 카메라 플러그인(mobile_scanner) 기반이라 실기기 검증이 필요하다.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});
  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    String? token;
    for (final b in capture.barcodes) {
      final v = b.rawValue?.trim();
      if (v != null && v.isNotEmpty) {
        token = v;
        break;
      }
    }
    if (token == null) return;
    _handled = true;
    Navigator.pop(context, token);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('QR 스캔',
            style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            // 카메라 시작 실패(권한 거부 등)엔 안내만 보여준다.
            errorBuilder: (_, __, ___) => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  '카메라를 열 수 없어요.\n설정에서 카메라 권한을 허용해 주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
                ),
              ),
            ),
          ),
          // 조준 가이드 프레임.
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const Positioned(
            bottom: 48,
            left: 24,
            right: 24,
            child: Text(
              '보호자 폰의 초대 QR을 사각형 안에 맞춰 주세요',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
