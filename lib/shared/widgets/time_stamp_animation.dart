import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../core/theme/app_theme.dart';

class TimeStampAnimation extends StatefulWidget {
  final int index;
  final VoidCallback? onComplete;

  const TimeStampAnimation({
    super.key,
    required this.index,
    this.onComplete,
  });

  @override
  State<TimeStampAnimation> createState() => _TimeStampAnimationState();
}

class _TimeStampAnimationState extends State<TimeStampAnimation>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _rotationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  final List<TimeStampData> _stamps = [
    TimeStampData(
      title: 'Sello Temporal 1',
      icon: Icons.extension,
      gradient: [const Color(0xFF3B82F6), const Color(0xFF06B6D4)],
    ),
    TimeStampData(
      title: 'Sello Temporal 2',
      icon: Icons.lock_open,
      gradient: [const Color(0xFF06B6D4), const Color(0xFF10B981)],
    ),
    TimeStampData(
      title: 'Sello Temporal 3',
      icon: Icons.history_edu,
      gradient: [const Color(0xFF10B981), const Color(0xFF84CC16)],
    ),
    TimeStampData(
      title: 'Sello Temporal 4',
      icon: Icons.warning_amber,
      gradient: [const Color(0xFF84CC16), const Color(0xFFF59E0B)],
    ),
    TimeStampData(
      title: 'Sello Temporal 5',
      icon: Icons.cable,
      gradient: [const Color(0xFFF59E0B), const Color(0xFFEF4444)],
    ),
    TimeStampData(
      title: 'Sello Temporal 6',
      icon: Icons.palette,
      gradient: [const Color(0xFFEF4444), const Color(0xFFEC4899)],
    ),
    TimeStampData(
      title: 'Sello Temporal 7',
      icon: Icons.visibility,
      gradient: [const Color(0xFFEC4899), const Color(0xFFD946EF)],
    ),
    TimeStampData(
      title: 'Sello Temporal 8',
      icon: Icons.settings_suggest,
      gradient: [const Color(0xFFD946EF), const Color(0xFF8B5CF6)],
    ),
    TimeStampData(
      title: 'Sello Temporal 9',
      icon: Icons.flash_on,
      gradient: [const Color(0xFF8B5CF6), const Color(0xFF6366F1)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2).chain(CurveTween(curve: Curves.easeOutBack)), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 30),
    ]).animate(_mainController);

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)),
    );

    _mainController.forward().then((_) {
      if (mounted && widget.onComplete != null) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted && widget.onComplete != null) {
             widget.onComplete!();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Clamping index to avoid range errors
    final stampIndex = (widget.index - 1).clamp(0, _stamps.length - 1);
    final stamp = _stamps[stampIndex];

    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
        );
      },
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                // Particle Burst Background
                ...List.generate(12, (index) {
                  final angle = (index * 30) * math.pi / 180;
                  final distance = 100.0 * _mainController.value;
                  return Opacity(
                    opacity: (1.0 - _mainController.value).clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(math.cos(angle) * distance, math.sin(angle) * distance),
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: stamp.gradient[0],
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: stamp.gradient[0], blurRadius: 10, spreadRadius: 2),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                // Glowing background
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: stamp.gradient[0].withOpacity(0.4 * _mainController.value),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
                // Rotating outer ring
                AnimatedBuilder(
                  animation: _rotationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _rotationController.value * 2 * math.pi,
                      child: CustomPaint(
                        size: const Size(180, 180),
                        painter: RingPainter(stamp.gradient),
                      ),
                    );
                  },
                ),
                // Main Seal
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: stamp.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(
                    stamp.icon,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: stamp.gradient,
              ).createShader(bounds),
              child: Text(
                stamp.title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
            ),
            const Text(
              "SELLO OBTENIDO",
              style: TextStyle(
                fontSize: 12,
                color: Colors.white70,
                letterSpacing: 4,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 60),
            // Botón de Saltar
            TextButton(
              onPressed: widget.onComplete,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white24,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Colors.white10),
                ),
              ),
              child: const Text(
                "SALTAR",
                style: TextStyle(letterSpacing: 2, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RingPainter extends CustomPainter {
  final List<Color> colors;

  RingPainter(this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = SweepGradient(colors: colors).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw broken ring
    for (int i = 0; i < 8; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        (i * 45 * math.pi / 180),
        (30 * math.pi / 180),
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class TimeStampData {
  final String title;
  final IconData icon;
  final List<Color> gradient;

  TimeStampData({
    required this.title,
    required this.icon,
    required this.gradient,
  });
}
