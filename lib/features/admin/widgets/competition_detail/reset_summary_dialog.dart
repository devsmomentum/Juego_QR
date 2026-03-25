import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class ResetSummaryDialog extends StatelessWidget {
  final Map<String, dynamic> result;

  const ResetSummaryDialog({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final summary = result['summary'] as Map<String, dynamic>? ?? {};
    final cluesPreserved = result['clues_preserved'] ?? 0;

    return AlertDialog(
      backgroundColor: Theme.of(context).cardTheme.color,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.verified_user_rounded, color: Colors.green, size: 28),
          const SizedBox(width: 12),
          Text("Reinicio Completado",
              style: TextStyle(
                  color: Theme.of(context).textTheme.displayLarge?.color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Integrity verification
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_rounded, color: Colors.green, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "$cluesPreserved pistas intactas e íntegras",
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text("DETALLES DE LIMPIEZA:",
                style: TextStyle(
                    color: Theme.of(context).textTheme.displayLarge?.color,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.5)),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            _summaryRow(context, "Jugadores expulsados", summary['players_removed']),
            _summaryRow(context, "Solicitudes limpiadas", summary['requests_removed']),
            _summaryRow(context, "Progreso de pistas", summary['progress_cleared']),
            _summaryRow(context, "Poderes limpiados", summary['powers_cleared']),
            _summaryRow(context, "Transacciones", summary['transactions_cleared']),
            _summaryRow(context, "Logs de combate", summary['combat_logs_cleared']),
            _summaryRow(context, "Apuestas", summary['bets_cleared']),
            _summaryRow(context, "Premios", summary['prizes_cleared']),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.lGoldAction,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            elevation: 4,
          ),
          onPressed: () => Navigator.pop(context),
          child: const Text("ENTENDIDO", style: TextStyle(fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }

  Widget _summaryRow(BuildContext context, String label, dynamic count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.lGoldAction.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text("${count ?? 0}",
                style: const TextStyle(
                    color: AppTheme.lGoldAction,
                    fontWeight: FontWeight.w900,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
