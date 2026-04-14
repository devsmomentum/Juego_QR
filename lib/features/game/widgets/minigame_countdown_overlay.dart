import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../../../../core/theme/app_theme.dart';

class MinigameCountdownOverlay extends StatefulWidget {
  final String instruction;
  final Widget child;

  const MinigameCountdownOverlay({
    super.key,
    required this.instruction,
    required this.child,
  });

  @override
  State<MinigameCountdownOverlay> createState() =>
      _MinigameCountdownOverlayState();
}

class _MinigameCountdownOverlayState extends State<MinigameCountdownOverlay>
    with TickerProviderStateMixin {
  int _counter = 3;
  bool _isFinished = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.7, 1.0, curve: Curves.easeOut)),
    );

    _startCountdown();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startCountdown() async {
    // 3
    if (!mounted) return;
    await _checkPause();
    await _playPulse();

    // 2
    if (!mounted) return;
    await _checkPause();
    setState(() => _counter = 2);
    await _playPulse();

    // 1
    if (!mounted) return;
    await _checkPause();
    setState(() => _counter = 1);
    await _playPulse();

    // YA!
    if (!mounted) return;
    await _checkPause();
    setState(() => _counter = 0);
    await _playPulse();

    if (mounted) {
      setState(() {
        _isFinished = true;
      });
    }
  }

  Future<void> _checkPause() async {
    if (!mounted) return;
    final provider = Provider.of<GameProvider>(context, listen: false);
    while (provider.isPaused && mounted) {
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  Future<void> _playPulse() async {
    if (!mounted) return;
    _controller.reset();
    HapticFeedback.lightImpact();
    await _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    if (_isFinished) {
      return widget.child;
    }

    String displayText = _counter == 0 ? "¡YA!" : "$_counter";

    return Material(
      color: Colors.transparent, // Background transparent to show the app background below
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    widget.instruction.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                const SizedBox(height: 60),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _opacityAnimation.value,
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Text(
                          displayText,
                          style: TextStyle(
                            color: _counter == 0
                                ? AppTheme.successGreen
                                : AppTheme.accentGold,
                            fontSize: 100,
                            fontWeight: FontWeight.w900,
                            decoration: TextDecoration.none,
                            shadows: [
                              Shadow(
                                color: (_counter == 0
                                        ? AppTheme.successGreen
                                        : AppTheme.accentGold)
                                    .withOpacity(0.5),
                                blurRadius: 30,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
                const Text(
                  "PREPÁRATE",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
