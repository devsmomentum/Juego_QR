import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import '../models/story_data.dart';
import '../../../../core/theme/app_theme.dart';

class MissionBriefingOverlay extends StatefulWidget {
  final int stampIndex;
  final VoidCallback onStart;

  const MissionBriefingOverlay({
    super.key,
    required this.stampIndex,
    required this.onStart,
  });

  @override
  State<MissionBriefingOverlay> createState() => _MissionBriefingOverlayState();
}

class _MissionBriefingOverlayState extends State<MissionBriefingOverlay>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _gridController;
  late AnimationController _pulseController;
  
  String _displayText = "";
  Timer? _typewriterTimer;
  bool _showButton = false;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _gridController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _mainController.forward().then((_) {
      _startTypewriter();
    });
  }

  void _startTypewriter() {
    final moment = StoryData.moments[(widget.stampIndex - 1).clamp(0, StoryData.moments.length - 1)];
    final fullText = moment.description;
    int index = 0;

    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (index < fullText.length) {
        if (mounted) {
          setState(() {
            _displayText += fullText[index];
            index++;
          });
        }
      } else {
        timer.cancel();
        if (mounted) {
          setState(() => _showButton = true);
        }
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _gridController.dispose();
    _pulseController.dispose();
    _typewriterTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moment = StoryData.moments[(widget.stampIndex - 1).clamp(0, StoryData.moments.length - 1)];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.darkGradient,
        ),
        child: Stack(
        children: [
          // 1. Cyberspace Grid Animation
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _gridController,
              builder: (context, child) {
                return Stack(
                  children: [
                    CustomPaint(
                      painter: CyberGridPainter(_gridController.value, moment.gradient[0]),
                      size: Size.infinite,
                    ),
                    // Moving scan line
                    Positioned(
                      top: (math.sin(_gridController.value * 2 * math.pi) * 0.5 + 0.5) * MediaQuery.of(context).size.height,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: moment.gradient[0],
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              moment.gradient[0].withOpacity(0.5),
                              moment.gradient[0],
                              moment.gradient[0].withOpacity(0.5),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // 2. Glitchy Vignette
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Colors.transparent,
                  AppTheme.darkBg.withOpacity(0.8),
                ],
              ),
            ),
          ),
          
          // 4. Skip Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 20,
            child: TextButton.icon(
              onPressed: widget.onStart,
              icon: const Icon(Icons.skip_next, color: Colors.white54, size: 18),
              label: const Text(
                "SALTAR",
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.05),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Colors.white10),
                ),
              ),
            ),
          ),

          // 3. Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ICON WITH SCANNER EFFECT
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer Pulse
                      ScaleTransition(
                        scale: Tween(begin: 1.0, end: 1.5).animate(
                          CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
                        ),
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: moment.gradient[0].withOpacity(0.3), width: 2),
                          ),
                        ),
                      ),
                      // Scanner Aura
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: moment.gradient[0].withOpacity(0.4),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                      ),
                      // The Real Icon
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: moment.gradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(moment.icon, size: 45, color: Colors.white),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // TITLE WITH GLITCH SLIDE
                  FutureBuilder(
                    future: Future.delayed(const Duration(milliseconds: 300)),
                    builder: (context, snapshot) {
                      return AnimatedOpacity(
                        opacity: 1.0,
                        duration: const Duration(seconds: 1),
                        child: Column(
                          children: [
                            Text(
                              "SISTEMAS CALIBRANDO...",
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 5,
                                color: moment.gradient[0].withOpacity(0.7),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              moment.title.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 5),
                            Container(
                              height: 2,
                              width: 60,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: moment.gradient),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  ),

                  const SizedBox(height: 30),

                  // TYPEWRITER DESCRIPTION
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 120),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.terminal, size: 14, color: moment.gradient[0]),
                            const SizedBox(width: 8),
                            Text(
                              "DATA_STREAM_0X${widget.stampIndex}",
                              style: TextStyle(
                                fontSize: 10,
                                color: moment.gradient[0],
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white10),
                        Text(
                          _displayText,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.6,
                            color: Colors.white70,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.left,
                        ),
                        if (_displayText.length < moment.description.length)
                          const Text("_", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // BUTTON WITH FADE IN
                  AnimatedOpacity(
                    opacity: _showButton ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 800),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _showButton ? widget.onStart : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Colors.white24),
                          ),
                          elevation: 15,
                          shadowColor: AppTheme.primaryPurple.withOpacity(0.5),
                        ),
                        child: const Text(
                          "ESTABLECER CONEXIÓN",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}

class CyberGridPainter extends CustomPainter {
  final double progress;
  final Color color;

  CyberGridPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.05)
      ..strokeWidth = 1.0;

    const double spacing = 40.0;
    final double offset = progress * spacing;

    // Horizontal lines
    for (double y = 0; y < size.height + spacing; y += spacing) {
      canvas.drawLine(Offset(0, y + (offset % spacing)), Offset(size.width, y + (offset % spacing)), paint);
    }

    // Vertical lines
    for (double x = 0; x < size.width + spacing; x += spacing) {
      canvas.drawLine(Offset(x + (offset % spacing), 0), Offset(x + (offset % spacing), size.height), paint);
    }

    // Floating dots
    final math.Random random = math.Random(42);
    final dotPaint = Paint()..color = color.withOpacity(0.15);
    for (int i = 0; i < 20; i++) {
        final double rx = random.nextDouble() * size.width;
        final double ry = (random.nextDouble() * size.height + (progress * 100)) % size.height;
        canvas.drawCircle(Offset(rx, ry), 1.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(CyberGridPainter oldDelegate) => true;
}
