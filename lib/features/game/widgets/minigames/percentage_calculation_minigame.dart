import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/clue.dart';
import '../../providers/game_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../../../core/theme/app_theme.dart';
import 'game_over_overlay.dart';
import '../../utils/minigame_logic_helper.dart';
import '../../../auth/providers/player_provider.dart';
import '../../../mall/screens/mall_screen.dart';

class PercentageCalculationMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const PercentageCalculationMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<PercentageCalculationMinigame> createState() =>
      _PercentageCalculationMinigameState();
}

class _PercentageCalculationMinigameState
    extends State<PercentageCalculationMinigame> {
  // Config
  static const int _targetScore = 5;
  static const int _gameDurationSeconds = 60;

  // State
  int _score = 0;
  int _secondsRemaining = _gameDurationSeconds;
  bool _isGameOver = false;
  bool _isProcessingSelection = false; // Guard against double-taps

  // Round Data
  late int _baseNumber;
  late int _percentage; // 10, 20, 25, 50
  late int _correctAnswer;
  List<int> _options = [];

  // Overlay
  bool _showOverlay = false;
  String _overlayTitle = "";
  String _overlayMessage = "";
  bool _canRetry = false;
  bool _showShopButton = false;

  Timer? _gameTimer;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _startGame();
  }

  void _startGame() {
    _score = 0;
    _secondsRemaining = _gameDurationSeconds;
    _isGameOver = false;
    _showOverlay = false;
    _generateRound();
    _startTimer();
  }

  void _startTimer() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isGameOver) {
        timer.cancel();
        return;
      }
      setState(() {
        // [FIX] Pause timer if connectivity is bad OR if game is frozen (sabotage)
        final gameProvider = Provider.of<GameProvider>(context, listen: false);
        final connectivityByProvider =
            Provider.of<ConnectivityProvider>(context, listen: false);
        if (!connectivityByProvider.isOnline || gameProvider.isPaused) {
          return; // Skip tick
        }

        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _endGame(win: false, reason: "Tiempo agotado.");
        }
      });
    });
  }

  void _generateRound() {
    // Generate clear percentages: 10, 20, 25, 50
    final List<int> percents = [10, 20, 25, 50];
    _percentage = percents[_random.nextInt(percents.length)];

    // Generate accurate base numbers (multiples of 10 or 4)
    if (_percentage == 25) {
      _baseNumber = (_random.nextInt(25) + 1) * 4; // 4, 8, ..., 100
    } else {
      _baseNumber = (_random.nextInt(40) + 1) * 10; // 10, 20, ..., 400
    }

    // Exact integer calculation (guaranteed by constraints above)
    _correctAnswer = (_baseNumber * _percentage) ~/ 100;

    debugPrint(
        '[PERCENT_MINIGAME] Round: $_percentage% of $_baseNumber = $_correctAnswer');

    // Generate distractors using a Set to ensure uniqueness
    final Set<int> distractorSet = {_correctAnswer};

    // 1. Try adding values calculating wrong percentages of the same base
    for (int p in percents) {
      if (p != _percentage) {
        int val = (_baseNumber * p) ~/ 100;
        if (val > 0 && val != _correctAnswer) {
          distractorSet.add(val);
        }
      }
    }

    // 2. Add random variants until we have 4 options
    int attempts = 0;
    while (distractorSet.length < 4 && attempts < 100) {
      attempts++;
      int type = _random.nextInt(3);
      int val;

      if (type == 0) {
        // Small offset (±1, ±2, ±3)
        val = _correctAnswer +
            (_random.nextBool() ? 1 : -1) * (_random.nextInt(3) + 1);
      } else if (type == 1) {
        // Large offset (±10)
        val = _correctAnswer + (_random.nextBool() ? 10 : -10);
      } else {
        // Random value within a reasonable range
        val = _random.nextInt(_baseNumber + 5);
      }

      if (val > 0 && val != _correctAnswer) {
        distractorSet.add(val);
      }
    }

    // 3. Absolute fallback: if we still don't have 4 options, force sequential distractors
    int offset = 1;
    while (distractorSet.length < 4) {
      int val = _correctAnswer + offset;
      distractorSet.add(val);
      offset++;
    }

    _options = distractorSet.toList();
    _options.shuffle(_random);

    // 4. Final safety check: ensure the correct answer is definitely in the options
    if (!_options.contains(_correctAnswer)) {
      debugPrint('[PERCENT_MINIGAME] ⚠️ ERROR: Correct answer was missing!');
      _options[0] = _correctAnswer;
      _options.shuffle(_random);
    }

    debugPrint('[PERCENT_MINIGAME] Options: $_options');
  }

  Future<void> _handleSelection(int selected) async {
    if (_isGameOver || _isProcessingSelection) return;

    // [FIX] Prevent interaction if offline
    final connectivity =
        Provider.of<ConnectivityProvider>(context, listen: false);
    if (!connectivity.isOnline) return;

    setState(() => _isProcessingSelection = true);

    if (selected == _correctAnswer) {
      setState(() {
        _score++;
      });

      if (_score >= _targetScore) {
        _endGame(win: true);
      } else {
        // Small delay for feedback and to prevent immediate next-round taps
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          setState(() {
            _generateRound();
            _isProcessingSelection = false;
          });
        }
      }
    } else {
      await _handleMistake();
      if (mounted) {
        setState(() => _isProcessingSelection = false);
      }
    }
  }

  Future<void> _handleMistake() async {
    _gameTimer?.cancel();
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    if (playerProvider.currentPlayer != null) {
      final newLives = await MinigameLogicHelper.executeLoseLife(context);
      if (!mounted) return;

      if (newLives <= 0) {
        _endGame(
            win: false, reason: "Cálculo erróneo. Sin vidas.", lives: newLives);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("¡ERROR DE CÁLCULO! -1 Vida"),
              backgroundColor: AppTheme.dangerRed,
              duration: Duration(milliseconds: 1000)),
        );
        _startTimer();
      }
    }
  }

  void _endGame({required bool win, String? reason, int? lives}) {
    _gameTimer?.cancel();
    setState(() {
      _isGameOver = true;
    });

    if (win) {
      widget.onSuccess();
    } else {
      final currentLives = lives ??
          Provider.of<PlayerProvider>(context, listen: false)
              .currentPlayer
              ?.lives ??
          0;

      setState(() {
        _showOverlay = true;
        _overlayTitle = "GAME OVER";
        _overlayMessage = reason ?? "Perdiste";
        _canRetry = currentLives > 0;
        _showShopButton = true;
      });
    }
  }

  void _resetGame() {
    setState(() {
      _isGameOver = false;
      _showOverlay = false;
    });
    _startGame();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }

  int? _selectedIdx; // Feedback on which index was tapped
  bool? _wasCorrect; // Feedback if the tap was correct

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Use minimum space
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 8),

              // 1. Header: Info and Progress (More compact)
              _buildTopBar(),

              const SizedBox(height: 12),

              // 2. Question Card: Premium Glassmorphism (Compact)
              _buildQuestionCard(),

              const SizedBox(height: 16),

              // 3. Instructions (Mini)
              const Text(
                "ELIGE EL RESULTADO",
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),

              const SizedBox(height: 12),

              // 4. Options Grid (More compact)
              _buildOptionsGrid(),

              const SizedBox(height: 20),
            ],
          ),
        ),
        if (_showOverlay)
          GameOverOverlay(
            title: _overlayTitle,
            message: _overlayMessage,
            onRetry: _canRetry ? _resetGame : null,
            onGoToShop: _showShopButton
                ? () async {
                    await Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const MallScreen()));
                    if (mounted) {
                      final player =
                          Provider.of<PlayerProvider>(context, listen: false)
                              .currentPlayer;
                      if ((player?.lives ?? 0) > 0) _resetGame();
                    }
                  }
                : null,
            onExit: () => Navigator.pop(context),
          ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildInfoItem(
            icon: Icons.timer_rounded,
            value: "$_secondsRemaining",
            label: "TIEMPO",
            color: _secondsRemaining < 10 ? AppTheme.dangerRed : AppTheme.accentGold,
          ),
          Container(height: 20, width: 1, color: Colors.white12),
          _buildInfoItem(
            icon: Icons.bolt_rounded,
            value: "$_score/$_targetScore",
            label: "PROGRESO",
            color: AppTheme.successGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white30,
            fontSize: 8,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4834D4).withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF150826).withAlpha(240), // Deep Indigo/Navy
                const Color(0xFF4834D4).withAlpha(220), // Dark Blue
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white12, width: 1.2),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            children: [
              Text(
                "¿CUÁNTO ES EL?",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 10),
              FittedBox(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      "$_percentage",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 54,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      "%",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  "DE",
                  style: TextStyle(
                    color: Colors.white24,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4.0,
                  ),
                ),
              ),
              Text(
                "$_baseNumber",
                style: const TextStyle(
                  color: AppTheme.accentGold,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Orbitron',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildOptionsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.8, // Shorter buttons
      ),
      itemCount: _options.length,
      itemBuilder: (context, index) {
        final opt = _options[index];
        final isSelected = _selectedIdx == index;

        Color cardColor = Colors.white.withOpacity(0.06);
        Color borderColor = Colors.white.withOpacity(0.12);
        Color textColor = Colors.white;

        if (isSelected && _wasCorrect != null) {
          cardColor = _wasCorrect!
              ? AppTheme.successGreen.withOpacity(0.15)
              : AppTheme.dangerRed.withOpacity(0.15);
          borderColor = _wasCorrect! ? AppTheme.successGreen : AppTheme.dangerRed;
          textColor = _wasCorrect! ? AppTheme.successGreen : AppTheme.dangerRed;
        }

        return RepaintBoundary(
          child: GestureDetector(
            onTap: () async {
              if (_isGameOver || _isProcessingSelection) return;
              setState(() {
                _selectedIdx = index;
                _wasCorrect = (opt == _correctAnswer);
              });
              await _handleSelection(opt);
              if (mounted) {
                setState(() {
                  _selectedIdx = null;
                  _wasCorrect = null;
                });
              }
            },
            child: AnimatedScale(
              scale: isSelected ? 0.94 : 1.0,
              duration: const Duration(milliseconds: 100),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor, width: 1.5),
                  boxShadow: isSelected && _wasCorrect == true
                      ? [
                          BoxShadow(
                            color: AppTheme.successGreen.withOpacity(0.2),
                            blurRadius: 10,
                          )
                        ]
                      : [],
                ),
                child: Center(
                  child: FittedBox(
                    child: Text(
                      "$opt",
                      style: TextStyle(
                        color: textColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}


