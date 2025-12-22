import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import '../models/story_data.dart';
import '../../../core/theme/app_theme.dart';

class StoryIntroScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const StoryIntroScreen({
    Key? key,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<StoryIntroScreen> createState() => _StoryIntroScreenState();
}

class _StoryIntroScreenState extends State<StoryIntroScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _particleController;
  late AnimationController _textController;
  late AudioPlayer _audioPlayer;
  
  int _currentPage = 0;
  final PageController _pageController = PageController();
  
  final List<StoryPage> _storyPages = [
    StoryPage(
      title: 'Protocolo Asthoria',
      subtitle: 'El Salto del Tiempo',
      description:
          'Año 2412. Te despiertas en una ciudad de neón y metal frío. No recuerdas cómo llegaste aquí, pero tu armadura de caballero desentona con las pantallas holográficas que te rodean.\n\nUn anciano que se hace llamar "El Arquitecto" te contacta por un visor: un experimento de alquimia prohibida te lanzó al futuro.\n\nPara volver a tu hogar en el Reino de Asthoria, debes localizar 9 Fallas Temporales (códigos QR) y extraer su energía a través de simulaciones de datos.',
      icon: Icons.auto_stories,
      gradient: [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..forward();

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    
    // Initialize and play background music
    _audioPlayer = AudioPlayer();
    _playBackgroundMusic();
  }
  
  Future<void> _playBackgroundMusic() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(0.4); // 40% volume for ambient music
      await _audioPlayer.play(AssetSource('audio/story_intro.mp3'));
    } catch (e) {
      // If audio file doesn't exist, continue without music
      print('Background music not available: $e');
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _particleController.dispose();
    _textController.dispose();
    _pageController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _storyPages.length - 1) {
      setState(() => _currentPage++);
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
      _textController.reset();
      _textController.forward();
    } else {
      widget.onComplete();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() => _currentPage--);
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
      _textController.reset();
      _textController.forward();
    }
  }

  void _skipIntro() {
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E1B4B),
              Color(0xFF312E81),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Animated particles background
            AnimatedBuilder(
              animation: _particleController,
              builder: (context, child) {
                return CustomPaint(
                  painter: ParticlesPainter(_particleController.value),
                  size: Size.infinite,
                );
              },
            ),

            // Content
            SafeArea(
              child: Column(
                children: [
                  // Skip button
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: _skipIntro,
                          icon: Icon(Icons.skip_next, color: Colors.white70),
                          label: Text(
                            'Saltar',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Page content
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: _storyPages.length,
                      itemBuilder: (context, index) {
                        return _buildStoryPage(_storyPages[index]);
                      },
                    ),
                  ),

                  // Page indicator
                  if (_storyPages.length > 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _storyPages.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentPage == index ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: _currentPage == index
                                  ? Colors.white
                                  : Colors.white30,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Navigation buttons
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      mainAxisAlignment: _storyPages.length > 1 
                          ? MainAxisAlignment.spaceBetween 
                          : MainAxisAlignment.center,
                      children: [
                        // Previous button
                        if (_storyPages.length > 1 && _currentPage > 0)
                          ElevatedButton.icon(
                            onPressed: _previousPage,
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Anterior'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white24,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                            ),
                          )
                        else if (_storyPages.length > 1)
                          const SizedBox(width: 120),

                        // Next/Start button
                        ElevatedButton.icon(
                          onPressed: _nextPage,
                          icon: Icon(_currentPage == _storyPages.length - 1
                              ? Icons.play_arrow
                              : Icons.arrow_forward),
                          label: Text(_currentPage == _storyPages.length - 1
                              ? 'COMENZAR'
                              : 'SIGUIENTE'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 18,
                            ),
                            elevation: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryPage(StoryPage page) {
    return AnimatedBuilder(
      animation: _textController,
      builder: (context, child) {
        final fadeAnimation = CurvedAnimation(
          parent: _textController,
          curve: Curves.easeIn,
        );

        final slideAnimation = Tween<Offset>(
          begin: Offset(0, 0.3),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _textController,
          curve: Curves.easeOutCubic,
        ));

        return FadeTransition(
          opacity: fadeAnimation,
          child: SlideTransition(
            position: slideAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 20),
                  
                  // Icon with gradient background
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: page.gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: page.gradient[0].withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      page.icon,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),

                  SizedBox(height: 24),

                  // Title
                  Text(
                    page.title,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                      shadows: [
                        Shadow(
                          color: page.gradient[0].withOpacity(0.5),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: 8),

                  // Subtitle
                  Text(
                    page.subtitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w300,
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: 24),

                  // Description
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Text(
                      page.description,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Colors.white.withOpacity(0.9),
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class StoryPage {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final List<Color> gradient;

  StoryPage({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.gradient,
  });
}

class ParticlesPainter extends CustomPainter {
  final double animationValue;
  final List<Particle> particles;

  ParticlesPainter(this.animationValue)
      : particles = List.generate(
          50,
          (index) => Particle(
            x: (index * 37.5) % 100,
            y: (index * 23.7) % 100,
            size: 1 + (index % 3),
            speed: 0.5 + (index % 5) * 0.3,
          ),
        );

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    for (var particle in particles) {
      final x = (particle.x / 100) * size.width;
      final y = ((particle.y + (animationValue * particle.speed * 100)) % 100 /
              100) *
          size.height;

      // Draw particle
      canvas.drawCircle(
        Offset(x, y),
        particle.size,
        paint,
      );

      // Draw glow
      final glowPaint = Paint()
        ..color = Colors.cyan.withOpacity(0.1)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, particle.size * 2);

      canvas.drawCircle(
        Offset(x, y),
        particle.size * 2,
        glowPaint,
      );
    }

    // Draw connecting lines
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 0.5;

    for (int i = 0; i < particles.length; i++) {
      for (int j = i + 1; j < particles.length; j++) {
        final x1 = (particles[i].x / 100) * size.width;
        final y1 = ((particles[i].y +
                    (animationValue * particles[i].speed * 100)) %
                100 /
                100) *
            size.height;

        final x2 = (particles[j].x / 100) * size.width;
        final y2 = ((particles[j].y +
                    (animationValue * particles[j].speed * 100)) %
                100 /
                100) *
            size.height;

        final distance = math.sqrt(math.pow(x2 - x1, 2) + math.pow(y2 - y1, 2));

        if (distance < 150) {
          canvas.drawLine(Offset(x1, y1), Offset(x2, y2), linePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(ParticlesPainter oldDelegate) => true;
}

class Particle {
  final double x;
  final double y;
  final double size;
  final double speed;

  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
  });
}
