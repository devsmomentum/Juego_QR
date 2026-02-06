import 'package:flutter/material.dart';

class ShieldBreakEffect extends StatefulWidget {
  final VoidCallback? onComplete;

  const ShieldBreakEffect({super.key, this.onComplete});

  @override
  State<ShieldBreakEffect> createState() => _ShieldBreakEffectState();
}

class _ShieldBreakEffectState extends State<ShieldBreakEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000), // Increased duration
    );

    // Bounce / Elastic scale up
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2).chain(CurveTween(curve: Curves.easeOut)), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.5).chain(CurveTween(curve: Curves.easeIn)), weight: 40),
    ]).animate(_controller);

    // Shake effect
    _shakeAnim = TweenSequence<double>([
       TweenSequenceItem(tween: Tween(begin: 0, end: 10), weight: 10),
       TweenSequenceItem(tween: Tween(begin: 10, end: -10), weight: 10),
       TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 10),
       TweenSequenceItem(tween: Tween(begin: 10, end: 0), weight: 10),
       TweenSequenceItem(tween: ConstantTween(0), weight: 60),
    ]).animate(_controller);

    // Fade out at the end
    _opacityAnim = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_controller);

    _controller.forward().then((_) {
      if (widget.onComplete != null) {
        widget.onComplete!();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnim.value,
              child: Transform.translate(
                offset: Offset(_shakeAnim.value, 0),
                child: Transform.scale(
                  scale: _scaleAnim.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                           // Glow beneath
                           Container(
                              width: 100, height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.cyanAccent.withOpacity(0.5),
                                    blurRadius: 40,
                                    spreadRadius: 10,
                                  )
                                ]
                              ),
                           ),
                           // Broken Shield Icon
                           const Icon(
                              Icons.gpp_bad_rounded,
                              size: 100,
                              color: Colors.cyanAccent,
                           ),
                           // Cracks overlay (Red)
                           const Icon(
                              Icons.flash_on_rounded,
                              size: 80,
                              color: Colors.redAccent,
                           ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red, width: 2),
                        ),
                        child: const Text(
                          '¡ESCUDO ROTO!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                            decoration: TextDecoration.none,
                            shadows: [
                              Shadow(color: Colors.black45, offset: Offset(2, 2), blurRadius: 4)
                            ]
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
