import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../models/clue.dart';

class SuccessCelebrationDialog extends StatelessWidget {
  final Clue clue;
  final bool showNextStep;
  final VoidCallback onMapReturn;

  const SuccessCelebrationDialog({
    super.key,
    required this.clue,
    required this.showNextStep,
    required this.onMapReturn,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.transparent,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 20),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.primaryPurple, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '¡DESAFÍO COMPLETADO!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.successGreen,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accentGold.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "INFORMACIÓN DESBLOQUEADA",
                        style: TextStyle(
                          color: AppTheme.accentGold,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        clue.description,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildRewardBadge(Icons.star, "+${clue.xpReward} XP", AppTheme.accentGold),
                    const SizedBox(width: 15),
                    _buildRewardBadge(Icons.monetization_on, "+${clue.coinReward}", Colors.amber),
                  ],
                ),
                if (showNextStep) ...[
                  const SizedBox(height: 20),
                  Text(
                    "¡Siguiente misión desbloqueada en el mapa!",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onMapReturn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 5,
                    ),
                    icon: const Icon(Icons.map),
                    label: const Text(
                      'VOLVER AL MAPA',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -40,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.primaryPurple, AppTheme.secondaryPink]),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.cardBg, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryPurple.withOpacity(0.5),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(Icons.emoji_events, size: 40, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
