import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../models/clue.dart';
import '../widgets/race_track_widget.dart';
import '../../../shared/widgets/sabotage_overlay.dart';
import '../../../shared/models/player.dart'; // Import Player model
import '../providers/connectivity_provider.dart';

// --- Imports de Minijuegos Existentes ---
import '../widgets/minigames/sliding_puzzle_minigame.dart';
import '../widgets/minigames/tic_tac_toe_minigame.dart';
import '../widgets/minigames/hangman_minigame.dart';

// --- Imports de NUEVOS Minijuegos ---
import '../widgets/minigames/tetris_minigame.dart';
import '../widgets/minigames/find_difference_minigame.dart';
import '../widgets/minigames/flags_minigame.dart';
import '../widgets/minigames/minesweeper_minigame.dart';
import '../widgets/minigames/snake_minigame.dart';
import '../widgets/minigames/block_fill_minigame.dart';
import '../widgets/minigame_countdown_overlay.dart';

// --- Import del Servicio de Penalización ---
import '../services/penalty_service.dart';
import '../utils/minigame_logic_helper.dart';
import 'winner_celebration_screen.dart';
import '../widgets/animated_lives_widget.dart';
import '../widgets/loss_flash_overlay.dart';
import '../widgets/success_celebration_dialog.dart';
import '../../../shared/widgets/time_stamp_animation.dart';
import '../widgets/mission_briefing_overlay.dart';
import '../../../shared/widgets/animated_cyber_background.dart';

class PuzzleScreen extends StatefulWidget {
  final Clue clue;

  const PuzzleScreen({super.key, required this.clue});

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen>
    with WidgetsBindingObserver {
  late final PenaltyService _penaltyService;
  bool _legalExit = false;
  bool _isNavigatingToWinner = false; // Flag to prevent double navigation
  bool _showBriefing = true; // Empieza mostrando la historia

  @override
  void initState() {
    super.initState();
    _penaltyService = context.read<PenaltyService>();
    WidgetsBinding.instance.addObserver(this);
    // Bandera arriba: El jugador está intentando jugar.
    // Si sale sin _finishLegally, el servicio sabrá que fue un abandono forzoso.
    _penaltyService.attemptStartGame();

    // Verificar vidas al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLives();

      // --- MARCAR ENTRADA A MINIJUEGO PARA CONNECTIVITY ---
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      final eventId = gameProvider.currentEventId ?? '';
      context.read<ConnectivityProvider>().enterMinigame(eventId);

      // --- ESCUCHA DE FIN DE CARRERA EN TIEMPO REAL ---
      // --- ESCUCHA DE FIN DE CARRERA EN TIEMPO REAL ---
      Provider.of<GameProvider>(context, listen: false)
          .addListener(_checkRaceCompletion);
      
      // MOVED: _checkGlobalLivesGameOver monitoring is now started inside _checkLives
      // to avoid race conditions during initialization.
    });
  }

  /// Begins monitoring global lives for in-game changes.
  /// This should only be called AFTER we have verified the user has lives to start with.
  void _startLivesMonitoring() {
    if (!mounted) return;
    try {
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      // Remove first just in case to avoid duplicates
      gameProvider.removeListener(_checkGlobalLivesGameOver);
      gameProvider.addListener(_checkGlobalLivesGameOver);
    } catch (e) {
      debugPrint("Error starting lives monitoring: $e");
    }
  }

  /// Monitorea si las vidas globales llegan a 0 durante el juego.
  /// Si detecta 0 vidas (por ej. Life Steal enemigo), cierra el minijuego.
  void _checkGlobalLivesGameOver() {
    if (!mounted || _legalExit) return;
    
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    
    // Si las vidas globales llegaron a 0, forzar salida
    if (gameProvider.lives <= 0) {
      debugPrint('[LIVES_MONITOR] 🔴 Global lives reached 0. Forcing minigame exit.');
      _finishLegally(); // Marcar como salida legal para evitar penalización
      
      if (!mounted) return;
      
      // Mostrar diálogo explicativo
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: const Text('¡Sin Vidas!', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Te has quedado sin vidas. No puedes continuar en este minijuego.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx); // Cerrar diálogo
                if (mounted) {
                  Navigator.pop(context); // Cerrar minijuego
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    }
  }

  void _checkRaceCompletion() async {
    if (!mounted || _isNavigatingToWinner) return;
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    // Si la carrera terminó (alguien ganó) y yo no he terminado todo
    if (gameProvider.isRaceCompleted && !gameProvider.hasCompletedAllClues) {
      _isNavigatingToWinner = true; // Set flag
      _finishLegally(); // Quitamos penalización

      final currentPlayerId = playerProvider.currentPlayer?.id ?? '';
      List<Player> leaderboard = gameProvider.leaderboard;

      // Si el leaderboard está vacío, intentamos traerlo una vez más para asegurar la posición
      if (leaderboard.isEmpty) {
        await gameProvider.fetchLeaderboard(silent: true);
        leaderboard = gameProvider.leaderboard;
      }

      int position = 0; // Default to 0 (Unranked) instead of 1
      if (leaderboard.isNotEmpty) {
        final index = leaderboard.indexWhere((p) => p.id == currentPlayerId);
        position = index >= 0 ? index + 1 : leaderboard.length + 1;
      } else {
        // Fallback si falla todo: Posición muy alta para no decir "Campeón"
        position = 999;
      }

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => WinnerCelebrationScreen(
            eventId: gameProvider.currentEventId ?? '',
            playerPosition: position,
            totalCluesCompleted: gameProvider.completedClues,
          ),
        ),
        (route) => route.isFirst,
      );
    }
  }

  Future<void> _checkLives() async {
    // Usamos listen: false para obtener el estado MÁS RECIENTE, no suscribirnos
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    // 1. Verificación preliminar con source-of-truth visual (PlayerProvider)
    if (playerProvider.currentPlayer != null && playerProvider.currentPlayer!.lives > 0) {
      // Si el perfil dice que tenemos vidas, CONFIAMOS EN ÉL y no bloqueamos.
      // Solo verificamos si GameProvider está desincronizado
      if (gameProvider.lives <= 0) {
        debugPrint("SYNC: Forzando actualización de vidas en GameProvider...");
        // Intentamos sincronizar pero SIN bloquear UI
        await gameProvider.fetchLives(playerProvider.currentPlayer!.userId);
      }
      
      // Safe to monitor now
      _startLivesMonitoring();
      return; 
    }

    // 2. Si PlayerProvider dice 0 o es null, verificamos con GameProvider (Server)
    if (playerProvider.currentPlayer != null) {
      await gameProvider.fetchLives(playerProvider.currentPlayer!.userId);
      
      // Volvemos a leer PlayerProvider por si acaso se actualizó en background
      final freshPlayerLives = playerProvider.currentPlayer?.lives ?? 0;
      
      if (gameProvider.lives <= 0 && freshPlayerLives <= 0) {
        if (!mounted) return;
        _showNoLivesDialog();
        // DO NOT start monitoring if we are dead.
      } else {
        debugPrint("SYNC INFO: Vidas encontradas (Game: ${gameProvider.lives}, Player: $freshPlayerLives). Juego permitido.");
        // Lives found, start monitoring
        _startLivesMonitoring();
      }
    }
  }

  void _showNoLivesDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text("¡Sin vidas!", style: TextStyle(color: Colors.white)),
        content: const Text(
            "Te has quedado sin vidas. Necesitas comprar más en la tienda para continuar jugando.",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close screen
            },
            child: const Text("Entendido"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    
    // --- MARCAR SALIDA DEL MINIJUEGO PARA CONNECTIVITY ---
    try {
      context.read<ConnectivityProvider>().exitMinigame();
    } catch (_) {}
    
    // Limpiar listener de fin de carrera
    try {
      Provider.of<GameProvider>(context, listen: false)
          .removeListener(_checkRaceCompletion);
    } catch (_) {}
    
    // Limpiar listener de monitoreo de vidas
    try {
      Provider.of<GameProvider>(context, listen: false)
          .removeListener(_checkGlobalLivesGameOver);
    } catch (_) {}
    
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // LEAVER BUSTER: Si minimiza (paused) y no ha salido legalmente, lo sacamos.
    // Esto previene trampas de salir al home del móvil para buscar respuestas.
    if (state == AppLifecycleState.paused && !_legalExit) {
      if (mounted) {
        Navigator.of(context).pop(); // Cierre forzoso = Penalización latente
      }
    }
  }

  // Helper para marcar salida legal (Ganar o Rendirse)
  Future<void> _finishLegally() async {
    setState(() => _legalExit = true);
    await _penaltyService.markGameFinishedLegally();
  }

  @override
  Widget build(BuildContext context) {
    // TAREA 4: Bloqueo de Acceso si no hay vidas
    final gameProvider = Provider.of<GameProvider>(context);
    // Mantener rebuilds si cambia el perfil del jugador, sin usar la variable.
    final player = context.watch<PlayerProvider>().currentPlayer;

    // --- STATUS OVERLAYS (Handled Globally) ---

    // Corrección para evitar "flickeo" al rendirse Y errores de sincro:
    // 1. Si _legalExit es true, estamos saliendo. No bloquear.
    // 2. Si el PlayerProvider (Visual) dice que tenemos vidas, CONFIAMOS EN ÉL. No bloquear.
    final hasVisualLives = player != null && player.lives > 0;
    
    if (gameProvider.lives <= 0 && !_legalExit && !hasVisualLives) {
      // Retornar contenedor negro con aviso
      // Nota: El diálogo _showNoLivesDialog ya se muestra en initState/checkLives,
      // pero aquí aseguramos que no se renderice el juego.
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.heart_broken,
                  color: AppTheme.dangerRed, size: 64),
              const SizedBox(height: 20),
              const Text(
                "¡SIN VIDAS!",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "No puedes jugar sin vidas.",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.dangerRed,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                ),
                child:
                    const Text("Salir", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    Widget gameWidget;
    // Pasamos _finishLegally a TODOS los hijos para que avisen antes de cerrar o ganar
    switch (widget.clue.puzzleType) {
      case PuzzleType.slidingPuzzle:
        gameWidget =
            SlidingPuzzleWrapper(clue: widget.clue, onFinish: _finishLegally);
        break;
      case PuzzleType.ticTacToe:
        gameWidget =
            TicTacToeWrapper(clue: widget.clue, onFinish: _finishLegally);
        break;
      case PuzzleType.hangman:
        gameWidget =
            HangmanWrapper(clue: widget.clue, onFinish: _finishLegally);
        break;
      case PuzzleType.tetris:
        gameWidget = TetrisWrapper(clue: widget.clue, onFinish: _finishLegally);
        break;
      case PuzzleType.findDifference:
        gameWidget =
            FindDifferenceWrapper(clue: widget.clue, onFinish: _finishLegally);
        break;
      case PuzzleType.flags:
        gameWidget = FlagsWrapper(clue: widget.clue, onFinish: _finishLegally);
        break;
      case PuzzleType.minesweeper:
        gameWidget =
            MinesweeperWrapper(clue: widget.clue, onFinish: _finishLegally);
        break;
      case PuzzleType.snake:
        gameWidget = SnakeWrapper(clue: widget.clue, onFinish: _finishLegally);
        break;
      case PuzzleType.blockFill:
        gameWidget =
            BlockFillWrapper(clue: widget.clue, onFinish: _finishLegally);
        break;
    }

    if (_showBriefing) {
      return MissionBriefingOverlay(
        stampIndex: ((widget.clue.sequenceIndex - 1) % 9) + 1,
        onStart: () => setState(() => _showBriefing = false),
      );
    }

    // WRAPPER DE SEGURIDAD: Evitar salir sin penalización
    return PopScope(
      canPop: _legalExit,
      onPopInvoked: (didPop) async {
        if (didPop || _legalExit) return;
        
        // Si intenta salir con Back, mostramos el diálogo de rendición (que cobra vida)
        showSkipDialog(context, _finishLegally);
      },
      child: gameWidget,
    );
  }
}

// ... (Rest of file content: helper functions and wrappers) ...
// NOTE: I am not replacing the whole file, just the beginning and ending part involving _buildMinigameScaffold
// But replace_file_content does replace whole blocks. I need to be careful.
// Wait, replace_file_content replaces a CONTIGUOUS BLOCK.
// I need to replace from imports to the end of _buildMinigameScaffold if I want to do it all in one go, but the file is large.
// I will use multi_replace_file_content to be safer and precise.

// --- FUNCIONES HELPER GLOBALES ---

void showClueSelector(BuildContext context, Clue currentClue) {
  final gameProvider = Provider.of<GameProvider>(context, listen: false);
  final availableClues = gameProvider.clues.where((c) => !c.isLocked).toList();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppTheme.cardBg,
      title: const Text('Cambiar Pista', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: availableClues.length,
          itemBuilder: (context, index) {
            final clue = availableClues[index];
            final isCurrentClue = clue.id == currentClue.id;

            return ListTile(
              leading: Icon(
                clue.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                color: clue.isCompleted
                    ? AppTheme.successGreen
                    : AppTheme.accentGold,
              ),
              title: Text(
                clue.title,
                style: TextStyle(
                  color: isCurrentClue ? AppTheme.secondaryPink : Colors.white,
                  fontWeight:
                      isCurrentClue ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                clue.description,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: isCurrentClue
                  ? const Icon(Icons.arrow_forward,
                      color: AppTheme.secondaryPink)
                  : null,
              onTap: isCurrentClue
                  ? null
                  : () {
                      gameProvider.switchToClue(clue.id);

                      Navigator.pop(context); // Close dialog
                      Navigator.pop(context); // Close current PuzzleScreen

                      // Navigate to new puzzle screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PuzzleScreen(clue: clue),
                        ),
                      );
                    },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    ),
  );
}

/// Diálogo de rendición actualizado para manejar la salida legal
void showSkipDialog(BuildContext context, VoidCallback? onLegalExit) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppTheme.cardBg,
      title: const Text('¿Rendirse?', style: TextStyle(color: Colors.white)),
      content: const Text(
        '¡Lástima! Si te rindes, NO podrás desbloquear la siguiente pista porque no resolviste este desafío.',
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () async {
            // RENDICIÓN = SALIDA LEGAL
            if (onLegalExit != null) {
              onLegalExit();
            }

            // Usamos dialogContext para cerrar el diálogo
            Navigator.pop(dialogContext); 
            // Usamos context (el argumento original de la función) para cerrar el PuzzleScreen
            if (context.mounted) {
               Navigator.pop(context);
            }

            // Deduct life logic
            final playerProvider =
                Provider.of<PlayerProvider>(context, listen: false);
            final gameProvider =
                Provider.of<GameProvider>(context, listen: false);
            
            if (playerProvider.currentPlayer != null) {
               // USAR HELPER CENTRALIZADO
               await MinigameLogicHelper.executeLoseLife(context);
            }

            // No llamamos a skipCurrentClue(), simplemente salimos.
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Te has rendido (-1 Vida). Puedes volver a intentarlo cuando estés listo.'),
                  backgroundColor: AppTheme.warningOrange,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
          child: const Text('Rendirse'),
        ),
      ],
    ),
  );
}

// --- WIDGETS INTEGRADOS (Con soporte de onFinish) ---

// --- LOGICA DE VICTORIA COMPARTIDA ---

void _showSuccessDialog(BuildContext context, Clue clue) async {
  final gameProvider = Provider.of<GameProvider>(context, listen: false);
  final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const Center(
      child: CircularProgressIndicator(color: AppTheme.accentGold),
    ),
  );

  bool success = false;

  try {
    if (clue.id.startsWith('demo_')) {
      gameProvider.completeLocalClue(clue.id);
      success = true;
    } else {
      debugPrint('--- COMPLETING CLUE: ${clue.id} (XP: ${clue.xpReward}, Coins: ${clue.coinReward}) ---');
      success =
          await gameProvider.completeCurrentClue(clue.riddleAnswer ?? "WIN");
      debugPrint('--- CLUE COMPLETION RESULT: $success ---');
    }
  } catch (e) {
    debugPrint("Error completando pista: $e");
    success = false;
  }

  if (context.mounted) {
    Navigator.pop(context);
  }

  if (success) {
    if (playerProvider.currentPlayer != null) {
      debugPrint('--- REFRESHING PROFILE START ---');
      await playerProvider.refreshProfile();
      debugPrint('--- REFRESHING PROFILE END. New Coins: ${playerProvider.currentPlayer?.coins} ---');
    }

    // Check if race was completed or if player completed all clues
    if (gameProvider.isRaceCompleted || gameProvider.hasCompletedAllClues) {
      // Get player position
      int playerPosition = 0; // Default 0
      final currentPlayerId = playerProvider.currentPlayer?.id ?? '';

      // Wait for leaderboard if needed? (Cant await easily here without bigger refactor, better safegaurd default)
      if (gameProvider.leaderboard.isNotEmpty) {
        final index =
            gameProvider.leaderboard.indexWhere((p) => p.id == currentPlayerId);
        playerPosition =
            index >= 0 ? index + 1 : gameProvider.leaderboard.length + 1;
      } else {
        playerPosition = 999; // Safe default
      }

      // Navigate to winner celebration screen
      if (context.mounted) {
        // Get event ID from the current clue
        // We need to pass the event ID - assuming we can get it from somewhere
        // For now, navigate with position and completed clues
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => WinnerCelebrationScreen(
              eventId: gameProvider.currentEventId ?? '',
              playerPosition: playerPosition,
              totalCluesCompleted: gameProvider.completedClues,
            ),
          ),
          (route) => route.isFirst, // Remove all routes except first
        );
      }
      return; // Don't show normal success dialog
    }
  } else {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Error al guardar el progreso. Verifica tu conexión.'),
            backgroundColor: AppTheme.dangerRed),
      );
    }
    return;
  }

  if (!context.mounted) return;

  // 1. Mostrar la Animación del Sello Temporal
  await showGeneralDialog(
    context: context,
    barrierDismissible: false,
    pageBuilder: (dialogContext, _, __) => Scaffold(
      backgroundColor: Colors.black.withOpacity(0.85),
      body: TimeStampAnimation(
        index: ((clue.sequenceIndex - 1) % 9) + 1,
        onComplete: () => Navigator.pop(dialogContext),
      ),
    ),
  );

  // Verificar contexto después de animación
  if (!context.mounted) {
    debugPrint('WARN: Context not mounted after TimeStampAnimation');
    return;
  }

  // 2. Determinar si hay siguiente pista
  final clues = gameProvider.clues;
  final currentIdx = clues.indexWhere((c) => c.id == clue.id);
  Clue? nextClue;
  if (currentIdx != -1 && currentIdx + 1 < clues.length) {
    nextClue = clues[currentIdx + 1];
  }
  // Mostrar "siguiente misión" si hay más pistas después de esta
  final showNextStep = nextClue != null;

  // 3. Mostrar el panel de celebración - siempre se muestra después del sello
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => SuccessCelebrationDialog(
      clue: clue,
      showNextStep: showNextStep,
      totalClues: clues.length,
      onMapReturn: () {
        Navigator.of(dialogContext).pop();
        Future.delayed(const Duration(milliseconds: 100), () {
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        });
      },
    ),
  );
}

// --- WRAPPERS ACTUALIZADOS CON ONFINISH ---

class SlidingPuzzleWrapper extends StatelessWidget {
  final Clue clue;
  final VoidCallback onFinish;
  const SlidingPuzzleWrapper(
      {super.key, required this.clue, required this.onFinish});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      onFinish,
      SlidingPuzzleMinigame(
          clue: clue,
          onSuccess: () {
            onFinish();
            _showSuccessDialog(context, clue);
          }));
}

class TicTacToeWrapper extends StatelessWidget {
  final Clue clue;
  final VoidCallback onFinish;
  const TicTacToeWrapper(
      {super.key, required this.clue, required this.onFinish});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      onFinish,
      TicTacToeMinigame(
          clue: clue,
          onSuccess: () {
            onFinish();
            _showSuccessDialog(context, clue);
          }));
}

class HangmanWrapper extends StatelessWidget {
  final Clue clue;
  final VoidCallback onFinish;
  const HangmanWrapper({super.key, required this.clue, required this.onFinish});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      onFinish,
      HangmanMinigame(
          clue: clue,
          onSuccess: () {
            onFinish();
            _showSuccessDialog(context, clue);
          }));
}

class TetrisWrapper extends StatelessWidget {
  final Clue clue;
  final VoidCallback onFinish;
  const TetrisWrapper({super.key, required this.clue, required this.onFinish});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      onFinish,
      TetrisMinigame(
          clue: clue,
          onSuccess: () {
            onFinish();
            _showSuccessDialog(context, clue);
          }));
}

class FlagsWrapper extends StatelessWidget {
  final Clue clue;
  final VoidCallback onFinish;
  const FlagsWrapper({super.key, required this.clue, required this.onFinish});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      onFinish,
      FlagsMinigame(
          clue: clue,
          onSuccess: () {
            onFinish();
            _showSuccessDialog(context, clue);
          }));
}

class MinesweeperWrapper extends StatelessWidget {
  final Clue clue;
  final VoidCallback onFinish;
  const MinesweeperWrapper(
      {super.key, required this.clue, required this.onFinish});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      onFinish,
      MinesweeperMinigame(
          clue: clue,
          onSuccess: () {
            onFinish();
            _showSuccessDialog(context, clue);
          }));
}

class SnakeWrapper extends StatelessWidget {
  final Clue clue;
  final VoidCallback onFinish;
  const SnakeWrapper({super.key, required this.clue, required this.onFinish});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      onFinish,
      SnakeMinigame(
          clue: clue,
          onSuccess: () {
            onFinish();
            _showSuccessDialog(context, clue);
          }));
}

class BlockFillWrapper extends StatelessWidget {
  final Clue clue;
  final VoidCallback onFinish;
  const BlockFillWrapper(
      {super.key, required this.clue, required this.onFinish});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      onFinish,
      BlockFillMinigame(
          clue: clue,
          onSuccess: () {
            onFinish();
            _showSuccessDialog(context, clue);
          }));
}

// Para FindDifference, asumo que existe un wrapper similar o debes crearlo si no existe en el archivo original
class FindDifferenceWrapper extends StatelessWidget {
  final Clue clue;
  final VoidCallback onFinish;
  const FindDifferenceWrapper(
      {super.key, required this.clue, required this.onFinish});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      onFinish,
      FindDifferenceMinigame(
          clue: clue,
          onSuccess: () {
            onFinish();
            _showSuccessDialog(context, clue);
          }));
}

// --- SCAFFOLD COMPARTIDO ACTUALIZADO (Soporta onFinish para Rendición Legal) ---

String _getMinigameInstruction(Clue clue) {
  switch (clue.puzzleType) {
    case PuzzleType.slidingPuzzle:
      return "Ordena los números (1 al 8)";
    case PuzzleType.ticTacToe:
      return "Gana a la Vieja";
    case PuzzleType.hangman:
      return "Adivina la palabra";
    case PuzzleType.tetris:
      return "Completa las líneas";
    case PuzzleType.findDifference:
      return "Encuentra el icono extra y toca ese cuadro";
    case PuzzleType.flags:
      return "Adivina las banderas";
    case PuzzleType.minesweeper:
      return "Limpia las minas";
    case PuzzleType.snake:
      return "Maneja la culebrita";
    case PuzzleType.blockFill:
      return "Rellena los bloques";
    default:
      // Si es un tipo estándar, verificamos por el título o descripción
      if (clue.riddleQuestion?.contains("código") ?? false) return "Descifra el código";
      if (clue.minigameUrl != null && clue.minigameUrl!.isNotEmpty) return "Adivina la imagen";
      return "¡Resuelve el desafío!";
  }
}

Widget _buildMinigameScaffold(
    BuildContext context, Clue clue, VoidCallback onFinish, Widget child) {
  final player = Provider.of<PlayerProvider>(context).currentPlayer;

  // Envolvemos el minijuego en el countdown
  final instruction = _getMinigameInstruction(clue);
  final wrappedChild = MinigameCountdownOverlay(
    instruction: instruction,
    child: child,
  );

  return SabotageOverlay(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.darkGradient,
        ),
        child: SafeArea(
          child: Consumer<GameProvider>(
            builder: (context, game, _) {
              return Stack(
                children: [
                  Column(
                    children: [
                      // AppBar Personalizado
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // BOTÓN DE REGRESAR ELIMINADO: 
                            // El usuario debe rendirse o ganar para salir.
                            const SizedBox(width: 8), // Espaciador mínimo
                            const Spacer(),

                            // INDICADOR DE VIDAS CON ANIMACIÓN
                            AnimatedLivesWidget(),
                            const SizedBox(width: 10),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.accentGold.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: AppTheme.accentGold),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.star,
                                      color: AppTheme.accentGold, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    '+${clue.xpReward} XP',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.flag,
                                  color: AppTheme.dangerRed, size: 20),
                              tooltip: 'Rendirse',
                              onPressed: () =>
                                  showSkipDialog(context, onFinish),
                            ),
                          ],
                        ),
                      ),

                      // Mapa de Progreso
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: RaceTrackWidget(
                          leaderboard: game.leaderboard,
                          currentPlayerId: player?.id ?? '',
                          totalClues: game.clues.length,
                          onSurrender: () => showSkipDialog(context, onFinish),
                        ),
                      ),

                      const SizedBox(height: 10),

                      Expanded(
                        child: IgnorePointer(
                          ignoring: player != null && player.isFrozen,
                          child: wrappedChild, // Usamos el hijo con countdown
                        ),
                      ),
                    ],
                  ),

                  // Efecto Visual de Daño (Flash Rojo) al perder vida
                  LossFlashOverlay(lives: game.lives),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

// --- WIDGETS DE SOPORTE PARA ANIMACIONES MOVIDOS A ARCHIVOS EXTERNOS ---
