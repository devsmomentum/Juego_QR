import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import '../../features/auth/providers/player_provider.dart';

class SabotageOverlay extends StatelessWidget {
  final Widget child;

  const SabotageOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, playerProvider, _) {
        final player = playerProvider.currentPlayer;
        
        // Handle Slow Motion
        if (player != null && player.isSlowed) {
          timeDilation = 5.0; // 5x slower
        } else {
          timeDilation = 1.0; // Normal speed
        }
        
        // Check if user is blinded (frozen screen)
        if (player != null && player.isBlinded) {
          return Stack(
            children: [
              child,
              Container(
                color: Colors.black,
                width: double.infinity,
                height: double.infinity,
                child: Material( // Material needed for Text styles if not present
                  color: Colors.black,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.visibility_off,
                          color: Colors.red,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '¡SABOTAJE!',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tu pantalla ha sido congelada...',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        
        return child;
      },
    );
  }
}
