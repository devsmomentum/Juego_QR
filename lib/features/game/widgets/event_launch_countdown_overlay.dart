import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

/// Full-screen black overlay with a 5→0 countdown.
/// Shown the moment an online event transitions from pending → active,
/// giving all lobby participants a synchronised "3-2-1 GO!" moment.
/// Once finished it calls [onComplete] so the host widget can navigate.
class EventLaunchCountdownOverlay extends StatefulWidget {
  final VoidCallback onComplete;

  const EventLaunchCountdownOverlay({super.key, required this.onComplete});

  @override
  State<EventLaunchCountdownOverlay> createState() =>
      _EventLaunchCountdownOverlayState();
}

class _EventLaunchCountdownOverlayState
    extends State<EventLaunchCountdownOverlay>
    with SingleTickerProviderStateMixin {
  /// Current value shown on screen. We start at 5 and go to 0 → "¡YA!"
  int _counter = 5;
  bool _showGo = false;
  bool _done = false;

  late AnimationController _pulse;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  final AudioPlayer _audio = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scaleAnim = Tween<double>(begin: 0.4, end: 1.6).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.elasticOut),
    );
    _opacityAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _pulse,
        curve: const Interval(0.65, 1.0, curve: Curves.easeOut),
      ),
    );

    _audio.setVolume(0.9);
    _runCountdown();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _audio.dispose();
    super.dispose();
  }

  Future<void> _runCountdown() async {
    try {
      await _audio.play(AssetSource('audio/countdown.mp3'));
    } catch (_) {}

    // 5 → 1
    for (int i = 5; i >= 1; i--) {
      if (!mounted) return;
      setState(() => _counter = i);
      HapticFeedback.mediumImpact();
      _pulse.reset();
      await _pulse.forward();
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // "¡A JUGAR!"
    if (!mounted) return;
    setState(() => _showGo = true);
    HapticFeedback.heavyImpact();
    _pulse.reset();
    await _pulse.forward();
    if (!mounted) return;

    try {
      await _audio.stop();
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    setState(() => _done = true);

    // Jitter: distributes startGame() calls over 0–3 s so 50 clients
    // don't hit the DB simultaneously when a manual event is started.
    final jitter = Duration(milliseconds: Random().nextInt(3000));
    debugPrint('⏱️ Launch overlay jitter: ${jitter.inMilliseconds} ms');
    await Future.delayed(jitter);

    if (!mounted) return;
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return const SizedBox.shrink();

    final String label = _showGo ? '¡A JUGAR!' : '$_counter';
    final Color color =
        _showGo ? const Color(0xFFFECB00) : Colors.white;

    return AnimatedOpacity(
      opacity: _done ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        color: Colors.black,
        child: Center(
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) {
              return Opacity(
                opacity: _opacityAnim.value,
                child: Transform.scale(
                  scale: _scaleAnim.value,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: color,
                      fontSize: 100,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Orbitron',
                      letterSpacing: _showGo ? 2 : 0,
                      shadows: [
                        Shadow(
                          color: color.withOpacity(0.7),
                          blurRadius: 40,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
