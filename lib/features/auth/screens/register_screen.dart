import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/animated_cyber_background.dart';
import '../../../shared/widgets/animated_green_background.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/providers/theme_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _acceptedTerms = false;
  
  final List<String> _bannedWords = ['admin', 'root', 'moderator', 'tonto', 'estupido', 'idiota', 'groseria', 'puto', 'mierda'];
  
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      if (!_acceptedTerms) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes aceptar los términos y condiciones para continuar.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      try {
        final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );

        await playerProvider.register(
          _nameController.text.trim(),
          _emailController.text.trim(),
          _passwordController.text,
        );
        
        if (!mounted) return;
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Cuenta creada exitosamente. ¡Inicia sesión!',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
            duration: const Duration(seconds: 3),
          ),
        );

        Navigator.pop(context);

      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ErrorHandler.getFriendlyErrorMessage(e),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.dangerRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDayMode = themeProvider.isDayMode;

    return Scaffold(
      body: Stack(
        children: [
          // Fondo gradiente beige/crema con partículas doradas (mismo que login)
          if (isDayMode)
            Stack(
              children: [
                // Gradiente base
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFD4C5A0), // Beige arena
                        const Color(0xFFE8DCC4), // Crema claro
                        const Color(0xFFC9B591), // Beige dorado
                        const Color(0xFFB8A97A), // Beige oscuro
                      ],
                      stops: const [0.0, 0.3, 0.6, 1.0],
                    ),
                  ),
                ),
                // Partículas doradas flotantes
                Positioned.fill(
                  child: _GoldenParticles(),
                ),
                // Overlay suave
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF4A7C59).withOpacity(0.03),
                        Colors.transparent,
                        const Color(0xFFD4AF37).withOpacity(0.05),
                      ],
                    ),
                  ),
                ),
              ],
            )
          else
            Container(
              color: const Color(0xFF0A0E27),
              child: const AnimatedCyberBackground(child: SizedBox.expand()),
            ),

          SafeArea(
            child: Column(
              children: [
                // Botón de regreso
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDayMode 
                            ? const Color(0xFFB8A97A).withOpacity(0.3)
                            : Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDayMode
                              ? const Color(0xFF6B5D4F).withOpacity(0.3)
                              : Colors.white.withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.arrow_back, 
                          color: isDayMode 
                              ? const Color(0xFF3D5A3C)
                              : Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Título
                            Text(
                              'Crear Cuenta',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                color: isDayMode 
                                    ? const Color(0xFF3D5A3C)
                                    : Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Únete a la aventura',
                              style: TextStyle(
                                fontSize: 16,
                                color: isDayMode 
                                    ? const Color(0xFF6B5D4F)
                                    : Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 40),
                            
                            // Campo Nombre
                            Container(
                              decoration: BoxDecoration(
                                color: isDayMode 
                                    ? Colors.white.withOpacity(0.65)
                                    : Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDayMode
                                      ? const Color(0xFFD4AF37).withOpacity(0.3)
                                      : Colors.white24,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDayMode
                                        ? const Color(0xFFD4AF37).withOpacity(0.15)
                                        : Colors.black.withOpacity(0.1),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: TextFormField(
                                controller: _nameController,
                                style: TextStyle(
                                  color: isDayMode 
                                      ? const Color(0xFF2C2416)
                                      : Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(50),
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[a-zA-ZñÑáéíóúÁÉÍÓÚ\s]'),
                                  ),
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Nombre Completo',
                                  labelStyle: TextStyle(
                                    color: isDayMode 
                                        ? const Color(0xFF6B5D4F)
                                        : Colors.white60,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.person_outline, 
                                    color: isDayMode 
                                        ? const Color(0xFFD4AF37)
                                        : const Color(0xFFD4AF37),
                                  ),
                                  filled: false,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: isDayMode
                                          ? const Color(0xFFD4AF37)
                                          : const Color(0xFFFAE500),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Ingresa tu nombre';
                                  }
                                  if (!value.trim().contains(' ')) {
                                    return 'Ingresa tu nombre completo (Nombre y Apellido)';
                                  }
                                  final lowerValue = value.toLowerCase();
                                  for (final word in _bannedWords) {
                                    if (lowerValue.contains(word)) {
                                      return 'Nombre no permitido. Elige otro.';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Campo Email
                            Container(
                              decoration: BoxDecoration(
                                color: isDayMode 
                                    ? Colors.white.withOpacity(0.65)
                                    : Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDayMode
                                      ? const Color(0xFFD4AF37).withOpacity(0.3)
                                      : Colors.white24,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDayMode
                                        ? const Color(0xFFD4AF37).withOpacity(0.15)
                                        : Colors.black.withOpacity(0.1),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: TextStyle(
                                  color: isDayMode 
                                      ? const Color(0xFF2C2416)
                                      : Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  labelStyle: TextStyle(
                                    color: isDayMode 
                                        ? const Color(0xFF6B5D4F)
                                        : Colors.white60,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.email_outlined, 
                                    color: isDayMode 
                                        ? const Color(0xFFD4AF37)
                                        : const Color(0xFFD4AF37),
                                  ),
                                  filled: false,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: isDayMode
                                          ? const Color(0xFFD4AF37)
                                          : const Color(0xFFFAE500),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Ingresa tu email';
                                  }
                                  if (!value.contains('@')) {
                                    return 'Email inválido';
                                  }
                                  final domain = value.split('@').last.toLowerCase();
                                  final blockedDomains = ['yopmail.com', 'tempmail.com', '10minutemail.com', 'guerrillamail.com', 'mailinator.com'];
                                  if (blockedDomains.contains(domain)) {
                                    return 'Dominio de correo no permitido';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Campo Contraseña
                            Container(
                              decoration: BoxDecoration(
                                color: isDayMode 
                                    ? Colors.white.withOpacity(0.65)
                                    : Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDayMode
                                      ? const Color(0xFFD4AF37).withOpacity(0.3)
                                      : Colors.white24,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDayMode
                                        ? const Color(0xFFD4AF37).withOpacity(0.15)
                                        : Colors.black.withOpacity(0.1),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: TextFormField(
                                controller: _passwordController,
                                obscureText: !_isPasswordVisible,
                                style: TextStyle(
                                  color: isDayMode 
                                      ? const Color(0xFF2C2416)
                                      : Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Contraseña',
                                  labelStyle: TextStyle(
                                    color: isDayMode 
                                        ? const Color(0xFF6B5D4F)
                                        : Colors.white60,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.lock_outline, 
                                    color: isDayMode 
                                        ? const Color(0xFFD4AF37)
                                        : const Color(0xFFD4AF37),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                      color: isDayMode 
                                          ? const Color(0xFF6B5D4F)
                                          : Colors.white60,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isPasswordVisible = !_isPasswordVisible;
                                      });
                                    },
                                  ),
                                  filled: false,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: isDayMode
                                          ? const Color(0xFFD4AF37)
                                          : const Color(0xFFFAE500),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Ingresa tu contraseña';
                                  }
                                  if (value.length < 6) {
                                    return 'Mínimo 6 caracteres';
                                  }
                                  if (value.length > 30) {
                                    return 'Máximo 30 caracteres';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Campo Confirmar Contraseña
                            Container(
                              decoration: BoxDecoration(
                                color: isDayMode 
                                    ? Colors.white.withOpacity(0.65)
                                    : Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDayMode
                                      ? const Color(0xFFD4AF37).withOpacity(0.3)
                                      : Colors.white24,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDayMode
                                        ? const Color(0xFFD4AF37).withOpacity(0.15)
                                        : Colors.black.withOpacity(0.1),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: !_isConfirmPasswordVisible,
                                style: TextStyle(
                                  color: isDayMode 
                                      ? const Color(0xFF2C2416)
                                      : Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Confirmar Contraseña',
                                  labelStyle: TextStyle(
                                    color: isDayMode 
                                        ? const Color(0xFF6B5D4F)
                                        : Colors.white60,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.lock_outline, 
                                    color: isDayMode 
                                        ? const Color(0xFFD4AF37)
                                        : const Color(0xFFD4AF37),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                      color: isDayMode 
                                          ? const Color(0xFF6B5D4F)
                                          : Colors.white60,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                                      });
                                    },
                                  ),
                                  filled: false,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: isDayMode
                                          ? const Color(0xFFD4AF37)
                                          : const Color(0xFFFAE500),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Confirma tu contraseña';
                                  }
                                  if (value != _passwordController.text) {
                                    return 'Las contraseñas no coinciden';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            // Checkbox de términos
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                "Acepto los términos y condiciones de uso.",
                                style: TextStyle(
                                  color: isDayMode 
                                      ? const Color(0xFF6B5D4F)
                                      : Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              value: _acceptedTerms,
                              activeColor: isDayMode 
                                  ? const Color(0xFF4A7C59)
                                  : AppTheme.accentGold,
                              checkColor: Colors.white,
                              onChanged: (newValue) {
                                setState(() {
                                  _acceptedTerms = newValue ?? false;
                                });
                              },
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                            
                            const SizedBox(height: 30),
                            
                            // Botón Crear Cuenta
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isDayMode
                                        ? [
                                            const Color(0xFF4A7C59), // Verde bosque
                                            const Color(0xFF5C9970), // Verde medio
                                            const Color(0xFFD4AF37), // Dorado
                                          ]
                                        : [
                                            AppTheme.primaryPurple,
                                            AppTheme.secondaryPink,
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDayMode
                                          ? const Color(0xFF4A7C59).withOpacity(0.4)
                                          : AppTheme.primaryPurple.withOpacity(0.4),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _handleRegister,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text(
                                    'CREAR CUENTA',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                      color: Colors.white,
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Widget de partículas doradas flotantes (mismo que login)
class _GoldenParticles extends StatefulWidget {
  @override
  State<_GoldenParticles> createState() => _GoldenParticlesState();
}

class _GoldenParticlesState extends State<_GoldenParticles> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    
    // Crear 30 partículas
    for (int i = 0; i < 30; i++) {
      _particles.add(_Particle());
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ParticlesPainter(_particles, _controller.value),
        );
      },
    );
  }
}

class _Particle {
  double x = (DateTime.now().millisecondsSinceEpoch % 1000) / 1000.0;
  double y = (DateTime.now().millisecondsSinceEpoch % 2000) / 2000.0;
  double size = ((DateTime.now().millisecondsSinceEpoch % 100) / 100.0) * 3 + 1;
  double speed = ((DateTime.now().millisecondsSinceEpoch % 150) / 150.0) * 0.5 + 0.2;
  double opacity = ((DateTime.now().millisecondsSinceEpoch % 200) / 200.0) * 0.4 + 0.2;
}

class _ParticlesPainter extends CustomPainter {
  final List<_Particle> particles;
  final double animationValue;
  
  _ParticlesPainter(this.particles, this.animationValue);
  
  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      final paint = Paint()
        ..color = Color(0xFFD4AF37).withOpacity(particle.opacity)
        ..style = PaintingStyle.fill;
      
      // Calcular posición animada
      final dy = ((particle.y + animationValue * particle.speed) % 1.0) * size.height;
      final dx = particle.x * size.width;
      
      // Dibujar partícula
      canvas.drawCircle(
        Offset(dx, dy),
        particle.size,
        paint,
      );
      
      // Agregar brillo
      final glowPaint = Paint()
        ..color = Color(0xFFFAE500).withOpacity(particle.opacity * 0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, particle.size * 2);
      
      canvas.drawCircle(
        Offset(dx, dy),
        particle.size * 2,
        glowPaint,
      );
    }
  }
  
  @override
  bool shouldRepaint(_ParticlesPainter oldDelegate) => true;
}
}