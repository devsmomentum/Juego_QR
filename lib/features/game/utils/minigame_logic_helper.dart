import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../../auth/providers/player_provider.dart';

class MinigameLogicHelper {
  /// Ejecuta la lógica centralizada de pérdida de vida:
  /// 1. Llama al backend (GameProvider)
  /// 2. Actualiza forzosamente el estado local (PlayerProvider)
  /// 3. Inicia la sincronización en background
  /// Retorna la cantidad definitiva de vidas restantes.
  static Future<int> executeLoseLife(BuildContext context) async {
    // Usamos read porque esto se llama dentro de funciones, no en build
    final gameProvider = context.read<GameProvider>();
    final playerProvider = context.read<PlayerProvider>();

    if (playerProvider.currentPlayer == null) return 0;

    // 1. Backend + Source of Truth
    final newLives = await gameProvider.loseLife(playerProvider.currentPlayer!.userId);

    // 2. Actualización Local Inmediata (Critical Path)
    playerProvider.updateLocalLives(newLives);

    // 3. Sync Background (Eventual Consistency)
    if (context.mounted) {
      playerProvider.refreshProfile(eventId: gameProvider.currentEventId);
    }

    return newLives;
  }
}
