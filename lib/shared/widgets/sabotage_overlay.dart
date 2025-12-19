import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../features/game/providers/power_effect_provider.dart';
import '../../../features/game/widgets/effects/blind_effect.dart';
import '../../../features/game/widgets/effects/freeze_effect.dart';
import '../../../features/game/widgets/effects/slow_motion_effect.dart';

class SabotageOverlay extends StatelessWidget {
  final Widget child;
  const SabotageOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final powerProvider = Provider.of<PowerEffectProvider>(context);
    final activeSlug = powerProvider.activePowerSlug;
    final defenseAction = powerProvider.lastDefenseAction;

    return Stack(
      children: [
        child, // El juego base siempre debajo
        
        // Capas de sabotaje (se activan según el slug recibido de la DB)
        if (activeSlug == 'black_screen') const BlindEffect(),
        if (activeSlug == 'freeze') const FreezeEffect(),
        if (activeSlug == 'slow_motion') const SlowMotionEffect(),

        // Feedback rápido para el atacante cuando su acción fue bloqueada o devuelta.
        _DefenseFeedbackToast(action: defenseAction),
      ],
    );
  }
}

class _DefenseFeedbackToast extends StatelessWidget {
  final DefenseAction? action;

  const _DefenseFeedbackToast({required this.action});

  @override
  Widget build(BuildContext context) {
    if (action == null) return const SizedBox.shrink();

    final message = action == DefenseAction.shieldBlocked
        ? '🛡️ ¡ATAQUE BLOQUEADO POR ESCUDO!'
        : '↩️ ¡ATAQUE DEVUELTO!';

    return Positioned(
      top: 16,
      right: 16,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.1),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: Container(
          key: ValueKey(action),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white24),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}