import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class RaceTrackWidget extends StatelessWidget {
  final int currentClueIndex;
  final int totalClues;
  final VoidCallback? onSurrender;

  const RaceTrackWidget({
    super.key,
    required this.currentClueIndex,
    required this.totalClues,
    this.onSurrender,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '🏁 CARRERA EN VIVO',
                style: TextStyle(
                  color: AppTheme.accentGold,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Row(
                children: [
                  if (onSurrender != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: GestureDetector(
                        onTap: onSurrender,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.dangerRed.withOpacity(0.2),
                            border: Border.all(color: AppTheme.dangerRed),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.flag, color: AppTheme.dangerRed, size: 12),
                              SizedBox(width: 4),
                              Text(
                                'RENDIRSE',
                                style: TextStyle(
                                  color: AppTheme.dangerRed,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerRed,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Pista de carreras
          SizedBox(
            height: 60,
            // CORRECCIÓN: El LayoutBuilder envuelve al Stack completo
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Calculamos el ancho disponible aquí
                final double trackWidth = constraints.maxWidth;
                
                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // Línea de la pista
                    Container(
                      height: 8,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    
                    // Meta
                    const Positioned(
                      right: 0,
                      top: 15,
                      child: Icon(Icons.flag, color: Colors.white, size: 24),
                    ),

                    // Jugador (Tú)
                    _buildRacer(
                      context,
                      progress: totalClues > 0 ? currentClueIndex / totalClues : 0.0,
                      color: AppTheme.primaryPurple,
                      label: 'TÚ',
                      isMe: true,
                      trackWidth: trackWidth, // Pasamos el ancho
                    ),

                    // Rival 1 (Bot)
                    _buildRacer(
                      context,
                      progress: totalClues > 0 ? (currentClueIndex + 1).clamp(0, totalClues) / totalClues : 0.0,
                      color: AppTheme.dangerRed,
                      label: 'Rival 1',
                      isMe: false,
                      offsetY: -25,
                      trackWidth: trackWidth,
                    ),

                    // Rival 2 (Bot)
                    _buildRacer(
                      context,
                      progress: totalClues > 0 ? (currentClueIndex - 1).clamp(0, totalClues) / totalClues : 0.0,
                      color: AppTheme.successGreen,
                      label: 'Rival 2',
                      isMe: false,
                      offsetY: 25,
                      trackWidth: trackWidth,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // CORRECCIÓN: Quitamos LayoutBuilder interno y recibimos trackWidth
  Widget _buildRacer(
    BuildContext context, {
    required double progress,
    required Color color,
    required String label,
    required bool isMe,
    required double trackWidth,
    double offsetY = 0,
  }) {
    final safeProgress = progress.clamp(0.0, 1.0);
    final double maxScroll = trackWidth - 40; // Restar ancho del avatar

    // AHORA SÍ: Positioned es hijo directo del Stack
    return Positioned(
      left: maxScroll * safeProgress,
      top: 30 + offsetY,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: isMe ? 2 : 1,
              ),
              boxShadow: isMe
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ]
                  : [],
            ),
            child: Center(
              child: Text(
                label[0],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          if (!isMe)
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('¡Sabotaje lanzado! -50 Monedas'),
                    backgroundColor: Colors.red,
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.flash_on, size: 12, color: Colors.yellow),
              ),
            ),
        ],
      ),
    );
  }
}