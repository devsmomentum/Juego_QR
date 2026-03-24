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
      backgroundColor: AppTheme.cardBg,
      title: const Row(
        children: [
          Icon(Icons.verified_user, color: Colors.greenAccent, size: 28),
          SizedBox(width: 8),
          Text("Reinicio Seguro Completado",
              style: TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Integrity verification
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield, color: Colors.greenAccent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "$cluesPreserved pistas intactas e íntegras",
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text("Datos eliminados:",
                style: TextStyle(
                    color: Colors.white70, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _summaryRow("Jugadores expulsados", summary['players_removed']),
            _summaryRow("Solicitudes limpiadas", summary['requests_removed']),
            _summaryRow("Progreso de pistas", summary['progress_cleared']),
            _summaryRow("Poderes limpiados", summary['powers_cleared']),
            _summaryRow("Transacciones", summary['transactions_cleared']),
            _summaryRow("Logs de combate", summary['combat_logs_cleared']),
            _summaryRow("Apuestas", summary['bets_cleared']),
            _summaryRow("Premios", summary['prizes_cleared']),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple),
          onPressed: () => Navigator.pop(context),
          child: const Text("Entendido", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, dynamic count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Text("${count ?? 0}",
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 13)),
        ],
      ),
    );
  }
}
