import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/animated_cyber_background.dart';
import '../../../core/providers/app_mode_provider.dart';
import 'scenarios_screen.dart';
import '../../auth/providers/player_provider.dart';
import '../../auth/screens/login_screen.dart';

class GameModeSelectorScreen extends StatelessWidget {
  const GameModeSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final playerProvider = context.watch<PlayerProvider>();
    final bool isDarkMode = playerProvider.isDarkMode;

    // Colores del Sistema Cromático (Actualizado según imagen oficial)
    const Color dSurface0 = Color(0xFF0D0D0F); // Void absolute surface
    const Color dSurface1 = Color(0xFF1A1A1D); // Card surface
    const Color dSurface2 = Color(0xFF24242A); // Modal surface
    
    const Color dGoldMain = Color(0xFFFECB00); // Legendary Gold
    const Color dGoldLight = Color(0xFFFFF176); // Gold Hover
    
    const Color lSurface0 = Color(0xFFF2F2F7);
    const Color lSurface1 = Color(0xFFFFFFFF);
    
    const Color brandMain = Color(0xFF7B2CBF); // Mystic Tech
    const Color brandDeep = Color(0xFF150826); // Shadow / Deep brand
    
    const Color lMysticPurple = Color(0xFF5A189A);
    const Color lTextPrimary = Color(0xFF1A1A1D);
    const Color lTextSecondary = Color(0xFF4A4A5A);

    final Color currentBg = isDarkMode ? dSurface0 : lSurface0;
    final Color currentSurface = isDarkMode ? dSurface1 : lSurface1;
    final Color currentText = isDarkMode ? Colors.white : lTextPrimary;
    final Color currentTextSec = isDarkMode ? Colors.white.withOpacity(0.85) : lTextSecondary;
    final Color currentBrand = isDarkMode ? brandMain : lMysticPurple;
    final Color currentAction = isDarkMode ? dGoldMain : lMysticPurple;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 800),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Scaffold(
            backgroundColor: currentBg,
            body: Stack(
              children: [
                // Fondo unificado con el estilo del Login
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: isDarkMode ? RadialGradient(
                        center: const Alignment(-0.8, -0.6),
                        radius: 1.5,
                        colors: [
                          brandDeep, // Color(0xFF150826)
                          dSurface0, // Color(0xFF0D0D0F)
                        ],
                      ) : LinearGradient(
                        colors: [
                          lSurface0,
                          const Color(0xFFE9D5FF),
                          lSurface1,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    // Solo mostramos el animado en modo claro ya que en modo oscuro queremos que sea IGUAL al login
                    child: !isDarkMode ? const AnimatedCyberBackground(
                      gridColor: Color(0xFFD1D1DB),
                      vignetteColor: Color(0xFFE9D5FF),
                    ) : null,
                  ),
                ),
                
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () async {
                                await context.read<PlayerProvider>().logout();
                                if (context.mounted) {
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                                    (route) => false,
                                  );
                                }
                              },
                              icon: Icon(Icons.arrow_back_ios_new, color: currentAction), // Usamos Oro/Púrpura según tema
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'SELECCIONA TU MODO',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: currentText,
                            fontFamily: 'Inter',
                            shadows: isDarkMode ? [
                              Shadow(
                                color: currentAction.withOpacity(0.5),
                                blurRadius: 15,
                              ),
                            ] : [],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '¿Cómo deseas participar hoy?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: currentTextSec,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        
                        _ModeCard(
                          title: 'MODO PRESENCIAL',
                          description: 'Vive la aventura en el mundo real. Requiere GPS y escanear códigos QR físicos.',
                          icon: Icons.location_on_rounded,
                          color: dGoldMain, // Siempre dorado por petición
                          isDarkMode: isDarkMode,
                          onTap: () {
                            context.read<AppModeProvider>().setMode(GameMode.presencial);
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const ScenariosScreen()),
                            );
                          },
                        ),
                        
                        const SizedBox(height: 24),
                        
                        _ModeCard(
                          title: 'MODO ONLINE',
                          description: 'Participa desde cualquier lugar. Acceso mediante códigos PIN y minijuegos.',
                          icon: Icons.wifi_protected_setup_rounded,
                          color: dGoldMain, // Siempre dorado por petición
                          isDarkMode: isDarkMode,
                          onTap: () {
                            context.read<AppModeProvider>().setMode(GameMode.online);
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const ScenariosScreen()),
                            );
                          },
                        ),
                        
                        const Spacer(flex: 2),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ModeCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isDarkMode;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard> with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _rotationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = widget.isDarkMode 
        ? const Color(0xFF1A1A1D) // dSurface1 sólido, no transparente
        : Colors.white;
    final textSec = widget.isDarkMode ? Colors.white70 : const Color(0xFF4A4A5A);

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: Listenable.merge([_scaleAnimation, _rotationController]),
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              // Eliminado el gradiente vibrante para hacerlo sólido como pidió el usuario
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: widget.isDarkMode 
                      ? Colors.black.withOpacity(0.4) 
                      : Colors.black.withOpacity(0.05),
                  blurRadius: 15,
                  spreadRadius: widget.isDarkMode ? 2 : 0,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  // Borde animado (Siempre Dorado por petición)
                  // Corrección ParentDataWidget: Positioned debe ser hijo directo del Stack
                  Positioned.fill(
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 1000),
                      tween: Tween(begin: 0.0, end: 1.0),
                      builder: (context, opacity, child) {
                        return Opacity(
                          opacity: opacity,
                          child: Container(
                            padding: const EdgeInsets.all(2), 
                            child: CustomPaint(
                              painter: _AnimatedBorderPainter(
                                animationValue: _rotationController.value,
                                primaryColor: const Color(0xFFFECB00).withOpacity(0.9), // Legendary Gold
                                secondaryColor: const Color(0xFFFFF176).withOpacity(0.4), // Gold Light
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  // Contenido interno
                  Container(
                    margin: const EdgeInsets.all(2), 
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: widget.onTap,
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: widget.color.withOpacity(widget.isDarkMode ? 0.2 : 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  widget.icon,
                                  color: widget.color,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.title,
                                      style: TextStyle(
                                        color: widget.isDarkMode ? widget.color : const Color(0xFF1A1A1D),
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      widget.description,
                                      style: TextStyle(
                                        color: textSec,
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: widget.isDarkMode ? widget.color.withOpacity(0.5) : const Color(0xFF1A1A1D).withOpacity(0.3),
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Pintor para el efecto de borde dorado rotativo
class _AnimatedBorderPainter extends CustomPainter {
  final double animationValue;
  final Color primaryColor;
  final Color secondaryColor;

  _AnimatedBorderPainter({
    required this.animationValue,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = SweepGradient(
        colors: [
          primaryColor.withOpacity(0.0),
          primaryColor.withOpacity(0.5),
          primaryColor,
          secondaryColor,
          primaryColor,
          primaryColor.withOpacity(0.5),
          primaryColor.withOpacity(0.0),
        ],
        stops: const [0.0, 0.15, 0.3, 0.5, 0.7, 0.85, 1.0],
        transform: GradientRotation(animationValue * 2 * math.pi),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    final RRect rrect = RRect.fromRectAndRadius(rect, const Radius.circular(20));
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _AnimatedBorderPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}
