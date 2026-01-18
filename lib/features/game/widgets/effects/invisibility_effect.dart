import 'package:flutter/material.dart';
import 'effect_timer.dart';

class InvisibilityEffect extends StatelessWidget {
  final DateTime? expiresAt;
  const InvisibilityEffect({super.key, this.expiresAt});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final overlay = Color.alphaBlend(
      Colors.black.withOpacity(0.22),
      primary.withOpacity(0.16),
    );

    return Material(
      color: Colors.transparent,
      child: IgnorePointer(
        child: Stack(
          children: [
            Container(color: overlay),
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 0,
              right: 0,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.visibility_off_outlined,
                            size: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'MODO INVISIBLE',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              decoration: TextDecoration.none, // Quita subrayado amarillo
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (expiresAt != null) ...[
                      const SizedBox(height: 12),
                      EffectTimer(expiresAt: expiresAt!),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
