import 'dart:math';
import 'package:flutter/material.dart';

/// Efecto visual que muestra el escudo rompiéndose cuando protege de un ataque.
/// Muestra un destello azul/cyan que se expande y fragmenta.
class ShieldBreakingEffect extends StatefulWidget {
  final VoidCallback? onComplete;
  final String? title;
  final String? subtitle;
  
  const ShieldBreakingEffect({
    super.key, 
    this.onComplete,
    this.title,
    this.subtitle,
  });

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
      duration: const Duration(milliseconds: 5000), // Increased to 5s
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 2.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.6, 1.0)), // Fade out later
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
          // Background flash: Blue tint
          color: Colors.blueAccent.withOpacity(0.15 * _opacityAnimation.value),
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
                            Colors.white.withOpacity(0.9),
                            Colors.cyanAccent.withOpacity(0.7), 
                            Colors.blueAccent.withOpacity(0.4),    
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.3, 0.6, 1.0],
                        ),
                        boxShadow: [
                           // Strong blue glow
                          BoxShadow(
                            color: Colors.cyanAccent.withOpacity(0.6),
                            blurRadius: 50,
                            spreadRadius: 20,
                          ),
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.4),
                            blurRadius: 80,
                            spreadRadius: 30,
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
              
              // Texto de protección - Improved styling
              Positioned(
                bottom: MediaQuery.of(context).size.height * 0.35,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: Material(
                    color: Colors.transparent,
                    child: Column(
                      children: [
                        // Shield Icon with glow
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.cyanAccent.withOpacity(0.5),
                                blurRadius: 30,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.shield_outlined, 
                            color: Colors.cyanAccent, 
                            size: 50,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Main title
                        Text(
                          widget.title ?? '¡ATAQUE BLOQUEADO!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36, 
                            fontWeight: FontWeight.w900, 
                            letterSpacing: 3.0,
                            decoration: TextDecoration.none,
                            shadows: [
                              Shadow(
                                color: Colors.cyanAccent,
                                blurRadius: 40,
                              ),
                              Shadow(
                                color: Colors.blueAccent,
                                blurRadius: 20,
                              ),
                              Shadow(
                                color: Colors.black,
                                offset: Offset(4, 4),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Subtitle
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            widget.subtitle ?? 'El objetivo tenía un escudo activo',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                              decoration: TextDecoration.none,
                              shadows: [
                                Shadow(
                                  color: Colors.black87,
                                  offset: Offset(2, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
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
