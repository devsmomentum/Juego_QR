// lib/features/game/widgets/effects/return_status_effect.dart
import 'package:flutter/material.dart';

class ReturnStatusEffect extends StatelessWidget {
  const ReturnStatusEffect({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          // Aura púrpura en los bordes
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 1.2,
                colors: [
                  Colors.transparent,
                  Colors.purpleAccent.withOpacity(0.05),
                  Colors.purpleAccent.withOpacity(0.2),
                ],
                stops: const [0.7, 0.9, 1.0],
              ),
            ),
          ),
          // Etiqueta superior
          Positioned(
            top: MediaQuery.of(context).padding.top + 45, // Debajo del modo invisible si ambos están activos
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.purpleAccent.withOpacity(0.5)),
                ),
                child: const Text(
                  '🔄 Devolución activa',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}