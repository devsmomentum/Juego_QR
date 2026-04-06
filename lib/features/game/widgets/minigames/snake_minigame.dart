import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/minigame_logic_helper.dart';
import '../../models/clue.dart';
import '../../../auth/providers/player_provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/connectivity_provider.dart';
import 'game_over_overlay.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../mall/screens/mall_screen.dart';
import '../../../admin/models/sponsor.dart';
import '../../../admin/services/sponsor_service.dart';

class SnakeMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const SnakeMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<SnakeMinigame> createState() => _SnakeMinigameState();
}

enum Direction { up, down, left, right }

class _SnakeMinigameState extends State<SnakeMinigame> {
  // Config
  static const int rows = 12; // Compact grid for bigger cells
  static const int cols = 12; // Compact grid for bigger cells

  // Overlay State
  bool _showOverlay = false;
  String _overlayTitle = "";
  String _overlayMessage = "";
  bool _canRetry = false;
  bool _showShopButton = false;

  void _showOverlayState(
      {required String title,
      required String message,
      bool retry = false,
      bool showShop = false}) {
    setState(() {
      _showOverlay = true;
      _overlayTitle = title;
      _overlayMessage = message;
      _canRetry = retry;
      _showShopButton = showShop;
    });
  }

  static const int winScore = 10;

  // Game State
  List<Point<int>> _snake = [
    const Point(6, 6)
  ]; // Centered start position for 12x12 grid
  List<Point<int>> _obstacles = [];
  bool _isOrangeMode = false;

  Point<int>? _food;
  Direction _direction = Direction.right;
  Direction _nextDirection = Direction.right;
  bool _isPlaying = false;
  bool _isGameOver = false;
  int _score = 0;

  // Intentos Locales
  int _crashAllowance = 3;
  Direction? _lastPressedDirection;

  // Timer
  Timer? _gameLoop;
  Timer? _countdownTimer;
  int _secondsRemaining = 90;

  // Pre-game Countdown
  int _preStartCount = 3;
  bool _showingPreStart = false;
  Timer? _preStartTimer;

  // Touch Control State
  Offset _swipeStart = Offset.zero;
  bool _swipeLocked = false;

  // Sponsor Logic
  Sponsor? _activeSponsor;
  final SponsorService _sponsorService = SponsorService();

  @override
  void initState() {
    super.initState();
    _fetchSponsorAndStart();
  }

  Future<void> _fetchSponsorAndStart() async {
    // [FIX] CRITICAL: El juego inicia INMEDIATAMENTE. El sponsor es solo
    // un banner cosmético en el GameOverOverlay, no debe bloquear el inicio.
    // Si la red es lenta o el sponsor falla, el usuario verá el juego igual.
    _startNewGame();

    // Cargar el sponsor en segundo plano (fire-and-forget)
    _loadSponsorInBackground();
  }

  Future<void> _loadSponsorInBackground() async {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final eventId = gameProvider.currentEventId;

    try {
      Sponsor? sponsor;
      if (eventId != null) {
        sponsor = await _sponsorService
            .getSponsorForEvent(eventId)
            .timeout(const Duration(seconds: 5));
      }
      // Fallback global si no hay sponsor de evento
      if (sponsor == null) {
        sponsor = await _sponsorService
            .getActiveSponsor()
            .timeout(const Duration(seconds: 5));
      }
      if (mounted && sponsor != null) {
        setState(() => _activeSponsor = sponsor);
      }
    } catch (e) {
      // Sponsor es opcional → fallo silencioso, el juego continúa sin banner
      debugPrint('[Snake] Sponsor load failed (non-critical): $e');
    }
  }

  @override
  void dispose() {
    _gameLoop?.cancel();
    _countdownTimer?.cancel();
    _preStartTimer?.cancel();
    super.dispose();
  }

  void _startNewGame() {
    _gameLoop?.cancel();
    _countdownTimer?.cancel();
    _preStartTimer?.cancel();

    setState(() {
      _snake = [const Point(6, 6), const Point(5, 6), const Point(4, 6)];
      _obstacles = [];
      _isOrangeMode = false;
      _direction = Direction.right;
      _nextDirection = Direction.right;
      _score = 0;
      _secondsRemaining = 90;
      _isPlaying = true; // Started immediately
      _isGameOver = false;
      _crashAllowance = 3; // Reset intentos
      _generateFood();
      _showingPreStart = false; // No more local countdown
      _preStartCount = 0;
    });

    _startCountdown();
    _startGameLoop();
  }

  void _startGameLoop() {
    _gameLoop?.cancel();
    int speed = _isOrangeMode ? 300 : 400;

    _gameLoop = Timer.periodic(Duration(milliseconds: speed), (timer) {
      if (!mounted) return;

      // Check for freeze state
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      if (gameProvider.isPaused) return; // Pause game loop

      // [FIX] Pause game loop if connectivity is bad
      final connectivityByProvider =
          Provider.of<ConnectivityProvider>(context, listen: false);
      if (!connectivityByProvider.isOnline) {
        return; // Skip tick
      }

      _updateGame();
    });
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      // Check for freeze state
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      if (gameProvider.isPaused) return; // Pause timer

      // [FIX] Pause timer if connectivity is bad
      final connectivityByProvider =
          Provider.of<ConnectivityProvider>(context, listen: false);
      if (!connectivityByProvider.isOnline) {
        return; // Skip tick
      }

      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _loseGlobalLife("¡Se acabó el tiempo!", isTimeOut: true);
      }
    });
  }

  void _generateFood() {
    final random = Random();
    Point<int> newFood;
    do {
      newFood = Point(random.nextInt(cols), random.nextInt(rows));
    } while (_snake.contains(newFood) || _obstacles.contains(newFood));

    setState(() {
      _food = newFood;
    });
  }

  void _generateObstacles(int count) {
    final random = Random();

    setState(() {
      for (int i = 0; i < count; i++) {
        Point<int> obstacle;
        int attempts = 0;
        do {
          obstacle = Point(random.nextInt(cols), random.nextInt(rows));
          attempts++;
        } while ((_snake.contains(obstacle) ||
                _obstacles.contains(obstacle) ||
                obstacle == _food) &&
            attempts < 50);

        if (attempts < 50) {
          _obstacles.add(obstacle);
        }
      }
    });
  }

  void _updateGame() {
    if (!_isPlaying || _isGameOver) return;

    // [FIX] Double check connectivity in game logic update
    if (!Provider.of<ConnectivityProvider>(context, listen: false).isOnline)
      return;

    // 1. Calculate Next Head based on current/next direction
    // We update _direction here temporarily for calculation, committed in setState later if valid
    Direction currentMoveDir = _nextDirection;

    Point<int> newHead;
    switch (currentMoveDir) {
      case Direction.up:
        newHead = Point(_snake.first.x, _snake.first.y - 1);
        break;
      case Direction.down:
        newHead = Point(_snake.first.x, _snake.first.y + 1);
        break;
      case Direction.left:
        newHead = Point(_snake.first.x - 1, _snake.first.y);
        break;
      case Direction.right:
        newHead = Point(_snake.first.x + 1, _snake.first.y);
        break;
    }

    // 2. Check Collisions (Pure Logic)

    // Colisión Paredes
    if (newHead.x < 0 ||
        newHead.x >= cols ||
        newHead.y < 0 ||
        newHead.y >= rows) {
      _handleCrash("¡Chocaste con la pared!");
      return;
    }

    // Colisión a sí mismo
    if (_snake.contains(newHead)) {
      _handleCrash("¡Te mordiste la cola!");
      return;
    }

    // Colisión Obstáculos
    if (_obstacles.contains(newHead)) {
      _handleCrash("¡Chocaste con una roca!");
      return;
    }

    // 3. Commit Valid Move
    setState(() {
      _direction = currentMoveDir;
      _snake.insert(0, newHead);

      // Comer
      if (newHead == _food) {
        _score++;

        // Generar 3 Obstáculos cada 2 puntos
        if (_score % 2 == 0) {
          _generateObstacles(3);
        }

        // Activar MODO NARANJA (Velocidad) al llegar a 5 puntos
        if (_score == 5 && !_isOrangeMode) {
          _isOrangeMode = true;
          _startGameLoop(); // Reinicia el loop con la nueva velocidad

          // Feedback visual
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("¡MODO TURBO ACTIVADO! 🍊💨"),
            backgroundColor: Colors.deepOrange,
            duration: Duration(seconds: 1),
          ));
        }

        if (_score >= winScore) {
          _winGame();
        } else {
          _generateFood();
        }
      } else {
        _snake.removeLast();
      }
    });
  }

  void _handleCrash(String reason) {
    try {
      debugPrint("💥 CRASH DETECTED START: $reason");

      // Stop game loop immediately to prevent multiple calls
      _gameLoop?.cancel();
      debugPrint("Timer cancelled successfully.");

      // Show Feedback (Wrap in try-catch in case Context is invalid, though unlikely)
      try {
        ScaffoldMessenger.of(context)
            .hideCurrentSnackBar(); // Hide previous if any
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              "¡Choque! Intentos restantes: ${_crashAllowance - 1}. Reiniciando..."),
          duration: const Duration(milliseconds: 1000),
          backgroundColor: AppTheme.warningOrange,
        ));
      } catch (e) {
        debugPrint("Error showing SnackBar: $e");
      }

      // State Update
      setState(() {
        debugPrint("Decreasing crash allowance. Current: $_crashAllowance");
        _crashAllowance--;

        if (_crashAllowance > 0) {
          // 1. Reset Snake
          _snake = [const Point(7, 7), const Point(6, 7), const Point(5, 7)];
          _direction = Direction.right;
          _nextDirection = Direction.right;

          // 2. Clear Safe Zone
          final safeZone = [
            const Point(7, 7),
            const Point(6, 7),
            const Point(5, 7),
            const Point(8, 7)
          ];
          _obstacles.removeWhere((obs) => safeZone.contains(obs));

          // 3. FORCE REBUILD OF BOARD
          _boardKey = UniqueKey();
          debugPrint("Board Reset Key: $_boardKey");
        }
      });

      if (_crashAllowance <= 0) {
        _loseGlobalLife("¡Agotaste tus intentos!");
      } else {
        debugPrint("Scheduling restart...");
        // Resume loop after delay
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted && !_isGameOver) {
            debugPrint("RESUMING GAME LOOP NOW (Future).");
            _startGameLoop();
          } else {
            debugPrint(
                "Restart aborted: mounted=$mounted, gameOver=$_isGameOver");
          }
        });
      }
    } catch (e, stack) {
      debugPrint("CRITICAL ERROR IN HANDLE_CRASH: $e");
      debugPrint(stack.toString());
    }
  }

  void _winGame() {
    _isPlaying = false;
    _isGameOver = true;
    _gameLoop?.cancel();
    _countdownTimer?.cancel();
    widget.onSuccess();
  }

  void _loseGlobalLife(String reason, {bool isTimeOut = false}) async {
    _isPlaying = false;
    _isGameOver = true;
    _gameLoop?.cancel();
    _countdownTimer?.cancel();

    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    if (playerProvider.currentPlayer != null) {
      final newLives = await MinigameLogicHelper.executeLoseLife(context);

      if (!mounted) return;

      if (newLives <= 0) {
        _showOverlayState(
            title: "GAME OVER",
            message: "Te has quedado sin vidas.",
            retry: false,
            showShop: true);
      } else {
        _showOverlayState(
            title: "¡FALLASTE!",
            message: "$reason",
            retry: true,
            showShop: false);
      }
    }
  }

  void _onChangeDirection(Direction newDir) {
    // [FIX] Prevent interaction if offline
    if (!Provider.of<ConnectivityProvider>(context, listen: false).isOnline)
      return;

    if (_direction == Direction.up && newDir == Direction.down) return;
    if (_direction == Direction.down && newDir == Direction.up) return;
    if (_direction == Direction.left && newDir == Direction.right) return;
    if (_direction == Direction.right && newDir == Direction.left) return;
    _nextDirection = newDir;
  }

  // Force Rebuild Key
  Key _boardKey = UniqueKey();

  @override
  Widget build(BuildContext context) {
    final minutes = (_secondsRemaining / 60).floor().toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    final isLowTime = _secondsRemaining <= 10;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {},
      child: Stack(
        children: [
          // 1. GAME CONTENT (Wrapped in Column as before)
          Column(
            children: [
              // Header Info reducido
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    // Score
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                              color: AppTheme.successGreen.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Center(
                              child: Text("🍎", style: TextStyle(fontSize: 16)),
                            ),
                            const SizedBox(width: 6),
                            Text("$_score / $winScore",
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Intentos
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(3, (index) {
                          return Icon(
                            index < _crashAllowance
                                ? Icons.flash_on
                                : Icons.flash_off,
                            color: index < _crashAllowance
                                ? AppTheme.accentGold
                                : Colors.white24,
                            size: 18,
                          );
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Timer
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isLowTime
                              ? AppTheme.dangerRed.withOpacity(0.2)
                              : Colors.black45,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                              color: isLowTime
                                  ? AppTheme.dangerRed
                                  : Colors.white12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.timer_outlined,
                                color: isLowTime
                                    ? AppTheme.dangerRed
                                    : Colors.white70,
                                size: 16),
                            const SizedBox(width: 4),
                            Text("$minutes:$seconds",
                                style: TextStyle(
                                    color: isLowTime
                                        ? AppTheme.dangerRed
                                        : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (details) {
                    _swipeStart = details.localPosition;
                    _swipeLocked = false;
                  },
                  onPanUpdate: (details) {
                    if (_swipeLocked) return;
                    
                    final delta = details.localPosition - _swipeStart;
                    const threshold = 30.0;
                    
                    if (delta.distance > threshold) {
                      if (delta.dx.abs() > delta.dy.abs()) {
                        if (delta.dx > 0) {
                          _onChangeDirection(Direction.right);
                        } else {
                          _onChangeDirection(Direction.left);
                        }
                      } else {
                        if (delta.dy > 0) {
                          _onChangeDirection(Direction.down);
                        } else {
                          _onChangeDirection(Direction.up);
                        }
                      }
                      _swipeLocked = true;
                    }
                  },
                  onPanEnd: (_) {
                    _swipeLocked = false;
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Center(
                      child: AspectRatio(
                        key: _boardKey, // FORCE REBUILD ON CRASH
                        aspectRatio: cols / rows,
                        child: Container(
                          decoration: BoxDecoration(
                              color: const Color(0xFF0A0A0B),
                              border: Border.all(
                                  color: AppTheme.primaryPurple.withOpacity(0.4),
                                  width: 3),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                    color:
                                        AppTheme.primaryPurple.withOpacity(0.15),
                                    blurRadius: 30,
                                    spreadRadius: 5)
                              ]),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final cellSize = constraints.maxWidth / cols;
                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  // Grid de Fondo Neon
                                  CustomPaint(
                                    size: Size(constraints.maxWidth,
                                        constraints.maxHeight),
                                    painter: GridPainter(rows, cols,
                                        AppTheme.primaryPurple.withOpacity(0.08)),
                                  ),

                                  // Render Obstacles (Rocas con estilo)
                                  ..._obstacles.map((obs) {
                                    return Positioned(
                                      left: obs.x * cellSize,
                                      top: obs.y * cellSize,
                                      child: Container(
                                        width: cellSize,
                                        height: cellSize,
                                        margin: const EdgeInsets.all(1),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [Colors.grey[800]!, Colors.grey[900]!],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(4),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.5),
                                              blurRadius: 2,
                                            )
                                          ],
                                        ),
                                      ),
                                    );
                                  }),

                                  // Render Player Snake
                                  ..._snake.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final part = entry.value;
                                    final isHead = index == 0;
                                    final isTail = index == _snake.length - 1;

                                    Color headColor = _isOrangeMode ? Colors.orangeAccent : AppTheme.successGreen;
                                    Color bodyColor = _isOrangeMode ? Colors.orange.withOpacity(0.8) : Colors.greenAccent[400]!.withOpacity(0.8);

                                    return Positioned(
                                      key: ValueKey('snake_${index}_${part.x}_${part.y}'),
                                      left: part.x * cellSize,
                                      top: part.y * cellSize,
                                      child: Container(
                                        width: cellSize,
                                        height: cellSize,
                                        margin: EdgeInsets.all(isHead ? 0.5 : 1.5),
                                        decoration: BoxDecoration(
                                          color: isHead ? headColor : bodyColor,
                                          borderRadius:
                                              BorderRadius.circular(isHead ? 4 : 2),
                                          boxShadow: _isOrangeMode
                                              ? [
                                                  BoxShadow(
                                                      color: Colors.orange
                                                          .withOpacity(0.5),
                                                      blurRadius: 5)
                                                ]
                                              : null,
                                        ),
                                        child: isHead
                                            ? _buildHeadEyes(cellSize)
                                            : null,
                                      ),
                                    );
                                  }),

                                  // Comida (Manzana con brillo)
                                  if (_food != null)
                                    Positioned(
                                      left: _food!.x * cellSize,
                                      top: _food!.y * cellSize,
                                      child: Container(
                                        width: cellSize,
                                        height: cellSize,
                                        alignment: Alignment.center,
                                        child: TweenAnimationBuilder<double>(
                                          tween: Tween(begin: 0.8, end: 1.1),
                                          duration: const Duration(milliseconds: 600),
                                          curve: Curves.easeInOutSine,
                                          builder: (context, scale, child) {
                                            return Transform.scale(
                                              scale: scale,
                                              child: child,
                                            );
                                          },
                                          onEnd: () {}, // Handled by repeating tween if needed or just one-off pulse
                                          child: FittedBox(
                                            fit: BoxFit.contain,
                                            child: const Text("🍎", style: TextStyle(fontSize: 20)),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // CONTROLES D-PAD COMPACTOS
              if (!_showOverlay) _buildDPad(),
              const SizedBox(height: 4),
            ],
          ),

          // OVERLAY
          if (_showOverlay)
            GameOverOverlay(
              title: _overlayTitle,
              message: _overlayMessage,
              bannerUrl: _activeSponsor?.bannerUrl,
              onRetry: _canRetry
                  ? () {
                      setState(() {
                        _showOverlay = false;
                      });
                      _startNewGame();
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

  Widget _buildDPad() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDPadButton(Icons.keyboard_arrow_up, Direction.up),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDPadButton(Icons.keyboard_arrow_left, Direction.left),
              const SizedBox(width: 70), // Tighter spacing
              _buildDPadButton(Icons.keyboard_arrow_right, Direction.right),
            ],
          ),
          const SizedBox(height: 4),
          _buildDPadButton(Icons.keyboard_arrow_down, Direction.down),
        ],
      ),
    );
  }

  Widget _buildDPadButton(IconData icon, Direction direction) {
    final bool isPressed = _lastPressedDirection == direction;

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _lastPressedDirection = direction);
        _onChangeDirection(direction);
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) setState(() => _lastPressedDirection = null);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 52,
        height: 52,
        transform: Matrix4.identity()..scale(isPressed ? 0.9 : 1.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isPressed
                ? [AppTheme.accentGold, AppTheme.warningOrange]
                : [
                    Colors.white.withOpacity(0.12),
                    Colors.white.withOpacity(0.05),
                  ],
          ),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isPressed ? AppTheme.accentGold : Colors.white12,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isPressed
                  ? AppTheme.accentGold.withOpacity(0.4)
                  : Colors.black.withOpacity(0.2),
              blurRadius: isPressed ? 10 : 5,
              offset: isPressed ? Offset.zero : const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: isPressed ? Colors.black : Colors.white.withOpacity(0.8),
          size: 34,
        ),
      ),
    );
  }

  // _buildPreStartOverlay removed completely.

  Widget _buildHeadEyes(double cellSize) {
    int quarterTurns = 0;
    switch (_direction) {
      case Direction.up:
        quarterTurns = 0;
        break;
      case Direction.right:
        quarterTurns = 1;
        break;
      case Direction.down:
        quarterTurns = 2;
        break;
      case Direction.left:
        quarterTurns = 3;
        break;
    }

    final eyeSize = cellSize * 0.2;

    return RotatedBox(
      quarterTurns: quarterTurns,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Container(
              width: eyeSize,
              height: eyeSize,
              decoration: const BoxDecoration(
                  color: Colors.black, shape: BoxShape.circle)),
          Container(
              width: eyeSize,
              height: eyeSize,
              decoration: const BoxDecoration(
                  color: Colors.black, shape: BoxShape.circle)),
        ],
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  final int rows;
  final int cols;
  final Color color;

  GridPainter(this.rows, this.cols, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    final cellWidth = size.width / cols;
    final cellHeight = size.height / rows;

    for (int i = 0; i <= cols; i++) {
      canvas.drawLine(
          Offset(i * cellWidth, 0), Offset(i * cellWidth, size.height), paint);
    }

    for (int i = 0; i <= rows; i++) {
      canvas.drawLine(
          Offset(0, i * cellHeight), Offset(size.width, i * cellHeight), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
