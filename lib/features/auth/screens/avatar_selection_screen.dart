import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/player_provider.dart';
import '../../game/providers/game_provider.dart';
import 'story_screen.dart';
import '../../../core/services/video_preload_service.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../game/screens/game_mode_selector_screen.dart';

class AvatarSelectionScreen extends StatefulWidget {
  final String? eventId;

  static const List<String> validAvatarIds = [
    'explorer_m', 'hacker_m', 'warrior_m', 'spec_m',
    'explorer_f', 'hacker_f', 'warrior_f', 'spec_f',
  ];

  const AvatarSelectionScreen({super.key, this.eventId});

  @override
  State<AvatarSelectionScreen> createState() => _AvatarSelectionScreenState();
}

class _AvatarSelectionScreenState extends State<AvatarSelectionScreen> with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _hoverController;
  late AnimationController _particleController;
  
  // Video Controllers for seamless transition (Double Buffering)
  VideoPlayerController? _activeController;
  VideoPlayerController? _previousController;
  
  String? _activeAvatarId;
  int _currentIndex = 0;
  bool _isSaving = false;
  
  // Infinite scroll offset
  static const int _initialPageOffset = 1000;

  final List<Map<String, String>> _avatars = [
    {'id': 'explorer_m', 'name': 'EXPLORADOR', 'desc': 'Experto en mapas y brújulas legendarias.'},
    {'id': 'hacker_m', 'name': 'HACKER', 'desc': 'Capaz de descifrar cualquier código de red.'},
    {'id': 'warrior_m', 'name': 'CYBER GUERRERO', 'desc': 'Fuerza bruta y reflejos aumentados.'},
    {'id': 'spec_m', 'name': 'ESPECIALISTA', 'desc': 'Usa visión VR para ver lo invisible.'},
    {'id': 'explorer_f', 'name': 'EXPLORADORA', 'desc': 'Busca reliquias en lo desconocido.'},
    {'id': 'hacker_f', 'name': 'CIBER-HACKER', 'desc': 'Domina la red con elegancia letal.'},
    {'id': 'warrior_f', 'name': 'ASESINA NEON', 'desc': 'Silenciosa como una sombra eléctrica.'},
    {'id': 'spec_f', 'name': 'ESPECIALISTA', 'desc': 'Tecnología de punta a su servicio.'},
  ];

  final Map<String, String> _avatarVideos = {
    'explorer_m': 'assets/escenarios.avatar/explorer_m_scene.mp4',
    'hacker_m': 'assets/escenarios.avatar/hacker_m_scene.mp4',
    'warrior_m': 'assets/escenarios.avatar/warrior_m_scene.mp4',
    'spec_m': 'assets/escenarios.avatar/spec_m_scene.mp4',
    'explorer_f': 'assets/escenarios.avatar/explorer_f_scene.mp4',
    'hacker_f': 'assets/escenarios.avatar/hacker_f_scene.mp4',
    'warrior_f': 'assets/escenarios.avatar/warrior_f_scene.mp4',
    'spec_f': 'assets/escenarios.avatar/spec_f_scene.mp4',
  };

  @override
  void initState() {
    super.initState();
    // Iniciar en un índice alto para permitir scroll infinito hacia atrás
    _currentIndex = 0;
    _pageController = PageController(
      viewportFraction: 0.8, 
      initialPage: _initialPageOffset,
    );
    
    _hoverController = AnimationController(
       vsync: this,
       duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Cargar video inicial
    _loadVideoForAvatar(_avatars[0]['id']!);
  }

  void _loadVideoForAvatar(String avatarId) {
    if (_activeAvatarId == avatarId) return;
    
    final videoPath = _avatarVideos[avatarId];
    if (videoPath == null) return;

    debugPrint('🎬 AvatarSelection: Loading video for $avatarId -> $videoPath');

    // 1. Move current active to previous (Background layer)
    final oldActive = _activeController;
    
    // Si ya teníamos un "previous" pendiente de limpieza, lo limpiamos ahora
    if (_previousController != null && _previousController != oldActive) {
      _previousController?.dispose();
    }
    
    _previousController = oldActive;
    _activeController = null; // Clear active while loading new one

    // 2. Load new video
    final newController = VideoPlayerController.asset(videoPath);
    
    newController.initialize().then((_) {
      if (mounted) {
        debugPrint('🎬 AvatarSelection: Video initialized for $avatarId');
        setState(() {
          _activeController = newController;
          _activeAvatarId = avatarId;
          
          _activeController?.setLooping(true);
          _activeController?.setVolume(0.0);
          _activeController?.play();
        });

        // 3. Clean up previous after transition (DELAYED)
        // Wait for the fade-in animation (e.g. 1 second) plus a buffer
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted && _previousController != null) {
            // Solo disponer si no se ha convertido en el activo de nuevo (race condition check)
            if (_previousController != _activeController) {
               _previousController?.dispose();
               _previousController = null;
               // Trigger rebuild to remove the background layer
               if (mounted) setState(() {}); 
            }
          }
        });
      }
    }).catchError((e) {
      debugPrint("🛑 AvatarSelection: Error loading video: $e");
      // En caso de error, intentar restaurar el anterior como activo si existe
      if (mounted) {
        setState(() {
           _activeController = _previousController; 
           _previousController = null;
        });
      }
    });
  }

  void _onPageChanged(int index) {
    // Calcular índice real basado en módulo
    final realIndex = index % _avatars.length;
    setState(() => _currentIndex = realIndex);
    
    final avatarId = _avatars[realIndex]['id'];
    if (avatarId != null) {
      _loadVideoForAvatar(avatarId);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _hoverController.dispose();
    _particleController.dispose();
    _activeController?.dispose();
    _previousController?.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    final selectedId = _avatars[_currentIndex]['id'];
    if (selectedId == null) return;
    
    setState(() => _isSaving = true);
    try {
      final playerProvider = context.read<PlayerProvider>();
      final gameProvider = context.read<GameProvider>();
      
      await playerProvider.updateAvatar(selectedId);
      
      if (!mounted) return;

      if (widget.eventId != null) {
        await gameProvider.initializeGameForApprovedUser(playerProvider.currentPlayer!.userId, widget.eventId!);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => StoryScreen(eventId: widget.eventId!)),
        );
      } else {
        Navigator.of(context).pushReplacement(
           MaterialPageRoute(builder: (_) => const GameModeSelectorScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e'), backgroundColor: AppTheme.dangerRed),
      );
    }
  }

  void _nextPage() {
    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _previousPage() {
    _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: Stack(
        children: [
          // 1. Imagen de fondo base (Universal para evitar el pop visual)
          Positioned.fill(
            child: Image.asset(
              'assets/images/intro_bg.png',
              fit: BoxFit.cover,
            ),
          ),
          
          // 2. CAPA DE FONDO (PREVIOUS VIDEO) - Mantiene el último frame visible
          if (_previousController != null && _previousController!.value.isInitialized)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                   width: _previousController!.value.size.width,
                   height: _previousController!.value.size.height,
                   child: VideoPlayer(_previousController!),
                ),
              ),
            ),

          // 3. CAPA ACTIVA (CURRENT VIDEO) - Fade In
          // Usamos AnimatedOpacity para la transición suave
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: (_activeController != null && _activeController!.value.isInitialized) ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 800), // Duración del Fade
              curve: Curves.easeInOut,
              child: (_activeController != null && _activeController!.value.isInitialized) 
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _activeController!.value.size.width,
                      height: _activeController!.value.size.height,
                      child: VideoPlayer(_activeController!),
                    ),
                  )
                : const SizedBox(),
            ),
          ),
          
          // 4. Overlay oscuro constante
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.4),
            ),
          ),
          
          // Partículas flotantes animadas
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, child) {
              return CustomPaint(
                painter: ParticlePainter(_particleController.value),
                size: Size.infinite,
              );
            },
          ),

          // UI Principal
          SafeArea(
            child: Column(
              children: [
                // Back Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 10),
                
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryPurple.withOpacity(0.15),
                        Colors.transparent,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                        child: const Icon(
                          Icons.person_search_outlined, 
                          size: 50, 
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ShaderMask(
                        shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                        child: Text(
                          'ELIGE TU CAZADOR',
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            fontSize: 26,
                            letterSpacing: 3,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: AppTheme.primaryPurple.withOpacity(0.6),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                
                // Carousel Infinito
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PageView.builder(
                        controller: _pageController,
                        onPageChanged: _onPageChanged,
                        // itemCount: null -> Infinite
                        itemBuilder: (context, index) {
                          // Módulo para ciclo infinito
                          final realIndex = index % _avatars.length;
                          final avatar = _avatars[realIndex];
                          
                          final isSelected = realIndex == _currentIndex;
                          
                          return AnimatedScale(
                            scale: isSelected ? 1.0 : 0.7,
                            duration: const Duration(milliseconds: 300),
                            child: Opacity(
                              opacity: isSelected ? 1.0 : 0.5,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedBuilder(
                                    animation: _hoverController,
                                    builder: (context, child) {
                                      final double offset = isSelected 
                                        ? Curves.easeInOut.transform(_hoverController.value) * 10 
                                        : 0;
                                      return Transform.translate(
                                        offset: Offset(0, -offset),
                                        child: child,
                                      );
                                    },
                                    child: SizedBox(
                                      height: 150,
                                      width: 150,
                                      child: Image.asset(
                                        'assets/images/avatars/${avatar['id']}.png',
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => const Icon(
                                          Icons.person, 
                                          color: Colors.white70, 
                                          size: 100,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 30),
                                  ShaderMask(
                                    shaderCallback: (bounds) => isSelected
                                        ? AppTheme.primaryGradient.createShader(bounds)
                                        : LinearGradient(
                                            colors: [Colors.white70, Colors.white70],
                                          ).createShader(bounds),
                                    child: Text(
                                      avatar['name']!,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: isSelected ? 28 : 24,
                                        letterSpacing: 2,
                                        shadows: isSelected ? [
                                          Shadow(
                                            color: AppTheme.primaryPurple.withOpacity(0.5),
                                            blurRadius: 10,
                                          ),
                                        ] : [],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 40),
                                    child: Text(
                                      avatar['desc']!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white70 : Colors.white54,
                                        fontSize: 16,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      
                      // Flechas siempre visibles
                      Positioned(
                        left: 10,
                        child: _buildArrowButton(
                          icon: Icons.arrow_back_ios_new,
                          onPressed: _previousPage,
                        ),
                      ),
                      Positioned(
                        right: 10,
                        child: _buildArrowButton(
                          icon: Icons.arrow_forward_ios,
                          onPressed: _nextPage,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Confirm Button
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient: AppTheme.primaryGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryPurple.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: !_isSaving ? _handleConfirm : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: _isSaving 
                        ? const LoadingIndicator(fontSize: 14, color: Colors.white)
                        : const Text(
                            'CONFIRMAR IDENTIDAD',
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              letterSpacing: 2, 
                              fontSize: 16,
                            ),
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArrowButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppTheme.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPurple.withOpacity(0.4),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 30),
        onPressed: onPressed,
      ),
    );
  }
}

class ParticlePainter extends CustomPainter {
  final double animationValue;
  
  ParticlePainter(this.animationValue);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    // Generar partículas deterministas
    final random = math.Random(42);
    for (int i = 0; i < 50; i++) {
      final x = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final speed = 0.5 + random.nextDouble() * 0.5;
      final y = (baseY + animationValue * size.height * speed) % size.height;
      final radius = 1.0 + random.nextDouble() * 2.5;
      
      // Colores usando la paleta del login
      final colors = [
        AppTheme.primaryPurple,
        AppTheme.secondaryPink,
        Colors.white,
      ];
      paint.color = colors[i % colors.length].withOpacity(0.5);
      
      canvas.drawCircle(Offset(x, y), radius, paint);
      
      // Efecto de brillo
      paint.color = colors[i % colors.length].withOpacity(0.15);
      canvas.drawCircle(Offset(x, y), radius * 2, paint);
    }
  }
  
  @override
  bool shouldRepaint(ParticlePainter oldDelegate) => true;
}

extension GlowExtension on Widget {
  Widget withGlow({bool isVisible = true}) {
    if (!isVisible) return Opacity(opacity: 0, child: this);
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentGold.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: this,
    );
  }
}
