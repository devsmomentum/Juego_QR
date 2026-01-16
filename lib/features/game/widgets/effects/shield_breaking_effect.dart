import 'dart:math';
import 'package:flutter/material.dart';

/// Efecto visual que muestra el escudo rompiéndose cuando protege de un ataque.
/// Muestra un destello azul/cyan que se expande y fragmenta.
class ShieldBreakingEffect extends StatefulWidget {
  final VoidCallback? onComplete;
  
  const ShieldBreakingEffect({super.key, this.onComplete});

  @override
  State<ShieldBreakingEffect> createState() => _ShieldBreakingEffectState();
}

class _ShieldBreakingEffectState extends State<ShieldBreakingEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 2.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.3, 1.0)),
    );
    
    _controller.forward().then((_) => widget.onComplete?.call());
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
        return Container(
          color: Colors.cyanAccent.withOpacity(0.15 * _opacityAnimation.value),
          child: Stack(
            children: [
              // Destello central
              Center(
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Opacity(
                    opacity: _opacityAnimation.value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withOpacity(0.8),
                            Colors.cyanAccent.withOpacity(0.6),
                            Colors.cyan.withOpacity(0.3),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.3, 0.6, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.cyanAccent.withOpacity(0.6),
                            blurRadius: 40,
                            spreadRadius: 20,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.shield,
                        size: 60,
                        color: Colors.white.withOpacity(_opacityAnimation.value),
                      ),
                    ),
                  ),
                ),
              ),
              
              // Fragmentos de escudo rompiendo
              if (_controller.value > 0.2)
                ...List.generate(8, (index) {
                  final angle = (index / 8) * 2 * pi;
                  final distance = 100 * (_controller.value - 0.2) * 1.25;
                  return Positioned(
                    left: MediaQuery.of(context).size.width / 2 + cos(angle) * distance - 10,
                    top: MediaQuery.of(context).size.height / 2 + sin(angle) * distance - 10,
                    child: Opacity(
                      opacity: (1 - _controller.value).clamp(0.0, 1.0),
                      child: Transform.rotate(
                        angle: angle + _controller.value * 2,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.cyanAccent.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.cyanAccent.withOpacity(0.4),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              
              // Texto de protección
              Positioned(
                bottom: MediaQuery.of(context).size.height * 0.35,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: const Text(
                    '¡ESCUDO ROTO!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.cyanAccent,
                          blurRadius: 20,
                        ),
                        Shadow(
                          color: Colors.black,
                          offset: Offset(2, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              Positioned(
                bottom: MediaQuery.of(context).size.height * 0.30,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: const Text(
                    'Tu protección ha sido consumida',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
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
