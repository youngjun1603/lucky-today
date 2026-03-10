import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/prize_config.dart';

class RouletteWidget extends StatefulWidget {
  final int winningIndex; // 당첨될 인덱스
  final VoidCallback onSpinComplete; // 회전 완료 콜백

  const RouletteWidget({
    super.key,
    required this.winningIndex,
    required this.onSpinComplete,
  });

  @override
  State<RouletteWidget> createState() => _RouletteWidgetState();
}

class _RouletteWidgetState extends State<RouletteWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isSpinning = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    // 자동 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startSpin();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startSpin() {
    if (_isSpinning) return;

    setState(() => _isSpinning = true);

    // 각 경품은 360도 / 6 = 60도씩 차지
    const sectionAngle = 360.0 / 6;

    // 당첨 위치 계산 (중앙을 맞추기 위해 섹션의 중간으로)
    final targetAngle = (widget.winningIndex * sectionAngle) + (sectionAngle / 2);

    // 최소 5바퀴 + 당첨 위치
    final totalRotation = (360.0 * 5) + targetAngle;

    _animation = Tween<double>(
      begin: 0,
      end: totalRotation,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward().then((_) {
      // 회전 완료 후 0.5초 대기 후 콜백
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          widget.onSpinComplete();
        }
      });
    });
  }

  Color _parseColor(String hexColor) {
    hexColor = hexColor.replaceAll('#', '');
    return Color(int.parse('FF$hexColor', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1A1A1A),
            const Color(0xFF2D2D2D),
            const Color(0xFF1A1A1A),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 상단 타이틀
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFFD700),
                    Color(0xFFFFE55C),
                    Color(0xFFFFD700),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '💎 ',
                        style: TextStyle(fontSize: 28),
                      ),
                      Text(
                        '럭셔리 룰렛',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        ' 💎',
                        style: TextStyle(fontSize: 28),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    '최고의 행운이 당신을 기다립니다',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1A1A1A),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            
            // 룰렛 컨테이너
            Stack(
              alignment: Alignment.center,
              children: [
                // 외부 금색 링
                Container(
                  width: 360,
                  height: 360,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFFD700),
                        Color(0xFFFFE55C),
                        Color(0xFFFFD700),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withOpacity(0.6),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                ),
                
                // 룰렛 휠
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: -_animation.value * math.pi / 180,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 340,
                    height: 340,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1A1A1A),
                      border: Border.all(color: const Color(0xFFFFD700), width: 4),
                    ),
                    child: CustomPaint(
                      painter: _RoulettePainter(prizeStructure),
                    ),
                  ),
                ),
                
                // 중앙 금색 원
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [
                        Color(0xFFFFE55C),
                        Color(0xFFFFD700),
                      ],
                    ),
                    border: Border.all(color: const Color(0xFF1A1A1A), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withOpacity(0.8),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      '💎',
                      style: TextStyle(fontSize: 40),
                    ),
                  ),
                ),
                
                // 포인터 (상단 금색 화살표)
                Positioned(
                  top: -5,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [
                          Color(0xFFFFE55C),
                          Color(0xFFFFD700),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withOpacity(0.8),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                    child: CustomPaint(
                      size: const Size(30, 40),
                      painter: _ArrowPainter(),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 40),
            
            // 참담기 버튼
            Container(
              width: 240,
              height: 70,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFFD700),
                    Color(0xFFFFE55C),
                    Color(0xFFFFD700),
                  ],
                ),
                borderRadius: BorderRadius.circular(35),
                border: Border.all(color: const Color(0xFF1A1A1A), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withOpacity(0.6),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  '🎰 럭셔리 스핀 🎰',
                  style: TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 하단 안내
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1A1A1A),
                    Color(0xFF2D2D2D),
                  ],
                ),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0xFFFFD700), width: 2),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '✨ ',
                    style: TextStyle(fontSize: 24),
                  ),
                  Text(
                    '매일 새로운 행운이 기다립니다',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFD700),
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    ' ✨',
                    style: TextStyle(fontSize: 24),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoulettePainter extends CustomPainter {
  final List<PrizeStructure> prizes;

  _RoulettePainter(this.prizes);

  Color _parseColor(String hexColor) {
    hexColor = hexColor.replaceAll('#', '');
    return Color(int.parse('FF$hexColor', radix: 16));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sectionAngle = 2 * math.pi / prizes.length;

    // 각 섹션 그리기
    for (int i = 0; i < prizes.length; i++) {
      final startAngle = i * sectionAngle - math.pi / 2; // -90도부터 시작 (12시 방향)
      
      // 섹션 색상 (럭셔리 카지노 테마: 검은색/금색)
      Color color1, color2;
      if (prizes[i].displayName == 'JACKPOT') {
        // JACKPOT: 빨간색 그라데이션
        color1 = const Color(0xFFFF0000);
        color2 = const Color(0xFFCC0000);
      } else if (prizes[i].displayName == '100P') {
        // 100P: 보라색 그라데이션
        color1 = const Color(0xFF9B59B6);
        color2 = const Color(0xFF8E44AD);
      } else {
        // 일반 경품: 금색/검은색 교차 패턴
        if (i % 2 == 0) {
          color1 = const Color(0xFFFFD700); // 금색
          color2 = const Color(0xFFFFE55C);
        } else {
          color1 = const Color(0xFF2D2D2D); // 진한 검은색
          color2 = const Color(0xFF1A1A1A);
        }
      }

      // 그라데이션 섹션 그리기
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sectionAngle,
          false,
        )
        ..close();

      // 그라데이션 적용
      final gradient = RadialGradient(
        colors: [color2, color1],
        stops: const [0.0, 1.0],
      );
      
      final paint = Paint()
        ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.fill;

      canvas.drawPath(path, paint);

      // 흰색 테두리
      final borderPaint = Paint()
        ..color = const Color(0xFFFFD700) // 금색 테두리
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawPath(path, borderPaint);

      // 텍스트 그리기
      final textAngle = startAngle + sectionAngle / 2;
      final textRadius = radius * 0.7;
      final textX = center.dx + textRadius * math.cos(textAngle);
      final textY = center.dy + textRadius * math.sin(textAngle);

      final textPainter = TextPainter(
        text: TextSpan(
          text: prizes[i].displayName,
          style: TextStyle(
            color: (i % 2 == 0) ? const Color(0xFF1A1A1A) : const Color(0xFFFFD700), // 교차 색상
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            shadows: const [
              Shadow(
                color: Colors.black87,
                offset: Offset(2, 2),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      canvas.save();
      canvas.translate(textX, textY);
      canvas.rotate(textAngle + math.pi / 2);
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 금색 화살표 페인터
class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, 0) // 상단 중앙
      ..lineTo(0, size.height) // 왼쪽 하단
      ..lineTo(size.width, size.height) // 오른쪽 하단
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
