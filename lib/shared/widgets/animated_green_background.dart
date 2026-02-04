import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedGreenBackground extends StatefulWidget {
  final Widget? child;

  const AnimatedGreenBackground({
    super.key,
    this.child,
  });

  @override
  State<AnimatedGreenBackground> createState() => _AnimatedGreenBackgroundState();
}

class _AnimatedGreenBackgroundState extends State<AnimatedGreenBackground>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  final List<BackgroundParticle> _particles = [];

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Initialize random golden particles (glints)
    final random = math.Random();
    for (int i = 0; i < 40; i++) {
        _particles.add(BackgroundParticle(
          x: random.nextDouble() * 100,
          y: random.nextDouble() * 100,
          size: 1.5 + random.nextDouble() * 2.5,
          speed: 0.1 + random.nextDouble() * 0.3,
          opacity: 0.4 + random.nextDouble() * 0.4,
          isSparkle: random.nextBool(),
        ));
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Light Green Base with vibrant gradient
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2E7D32), // Emerald Green
                  Color(0xFF43A047), // Light Emerald
                  Color(0xFF66BB6A), // Bright Green
                ],
              ),
            ),
          ),
        ),
        
        // 2. Cyber Grid (Matches Dark Mode structure)
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _mainController,
            builder: (context, child) {
              return CustomPaint(
                painter: _GridPainter(_mainController.value, Colors.white), 
              );
            },
          ),
        ),

        // 3. Moving Golden Glints (Particles)
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _mainController,
            builder: (context, child) {
              return CustomPaint(
                painter: _GlintPainter(_mainController.value, _particles),
              );
            },
          ),
        ),

        // 4. Subtle Vignette Overlay (To maintain readability at edges)
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.8,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.15),
                ],
              ),
            ),
          ),
        ),

        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class BackgroundParticle {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double opacity;
  final bool isSparkle;

  BackgroundParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    this.isSparkle = false,
  });
}

class _GridPainter extends CustomPainter {
  final double progress;
  final Color color;

  _GridPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.2) // Slightly more visible grid
      ..strokeWidth = 1.0;

    const double spacing = 60.0;
    final double offset = progress * spacing;

    for (double y = 0; y < size.height + spacing; y += spacing) {
      canvas.drawLine(
        Offset(0, y + (offset % spacing)),
        Offset(size.width, y + (offset % spacing)),
        paint,
      );
    }
    for (double x = 0; x < size.width + spacing; x += spacing) {
      canvas.drawLine(
        Offset(x + (offset % spacing), 0),
        Offset(x + (offset % spacing), size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _GlintPainter extends CustomPainter {
  final double progress;
  final List<BackgroundParticle> particles;

  _GlintPainter(this.progress, this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final goldColor = const Color(0xFFFFD700); // Gold

    for (var p in particles) {
      // Calculate shimmering opacity
      double currentOpacity = p.opacity;
      if (p.isSparkle) {
        currentOpacity *= (0.7 + 0.3 * math.sin(progress * 5 * math.pi + p.x));
      }

      final paint = Paint()
        ..color = goldColor.withOpacity(currentOpacity)
        ..style = PaintingStyle.fill;

      final x = (p.x / 100) * size.width;
      final y = ((p.y + (progress * p.speed * 100)) % 100 / 100) * size.height;

      // Draw particle
      if (p.isSparkle) {
         _drawSparkle(canvas, Offset(x, y), p.size, paint);
      } else {
         canvas.drawCircle(Offset(x, y), p.size, paint);
      }
      
      // Glow effect
      final glowPaint = Paint()
        ..color = goldColor.withOpacity(currentOpacity * 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(x, y), p.size * 2.5, glowPaint);
    }
  }

  void _drawSparkle(Canvas canvas, Offset center, double size, Paint paint) {
    final Path path = Path();
    path.moveTo(center.dx, center.dy - size * 2.5);
    path.lineTo(center.dx + size * 0.5, center.dy - size * 0.5);
    path.lineTo(center.dx + size * 2.5, center.dy);
    path.lineTo(center.dx + size * 0.5, center.dy + size * 0.5);
    path.lineTo(center.dx, center.dy + size * 2.5);
    path.lineTo(center.dx - size * 0.5, center.dy + size * 0.5);
    path.lineTo(center.dx - size * 2.5, center.dy);
    path.lineTo(center.dx - size * 0.5, center.dy - size * 0.5);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
