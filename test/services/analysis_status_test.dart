import 'package:flutter_test/flutter_test.dart';
import 'package:safefam/models.dart';
import 'package:safefam/services/analysis_api.dart';

/// 비동기 분석 상태 파싱 회귀 테스트.
///
/// 백엔드가 동기→비동기로 바뀌며 종료 전(PENDING/PROCESSING)·실패(FAILED)에는
/// riskScore·riskLevel이 null로 온다. 이때 예전 fail-secure(null→HIGH, ??0)가
/// 그대로면 "분석 중"·"실패"가 '위험 0점'으로 오표시된다. 그 회귀를 고정한다.
void main() {
  group('AnalysisStatus', () {
    test('알 수 없는/누락 값은 pending으로 수렴(폴링 유도)', () {
      expect(AnalysisStatus.fromWire(null), AnalysisStatus.pending);
      expect(AnalysisStatus.fromWire('???'), AnalysisStatus.pending);
    });

    test('종료/결과 판정', () {
      expect(AnalysisStatus.pending.isTerminal, false);
      expect(AnalysisStatus.processing.isPending, true);
      expect(AnalysisStatus.completed.hasResult, true);
      expect(AnalysisStatus.partialSuccess.hasResult, true);
      expect(AnalysisStatus.failed.isTerminal, true);
      expect(AnalysisStatus.failed.hasResult, false); // 실패는 결과 아님
    });
  });

  group('AnalysisResult.fromJson 상태별 결과 필드', () {
    test('PENDING: 점수·등급 null, hasResult=false', () {
      final r = AnalysisResult.fromJson({
        'analysisId': 101,
        'status': 'PENDING',
        'riskScore': null,
        'riskLevel': null,
      });
      expect(r.status, AnalysisStatus.pending);
      expect(r.riskScore, isNull); // ★예전엔 0으로 떨어졌음
      expect(r.riskLevel, isNull); // ★예전엔 HIGH로 떨어졌음
      expect(r.hasResult, false);
    });

    test('FAILED: 등급 null + failureCode 보존(안전 아님)', () {
      final r = AnalysisResult.fromJson({
        'analysisId': 101,
        'status': 'FAILED',
        'riskScore': null,
        'riskLevel': null,
        'failureCode': 'PIPELINE_ERROR',
      });
      expect(r.status, AnalysisStatus.failed);
      expect(r.riskLevel, isNull);
      expect(r.failureCode, 'PIPELINE_ERROR');
      expect(r.hasResult, false);
    });

    test('COMPLETED: 등급·점수 매핑', () {
      final r = AnalysisResult.fromJson({
        'analysisId': 101,
        'status': 'COMPLETED',
        'riskScore': 92,
        'riskLevel': 'HIGH',
      });
      expect(r.hasResult, true);
      expect(r.riskScore, 92);
      expect(r.riskLevel, RiskLevel.high);
    });

    test('값이 있는데 손상된 등급 문자열은 fail-secure로 high', () {
      final r = AnalysisResult.fromJson({
        'analysisId': 1,
        'status': 'COMPLETED',
        'riskScore': 10,
        'riskLevel': 'BOGUS',
      });
      expect(r.riskLevel, RiskLevel.high);
    });
  });

  group('AnalysisListItem.fromJson', () {
    test('PROCESSING 항목은 등급 null + status 보존', () {
      final it = AnalysisListItem.fromJson({
        'analysisId': 7,
        'status': 'PROCESSING',
        'maskedSender': '1588****',
        'messagePreview': '분석 중...',
        'riskScore': null,
        'riskLevel': null,
      });
      expect(it.status, AnalysisStatus.processing);
      expect(it.riskLevel, isNull);
      expect(it.riskScore, isNull);
    });
  });
}
