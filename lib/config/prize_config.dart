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
    color: '#BDC3C7',
  ),
  PrizeStructure(
    range: '3-5 포인트',
    displayName: '3-5P',
    probability: 30.0,
    multiplier: 0.5,
    color: '#5B9CF6',
  ),
  PrizeStructure(
    range: '5-10 포인트',
    displayName: '5-10P',
    probability: 15.0,
    multiplier: 1.0,
    color: '#34C98E',
  ),
  PrizeStructure(
    range: '20-50 포인트',
    displayName: '20-50P',
    probability: 10.0,
    multiplier: 4.0,
    color: '#F5A623',
  ),
  PrizeStructure(
    range: '100 포인트',
    displayName: '100P',
    probability: 4.0,
    multiplier: 10.0,
    color: '#A55EEA',
  ),
  PrizeStructure(
    range: '500 포인트',
    displayName: 'JACKPOT',
    probability: 1.0,
    multiplier: 50.0,
    color: '#FF4757',
  ),
];

double probabilitySum() {
  return prizeStructure.fold(0.0, (sum, prize) => sum + prize.probability);
}
