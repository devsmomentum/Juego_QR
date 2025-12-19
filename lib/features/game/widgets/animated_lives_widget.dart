import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class AnimatedLivesWidget extends StatefulWidget {
  final int lives;
  const AnimatedLivesWidget({super.key, required this.lives});

  @override
  State<AnimatedLivesWidget> createState() => _AnimatedLivesWidgetState();
}

class _AnimatedLivesWidgetState extends State<AnimatedLivesWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  int _lastLives = 3;

  @override
  void initState() {
    super.initState();
    _lastLives = widget.lives;
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.5), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.5, end: 1.0), weight: 50),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(AnimatedLivesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lives < _lastLives) {
      _controller.forward(from: 0.0);
    }
    _lastLives = widget.lives;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.dangerRed.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: widget.lives <= 1 ? AppTheme.dangerRed : AppTheme.dangerRed.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.favorite, color: AppTheme.dangerRed, size: 14),
            const SizedBox(width: 4),
            Text(
              'x${widget.lives}',
              style: TextStyle(
                color: widget.lives <= 1 ? AppTheme.dangerRed : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
