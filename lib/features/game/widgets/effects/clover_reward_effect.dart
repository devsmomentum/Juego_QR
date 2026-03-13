import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/coin_image.dart';

class CloverRewardEffect extends StatefulWidget {
  final int amount;
  final VoidCallback onComplete;

  const CloverRewardEffect({
    super.key,
    required this.amount,
    required this.onComplete,
  });

  @override
  State<CloverRewardEffect> createState() => _CloverRewardEffectState();
}

class _CloverRewardEffectState extends State<CloverRewardEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_CloverParticle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // Create particles
    for (int i = 0; i < 25; i++) {
      _particles.add(_CloverParticle(
        angle: _random.nextDouble() * 2 * math.pi,
        distance: 50 + _random.nextDouble() * 150,
        size: 15 + _random.nextDouble() * 20,
        speed: 0.5 + _random.nextDouble() * 1.5,
        rotation: _random.nextDouble() * 2 * math.pi,
        delay: _random.nextDouble() * 0.4,
      ));
    }

    _controller.forward().then((_) => widget.onComplete());
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
      builder: (context, child) {
        final t = _controller.value;
        
        // Entrance animation for the center text (burst)
        double textScale = 0.0;
        double textOpacity = 0.0;
        if (t < 0.2) {
          textScale = 0.5 + (t / 0.2) * 0.7; // 0.5 to 1.2
          textOpacity = (t / 0.2);
        } else if (t < 0.3) {
          textScale = 1.2 - ((t - 0.2) / 0.1) * 0.2; // 1.2 to 1.0 (settle)
          textOpacity = 1.0;
        } else if (t > 0.8) {
          textScale = 1.0 + ((t - 0.8) / 0.2) * 0.5; // fly away
          textOpacity = 1.0 - ((t - 0.8) / 0.2);
        } else {
          textScale = 1.0;
          textOpacity = 1.0;
        }

        return Material(
          color: Colors.black.withOpacity(0.4 * (t < 0.1 ? t / 0.1 : (t > 0.9 ? 1 - (t - 0.9) / 0.1 : 1.0))),
          child: Stack(
            children: [
              // Particles
              ..._particles.map((p) {
                // Individual particle progress
                double pT = (t - p.delay) / (1.0 - p.delay);
                if (pT < 0) return const SizedBox();
                if (pT > 1.0) pT = 1.0;

                // Easing for outward movement
                final easedT = Curves.easeOutCubic.transform(pT);
                final x = math.cos(p.angle) * p.distance * easedT;
                final y = math.sin(p.angle) * p.distance * easedT - (easedT * 50); // Slight float up
                
                final pOpacity = pT < 0.1 
                    ? pT / 0.1 
                    : (pT > 0.6 ? 1.0 - (pT - 0.6) / 0.4 : 1.0);
                
                return Positioned(
                  left: MediaQuery.of(context).size.width / 2 + x - (p.size / 2),
                  top: MediaQuery.of(context).size.height / 2 + y - (p.size / 2),
                  child: Opacity(
                    opacity: pOpacity,
                    child: Transform.rotate(
                      angle: p.rotation + (pT * 4),
                      child: CoinImage(size: p.size),
                    ),
                  ),
                );
              }),

              // Central Content
              Center(
                child: Opacity(
                  opacity: textOpacity,
                  child: Transform.scale(
                    scale: textScale,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Large Glowy Coin
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.dGoldMain.withOpacity(0.5),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: const CoinImage(size: 80),
                        ),
                        const SizedBox(height: 20),
                        
                        // Text with Glitch/Cyber Style
                        Stack(
                          children: [
                            Text(
                              '+${widget.amount}',
                              style: TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: AppTheme.dGoldMain,
                                    blurRadius: 10,
                                    offset: Offset(0, 0),
                                  ),
                                  Shadow(
                                    color: Colors.white.withOpacity(0.8),
                                    blurRadius: 2,
                                    offset: Offset(0, 0),
                                  ),
                                ],
                              ),
                            ),
                            // Cyberpunk glitch line (decorative)
                            Positioned(
                              top: 30,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 2,
                                color: AppTheme.dGoldMain.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                        
                        Text(
                          'TRÉBOLES OBTENIDOS',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.dGoldMain,
                            letterSpacing: 4,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 4),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        Text(
                          '¡SABOTAJE EXITOSO!',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withOpacity(0.5),
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CloverParticle {
  final double angle;
  final double distance;
  final double size;
  final double speed;
  final double rotation;
  final double delay;

  _CloverParticle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.speed,
    required this.rotation,
    required this.delay,
  });
}
