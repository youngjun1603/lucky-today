import 'dart:math';
import '../config/prize_config.dart';

class PrizeService {
  final Random _random = Random();

  /// 당첨 결과 선택
  PrizeStructure pickPrize() {
    final totalProb = probabilitySum();
    final rand = _random.nextDouble() * totalProb;

    double cumulative = 0.0;
    for (final prize in prizeStructure) {
      cumulative += prize.probability;
      if (rand <= cumulative) {
        return prize;
      }
    }

    // Fallback (should never reach here)
    return prizeStructure.first;
  }

  /// 0.0 ~ 1.0 사이의 난수 생성
  double randomFloat01() {
    return _random.nextDouble();
  }

  /// 고유 ID 생성 (간단한 UUID 대체)
  String generateId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final length = 25;
    return List.generate(
      length,
      (index) => chars[_random.nextInt(chars.length)],
    ).join();
  }
}
