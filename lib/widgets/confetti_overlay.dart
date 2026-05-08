import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 당첨 결과 팝업 위에 표시되는 폭죽 파티클 오버레이
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({super.key});

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> _particles;

  static const _colors = [
    Color(0xFFF5A623),
    Color(0xFF34C98E),
    Color(0xFF5B9CF6),
    Color(0xFFFF4757),
    Color(0xFFA55EEA),
    Color(0xFFFFD700),
    Color(0xFFFF69B4),
    Color(0xFF00CED1),
  ];

  @override
  void initState() {
    super.initState();
    final rand = math.Random();
    _particles = List.generate(90, (_) => _Particle(rand));
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return IgnorePointer(
          child: CustomPaint(
            painter: _ConfettiPainter(
              _particles,
              _controller.value,
              _colors,
              MediaQuery.of(context).size,
            ),
            size: MediaQuery.of(context).size,
          ),
        );
      },
    );
  }
}

class _Particle {
  final double angle;
  final double speed;
  final double width;
  final double height;
  final int colorIndex;
  final double rotationSpeed;
  // 두 번째 폭죽 발사 지점 (왼쪽 / 오른쪽 위)
  final bool fromLeft;

  _Particle(math.Random rand)
      : angle = -math.pi * 0.9 + rand.nextDouble() * math.pi * 1.8,
        speed = 180 + rand.nextDouble() * 380,
        width = 6 + rand.nextDouble() * 7,
        height = 3 + rand.nextDouble() * 5,
        colorIndex = rand.nextInt(8),
        rotationSpeed = (rand.nextDouble() - 0.5) * 14,
        fromLeft = rand.nextBool();
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;
  final List<Color> colors;
  final Size screenSize;

  _ConfettiPainter(this.particles, this.t, this.colors, this.screenSize);

  @override
  void paint(Canvas canvas, Size size) {
    const gravity = 350.0;

    for (final p in particles) {
      // 화면 상단 좌우에서 발사
      final cx = p.fromLeft ? screenSize.width * 0.2 : screenSize.width * 0.8;
      final cy = screenSize.height * 0.15;

      final dx = math.cos(p.angle) * p.speed * t;
      final dy = math.sin(p.angle) * p.speed * t + 0.5 * gravity * t * t;

      // t=0.65 이후부터 페이드아웃
      final opacity =
          t < 0.65 ? 1.0 : (1.0 - (t - 0.65) / 0.35).clamp(0.0, 1.0);
      if (opacity <= 0) continue;

      final paint = Paint()
        ..color = colors[p.colorIndex].withOpacity(opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(cx + dx, cy + dy);
      canvas.rotate(p.rotationSpeed * t * math.pi);
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset.zero, width: p.width, height: p.height),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}
