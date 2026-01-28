import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:async';

class BlurScreenEffect extends StatefulWidget {
  final DateTime expiresAt;

  const BlurScreenEffect({super.key, required this.expiresAt});

  @override
  State<BlurScreenEffect> createState() => _BlurScreenEffectState();
}

class _BlurScreenEffectState extends State<BlurScreenEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _blurAnimation;
  late Animation<double> _opacityAnimation;
  Timer? _timer;
  Duration _timeLeft = Duration.zero;

  // Progressive blur: starts clear, gets blurrier over ~4 seconds
  static const double maxBlur = 12.0; // Strong blur effect
  static const Duration blurDuration = Duration(milliseconds: 4000);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: blurDuration,
    )..forward(); // Forward only, no repeat - progressive blur

    // Blur goes from 0 to maxBlur
    _blurAnimation = Tween<double>(begin: 0, end: maxBlur)
        .chain(CurveTween(curve: Curves.easeIn))
        .animate(_controller);

    // Opacity for overlay tint
    _opacityAnimation = Tween<double>(begin: 0, end: 0.25)
        .chain(CurveTween(curve: Curves.easeIn))
        .animate(_controller);

    _startTimer();
  }

  void _startTimer() {
    _updateTimeLeft();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _updateTimeLeft();
    });
  }

  void _updateTimeLeft() {
    final now = DateTime.now().toUtc(); // Supabase uses UTC usually, check provider usage
    // Provider logic usually handles utc/local, assumes DateTime object is correct.
    // If expiresAt is UTC, we compare with UTC.
    final diff = widget.expiresAt.difference(now);
    
    if (diff.isNegative) {
      setState(() => _timeLeft = Duration.zero);
      _timer?.cancel();
    } else {
      setState(() => _timeLeft = diff);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    // Format MM:SS, e.g. 05:00 or 00:30
    // But typically powers are seconds. just 00:SS is fine.
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    // IgnorePointer allows clicks to pass through to the game
    return IgnorePointer(
      ignoring: true, 
      child: Stack(
        children: [
          // 1. The visual blur filter
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final double blur = _blurAnimation.value;
              return BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: Container(
                  decoration: BoxDecoration(
                    // White haze overlay that also fades in
                    color: Colors.white.withOpacity(_opacityAnimation.value),
                  ),
                ),
              );
            },
          ),
          
          // 2. The countdown timer (Centered or Top Right)
          // Using Positioned NOT wrapped in IgnorePointer? 
          // Requirement: "que puedan seguir jugando". 
          // If we want them to play, we must ignore pointer on the WHOLE stack or just the background?
          // If the timer is just visual, it can be ignored too.
          if (_timeLeft.inSeconds > 0)
            Positioned(
              top: 100, // Adjusted to not overlap with top bar
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.blur_on, color: Colors.white70, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _formatDuration(_timeLeft),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20, // Visible font size
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Courier', // Monospace for numbers
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
