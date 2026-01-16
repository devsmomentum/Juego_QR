import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/game_provider.dart';

/// Widget reactivo que muestra las vidas globales del jugador.
/// Se actualiza automáticamente cuando GameProvider recibe cambios vía Realtime.
class AnimatedLivesWidget extends StatelessWidget {
  const AnimatedLivesWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ REACTIVIDAD: Escucha cambios en GameProvider.lives
    final lives = context.watch<GameProvider>().lives;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.dangerRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: lives <= 1 
            ? AppTheme.dangerRed 
            : AppTheme.dangerRed.withOpacity(0.5)
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.favorite, color: AppTheme.dangerRed, size: 14),
          const SizedBox(width: 4),
          Text(
            'x$lives',
            style: TextStyle(
              color: lives <= 1 ? AppTheme.dangerRed : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
