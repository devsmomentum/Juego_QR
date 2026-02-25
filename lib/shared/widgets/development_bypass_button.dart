import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/auth/providers/player_provider.dart';
import '../../../core/theme/app_theme.dart';

/// A development bypass button that is ONLY visible to admin users.
///
/// This widget renders a bypass button that allows admin users to skip
/// QR scanning validation during testing. It is completely invisible to
/// regular 'user' roles.
///
/// Usage:
/// ```dart
/// DevelopmentBypassButton(
///   onBypass: () => _handleScannedCode("DEV_SKIP_CODE"),
///   label: "Saltar Escaneo QR",
/// )
/// ```
class DevelopmentBypassButton extends StatelessWidget {
  /// Callback executed when the bypass button is pressed.
  final VoidCallback onBypass;

  /// Label text for the button.
  final String label;

  /// Optional icon (defaults to a bug icon).
  final IconData icon;

  const DevelopmentBypassButton({
    super.key,
    required this.onBypass,
    this.label = 'DEV: Saltar QR',
    this.icon = Icons.developer_mode,
  });

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>().currentPlayer;

    // SECURITY: Only render for admin role
    if (player == null || !player.isAdmin) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange.shade800,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Colors.orange.shade400,
              width: 1.5,
            ),
          ),
          elevation: 0,
        ),
        onPressed: () {
          // Show confirmation dialog to prevent accidental taps
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppTheme.cardBg,
              title: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange.shade400, size: 24),
                  const SizedBox(width: 8),
                  const Text('Bypass de Desarrollo',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
              content: const Text(
                '¿Saltar la validación QR? Este bypass solo está disponible para administradores.',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onBypass();
                  },
                  child: Text('Confirmar',
                      style: TextStyle(color: Colors.orange.shade400)),
                ),
              ],
            ),
          );
        },
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }
}
