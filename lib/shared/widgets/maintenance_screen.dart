import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/version_check_service.dart';
import '../../features/auth/providers/player_provider.dart';
import '../../features/auth/screens/login_screen.dart';

/// Pantalla de mantenimiento post-login.
/// - Usuarios normales: bloquea totalmente + cerrar sesión.
/// - Admins: muestra mensaje + botón para continuar + cerrar sesión.
/// Re-chequea el estado de mantenimiento periódicamente para salir automáticamente.
class MaintenanceScreen extends StatefulWidget {
  final bool isAdmin;
  final VoidCallback? onContinueAsAdmin;

  const MaintenanceScreen({
    super.key,
    required this.isAdmin,
    this.onContinueAsAdmin,
  });

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  Timer? _recheckTimer;

  @override
  void initState() {
    super.initState();
    // Re-chequear cada 30s si el mantenimiento sigue activo
    _recheckTimer = Timer.periodic(const Duration(seconds: 30), (_) => _recheckMaintenance());
  }

  @override
  void dispose() {
    _recheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _recheckMaintenance() async {
    try {
      final service = VersionCheckService(Supabase.instance.client);
      final status = await service.checkVersion();
      if (!mounted) return;
      if (!status.maintenanceMode) {
        // Mantenimiento desactivado → volver al login para flujo normal
        _navigateToLogin();
      }
    } catch (_) {
      // Silenciar errores del re-check
    }
  }

  Future<void> _logout() async {
    try {
      await Provider.of<PlayerProvider>(context, listen: false).logout();
    } catch (_) {}
    if (!mounted) return;
    _navigateToLogin();
  }

  void _navigateToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.construction_rounded,
                  size: 80,
                  color: Colors.orange,
                ),
                const SizedBox(height: 24),
                const Text(
                  'En Mantenimiento',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'La aplicación está en mantenimiento temporalmente.\n'
                  'Intenta nuevamente en unos minutos.',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                if (widget.isAdmin) ...[
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: widget.onContinueAsAdmin,
                      icon: const Icon(Icons.admin_panel_settings_rounded),
                      label: const Text(
                        'CONTINUAR COMO ADMIN',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text(
                      'CERRAR SESIÓN',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
