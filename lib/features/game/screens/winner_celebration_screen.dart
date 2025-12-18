import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../providers/game_provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/player.dart';

class WinnerCelebrationScreen extends StatefulWidget {
  final String eventId;
  final int playerPosition;
  final int totalCluesCompleted;

  const WinnerCelebrationScreen({
    super.key,
    required this.eventId,
    required this.playerPosition,
    required this.totalCluesCompleted,
  });

  @override
  State<WinnerCelebrationScreen> createState() => _WinnerCelebrationScreenState();
}

class _WinnerCelebrationScreenState extends State<WinnerCelebrationScreen> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    
    // Start confetti for top 3 finishers
    if (widget.playerPosition <= 3) {
      _confettiController.play();
    }
    
    // Load final leaderboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      gameProvider.fetchLeaderboard();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  String _getMedalEmoji() {
    switch (widget.playerPosition) {
      case 1:
        return '🏆';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '🏁';
    }
  }

  String _getCelebrationMessage() {
    if (widget.playerPosition == 1) {
      return '¡Eres el Campeón!';
    } else if (widget.playerPosition <= 3) {
      return '¡Podio Merecido!';
    } else {
      return '¡Carrera Completada!';
    }
  }

  Color _getPositionColor() {
    switch (widget.playerPosition) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return AppTheme.accentGold;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);
    final playerProvider = Provider.of<PlayerProvider>(context);
    final currentPlayerId = playerProvider.currentPlayer?.id ?? '';

    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.darkGradient,
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // Confetti overlay
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirection: pi / 2, // Down
                  maxBlastForce: 5,
                  minBlastForce: 2,
                  emissionFrequency: 0.05,
                  numberOfParticles: 20,
                  gravity: 0.3,
                  colors: const [
                    Colors.green,
                    Colors.blue,
                    Colors.pink,
                    Colors.orange,
                    Colors.purple,
                    Color(0xFFFFD700),
                  ],
                ),
              ),

              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // Medal/Trophy Icon
                      Text(
                        _getMedalEmoji(),
                        style: const TextStyle(fontSize: 100),
                      ),

                      const SizedBox(height: 20),

                      // Celebration Message
                      Text(
                        _getCelebrationMessage(),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: _getPositionColor(),
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 10),

                      // Position Display
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: _getPositionColor().withOpacity(0.2),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: _getPositionColor(),
                            width: 2,
                          ),
                        ),
                        child: Text(
                          'Posición #${widget.playerPosition}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: _getPositionColor(),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Clues completed
                      Text(
                        'Pistas Completadas: ${widget.totalCluesCompleted}',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white70,
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Final Leaderboard Title
                      const Text(
                        'Tabla de Posiciones Final',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Leaderboard
                      if (gameProvider.isLoading)
                        const CircularProgressIndicator()
                      else if (gameProvider.leaderboard.isEmpty)
                        const Text(
                          'No hay datos del ranking',
                          style: TextStyle(color: Colors.white70),
                        )
                      else
                        ...gameProvider.leaderboard.asMap().entries.map((entry) {
                          final index = entry.key;
                          final player = entry.value;
                          final position = index + 1;
                          final isCurrentPlayer = player.id == currentPlayerId;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isCurrentPlayer
                                  ? AppTheme.accentGold.withOpacity(0.2)
                                  : AppTheme.cardBg,
                              borderRadius: BorderRadius.circular(12),
                              border: isCurrentPlayer
                                  ? Border.all(color: AppTheme.accentGold, width: 2)
                                  : null,
                            ),
                            child: Row(
                              children: [
                                // Position
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: position <= 3
                                        ? _getPositionColorForRank(position)
                                        : Colors.grey.shade700,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      position <= 3 ? _getMedalEmojiForRank(position) : '$position',
                                      style: TextStyle(
                                        fontSize: position <= 3 ? 20 : 16,
                                        fontWeight: FontWeight.bold,
                                        color: position <= 3 ? null : Colors.white,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 16),

                                // Player Avatar
                                CircleAvatar(
                                  radius: 20,
                                  backgroundImage: player.avatarUrl.isNotEmpty
                                      ? NetworkImage(player.avatarUrl)
                                      : null,
                                  child: player.avatarUrl.isEmpty
                                      ? Text(
                                          player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        )
                                      : null,
                                ),

                                const SizedBox(width: 12),

                                // Player name
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        player.name,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isCurrentPlayer ? AppTheme.accentGold : Colors.white,
                                        ),
                                      ),
                                      Text(
                                        'Nivel ${player.level}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Clues completed (using totalXP as clues count)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${player.totalXP} pistas',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.greenAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),

                      const SizedBox(height: 40),

                      // Return to Home Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Navigate to home and clear stack
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentGold,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.home, size: 24),
                          label: const Text(
                            'VOLVER AL INICIO',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPositionColorForRank(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return Colors.grey.shade700;
    }
  }

  String _getMedalEmojiForRank(int rank) {
    switch (rank) {
      case 1:
        return '🏆';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '';
    }
  }
}
