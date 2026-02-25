import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/clue.dart';
import '../../../auth/providers/player_provider.dart';
import '../../utils/minigame_logic_helper.dart';
import '../../providers/game_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../../../core/theme/app_theme.dart';
import 'game_over_overlay.dart';
import 'cyber_surrender_button.dart';
import '../../../mall/screens/mall_screen.dart';

class TicTacToeMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const TicTacToeMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<TicTacToeMinigame> createState() => _TicTacToeMinigameState();
}

class _TicTacToeMinigameState extends State<TicTacToeMinigame> {
  // Configuración
  static const int gridSize = 3;
  late List<String> board; // '' empty, 'X' player, 'O' computer

  // Overlay State
  bool _showOverlay = false;
  String _overlayTitle = "";
  String _overlayMessage = "";
  bool _canRetry = false;
  bool _isVictory = false;
  bool _showShopButton = false;

  void _showOverlayState(
      {required String title,
      required String message,
      bool retry = false,
      bool victory = false,
      bool showShop = false}) {
    setState(() {
      _showOverlay = true;
      _overlayTitle = title;
      _overlayMessage = message;
      _canRetry = retry;
      _isVictory = victory;
      _showShopButton = showShop;
    });
  }

  // Estado del juego
  late Timer _timer;
  int _secondsRemaining = 45; // 45 segundos para ganar
  bool _isGameOver = false;
  bool _isPlayerTurn = true; // El jugador siempre empieza (X)

  @override
  void initState() {
    super.initState();
    _initializeGame();
    _startTimer();
  }

  void _initializeGame() {
    board = List.generate(gridSize * gridSize, (_) => '');
    _isPlayerTurn = true;
    _isGameOver = false;
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      // Check for freeze state
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      if (gameProvider.isFrozen) return; // Pause timer

      // [FIX] Pause timer if connectivity is bad
      final connectivityByProvider =
          Provider.of<ConnectivityProvider>(context, listen: false);
      if (!connectivityByProvider.isOnline) {
        return; // Skip tick
      }

      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _handleTimeOut();
      }
    });
  }

  void _stopTimer() {
    _timer.cancel();
  }

  void _handleTimeOut() {
    _stopTimer();
    setState(() => _isGameOver = true);
    _loseLife("¡Se acabó el tiempo!");
  }

  void _handleGiveUp() {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    if (gameProvider.isFrozen) return;

    _stopTimer();
    _loseLife("Te has rendido.");
  }

  void _loseLife(String reason) async {
    _stopTimer(); // Asegurar detención
    setState(() => _isGameOver = true);

    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    if (playerProvider.currentPlayer != null) {
      final newLives = await MinigameLogicHelper.executeLoseLife(context);

      if (!mounted) return;

      if (newLives <= 0) {
        _showOverlayState(
            title: "GAME OVER",
            message: "Te has quedado sin vidas.\nVe a la Tienda a comprar más.",
            retry: false,
            showShop: true);
      } else {
        _showOverlayState(
            title: "¡FALLASTE!",
            message: "$reason\nHas perdido 1 vida.",
            retry: true,
            showShop: false);
      }
    }
  }

  // DIALOGS REMOVED

  void _onTileTap(int index) {
    if (!mounted) return;
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    if (gameProvider.isFrozen) return;

    // [FIX] Prevent interaction if offline
    final connectivity =
        Provider.of<ConnectivityProvider>(context, listen: false);
    if (!connectivity.isOnline) return;

    final player =
        Provider.of<PlayerProvider>(context, listen: false).currentPlayer;
    if (_isGameOver ||
        board[index].isNotEmpty ||
        !_isPlayerTurn ||
        (player != null && player.isFrozen)) return;

    setState(() {
      board[index] = 'X';
      _isPlayerTurn = false;
    });

    if (_checkWin('X')) {
      _stopTimer();
      widget.onSuccess();
      return;
    }

    if (!board.contains('')) {
      // Empate
      _handleDraw();
      return;
    }

    // Turno de la IA con un pequeño delay
    Future.delayed(const Duration(milliseconds: 500), _computerMove);
  }

  void _computerMove() {
    if (_isGameOver) return;

    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    if (gameProvider.isFrozen) {
      // If frozen, retry later
      Future.delayed(const Duration(milliseconds: 500), _computerMove);
      return;
    }

    // IA Simple: Bloquear o ganar si puede, o random.
    // 1. Check if AI can win
    int? winMove = _findWinningMove('O');
    // 2. Check if AI needs to block
    int? blockMove = _findWinningMove('X');

    int moveIndex;
    if (winMove != null) {
      moveIndex = winMove;
    } else if (blockMove != null) {
      moveIndex = blockMove;
    } else {
      // Random valid move
      List<int> available = [];
      for (int i = 0; i < board.length; i++) {
        if (board[i].isEmpty) available.add(i);
      }
      if (available.isEmpty) return;
      moveIndex = available[Random().nextInt(available.length)];
    }

    setState(() {
      board[moveIndex] = 'O';
      _isPlayerTurn = true;
    });

    if (_checkWin('O')) {
      _stopTimer();
      _loseLife("¡La vieja te ha ganado!");
    } else if (!board.contains('')) {
      _stopTimer();
      _handleDraw();
    }
  }

  void _handleDraw() {
    _stopTimer();
    setState(() => _isGameOver = true);
    _showOverlayState(
        title: "¡EMPATE!",
        message: "Nadie gana esta ronda.\n¡Inténtalo de nuevo!",
        retry: true,
        victory: true // Just visually green/yellow
        );
  }

  int? _findWinningMove(String player) {
    for (int i = 0; i < board.length; i++) {
      if (board[i].isEmpty) {
        // Try move
        board[i] = player;
        if (_checkWin(player)) {
          board[i] = ''; // Backtrack
          return i;
        }
        board[i] = ''; // Backtrack
      }
    }
    return null;
  }

  bool _checkWin(String player) {
    // Rows
    for (int i = 0; i < 9; i += 3) {
      if (board[i] == player &&
          board[i + 1] == player &&
          board[i + 2] == player) return true;
    }
    // Cols
    for (int i = 0; i < 3; i++) {
      if (board[i] == player &&
          board[i + 3] == player &&
          board[i + 6] == player) return true;
    }
    // Diagonals
    if (board[0] == player && board[4] == player && board[8] == player)
      return true;
    if (board[2] == player && board[4] == player && board[6] == player)
      return true;

    return false;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // final player = Provider.of<PlayerProvider>(context).currentPlayer; // unused

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {},
      child: Stack(
        children: [
          // GAME CONTENT
          Column(
            children: [
              const Text(
                "GANA A LA VIEJA",
                style: TextStyle(
                    color: AppTheme.accentGold,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Orbitron',
                    letterSpacing: 1.2),
              ),
              const SizedBox(height: 10),

              Expanded(
                child: Center(
                  child: LayoutBuilder(builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 600;
                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isWide ? constraints.maxWidth * 0.25 : 20,
                        vertical: 10,
                      ),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                              color: AppTheme.cardBg,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.3)),
                              boxShadow: [
                                BoxShadow(
                                    color: AppTheme.primaryPurple.withOpacity(0.2),
                                    blurRadius: 20)
                              ]),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemCount: 9,
                            itemBuilder: (context, index) {
                              final cell = board[index];
                              Color cellColor = Colors.white.withOpacity(0.05);
                              if (cell == 'X') cellColor = AppTheme.primaryPurple;
                              if (cell == 'O') cellColor = AppTheme.warningOrange;

                              return GestureDetector(
                                onTap: () => _onTileTap(index),
                                child: Container(
                                  decoration: BoxDecoration(
                                      color: cellColor,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white10),
                                      boxShadow: [
                                        BoxShadow(
                                            color: Colors.black26,
                                            offset: const Offset(2, 4),
                                            blurRadius: 4)
                                      ]),
                                  child: Center(
                                    child: FittedBox(
                                      child: Text(
                                        cell,
                                        style: const TextStyle(
                                          fontSize: 48,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          fontFamily: 'Orbitron'
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // Controles Inferiores
              CyberSurrenderButton(
                onPressed: _showOverlay ? null : _handleGiveUp,
              )
            ],
          ),

          // OVERLAY
          if (_showOverlay)
            GameOverOverlay(
              title: _overlayTitle,
              message: _overlayMessage,
              isVictory: _isVictory,
              onRetry: _canRetry
                  ? () {
                      setState(() {
                        _showOverlay = false;
                        _isGameOver = false;
                        _secondsRemaining = 45;
                        _initializeGame();
                        _startTimer();
                      });
                    }
                  : null,
              onGoToShop: _showShopButton
                  ? () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MallScreen()),
                      );
                      // Check lives upon return
                      if (!context.mounted) return;
                      final player =
                          Provider.of<PlayerProvider>(context, listen: false)
                              .currentPlayer;
                      if ((player?.lives ?? 0) > 0) {
                        setState(() {
                          _canRetry = true;
                          _showShopButton = false;
                          _overlayTitle = "¡VIDAS OBTENIDAS!";
                          _overlayMessage = "Puedes continuar jugando.";
                        });
                      }
                    }
                  : null,
              onExit: () {
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }
}
