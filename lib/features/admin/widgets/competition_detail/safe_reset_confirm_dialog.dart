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
      backgroundColor: Theme.of(context).cardTheme.color,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Text("Reinicio Seguro",
                style: TextStyle(
                    color: Theme.of(context).textTheme.displayLarge?.color,
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
                  color: AppTheme.lGoldAction, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),

            // What WILL be deleted
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.1)),
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
                  _buildListItem("Inscripciones de jugadores", isRed: true),
                  _buildListItem("Progreso de pistas de todos los usuarios", isRed: true),
                  _buildListItem("Poderes, transacciones y combates", isRed: true),
                  _buildListItem("Apuestas y distribuciones de premios", isRed: true),
                  _buildListItem("Solicitudes de ingreso", isRed: true),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // What will NOT be deleted
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.1)),
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
                  _buildListItem("Todas las pistas y sus ubicaciones", isRed: false),
                  _buildListItem("Configuración del evento", isRed: false),
                  _buildListItem("Tiendas del centro comercial", isRed: false),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Confirmation input
            Text(
              'Escribe REINICIAR para confirmar:',
              style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6), fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              style: TextStyle(
                  color: Theme.of(context).textTheme.displayLarge?.color,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: _confirmWord,
                hintStyle: TextStyle(
                    color: Theme.of(context)
                        .textTheme
                        .displayLarge
                        ?.color
                        ?.withOpacity(0.1)),
                filled: true,
                fillColor: Theme.of(context).dividerColor.withOpacity(0.03),
                prefixIcon: const Icon(Icons.security_rounded,
                    color: AppTheme.lGoldAction),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _canConfirm
                        ? Colors.green
                        : Theme.of(context).dividerColor.withOpacity(0.1),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _canConfirm
                        ? Colors.green
                        : Theme.of(context).dividerColor.withOpacity(0.1),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _canConfirm ? Colors.green : AppTheme.lGoldAction,
                    width: 2,
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
          child: Text("Cancelar",
              style: TextStyle(
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withOpacity(0.5))),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _canConfirm
                ? Colors.redAccent
                : Theme.of(context).dividerColor.withOpacity(0.1),
            foregroundColor: _canConfirm
                ? Colors.white
                : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3),
            elevation: _canConfirm ? 4 : 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onPressed: _canConfirm ? () => Navigator.pop(context, true) : null,
          child: Text(
            _canConfirm ? "REINICIAR EVENTO" : "Escribe REINICIAR...",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildListItem(String text, {required bool isRed}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(Icons.circle,
              size: 6,
              color: (isRed ? Colors.red : Colors.green).withOpacity(0.5)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withOpacity(0.7),
                    fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
