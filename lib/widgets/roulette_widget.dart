import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/prize_config.dart';
import '../config/app_colors.dart';
import '../services/sound_service.dart';

class RouletteWidget extends StatefulWidget {
  final int winningIndex;
  final VoidCallback onSpinComplete;

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
  int _lastTickSection = -1;
  DateTime _lastSoundTime = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSpin());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSpinTick() {
    final section = (_animation.value / 60.0).floor();
    if (section == _lastTickSection) return;
    _lastTickSection = section;

    // 최소 80ms 간격으로 클릭음 (빠른 구간에서 과도한 사운드 방지)
    final now = DateTime.now();
    if (now.difference(_lastSoundTime).inMilliseconds < 80) return;
    _lastSoundTime = now;

    SoundService().playTick();
  }

  void _startSpin() {
    if (_isSpinning) return;
    setState(() => _isSpinning = true);

    const sectionAngle = 360.0 / 6;
    final targetAngle =
        (widget.winningIndex * sectionAngle) + (sectionAngle / 2);
    final totalRotation = (360.0 * 5) + targetAngle;

    _animation = Tween<double>(begin: 0, end: totalRotation).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _animation.addListener(_onSpinTick);

    _controller.forward().then((_) {
      SoundService().playWin();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) widget.onSpinComplete();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth > 0
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width - 80;
        final wheelSize = (availableWidth * 0.88).clamp(220.0, 340.0);

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFFDF7), Color(0xFFFFF8E1)],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 타이틀
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppColors.goldGradient,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🍀', style: TextStyle(fontSize: 22)),
                    SizedBox(width: 10),
                    Text(
                      '오늘의 행운 룰렛',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text('🍀', style: TextStyle(fontSize: 22)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 룰렛 휠
              Stack(
                alignment: Alignment.center,
                children: [
                  // 외부 링 (그라디언트)
                  Container(
                    width: wheelSize + 20,
                    height: wheelSize + 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: AppColors.goldGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.4),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),

                  // 회전 휠
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: -_animation.value * math.pi / 180,
                        child: child,
                      );
                    },
                    child: Container(
                      width: wheelSize,
                      height: wheelSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border:
                            Border.all(color: AppColors.primaryLight, width: 3),
                      ),
                      child: CustomPaint(
                        painter: _RoulettePainter(prizeStructure),
                      ),
                    ),
                  ),

                  // 중앙 원
                  Container(
                    width: wheelSize * 0.26,
                    height: wheelSize * 0.26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Colors.white, AppColors.primarySurface],
                      ),
                      border: Border.all(
                          color: AppColors.primaryLight, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '🍀',
                        style: TextStyle(fontSize: wheelSize * 0.1),
                      ),
                    ),
                  ),

                  // 포인터 (상단)
                  Positioned(
                    top: 0,
                    child: CustomPaint(
                      size: const Size(24, 32),
                      painter: _ArrowPainter(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 스핀 상태 표시
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Text(
                  '✨ 행운을 돌리는 중... ✨',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
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

    for (int i = 0; i < prizes.length; i++) {
      final startAngle = i * sectionAngle - math.pi / 2;
      final sectionColor = _parseColor(prizes[i].color);

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sectionAngle,
          false,
        )
        ..close();

      // 섹션 배경 (밝은 채도)
      final paint = Paint()
        ..color = sectionColor.withOpacity(0.15)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, paint);

      // 섹션 색상 (바깥쪽 테두리 느낌으로 arc)
      final arcPaint = Paint()
        ..color = sectionColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawPath(path, arcPaint);

      // 섹션 내부 채우기 (반투명)
      final fillPaint = Paint()
        ..shader = RadialGradient(
          colors: [sectionColor.withOpacity(0.35), sectionColor.withOpacity(0.08)],
          stops: const [0.3, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);

      // 텍스트
      final textAngle = startAngle + sectionAngle / 2;
      final textRadius = radius * 0.68;
      final textX = center.dx + textRadius * math.cos(textAngle);
      final textY = center.dy + textRadius * math.sin(textAngle);

      final textPainter = TextPainter(
        text: TextSpan(
          text: prizes[i].displayName,
          style: TextStyle(
            color: sectionColor.withOpacity(0.9),
            fontSize: size.width * 0.062,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(
                color: Colors.white.withOpacity(0.9),
                offset: const Offset(1, 1),
                blurRadius: 3,
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

class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryDark
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();

    // 흰 테두리
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
