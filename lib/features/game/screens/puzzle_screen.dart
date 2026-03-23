import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/game_provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../models/clue.dart';
import 'dart:async';
import '../widgets/race_track_widget.dart';
import '../../../shared/widgets/sabotage_overlay.dart';
import '../../../shared/models/player.dart'; // Import Player model
import '../providers/connectivity_provider.dart';
import '../../mall/models/power_item.dart';
import '../widgets/effects/blur_effect.dart';
import '../providers/power_interfaces.dart';
import '../providers/power_effect_provider.dart'; // NEW IMPORT
import 'package:flutter/foundation.dart' show kDebugMode; // NEW IMPORT

// --- Imports de Minijuegos Existentes ---
import '../widgets/minigames/sliding_puzzle_minigame.dart';
import '../widgets/minigames/tic_tac_toe_minigame.dart';
import '../widgets/minigames/hangman_minigame.dart';

// --- Imports de NUEVOS Minijuegos ---
import '../widgets/minigames/tetris_minigame.dart';
import '../widgets/effects/shield_badge.dart'; // NEW IMPORT
import '../widgets/minigames/find_difference_minigame.dart';
import '../widgets/minigames/flags_minigame.dart';
import '../widgets/minigames/minesweeper_minigame.dart';
import '../widgets/minigames/snake_minigame.dart';
import '../widgets/minigames/block_fill_minigame.dart';
import '../widgets/minigames/emoji_movie_minigame.dart';
import '../widgets/minigames/virus_tap_minigame.dart';
import '../widgets/minigames/drone_dodge_minigame.dart';
import '../widgets/minigames/memory_sequence_minigame.dart';
import '../widgets/minigames/drink_mixer_minigame.dart';
import '../widgets/minigames/fast_number_minigame.dart'; // NEW IMPORT
import '../widgets/minigames/bag_shuffle_minigame.dart'; // NEW IMPORT
import '../widgets/minigames/holographic_panels_minigame.dart';
import '../widgets/minigames/missing_operator_minigame.dart';
import '../widgets/minigames/prime_network_minigame.dart';
import '../widgets/minigames/percentage_calculation_minigame.dart';
import '../widgets/minigames/chronological_order_minigame.dart';
import '../widgets/minigames/capital_cities_minigame.dart';
import '../widgets/minigames/true_false_minigame.dart';
import '../widgets/minigame_countdown_overlay.dart';
import 'scenarios_screen.dart';
import '../../game/providers/game_request_provider.dart';

// --- Import del Servicio de Penalización ---
import '../../mall/screens/mall_screen.dart';
import '../utils/minigame_logic_helper.dart';
import 'winner_celebration_screen.dart';
import '../widgets/animated_lives_widget.dart';
import '../widgets/loss_flash_overlay.dart';
import '../widgets/success_celebration_dialog.dart';
import '../../../shared/widgets/time_stamp_animation.dart';

import '../../../shared/widgets/animated_cyber_background.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../widgets/no_lives_widget.dart';
import 'waiting_room_screen.dart'; // NEW IMPORT
import '../../../shared/widgets/cyber_tutorial_overlay.dart';
import '../../../shared/widgets/master_tutorial_content.dart';
import '../providers/game_flow_provider.dart';

class PuzzleScreen extends StatefulWidget {
  final Clue clue;

  const PuzzleScreen({super.key, required this.clue});

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> {
  // PenaltyService removed as requested
  bool _legalExit = false;
  bool _isNavigatingToWinner = false; // Flag to prevent double navigation
  bool _showBriefing = false; // Deshabilitado como se solicitó
  Timer?
      _raceStatusPollingTimer; // Fallback: polling de recuperación si Realtime falla

  // Safe Provider Access
  late GameProvider _gameProvider;
  late ConnectivityProvider _connectivityProvider;
  bool _isActive = true;
  bool _isSuccessFlowActive = false; // Prevents double success/navigation

  @override
  void initState() {
    super.initState();
    // Cache provider for safe disposal
    _gameProvider = Provider.of<GameProvider>(context, listen: false);
    _connectivityProvider =
        Provider.of<ConnectivityProvider>(context, listen: false);

    // Penalty logic removed

    // Verificar vidas al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLives();
      _checkBanStatus(); // Check ban on entry

      // --- SYNC PLAYER PROVIDER WITH CURRENT EVENT ---
      // Fix for issue where PlayerProvider loads "latest" (potentially banned) event
      // instead of the current active event.
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      final playerProvider =
          Provider.of<PlayerProvider>(context, listen: false);
      final eventId = gameProvider.currentEventId;

      if (eventId != null && playerProvider.currentPlayer != null) {
        // Sync strict: If IDs don't match, force refresh for THIS event
        if (playerProvider.currentPlayer?.currentEventId != eventId) {
          debugPrint(
              "PuzzleScreen: Syncing PlayerProvider to event $eventId...");
          playerProvider.refreshProfile(eventId: eventId);
        }
      }

      // --- MARCAR ENTRADA A MINIJUEGO PARA CONNECTIVITY ---
      if (eventId != null) {
        context.read<ConnectivityProvider>().enterMinigame(eventId);
      }

      // --- ESCUCHA DE FIN DE CARRERA EN TIEMPO REAL ---
      final gp = Provider.of<GameProvider>(context, listen: false);
      gp.addListener(_checkRaceCompletion);

      // Verificación inicial inmediata: ¿La carrera ya terminó?
      _checkRaceCompletion();

      // Polling de recuperación: si Realtime pierde el evento de finalización
      // (p.ej. durante la breve ventana de re-suscripción del canal), esto lo detecta.
      _raceStatusPollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!_isActive || !mounted || _isNavigatingToWinner) return;
        gp.checkRaceStatus().then((_) => _checkRaceCompletion());
      });

      // to avoid race conditions during initialization.

      // MOVED: Tutorial trigger
      _showMinigameTutorial();
    });
  }

  void _showMinigameTutorial() async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final player = playerProvider.currentPlayer;
    
    // 1. Solo para usuarios nuevos
    if (!playerProvider.isNewlyRegistered) return;
    
    // 2. No para espectadores
    if (player?.role == 'spectator') return;

    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('has_seen_tutorial_PUZZLE') ?? false;
    if (hasSeen) return;

    // 3. No mostrar si está congelado (evitar que aparezca 'detrás' del overlay de congelado)
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    if (gameProvider.isFrozen) {
      // Re-intentar en un momento si sigue siendo relevante
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _showMinigameTutorial();
      });
      return;
    }

    // Add a transition delay before showing the tutorial
    await Future.delayed(const Duration(milliseconds: 500)); // Transition delay

    final steps = MasterTutorialContent.getStepsForSection('PUZZLE', context);
    if (steps.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => CyberTutorialOverlay(
          steps: steps,
          onFinish: () {
            Navigator.pop(context);
            prefs.setBool('has_seen_tutorial_PUZZLE', true);
          },
        ),
      );
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
    if (!mounted || !_isActive || _legalExit) return;

    // Use stored provider or safely access context if active
    final gameProvider = _gameProvider;

    // Si las vidas globales llegaron a 0, simplemente dejamos que el build reaccione
    if (gameProvider.lives <= 0) {
      debugPrint(
          '[LIVES_MONITOR] 🔴 Global lives reached 0. Showing NoLives overlay.');
      // No hacemos pop(), el build detectará vidas <= 0 y mostrará NoLivesWidget
      if (mounted) {
        setState(() {}); // Forzar rebuild local
      }
    }
  }

  void _checkRaceCompletion() async {
    if (!mounted || !_isActive || _isNavigatingToWinner) return;

    final gameProvider = _gameProvider;
    if (!context.mounted) return;
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    // Navegar al podio si la carrera terminó Y el jugador NO está listo para ser
    // llevado a Winner por su propia lógica (ya habría salido a WaitingRoom).
    // NOTA: la condición original era `!hasCompletedAllClues`, pero eso bloqueaba
    // la navegación cuando el último clue quedó marcado optimistamente como completado
    // antes de que llegara el evento Realtime de finalización de carrera.
    // Fix: navegamos si isRaceCompleted, SALVO que el player ya esté en tránsito
    // (guard _isNavigatingToWinner evita doble navegación).
    if (gameProvider.isRaceCompleted) {
      _isNavigatingToWinner = true;
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
          settings: const RouteSettings(name: 'WinnerCelebrationScreen'),
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

  // Check for ban status (Per-competition kick)
  Future<void> _checkBanStatus() async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final requestProvider =
        Provider.of<GameRequestProvider>(context, listen: false);

    final userId = playerProvider.currentPlayer?.userId;
    final eventId = gameProvider.currentEventId;

    if (userId != null && eventId != null) {
      final status = await requestProvider.getGamePlayerStatus(userId, eventId);
      if (status == 'banned') {
        if (!mounted) return;
        _handleBanKick();
      }
    }
  }

  void _handleBanKick() {
    // Prevent multiple kicks
    if (_legalExit) return;
    _legalExit = true; // Treat as exit to prevent loops

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('⛔ Acceso Denegado',
            style: TextStyle(color: AppTheme.dangerRed)),
        content: const Text(
          'Has sido baneado de esta competencia por un administrador.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
              onPressed: () {
                // Kick to Scenarios Screen (List of competitions)
                Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => ScenariosScreen()),
                    (route) => false);
              },
              child: const Text('Entendido'))
        ],
      ),
    );
  }

  Future<void> _checkLives() async {
    // Usamos listen: false para obtener el estado MÁS RECIENTE, no suscribirnos
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    // 1. Verificación preliminar con source-of-truth visual (PlayerProvider)
    if (playerProvider.currentPlayer != null &&
        playerProvider.currentPlayer!.lives > 0) {
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
        // _showNoLivesDialog();
        // DO NOT start monitoring if we are dead.
      } else {
        debugPrint(
            "SYNC INFO: Vidas encontradas (Game: ${gameProvider.lives}, Player: $freshPlayerLives). Juego permitido.");
        // Lives found, start monitoring
        _startLivesMonitoring();
      }
    }
  }

  @override
  void deactivate() {
    _isActive = false;
    super.deactivate();
  }

  @override
  void dispose() {
    // WidgetsBinding.instance.removeObserver(this); // Removed

    // --- MARCAR SALIDA DEL MINIJUEGO PARA CONNECTIVITY ---
    try {
      _connectivityProvider.exitMinigame();
    } catch (_) {}

    // Limpiar listener de fin de carrera usando la referencia CACHEADA
    try {
      _raceStatusPollingTimer?.cancel();
      _gameProvider.removeListener(_checkRaceCompletion);
    } catch (_) {}

    // Limpiar listener de monitoreo de vidas
    try {
      _gameProvider.removeListener(_checkGlobalLivesGameOver);
    } catch (_) {}

    super.dispose();
  }

  // didChangeAppLifecycleState removed to disable leaver penalty

  // Helper para marcar salida legal (Ganar o Rendirse)
  Future<void> _finishLegally() async {
    if (!mounted) return;
    setState(() {
      _legalExit = true;
      _isNavigatingToWinner = true; // Lock background navigation to let victory flow play
    });
  }

  void _handleSuccess(Clue clue) {
    if (_isSuccessFlowActive || !mounted) return;
    setState(() => _isSuccessFlowActive = true);

    _finishLegally();
    _showSuccessDialog(context, clue);
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);
    final player = context.watch<PlayerProvider>().currentPlayer;
    final isSpectator = player?.role == 'spectator';

    // --- STATUS OVERLAYS (Handled Globally) ---
    if (isSpectator) {
      // Spectators bypass lives check but see read-only UI
    } else {
      // 2. Si el PlayerProvider (Visual) dice que NO tenemos vidas, bloqueamos INMEDIATAMENTE.
      //    Ya no confiamos ciegamente en el servidor si la UI local dice 0.
      //    La lógica "stricter" solicitada: Si CUALQUIERA dice 0, no pasas.
      bool forcedBlock = false;

      // Check Status for realtime kick
      if (player != null && player.status == PlayerStatus.banned) {
        // Schedule kick if not already doing it
        WidgetsBinding.instance.addPostFrameCallback((_) => _checkBanStatus());
        forcedBlock = true; // Block UI
      }

      if (player != null && player.lives <= 0) {
        forcedBlock = true;
      }

      if ((gameProvider.lives <= 0 || forcedBlock)) {
        return const NoLivesWidget();
      }
    }

    // [FIX] REMOVED the auto-pop LoadingIndicator guard.
    // This was causing a race condition: optimistic update would trigger this guard,
    // which would Navigator.pop() the SUCCESS DIALOG that was just opening,
    // leaving the user stuck in a black screen.
    // Instead, we just trust the minigame UI or the onSuccess dialog to handle navigation.
    Widget gameWidget;
    // Cast seguro solicitado
    final onlineClue =
        widget.clue is OnlineClue ? widget.clue as OnlineClue : widget.clue;
    // Nota: Si pasamos PhysicalClue, usará el fallback de los getters virtuales.

    // Pasamos _finishLegally a TODOS los hijos para que avisen antes de cerrar o ganar
    switch (onlineClue.puzzleType) {
      case PuzzleType.slidingPuzzle:
        gameWidget =
            SlidingPuzzleWrapper(clue: widget.clue, onSuccess: _handleSuccess);
        break;
      case PuzzleType.ticTacToe:
        gameWidget =
            TicTacToeWrapper(clue: widget.clue, onSuccess: _handleSuccess);
        break;
      case PuzzleType.hangman:
        gameWidget =
            HangmanWrapper(clue: widget.clue, onSuccess: _handleSuccess);
        break;
      case PuzzleType.tetris:
        gameWidget = TetrisWrapper(clue: widget.clue, onSuccess: _handleSuccess);
        break;
      case PuzzleType.findDifference:
        gameWidget =
            FindDifferenceWrapper(clue: widget.clue, onSuccess: _handleSuccess);
        break;
      case PuzzleType.flags:
        gameWidget = FlagsWrapper(clue: widget.clue, onSuccess: _handleSuccess);
        break;
      case PuzzleType.minesweeper:
        gameWidget =
            MinesweeperWrapper(clue: widget.clue, onSuccess: _handleSuccess);
        break;
      case PuzzleType.snake:
        gameWidget = SnakeWrapper(clue: widget.clue, onSuccess: _handleSuccess);
        break;
      case PuzzleType.blockFill:
        gameWidget =
            BlockFillWrapper(clue: widget.clue, onSuccess: _handleSuccess);
        break;
      case PuzzleType.memorySequence:
        gameWidget =
            MemorySequenceWrapper(clue: widget.clue, onSuccess: _handleSuccess);
        break;
      case PuzzleType.drinkMixer:
        gameWidget =
            DrinkMixerWrapper(clue: widget.clue, onSuccess: _handleSuccess);
        break;
      case PuzzleType.fastNumber:
        gameWidget =
            FastNumberWrapper(clue: widget.clue, onSuccess: _handleSuccess);
        break;
      case PuzzleType.bagShuffle:
        gameWidget =
            BagShuffleWrapper(clue: widget.clue, onSuccess: _handleSuccess);
        break;
      case PuzzleType.emojiMovie:
        gameWidget =
            EmojiMovieWrapper(clue: widget.clue, onSuccess: _handleSuccess);
        break;
      case PuzzleType.virusTap:
        gameWidget =
            VirusTapWrapper(clue: widget.clue, onSuccess: _handleSuccess);
        break;
      case PuzzleType.droneDodge:
        gameWidget =
            DroneDodgeWrapper(clue: widget.clue, onSuccess: _handleSuccess);
        break;
      case PuzzleType.holographicPanels:
        gameWidget = HolographicPanelsWrapper(
            clue: widget.clue, onSuccess: _handleSuccess);
        break;
      case PuzzleType.missingOperator:
        gameWidget =
            MissingOperatorWrapper(clue: widget.clue, onSuccess: _handleSuccess);
        break;
      case PuzzleType.primeNetwork:
        gameWidget =
            PrimeNetworkWrapper(clue: widget.clue, onSuccess: _handleSuccess);
        break;
      case PuzzleType.percentageCalculation:
        gameWidget = PercentageCalculationWrapper(
            clue: widget.clue, onSuccess: _handleSuccess);
        break;
      case PuzzleType.chronologicalOrder:
        gameWidget = ChronologicalOrderWrapper(
            clue: widget.clue, onSuccess: _handleSuccess);
        break;
      case PuzzleType.capitalCities:
        gameWidget =
            CapitalCitiesWrapper(clue: widget.clue, onSuccess: _handleSuccess);
        break;
      case PuzzleType.trueFalse:
        gameWidget =
            TrueFalseWrapper(clue: widget.clue, onSuccess: _handleSuccess);
        break;
      default:
        gameWidget = const Center(child: Text("Minijuego no implementado"));
    }

    // WRAPPER DE SEGURIDAD: Evitar salir sin penalización
    return PopScope(
      canPop: _legalExit || isSpectator,
      onPopInvoked: (didPop) async {
        if (didPop || _legalExit || isSpectator) return;

        // Si intenta salir con Back, mostramos el diálogo de rendición (que cobra vida)
        showSkipDialog(context, _finishLegally);
      },
      child: Stack(
        children: [
          IgnorePointer(
            ignoring: isSpectator, // Bloquea interacción con el juego
            child: gameWidget,
          ),
          if (isSpectator)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.1), // Sutil oscurecimiento
              ),
            ),

        ],
      ),
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
                clue.hint.isNotEmpty ? clue.hint : clue.title,
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

/// Diálogo de rendición: quita 1 vida y reinicia el minijuego in-place.
/// Ya NO cierra la PuzzleScreen — el jugador puede seguir intentando.
/// Solo sale al mapa si se queda sin vidas.
void showSkipDialog(BuildContext context, VoidCallback? onLegalExit) {
  final provider = Provider.of<GameProvider>(context, listen: false);
  provider.setModalActive(true);

  showDialog(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 36),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppTheme.dangerRed.withOpacity(0.15),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppTheme.dangerRed.withOpacity(0.4),
            width: 1,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1D),
            borderRadius: BorderRadius.circular(21),
            border: Border.all(
              color: AppTheme.dangerRed.withOpacity(0.7),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.dangerRed, width: 2.5),
                ),
                child: const Icon(
                  Icons.flag_rounded,
                  color: AppTheme.dangerRed,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '¿RENDIRSE?',
                style: TextStyle(
                  color: AppTheme.dangerRed,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Orbitron',
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '¡Lástima! Si te rindes, NO podrás desbloquear la siguiente pista porque no resolviste este desafío.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        provider.setModalActive(false);
                        Navigator.pop(dialogContext);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'CANCELAR',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        // 1. CAPTURAR TODO LO NECESARIO ANTES DE NAVEGAR
                        final playerProvider =
                            Provider.of<PlayerProvider>(context, listen: false);
                        final gameProvider =
                            Provider.of<GameProvider>(context, listen: false);
                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(context);

                        if (onLegalExit != null) {
                          onLegalExit();
                        }

                        // 2. Cerrar diálogo
                        provider.setModalActive(false);
                        Navigator.pop(dialogContext);

                        // 3. Cerrar pantalla actual (PuzzleScreen)
                        if (context.mounted) {
                          navigator.pop();
                        }

                        // 4. Lógica de pérdida de vida (Usando los providers capturados)
                        if (playerProvider.currentPlayer != null) {
                          // Usamos el helper. Nota: El helper ahora captura sus propios providers si el context está vivo,
                          // pero aquí le pasamos el context que ya capturamos nosotros arriba de forma segura.
                          // En realidad, el helper internamente hace context.read de nuevo.
                          // Es mejor si el helper acepta los providers opcionalmente, o simplemente confiar en que
                          // context sigue siendo "suficiente" para lectura si no se ha destruído el árbol.
                          // Pero para máxima seguridad, el helper ya fue actualizado para usar mounted.
                          await MinigameLogicHelper.executeLoseLife(context);
                        }

                        // 5. Feedback Premium
                        messenger.showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            content: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.warningOrange,
                                    AppTheme.warningOrange.withOpacity(0.8),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.favorite_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  const Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'MISIÓN CANCELADA',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        Text(
                                          'Has perdido una vida (-1 ❤️). Reinténtalo cuando estés listo.',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.dangerRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'RENDIRSE',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// --- WIDGETS INTEGRADOS (Con soporte de onFinish) ---

// --- LOGICA DE VICTORIA COMPARTIDA ---

void _showSuccessDialog(BuildContext context, Clue clue) async {
  final gameProvider = Provider.of<GameProvider>(context, listen: false);
  final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
  final gameFlowProvider = Provider.of<GameFlowProvider>(context, listen: false);

  // [FIX] Capturar Navigator y ruta del PuzzleScreen ANTES de cualquier operación async
  final navigator = Navigator.of(context);
  final rootContext = context;
  final puzzleRoute = ModalRoute.of(context); // Para removeRoute confiable en onMapReturn

  debugPrint('🎉 SUCCESS FLOW STARTED for ${clue.id}');

  // ── DESACOPLADO DEL RPC ──────────────────────────────────────────────────
  Future<Map<String, dynamic>?> clueCompletionFuture;

  if (clue.id.startsWith('demo_')) {
    gameProvider.completeLocalClue(clue.id);
    clueCompletionFuture = Future.value({'success': true, 'coins_earned': 0});
  } else {
    debugPrint('--- COMPLETING CLUE (background): ${clue.id} ---');
    clueCompletionFuture =
        gameProvider.completeCurrentClue(clue.riddleAnswer ?? "WIN",
            clueId: clue.id);
  }

  // También lanzar el refresh de perfil en paralelo (no necesita el RPC aún)
  Future<void>? profileRefreshFuture;
  if (playerProvider.currentPlayer != null) {
    profileRefreshFuture = playerProvider.refreshProfile();
  }
  // ─────────────────────────────────────────────────────────────────────────

  if (!navigator.mounted) return;

  // 1. Mostrar la Animación del Trébol Dorado INMEDIATAMENTE
  bool sealCompleted = false;
  try {
    await showGeneralDialog(
      context: navigator.context,
      barrierDismissible: false,
      barrierColor: Colors.black, // [FIX] Fully opaque barrier - prevents loading/effects from showing through
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (dialogContext, _, __) => Scaffold(
        backgroundColor: Colors.black, // [FIX] Fully opaque - no bleed-through of underlying widget rebuilds
        body: TimeStampAnimation(
          index: ((clue.sequenceIndex - 1) % 9) + 1,
          onComplete: () {
            if (!sealCompleted && dialogContext.mounted) {
              sealCompleted = true;
              // [FIX] Usar removeRoute en vez de pop() para evitar cerrar
              // accidentalmente la _BlockingPageRoute si un poder se activó
              // encima de esta animación.
              final sealRoute = ModalRoute.of(dialogContext);
              if (sealRoute != null) {
                try {
                  Navigator.of(dialogContext).removeRoute(sealRoute);
                } catch (_) {
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                }
              } else {
                Navigator.pop(dialogContext);
              }
            }
          },
        ),
      ),
    );
  } catch (e) {
    debugPrint('Error showing TimeStampAnimation: $e');
  }

  // 2. Leer el resultado del RPC (el trébol tardó ~3.3s, el RPC ya debió terminar)
  // [FIX] Sin delays intermedios - evita que el usuario vea el "cargando" del widget
  // subyacente entre la animación del trébol y el diálogo de celebración.
  Map<String, dynamic>? result;
  int coinsEarned = 0;
  try {
    // El RPC se lanzó ANTES de la animación (~3.3s atrás), así que debería responder inmediato.
    // Timeout de 4s como safety net si la conexión es lenta.
    result = await clueCompletionFuture.timeout(const Duration(seconds: 4));
    coinsEarned = result?['coins_earned'] ?? 0;
    debugPrint('--- CLUE RPC RESULT: $result, Coins Earned: $coinsEarned ---');
  } catch (e) {
    debugPrint("Error completando pista (background/timeout): $e");
    result = {'success': true, 'coins_earned': 0};
  }

  // Esperar que el refreshProfile termine (si aún no lo hizo)
  if (profileRefreshFuture != null) {
    try {
      await profileRefreshFuture;
    } catch (e) {
      debugPrint('WARN: Profile refresh failed: $e');
    }
  }

  if (!navigator.mounted) return;

  // 3. Manejar fin de carrera o navegación a sala de espera
  if (result != null) {
    if (gameProvider.isRaceCompleted || gameProvider.hasCompletedAllClues) {
      int playerPosition = 0;
      final currentPlayerId = playerProvider.currentPlayer?.id ?? '';

      if (gameProvider.leaderboard.isNotEmpty) {
        final index =
            gameProvider.leaderboard.indexWhere((p) => p.id == currentPlayerId);
        playerPosition =
            index >= 0 ? index + 1 : gameProvider.leaderboard.length + 1;
      } else {
        playerPosition = 999;
      }

      if (!gameProvider.isRaceCompleted && gameProvider.hasCompletedAllClues) {
        debugPrint("🏆 User finished, Race still ACTIVE → Waiting Room");
        if (navigator.mounted) {
          navigator.pushReplacement(
            MaterialPageRoute(
              builder: (_) => WaitingRoomScreen(
                eventId: gameProvider.currentEventId ?? '',
              ),
            ),
          );
        }
        return;
      }

      if (navigator.mounted) {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            settings: const RouteSettings(name: 'WinnerCelebrationScreen'),
            builder: (_) => WinnerCelebrationScreen(
              eventId: gameProvider.currentEventId ?? '',
              playerPosition: playerPosition,
              totalCluesCompleted: gameProvider.completedClues,
            ),
          ),
          (route) => route.isFirst,
        );
      }
      return;
    }
  } else {
    // RPC falló: el Provider ya revirtió el estado optimista.
    // Mostramos error pero permitimos que el diálogo de celebración aparezca
    // para que el usuario pueda volver al mapa y reintentar.
    if (navigator.mounted) {
      ScaffoldMessenger.of(navigator.context).showSnackBar(
        const SnackBar(
            content:
                Text('Error al guardar el progreso. Verifica tu conexión e inténtalo de nuevo.'),
            backgroundColor: AppTheme.dangerRed,
            duration: Duration(seconds: 5)),
      );
    }
    // Salir directamente al mapa para que reintente con estado limpio
    if (navigator.mounted) {
      navigator.pop();
    }
    return;
  }

  if (!navigator.mounted) return;

  // 4. Registrar intención de celebración en GameFlowProvider
  gameFlowProvider.recordClueCompletion(PendingCelebration(
    clueId: clue.id,
    clueSequenceIndex: clue.sequenceIndex,
    coinsEarned: coinsEarned,
  ));

  // [FIX] Siempre mostrar el diálogo de celebración, sin importar si hay un
  // poder bloqueante activo. El diálogo se empuja como ruta por ENCIMA de la
  // _BlockingPageRoute, así que es visible e interactuable. Esto elimina las
  // race conditions donde la celebración diferida nunca se mostraba porque
  // _isBlockingActive y _isPowerBlocking quedaban desincronizados.

  // 5. Mostrar el panel de celebración "¡Pista Completada!"
  gameFlowProvider.markCelebrationShowing();

  final clues = gameProvider.clues;
  final currentIdx = clues.indexWhere((c) => c.id == clue.id);
  Clue? nextClue;
  if (currentIdx != -1 && currentIdx + 1 < clues.length) {
    nextClue = clues[currentIdx + 1];
  }
  final showNextStep = nextClue != null;
  final String? nextClueHint =
      nextClue?.hint.isNotEmpty == true ? nextClue!.hint : null;

  await showDialog(
    context: navigator.context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.85), // [FIX] Darker barrier to prevent bleed-through
    builder: (dialogContext) => SuccessCelebrationDialog(
      clue: clue,
      showNextStep: showNextStep,
      totalClues: clues.length,
      coinsEarned: coinsEarned,
      nextClueHint: nextClueHint,
      onMapReturn: () {
        gameFlowProvider.consumePendingCelebration();
        Navigator.of(dialogContext).pop();
        Future.delayed(const Duration(milliseconds: 100), () {
          if (navigator.mounted && puzzleRoute != null) {
            // [FIX] Usar removeRoute para sacar el PuzzleScreen específicamente,
            // sin importar si hay una _BlockingPageRoute encima (el SabotageOverlay
            // la limpiará cuando el poder expire).
            try {
              navigator.removeRoute(puzzleRoute);
            } catch (_) {
              if (navigator.mounted) navigator.maybePop();
            }
          } else if (navigator.mounted) {
            navigator.maybePop();
          }
        });
      },
    ),
  );
}

// --- WRAPPERS ACTUALIZADOS CON ONFINISH ---

class SlidingPuzzleWrapper extends StatelessWidget {
  final Clue clue;
  final Function(Clue) onSuccess;
  const SlidingPuzzleWrapper(
      {super.key, required this.clue, required this.onSuccess});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      () {}, // No-op, handled by onSuccess
      SlidingPuzzleMinigame(
          clue: clue,
          onSuccess: () => onSuccess(clue)));
}

class TicTacToeWrapper extends StatelessWidget {
  final Clue clue;
  final Function(Clue) onSuccess;
  const TicTacToeWrapper(
      {super.key, required this.clue, required this.onSuccess});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      () {},
      TicTacToeMinigame(
          clue: clue,
          onSuccess: () => onSuccess(clue)));
}

class HangmanWrapper extends StatelessWidget {
  final Clue clue;
  final Function(Clue) onSuccess;
  const HangmanWrapper({super.key, required this.clue, required this.onSuccess});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      () {},
      HangmanMinigame(
          clue: clue,
          onSuccess: () => onSuccess(clue)));
}

class TetrisWrapper extends StatelessWidget {
  final Clue clue;
  final Function(Clue) onSuccess;
  const TetrisWrapper({super.key, required this.clue, required this.onSuccess});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      () {},
      TetrisMinigame(
          clue: clue,
          onSuccess: () => onSuccess(clue)));
}

class FlagsWrapper extends StatelessWidget {
  final Clue clue;
  final Function(Clue) onSuccess;
  const FlagsWrapper({super.key, required this.clue, required this.onSuccess});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      () {},
      FlagsMinigame(
          clue: clue,
          onSuccess: () => onSuccess(clue)),
      isScrollable: true);
}

class MinesweeperWrapper extends StatelessWidget {
  final Clue clue;
  final Function(Clue) onSuccess;
  const MinesweeperWrapper(
      {super.key, required this.clue, required this.onSuccess});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      () {},
      MinesweeperMinigame(
          clue: clue,
          onSuccess: () => onSuccess(clue)));
}

class SnakeWrapper extends StatelessWidget {
  final Clue clue;
  final Function(Clue) onSuccess;
  const SnakeWrapper({super.key, required this.clue, required this.onSuccess});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      () {},
      SnakeMinigame(
          clue: clue,
          onSuccess: () => onSuccess(clue)));
}

class BlockFillWrapper extends StatelessWidget {
  final Clue clue;
  final Function(Clue) onSuccess;
  const BlockFillWrapper(
      {super.key, required this.clue, required this.onSuccess});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      () {},
      BlockFillMinigame(
          clue: clue,
          onSuccess: () => onSuccess(clue)));
}

// Para FindDifference, asumo que existe un wrapper similar o debes crearlo si no existe en el archivo original
class FindDifferenceWrapper extends StatelessWidget {
  final Clue clue;
  final Function(Clue) onSuccess;
  const FindDifferenceWrapper(
      {super.key, required this.clue, required this.onSuccess});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      () {},
      FindDifferenceMinigame(
          clue: clue,
          onSuccess: () => onSuccess(clue)));
}

class MemorySequenceWrapper extends StatelessWidget {
  final Clue clue;
  final Function(Clue) onSuccess;
  const MemorySequenceWrapper(
      {super.key, required this.clue, required this.onSuccess});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      () {},
      MemorySequenceMinigame(
          clue: clue,
          onSuccess: () => onSuccess(clue)));
}

class DrinkMixerWrapper extends StatelessWidget {
  final Clue clue;
  final Function(Clue) onSuccess;
  const DrinkMixerWrapper(
      {super.key, required this.clue, required this.onSuccess});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      () {},
      DrinkMixerMinigame(
          clue: clue,
          onSuccess: () => onSuccess(clue)));
}

class FastNumberWrapper extends StatelessWidget {
  final Clue clue;
  final Function(Clue) onSuccess;
  const FastNumberWrapper(
      {super.key, required this.clue, required this.onSuccess});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      () {},
      FastNumberMinigame(
          clue: clue,
          onSuccess: () => onSuccess(clue)));
}

class BagShuffleWrapper extends StatelessWidget {
  final Clue clue;
  final Function(Clue) onSuccess;
  const BagShuffleWrapper(
      {super.key, required this.clue, required this.onSuccess});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      () {},
      BagShuffleMinigame(
          clue: clue,
          onSuccess: () => onSuccess(clue)));
}

class EmojiMovieWrapper extends StatelessWidget {
  final Clue clue;
  final Function(Clue) onSuccess;
  const EmojiMovieWrapper(
      {super.key, required this.clue, required this.onSuccess});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      () {},
      EmojiMovieMinigame(
          clue: clue,
          onSuccess: () => onSuccess(clue)),
      isScrollable: true);
}

class VirusTapWrapper extends StatelessWidget {
  final Clue clue;
  final Function(Clue) onSuccess;
  const VirusTapWrapper(
      {super.key, required this.clue, required this.onSuccess});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      () {},
      VirusTapMinigame(
          clue: clue,
          onSuccess: () => onSuccess(clue)));
}

class DroneDodgeWrapper extends StatelessWidget {
  final Clue clue;
  final Function(Clue) onSuccess;
  const DroneDodgeWrapper(
      {super.key, required this.clue, required this.onSuccess});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      () {},
      DroneDodgeMinigame(
          clue: clue,
          onSuccess: () => onSuccess(clue)));
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

    case PuzzleType.memorySequence:
      return "Recuerda la secuencia";
    case PuzzleType.drinkMixer:
      return "Iguala el cóctel";

    case PuzzleType.fastNumber:
      return "Captura el número";
    case PuzzleType.bagShuffle:
      return "Sigue la bolsa";

    case PuzzleType.emojiMovie:
      return "Adivina la película";
    case PuzzleType.virusTap:
      return "¡Aplasta los virus!";
    case PuzzleType.droneDodge:
      return "Esquiva obstáculos";
    case PuzzleType.holographicPanels:
      return "Elige el mayor valor";
    case PuzzleType.missingOperator:
      return "Completa la ecuación";
    case PuzzleType.primeNetwork:
      return "Solo números primos";
    case PuzzleType.percentageCalculation:
      return "Calcula el porcentaje";
    case PuzzleType.chronologicalOrder:
      return "Ordena por fecha";
    case PuzzleType.capitalCities:
      return "Selecciona la capital";
    case PuzzleType.trueFalse:
      return "Verdadero o Falso";
    default:
      // Si es un tipo estándar, verificamos por el título o descripción
      if (clue.riddleQuestion?.contains("código") ?? false)
        return "Descifra el código";
      if (clue.minigameUrl != null && clue.minigameUrl!.isNotEmpty)
        return "Adivina la imagen";
      return "¡Resuelve el desafío!";
  }
}

Widget _buildMinigameScaffold(
    BuildContext context, Clue clue, VoidCallback onFinish, Widget child,
    {bool isScrollable = false}) {
  final player = Provider.of<PlayerProvider>(context).currentPlayer;

  final instruction = _getMinigameInstruction(clue);
  final isDarkMode = Provider.of<PlayerProvider>(context).isDarkMode;

  return SabotageOverlay(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              isDarkMode
                  ? 'assets/images/hero.png'
                  : 'assets/images/loginclaro.png',
              fit: BoxFit.cover,
            ),
          ),
          // Dark overlay for readability
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(isDarkMode ? 0.5 : 0.3),
            ),
          ),
          // Content wrapped in Countdown
          MinigameCountdownOverlay(
            instruction: instruction,
            child: SafeArea(
              left: clue.puzzleType != PuzzleType.droneDodge,
              right: clue.puzzleType != PuzzleType.droneDodge,
              child: Consumer<GameProvider>(
                builder: (context, game, _) {
                  return Stack(
                    children: [
                      Column(
                        children: [
                          // AppBar Personalizado
                          Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical:
                                    MediaQuery.of(context).size.height < 700
                                        ? 4
                                        : 8),
                            child: Row(
                              children: [
                                if (player?.role == 'spectator')
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back,
                                        color: Colors.white),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                const Spacer(),
                                if (player?.role != 'spectator') ...[
                                  // INDICADOR DE VIDAS CON ANIMACIÓN
                                  const ShieldBadge(), // NEW SHIELD WIDGET
                                  AnimatedLivesWidget(),
                                  const SizedBox(width: 10),

                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color:
                                          AppTheme.accentGold.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(
                                          color: AppTheme.accentGold),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.star,
                                            color: AppTheme.accentGold,
                                            size: 12),
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
                                        color: AppTheme.dangerRed, size: 28),
                                    tooltip: 'Rendirse',
                                    onPressed: () =>
                                        showSkipDialog(context, onFinish),
                                  ),
                                ] else
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border:
                                          Border.all(color: Colors.blueAccent),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.visibility,
                                            color: Colors.blueAccent, size: 14),
                                        SizedBox(width: 6),
                                        Text(
                                          'MODO ESPECTADOR',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Mapa de Progreso
                          Builder(
                            builder: (context) {
                              final screenHeight =
                                  MediaQuery.of(context).size.height;
                              // Threshold increased to 800 to cover more "tall but cramped" devices like Samsung S8/S9
                              final isSmallOrMediumScreen = screenHeight < 800;

                              // Force compact for complex minigames OR if the screen is not very tall
                              final forceCompact = isSmallOrMediumScreen ||
                                  (clue.puzzleType ==
                                          PuzzleType.slidingPuzzle ||
                                      clue.puzzleType == PuzzleType.ticTacToe ||
                                      clue.puzzleType == PuzzleType.tetris ||
                                      clue.puzzleType == PuzzleType.hangman ||
                                      clue.puzzleType == PuzzleType.fastNumber ||
                                      clue.puzzleType == PuzzleType.capitalCities ||
                                      clue.puzzleType == PuzzleType.emojiMovie ||
                                      clue.puzzleType == PuzzleType.trueFalse ||
                                      clue.puzzleType == PuzzleType.chronologicalOrder);

                              // Horizontal padding only if NOT a full-screen precision game like Dodge
                              final hPadding =
                                  (clue.puzzleType == PuzzleType.droneDodge)
                                      ? 0.0
                                      : (isSmallOrMediumScreen ? 8.0 : 16.0);

                              return Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: hPadding,
                                    vertical: isSmallOrMediumScreen ? 2 : 4),
                                child: RaceTrackWidget(
                                  leaderboard: game.leaderboard,
                                  currentPlayerId: player?.userId ?? '',
                                  totalClues: game.clues.length,
                                  // Pass null to remove redundant small button; the top flag and bottom buttons are enough
                                  onSurrender: null,
                                  compact: forceCompact,
                                ),
                              );
                            },
                          ),

                          SizedBox(
                              height: MediaQuery.of(context).size.height < 800
                                  ? 0
                                  : 4),

                          Expanded(
                            child: IgnorePointer(
                              ignoring: player != null && player.isFrozen,
                              child: isScrollable
                                  ? LayoutBuilder(
                                      builder: (context, constraints) {
                                      return SingleChildScrollView(
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                              minHeight: constraints.maxHeight),
                                          child: Center(child: child),
                                        ),
                                      );
                                    })
                                  : child, // Usamos el hijo directamente, el countdown envuelve todo
                            ),
                          ),
                        ],
                      ),

                      // EFECTO BLUR (Inyectado aquí)
                      if (context
                          .watch<PowerEffectReader>()
                          .isPowerActive(PowerType.blur))
                        Builder(builder: (context) {
                          final expiry = context
                              .read<PowerEffectReader>()
                              .getPowerExpirationByType(PowerType.blur);
                          if (expiry != null) {
                            return Positioned.fill(
                              child: BlurScreenEffect(expiresAt: expiry),
                            );
                          }
                          return const SizedBox.shrink();
                        }),

                      // Efecto Visual de Daño (Flash Rojo) al perder vida
                      LossFlashOverlay(lives: game.lives),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// --- WRAPPERS FOR NEW MINIGAMES ---

class HolographicPanelsWrapper extends StatelessWidget {
  final Clue clue;
  final Function(Clue) onSuccess;
  const HolographicPanelsWrapper(
      {super.key, required this.clue, required this.onSuccess});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      () {},
      HolographicPanelsMinigame(
          clue: clue,
          onSuccess: () => onSuccess(clue)),
      isScrollable: false);
}

class MissingOperatorWrapper extends StatelessWidget {
  final Clue clue;
  final Function(Clue) onSuccess;
  const MissingOperatorWrapper(
      {super.key, required this.clue, required this.onSuccess});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      () {},
      MissingOperatorMinigame(
          clue: clue,
          onSuccess: () => onSuccess(clue)),
      isScrollable: false);
}

class PrimeNetworkWrapper extends StatelessWidget {
  final Clue clue;
  final Function(Clue) onSuccess;
  const PrimeNetworkWrapper(
      {super.key, required this.clue, required this.onSuccess});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      () {},
      PrimeNetworkMinigame(
          clue: clue,
          onSuccess: () => onSuccess(clue)),
      isScrollable: false);
}

class PercentageCalculationWrapper extends StatelessWidget {
  final Clue clue;
  final Function(Clue) onSuccess;
  const PercentageCalculationWrapper(
      {super.key, required this.clue, required this.onSuccess});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      () {},
      PercentageCalculationMinigame(
          clue: clue,
          onSuccess: () => onSuccess(clue)),
      isScrollable: true);
}

class ChronologicalOrderWrapper extends StatelessWidget {
  final Clue clue;
  final Function(Clue) onSuccess;
  const ChronologicalOrderWrapper(
      {super.key, required this.clue, required this.onSuccess});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      () {},
      ChronologicalOrderMinigame(
          clue: clue,
          onSuccess: () => onSuccess(clue)),
      isScrollable: true);
}

class CapitalCitiesWrapper extends StatelessWidget {
  final Clue clue;
  final Function(Clue) onSuccess;
  const CapitalCitiesWrapper(
      {super.key, required this.clue, required this.onSuccess});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      () {},
      CapitalCitiesMinigame(
          clue: clue,
          onSuccess: () => onSuccess(clue)),
      isScrollable: true);
}

class TrueFalseWrapper extends StatelessWidget {
  final Clue clue;
  final Function(Clue) onSuccess;
  const TrueFalseWrapper(
      {super.key, required this.clue, required this.onSuccess});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      () {},
      TrueFalseMinigame(
          clue: clue,
          onSuccess: () => onSuccess(clue)),
      isScrollable: true);
}
