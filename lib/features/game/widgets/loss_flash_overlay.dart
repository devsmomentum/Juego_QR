import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class LossFlashOverlay extends StatefulWidget {
  final int lives;
  const LossFlashOverlay({super.key, required this.lives});

  @override
  State<LossFlashOverlay> createState() => _LossFlashOverlayState();
}

class _LossFlashOverlayState extends State<LossFlashOverlay> {
  bool _showFlash = false;
  int _lastLives = 3;

  @override
  void initState() {
    super.initState();
    _lastLives = widget.lives;
  }

  @override
  void didUpdateWidget(LossFlashOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lives < _lastLives) {
      setState(() => _showFlash = true);
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _showFlash = false);
      });
    }
    _lastLives = widget.lives;
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _showFlash ? 0.3 : 0.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.dangerRed, width: 10),
            color: AppTheme.dangerRed.withOpacity(0.5),
          ),
        ),
      ),
    );
  }
}
