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
          return Center(
              child: Text("No hay pistas configuradas para este evento.",
                  style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5))));
        }

        final clues = snapshot.data!;

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: clues.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final clue = clues[index];
            return Card(
              color: Theme.of(context).cardTheme.color,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.lGoldAction.withOpacity(0.12),
                  child: Text("${index + 1}",
                      style: const TextStyle(
                          color: AppTheme.lGoldAction,
                          fontWeight: FontWeight.bold)),
                ),
                title: Text(clue.title,
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
                subtitle: Text("${clue.typeName} - ${clue.puzzleType.label}",
                    style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5))),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (event.type != 'online')
                      IconButton(
                        icon: const Icon(Icons.qr_code_rounded,
                            color: AppTheme.lGoldAction),
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
                            const Icon(Icons.edit_rounded, color: AppTheme.lGoldAction),
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
