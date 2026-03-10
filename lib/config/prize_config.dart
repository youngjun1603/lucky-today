// 수수료율
const double feeRate = 0.35;

// 외부 경품 확률
const double externalPrizeProb = 0.05;

// 당첨 확률 구조
class PrizeStructure {
  final String range;
  final String displayName; // 룰렛에 표시될 이름
  final double probability;
  final double multiplier;
  final String color; // 룰렛 색상 (hex)

  const PrizeStructure({
    required this.range,
    required this.displayName,
    required this.probability,
    required this.multiplier,
    required this.color,
  });
}

// 6종 경품 구성 (룰렛용)
const List<PrizeStructure> prizeStructure = [
  PrizeStructure(
    range: '1-2 포인트',
    displayName: '꽝',
    probability: 40.0,
    multiplier: 0.2,
    color: '#9E9E9E', // 회색
  ),
  PrizeStructure(
    range: '3-5 포인트',
    displayName: '3-5P',
    probability: 30.0,
    multiplier: 0.5,
    color: '#2196F3', // 파란색
  ),
  PrizeStructure(
    range: '5-10 포인트',
    displayName: '5-10P',
    probability: 15.0,
    multiplier: 1.0,
    color: '#4CAF50', // 녹색
  ),
  PrizeStructure(
    range: '20-50 포인트',
    displayName: '20-50P',
    probability: 10.0,
    multiplier: 4.0,
    color: '#FF9800', // 주황색
  ),
  PrizeStructure(
    range: '100 포인트',
    displayName: '100P',
    probability: 4.0,
    multiplier: 10.0,
    color: '#9C27B0', // 보라색
  ),
  PrizeStructure(
    range: '500 포인트',
    displayName: 'JACKPOT',
    probability: 1.0,
    multiplier: 50.0,
    color: '#F44336', // 빨간색
  ),
];

double probabilitySum() {
  return prizeStructure.fold(0.0, (sum, prize) => sum + prize.probability);
}
