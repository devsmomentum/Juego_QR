import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/game/providers/game_provider.dart';
import '../../features/auth/providers/player_provider.dart';
import '../../core/theme/app_theme.dart';

class ProgressHeader extends StatelessWidget {
  const ProgressHeader({super.key});

  @override
  Widget build(BuildContext context) {
  return Consumer2<GameProvider, PlayerProvider>(
    builder: (context, gameProvider, playerProvider, child) {
      final player = playerProvider.currentPlayer;
      if (player == null) return const SizedBox.shrink();

      // ✅ SINGLE SOURCE OF TRUTH: Solo GameProvider para vidas globales
      final int displayLives = gameProvider.lives;
        
        return CustomPaint(
          painter: PixelBorderPainter(color: AppTheme.primaryPurple),
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryPurple.withOpacity(0.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CustomPaint(
                      painter: PixelBorderPainter(color: AppTheme.accentGold),
                      child: Container(
                        width: 42,
                        height: 42,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPurple.withOpacity(0.3),
                        ),
                        child: Builder(
                          builder: (context) {
                            // 1. Prioridad: Avatar Local
                            if (player.avatarId != null && player.avatarId!.isNotEmpty) {
                              return Image.asset(
                                'assets/images/avatars/${player.avatarId}.png',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Text(player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  );
                                },
                              );
                            }
                            
                            // 2. Fallback: Foto de perfil (URL)
                            if (player.avatarUrl != null && player.avatarUrl!.startsWith('http')) {
                              return Image.network(
                                player.avatarUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Center(
                                  child: Text(player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              );
                            }
                            
                            // 3. Fallback: Iniciales
                            return Center(
                              child: Text(player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            player.name.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            'LVL ${player.level} • ${player.profession.toUpperCase()}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.secondaryPink.withOpacity(0.8),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Stats Row
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Coins
                        Row(
                          children: [
                            const Icon(Icons.monetization_on, size: 14, color: AppTheme.accentGold),
                            const SizedBox(width: 4),
                            Text(
                              '${player.coins}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Lives
                        Row(
                          children: [
                            const Icon(Icons.favorite, size: 14, color: AppTheme.dangerRed),
                            const SizedBox(width: 4),
                            Text(
                              '$displayLives',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Progress Label
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PROGRESO DE MISIÓN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withOpacity(0.5),
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      '${gameProvider.completedClues}/${gameProvider.totalClues}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentGold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Custom Progress Bar
                Container(
                  height: 6,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: gameProvider.totalClues > 0
                        ? (gameProvider.completedClues / gameProvider.totalClues).clamp(0.0, 1.0)
                        : 0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryPurple.withOpacity(0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class PixelBorderPainter extends CustomPainter {
  final Color color;

  PixelBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);

    const double pixelSize = 4;
    final dotPaint = Paint()..color = color..style = PaintingStyle.fill;

    canvas.drawRect(const Rect.fromLTWH(0, 0, pixelSize, pixelSize), dotPaint);
    canvas.drawRect(Rect.fromLTWH(size.width - pixelSize, 0, pixelSize, pixelSize), dotPaint);
    canvas.drawRect(Rect.fromLTWH(0, size.height - pixelSize, pixelSize, pixelSize), dotPaint);
    canvas.drawRect(Rect.fromLTWH(size.width - pixelSize, size.height - pixelSize, pixelSize, pixelSize), dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}