import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';

class ExitProtectionWrapper extends StatelessWidget {
  final Widget child;
  final String title;
  final String message;
  final bool enableProtection;

  const ExitProtectionWrapper({
    super.key,
    required this.child,
    this.title = "¿Salir del Evento?",
    this.message = "Si sales ahora, podrías perder tu progreso o tu posición en el ranking.",
    this.enableProtection = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enableProtection) return child;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: Text(message, style: const TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("CANCELAR", style: TextStyle(color: Colors.white60)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
                child: const Text("SALIR"),
              ),
            ],
          ),
        );

        if (shouldExit == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: child,
    );
  }
}
