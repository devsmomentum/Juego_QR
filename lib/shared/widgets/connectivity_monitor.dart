import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../features/game/providers/connectivity_provider.dart';
import '../../features/auth/providers/player_provider.dart';
import '../../core/services/connectivity_service.dart';
import '../utils/global_keys.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/admin/screens/admin_login_screen.dart';
import 'low_signal_overlay.dart';

/// Widget que monitorea la conectividad y toma acciones
/// cuando se pierde la conexión:
/// - En minijuego: pierde vida + logout
/// - En otras pantallas: solo logout
class ConnectivityMonitor extends StatefulWidget {
  final Widget child;

  const ConnectivityMonitor({super.key, required this.child});

  @override
  State<ConnectivityMonitor> createState() => _ConnectivityMonitorState();
}

class _ConnectivityMonitorState extends State<ConnectivityMonitor> {
  Timer? _countdownTimer;
  int _secondsRemaining = 20;
  bool _showOverlay = false;
  bool _hasTriggeredDisconnect = false;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    final connectivity = Provider.of<ConnectivityProvider>(context);
    final status = connectivity.status;

    // Si volvió online, cancelar todo
    if (status == ConnectivityStatus.online) {
      _cancelCountdown();
      return;
    }

    // Si señal baja o offline, iniciar countdown si no está activo
    if ((status == ConnectivityStatus.lowSignal || 
         status == ConnectivityStatus.offline) && 
        !_showOverlay && 
        !_hasTriggeredDisconnect) {
      _startCountdown();
    }

    // Si llegamos a offline y ya pasó el tiempo
    if (status == ConnectivityStatus.offline && 
        _secondsRemaining <= 0 && 
        !_hasTriggeredDisconnect) {
      _handleDisconnect();
    }
  }

  void _startCountdown() {
    if (_countdownTimer != null) return;
    
    setState(() {
      _showOverlay = true;
      _secondsRemaining = 20;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsRemaining--;
        });

        if (_secondsRemaining <= 0) {
          timer.cancel();
          _handleDisconnect();
        }
      }
    });
  }

  void _cancelCountdown() {
    if (_showOverlay || _countdownTimer != null) {
      _countdownTimer?.cancel();
      _countdownTimer = null;
      if (mounted) {
        setState(() {
          _showOverlay = false;
          _secondsRemaining = 20;
        });
      }
    }
  }

  Future<void> _handleDisconnect() async {
    if (_hasTriggeredDisconnect || !mounted) return;
    _hasTriggeredDisconnect = true;

    _countdownTimer?.cancel();
    _countdownTimer = null;

    final connectivity = context.read<ConnectivityProvider>();
    final playerProvider = context.read<PlayerProvider>();

    String message;

    // Si estaba en minijuego, pierde vida
    if (connectivity.isInMinigame) {
      final eventId = connectivity.currentEventId;
      await playerProvider.loseLife(eventId: eventId);
      message = '¡Perdiste conexión durante el minijuego!\nHas perdido una vida.';
      debugPrint('ConnectivityMonitor: Vida perdida por desconexión en minijuego');
    } else {
      message = 'Perdiste conexión a internet.\nPor favor, reconéctate e inicia sesión.';
      debugPrint('ConnectivityMonitor: Desconexión fuera de minijuego');
    }

    // Detener monitoreo y hacer logout
    connectivity.stopMonitoring();
    await playerProvider.logout();

    // Mostrar mensaje y redirigir
    _showDisconnectMessage(message);
  }

  void _showDisconnectMessage(String message) {
    if (rootNavigatorKey.currentState == null) return;

    // Navegar a login
    rootNavigatorKey.currentState!.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => kIsWeb 
            ? const AdminLoginScreen() 
            : const LoginScreen(),
      ),
      (route) => false,
    );

    // Mostrar SnackBar después de un frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (rootNavigatorKey.currentContext != null) {
        ScaffoldMessenger.of(rootNavigatorKey.currentContext!).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.wifi_off, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        
        // Overlay de señal baja
        if (_showOverlay)
          Positioned.fill(
            child: LowSignalOverlay(
              secondsRemaining: _secondsRemaining,
            ),
          ),
      ],
    );
  }
}
