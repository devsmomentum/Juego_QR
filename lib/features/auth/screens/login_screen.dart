import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/player_provider.dart';
import '../../../shared/models/player.dart';
import '../../../core/theme/app_theme.dart';
import 'register_screen.dart';
import '../../game/screens/scenarios_screen.dart';
import '../../game/screens/game_request_screen.dart';
import '../../game/screens/game_mode_selector_screen.dart';
import '../../layouts/screens/home_screen.dart';
import '../../admin/screens/dashboard-screen.dart';
import '../../../shared/widgets/animated_cyber_background.dart';
import '../../../shared/widgets/animated_green_background.dart';
import '../../../core/utils/error_handler.dart';
import '../../game/providers/connectivity_provider.dart';
import '../../game/providers/game_provider.dart';
import '../../../core/providers/theme_provider.dart';
import 'dart:async'; // For TimeoutException
import 'dart:math' as math;


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  late AnimationController _shimmerTitleController;

@override
  void initState() {
    super.initState();
    _shimmerTitleController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat();
  }
  

@override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _shimmerTitleController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    if (playerProvider.banMessage != null) {
      final msg = playerProvider.banMessage!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        playerProvider.clearBanMessage();
      });
    }
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      try {
        final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
        final gameProvider = Provider.of<GameProvider>(context, listen: false);

        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );

        await playerProvider.login(
            _emailController.text.trim(), _passwordController.text);

        if (!mounted) return;
        Navigator.pop(context); // Dismiss loading

        // Verificar estado del usuario
        final player = playerProvider.currentPlayer;
        if (player == null) {
          if (playerProvider.banMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(playerProvider.banMessage!),
                backgroundColor: Colors.red,
              ),
            );
            playerProvider.clearBanMessage();
          }
          return;
        }

        // Administradores van directamente al Dashboard
        if (player.role == 'admin') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
          );
          return;
        }

        // Solicitar permisos de ubicación antes de navegar
        await _checkPermissions();
        if (!mounted) return;

        // Iniciar monitoreo de conectividad
        context.read<ConnectivityProvider>().startMonitoring();

        // === GATEKEEPER: Verificar estado del usuario respecto a eventos ===
        debugPrint('LoginScreen: Checking user event status...');
        final statusResult = await gameProvider
            .checkUserEventStatus(player.userId)
            .timeout(const Duration(seconds: 10), onTimeout: () {
              throw TimeoutException('La verificación de estado tardó demasiado');
            });
        debugPrint('LoginScreen: User status is ${statusResult.status}');

        if (!mounted) return;

        switch (statusResult.status) {
          // === CASOS DE BLOQUEO ===
          case UserEventStatus.banned:
            // Usuario baneado - cerrar sesión y mostrar mensaje
            await playerProvider.logout();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tu cuenta ha sido suspendida.'),
                backgroundColor: Colors.red,
              ),
            );
            break;

          case UserEventStatus.waitingApproval:
            // Usuario esperando aprobación - ir a selector de modo
             Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const GameModeSelectorScreen()),
            );
            break;

          // === CASOS DE FLUJO ABIERTO ===
          // El usuario siempre va al selector de modo
          case UserEventStatus.inGame:
          case UserEventStatus.readyToInitialize:
          case UserEventStatus.rejected:
          case UserEventStatus.noEvent:
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const GameModeSelectorScreen()),
            );
            break;
        }
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context); // Dismiss loading

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

  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController(text: _emailController.text);
    final formKey = GlobalKey<FormState>();
    bool isSending = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Recuperar Contraseña',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ingresa tu email y te enviaremos un enlace para restablecer tu contraseña.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Ingresa tu email';
                    if (!value.contains('@')) return 'Email inválido';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSending ? null : () => Navigator.pop(context),
              child: const Text('CANCELAR', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isSending
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setDialogState(() => isSending = true);
                        try {
                          await context
                              .read<PlayerProvider>()
                              .resetPassword(emailController.text.trim());
                          if (!mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Enlace enviado. Revisa tu correo.'),
                              backgroundColor: AppTheme.accentGold,
                            ),
                          );
                        } catch (e) {
                          setDialogState(() => isSending = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ErrorHandler.getFriendlyErrorMessage(e)),
                              backgroundColor: AppTheme.dangerRed,
                            ),
                          );
                        }
                      }
                    },
              child: isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('ENVIAR'),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _checkPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    // Si falta algo, mostramos el BottomSheet explicativo antes de pedirlo nativamente
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever ||
        !serviceEnabled) {
      if (mounted) {
        await showModalBottomSheet(
          context: context,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: AppTheme.cardBg,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 60, color: AppTheme.accentGold),
                const SizedBox(height: 16),
                const Text(
                  'Ubicación Necesaria',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Para encontrar los tesoros ocultos, necesitamos acceder a tu ubicación.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                      await _requestNativePermissions();
                    },
                    child: const Text('ACTIVAR UBICACIÓN',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                // === BOTÓN DE DESARROLLADOR ===
                if (true) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.pop(context); // Solo cierra sin pedir permiso
                      },
                      icon: const Icon(Icons.developer_mode),
                      label: const Text('DEV: Saltar Permisos'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }
    } else {
      // Si ya tiene todo, solo verificamos por seguridad
      await _requestNativePermissions();
    }
  }

  Future<void> _requestNativePermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      try {
        await Geolocator.getCurrentPosition(
            timeLimit: const Duration(seconds: 2));
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDayMode = themeProvider.isDayMode;
    
    return Scaffold(
      body: Stack(
        children: [
          // Fondo gradiente beige/crema con partículas doradas
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
            // Night mode: Cyber background
            Container(
              color: const Color(0xFF0A0E27),
              child: const AnimatedCyberBackground(child: SizedBox.expand()),
            ),
          
          // Main Content
          SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                      child: AutofillGroup(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Spacer(flex: 2),
                              
                              // Título con efecto glitch (restaurado)
                              const _GlitchText(
                                text: 'MapHunter',
                                style: TextStyle(
                                  fontSize: 38,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFFAE500),
                                  letterSpacing: 3,
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Logo circular simple sin efectos de sombra
                              Container(
                                width: 180,
                                height: 180,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(100),
                                  child: Transform.scale(
                                    scale: 1.5,
                                    child: Image.asset(
                                      isDayMode 
                                          ? 'assets/images/logodia.png' 
                                          : 'assets/images/logo.png',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 25),

                              // Subtítulo
                              Text(
                                'BIENVENIDO',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 3,
                                  color: isDayMode 
                                      ? const Color(0xFF3D5A3C) // Verde oscuro
                                      : Colors.white,
                                  shadows: isDayMode ? [] : [
                                    const Shadow(
                                      offset: Offset(1, 1),
                                      blurRadius: 3,
                                      color: Color(0x80000000),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'Inicia tu aventura',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDayMode 
                                      ? const Color(0xFF6B5D4F) // Marrón cálido
                                      : Colors.white70,
                                ),
                              ),
                              const Spacer(flex: 1),

                              // Email field con glassmorphism
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
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.email],
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
                                    if (value == null || value.isEmpty) return 'Ingresa tu email';
                                    if (!value.contains('@')) return 'Email inválido';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Password field con glassmorphism
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
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [AutofillHints.password],
                                  onEditingComplete: _handleLogin,
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
                                    if (value == null || value.isEmpty) return 'Ingresa tu contraseña';
                                    if (value.length < 6) return 'Mínimo 6 caracteres';
                                    return null;
                                  },
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _showForgotPasswordDialog,
                                  child: Text(
                                    '¿Olvidaste tu contraseña?',
                                    style: TextStyle(
                                      color: isDayMode 
                                          ? const Color(0xFF6B5D4F)
                                          : Colors.white70,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              
                              // Login button con gradiente dorado-verde
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
                                    onPressed: _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text(
                                      'INICIAR SESIÓN',
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
                              const SizedBox(height: 16),
                              
                              // Register link
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '¿No tienes cuenta? ',
                                    style: TextStyle(
                                      color: isDayMode 
                                          ? const Color(0xFF6B5D4F)
                                          : Colors.white70,
                                      fontSize: 15,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                      );
                                    },
                                    child: Text(
                                      'Regístrate',
                                      style: TextStyle(
                                        color: isDayMode
                                            ? const Color(0xFF4A7C59)
                                            : AppTheme.secondaryPink,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(flex: 2),
                              
                              // Morna Branding
                              _buildMornaBranding(isDayMode),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          ),
          
          // Theme Toggle Button (positioned last to be on top)
          Positioned(
            top: 16,
            right: 16,
            child: SafeArea(
              child: GestureDetector(
                onTap: () {
                  print('Toggle button tapped! Current mode: $isDayMode');
                  themeProvider.toggleTheme();
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
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
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    isDayMode ? Icons.nightlight_round : Icons.wb_sunny,
                    color: isDayMode 
                        ? const Color(0xFF3D5A3C)
                        : AppTheme.accentGold,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMornaBranding(bool isDayMode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "by",
          style: TextStyle(
            color: isDayMode
                ? const Color(0xFF6B5D4F).withOpacity(0.8)
                : Colors.white.withOpacity(0.7),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Image.asset(
          'assets/images/morna_logo_new.png',
          height: 35,
        ),
      ],
    );
  }
}

class _GlitchText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _GlitchText({required this.text, required this.style});

  @override
  State<_GlitchText> createState() => _GlitchTextState();
}

class _GlitchTextState extends State<_GlitchText> with SingleTickerProviderStateMixin {
  late AnimationController _glitchController;
  late String _displayText;
  final String _chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*';
  Timer? _decodeTimer;
  int _decodeIndex = 0;

  @override
  void initState() {
    super.initState();
    _displayText = '';
    _startDecoding();

    _glitchController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 4000)
    )..repeat();
  }

  void _startDecoding() {
    _decodeTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_decodeIndex >= widget.text.length) {
        timer.cancel();
        setState(() => _displayText = widget.text);
        return;
      }

      setState(() {
        _displayText = String.fromCharCodes(Iterable.generate(widget.text.length, (index) {
          if (index < _decodeIndex) return widget.text.codeUnitAt(index);
          return _chars.codeUnitAt(math.Random().nextInt(_chars.length));
        }));
        _decodeIndex++;
      });
    });
  }

  @override
  void dispose() {
    _glitchController.dispose();
    _decodeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glitchController,
    builder: (context, child) {
      final double value = _glitchController.value;
      
      // Much slower oscillation (10x instead of 40x)
      double offsetX = math.sin(value * 10 * math.pi) * 0.5;
      double offsetY = math.cos(value * 8 * math.pi) * 0.3;
      
      // Chromatic aberrations breathing much slower (5x instead of 20x)
      double cyanX = offsetX - 1.5 - (math.sin(value * 5 * math.pi) * 2.0);
      double magX = offsetX + 1.5 + (math.cos(value * 5 * math.pi) * 2.0);
      
      // Softer periodic spikes
      double spike = 0.0;
      if (value > 0.45 && value < 0.50) {
        spike = 3.0 * math.sin((value - 0.45) * 20 * math.pi);
      } else if (value > 0.90 && value < 0.95) {
        spike = -2.0 * math.sin((value - 0.90) * 20 * math.pi);
      }
      offsetX += spike;

      Color currentColor = widget.style.color ?? Colors.white;
      if (value > 0.98) {
        currentColor = Colors.white;
      }

        return Stack(
          children: [
            // Constant Chromatic Aberration Shadows (Cyan/Magenta)
            Transform.translate(
              offset: Offset(cyanX, offsetY),
              child: Text(
                _displayText,
                style: widget.style.copyWith(
                  color: const Color(0xFF00FFFF).withOpacity(0.6), // Cyan
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(magX, offsetY),
              child: Text(
                _displayText,
                style: widget.style.copyWith(
                  color: const Color(0xFFFF00FF).withOpacity(0.6), // Magenta
                ),
              ),
            ),
            // Primary Text
            Transform.translate(
              offset: Offset(offsetX, offsetY),
              child: Text(
                _displayText,
                style: widget.style.copyWith(color: currentColor),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Custom painter para patrón decorativo maya
class _MayaPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4A7C59).withOpacity(0.03)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Dibujar patrones geométricos inspirados en diseños mayas
    const double spacing = 80;
    
    for (double x = 0; x < size.width + spacing; x += spacing) {
      for (double y = 0; y < size.height + spacing; y += spacing) {
        // Círculos concéntricos pequeños
        canvas.drawCircle(Offset(x, y), 15, paint);
        canvas.drawCircle(Offset(x, y), 8, paint);
        
        // Líneas diagonales formando un patrón
        canvas.drawLine(
          Offset(x - 20, y - 20),
          Offset(x + 20, y + 20),
          paint,
        );
        canvas.drawLine(
          Offset(x + 20, y - 20),
          Offset(x - 20, y + 20),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Widget de partículas doradas flotantes
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
  double x = math.Random().nextDouble();
  double y = math.Random().nextDouble();
  double size = math.Random().nextDouble() * 3 + 1;
  double speed = math.Random().nextDouble() * 0.5 + 0.2;
  double opacity = math.Random().nextDouble() * 0.4 + 0.2;
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

