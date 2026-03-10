import 'dart:math';

/// 외부 포인트사 API Mock 서비스
/// 실제 환경에서는 HTTP 클라이언트로 실제 API를 호출합니다
class ExternalPointApiService {
  final Random _random = Random();

  /// 사용자의 외부 포인트 잔액 조회
  /// 
  /// 실제 구현 예시:
  /// ```dart
  /// final response = await http.get(
  ///   Uri.parse('https://api.pointcompany.com/users/$userId/balance'),
  ///   headers: {'Authorization': 'Bearer $apiKey'},
  /// );
  /// return json.decode(response.body)['balance'];
  /// ```
  Future<Map<String, dynamic>> getExternalBalance(String userId) async {
    // API 호출 시뮬레이션
    await Future.delayed(const Duration(seconds: 1));

    // Mock 데이터 반환
    return {
      'success': true,
      'balance': 50000 + _random.nextInt(50000), // 50,000 ~ 100,000 포인트
      'currency': 'KRW',
      'userId': userId,
    };
  }

  /// 외부 포인트를 앱 내부 포인트로 충전 (전환)
  /// 
  /// 실제 구현 예시:
  /// ```dart
  /// final response = await http.post(
  ///   Uri.parse('https://api.pointcompany.com/charge'),
  ///   headers: {
  ///     'Authorization': 'Bearer $apiKey',
  ///     'Content-Type': 'application/json',
  ///   },
  ///   body: json.encode({
  ///     'userId': userId,
  ///     'amount': amount,
  ///     'transactionId': transactionId,
  ///   }),
  /// );
  /// ```
  Future<Map<String, dynamic>> chargePoints({
    required String userId,
    required int amount,
    required String transactionId,
  }) async {
    // API 호출 시뮬레이션
    await Future.delayed(const Duration(seconds: 2));

    // 성공률 95% (실제로는 외부 API 응답에 따라 결정됨)
    final success = _random.nextDouble() > 0.05;

    if (success) {
      return {
        'success': true,
        'externalTransactionId': 'EXT_${_generateTransactionId()}',
        'amount': amount,
        'userId': userId,
        'completedAt': DateTime.now().toIso8601String(),
      };
    } else {
      return {
        'success': false,
        'error': '외부 포인트사 서버 오류',
        'errorCode': 'EXTERNAL_API_ERROR',
      };
    }
  }

  /// 앱 내부 포인트를 외부 포인트로 환전
  /// 
  /// 실제 구현 예시:
  /// ```dart
  /// final response = await http.post(
  ///   Uri.parse('https://api.pointcompany.com/withdraw'),
  ///   headers: {
  ///     'Authorization': 'Bearer $apiKey',
  ///     'Content-Type': 'application/json',
  ///   },
  ///   body: json.encode({
  ///     'userId': userId,
  ///     'amount': amount,
  ///     'transactionId': transactionId,
  ///   }),
  /// );
  /// ```
  Future<Map<String, dynamic>> withdrawPoints({
    required String userId,
    required int amount,
    required String transactionId,
  }) async {
    // API 호출 시뮬레이션
    await Future.delayed(const Duration(seconds: 2));

    // 성공률 95%
    final success = _random.nextDouble() > 0.05;

    if (success) {
      return {
        'success': true,
        'externalTransactionId': 'EXT_${_generateTransactionId()}',
        'amount': amount,
        'userId': userId,
        'completedAt': DateTime.now().toIso8601String(),
      };
    } else {
      return {
        'success': false,
        'error': '외부 포인트사 서버 오류',
        'errorCode': 'EXTERNAL_API_ERROR',
      };
    }
  }

  /// 외부 거래 상태 조회
  /// 
  /// 실제 구현 예시:
  /// ```dart
  /// final response = await http.get(
  ///   Uri.parse('https://api.pointcompany.com/transactions/$externalTransactionId'),
  ///   headers: {'Authorization': 'Bearer $apiKey'},
  /// );
  /// ```
  Future<Map<String, dynamic>> getTransactionStatus(
      String externalTransactionId) async {
    await Future.delayed(const Duration(milliseconds: 500));

    return {
      'success': true,
      'status': 'COMPLETED',
      'externalTransactionId': externalTransactionId,
    };
  }

  String _generateTransactionId() {
    const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    return List.generate(12, (index) => chars[_random.nextInt(chars.length)])
        .join();
  }
}
