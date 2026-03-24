import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// A two-step confirmation dialog that prevents accidental resets.
/// The admin must type "REINICIAR" to unlock the confirm button.
class SafeResetConfirmDialog extends StatefulWidget {
  final String eventTitle;

  const SafeResetConfirmDialog({super.key, required this.eventTitle});

  @override
  State<SafeResetConfirmDialog> createState() => _SafeResetConfirmDialogState();
}

class _SafeResetConfirmDialogState extends State<SafeResetConfirmDialog> {
  final _controller = TextEditingController();
  bool _canConfirm = false;

  static const _confirmWord = 'REINICIAR';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Text("Reinicio Seguro",
                style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 18,
                    fontWeight: FontWeight.w900)),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Evento: "${widget.eventTitle}"',
              style: const TextStyle(
                  color: AppTheme.accentGold, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),

            // What WILL be deleted
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("SE ELIMINARÁ:",
                      style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w900,
                          fontSize: 13)),
                  const SizedBox(height: 6),
                  const Text("• Inscripciones de jugadores",
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const Text("• Progreso de pistas de todos los usuarios",
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const Text("• Poderes, transacciones y combates",
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const Text("• Apuestas y distribuciones de premios",
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const Text("• Solicitudes de ingreso",
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // What will NOT be deleted
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("SE PRESERVARÁ:",
                      style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w900,
                          fontSize: 13)),
                  const SizedBox(height: 6),
                  const Text("• Todas las pistas y sus ubicaciones",
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const Text("• Configuración del evento",
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const Text("• Tiendas del centro comercial",
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Confirmation input
            const Text(
              'Escribe REINICIAR para confirmar:',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              style: const TextStyle(
                  color: Colors.white,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: _confirmWord,
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.1)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _canConfirm ? Colors.green : Colors.white12,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _canConfirm ? Colors.green : Colors.white12,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _canConfirm ? Colors.green : AppTheme.accentGold,
                  ),
                ),
              ),
              textCapitalization: TextCapitalization.characters,
              onChanged: (value) {
                setState(() {
                  _canConfirm = value.trim().toUpperCase() == _confirmWord;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _canConfirm ? Colors.red : Colors.grey[800],
            elevation: 0,
          ),
          onPressed: _canConfirm ? () => Navigator.pop(context, true) : null,
          child: Text(
            _canConfirm ? "REINICIAR EVENTO" : "Escribe REINICIAR...",
            style: TextStyle(
              color: _canConfirm ? Colors.white : Colors.white24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
