import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../game/models/event.dart';
import '../../../game/models/clue.dart';
import '../clue_form_dialog.dart';

class CluesTab extends StatelessWidget {
  final GameEvent event;
  final Future<List<Clue>>? cluesFuture;
  final VoidCallback onRefresh;
  final Function(String qrData, String title, String subtitle, {String? hint})
      onShowQR;

  const CluesTab({
    super.key,
    required this.event,
    this.cluesFuture,
    required this.onRefresh,
    required this.onShowQR,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Clue>>(
      future: cluesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
              child: Text("No hay pistas configuradas para este evento.",
                  style: TextStyle(color: Colors.white54)));
        }

        final clues = snapshot.data!;

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: clues.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final clue = clues[index];
            return Card(
              color: AppTheme.cardBg,
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.white.withOpacity(0.05)),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.accentGold.withOpacity(0.2),
                  child: Text("${index + 1}",
                      style: const TextStyle(
                          color: AppTheme.accentGold,
                          fontWeight: FontWeight.bold)),
                ),
                title: Text(clue.title,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text("${clue.typeName} - ${clue.puzzleType.label}",
                    style: const TextStyle(color: Colors.white54)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (event.type != 'online')
                      IconButton(
                        icon: const Icon(Icons.qr_code,
                            color: AppTheme.accentGold),
                        tooltip: "Ver QR",
                        onPressed: () {
                          final qrData = "CLUE:${event.id}:${clue.id}";
                          onShowQR(qrData, clue.title,
                              "Pista: ${clue.puzzleType.label}",
                              hint: clue.hint);
                        },
                      ),
                    IconButton(
                        icon:
                            const Icon(Icons.edit, color: AppTheme.accentGold),
                        onPressed: () async {
                          final result = await showDialog(
                            context: context,
                            builder: (_) => ClueFormDialog(
                              clue: clue,
                              eventId: event.id,
                              eventLatitude: event.latitude,
                              eventLongitude: event.longitude,
                            ),
                          );
                          if (result == true) onRefresh();
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
