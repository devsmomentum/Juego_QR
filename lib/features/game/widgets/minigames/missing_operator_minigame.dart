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

class MissingOperatorMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const MissingOperatorMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<MissingOperatorMinigame> createState() =>
      _MissingOperatorMinigameState();
}

class _MissingOperatorMinigameState extends State<MissingOperatorMinigame> {
  // Config
  static const int _targetScore = 5;
  static const int _gameDurationSeconds = 60;

  // State
  int _score = 0;
  int _secondsRemaining = _gameDurationSeconds;
  bool _isGameOver = false;
  bool _isProcessingSelection = false; // Guard against double-taps

  // Round Data
  late int _operand1;
  late int _operand2;
  late int _result;
  late String _correctOperator; // +, -, *, /
  List<String> _options = ['+', '-', 'x', '/'];

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
        if (!connectivityByProvider.isOnline || gameProvider.isFrozen) {
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
    // Determine operator first
    int opIndex = _random.nextInt(4); // 0:+, 1:-, 2:*, 3:/

    switch (opIndex) {
      case 0: // +
        _correctOperator = '+';
        _operand1 = _random.nextInt(50);
        _operand2 = _random.nextInt(50);
        _result = _operand1 + _operand2;
        break;
      case 1: // -
        _correctOperator = '-';
        _operand1 = _random.nextInt(50) + 10;
        _operand2 = _random.nextInt(_operand1); // Result positive
        _result = _operand1 - _operand2;
        break;
      case 2: // x
        _correctOperator = 'x';
        _operand1 = _random.nextInt(12) + 1;
        _operand2 = _random.nextInt(12) + 1;
        _result = _operand1 * _operand2;
        break;
      case 3: // /
        _correctOperator = '/';
        _operand2 = _random.nextInt(10) + 1; // Divisor
        _result = _random.nextInt(10) + 1; // Quotient
        _operand1 = _operand2 * _result; // Dividend
        break;
    }
  }

  Future<void> _handleSelection(String selectedOp) async {
    if (_isGameOver || _isProcessingSelection) return;

    // [FIX] Prevent interaction if offline
    final connectivity =
        Provider.of<ConnectivityProvider>(context, listen: false);
    if (!connectivity.isOnline) return;

    setState(() => _isProcessingSelection = true);

    // Dynamic Mathematical Validation
    // Instead of string matching, we check if the selected operator solves the equation.
    bool isCorrect = false;
    try {
      switch (selectedOp) {
        case '+':
          isCorrect = (_operand1 + _operand2 == _result);
          break;
        case '-':
          isCorrect = (_operand1 - _operand2 == _result);
          break;
        case 'x':
          isCorrect = (_operand1 * _operand2 == _result);
          break;
        case '/':
          if (_operand2 != 0) {
            // Check for integer division equality
            isCorrect = (_operand1 / _operand2 == _result.toDouble());
          }
          break;
      }
    } catch (e) {
      debugPrint("Mathematical validation error: $e");
      isCorrect = false;
    }

    if (isCorrect) {
      // Feedback Visual (Opcional, pero score++ ya es feedback)
      setState(() {
        _score++;
      });

      if (_score >= _targetScore) {
        _endGame(win: true);
      } else {
        // Small delay so the user feels the "hit" before it changes
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
            win: false,
            reason: "Operador incorrecto. Sin vidas.",
            lives: newLives);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("¡INCORRECTO! -1 Vida"),
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Título con Estilo Cyberpunk
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border:
                      Border.all(color: AppTheme.accentGold.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentGold.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Text(
                  "SISTEMA: OPERADOR FALTANTE",
                  style: TextStyle(
                    color: AppTheme.accentGold,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    shadows: [
                      Shadow(color: AppTheme.accentGold, blurRadius: 12),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 35),

              // Stats Bar (Glassmorphic)
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.timer_outlined,
                      label: "TIEMPO",
                      value: "$_secondsRemaining",
                      color: _secondsRemaining < 10
                          ? AppTheme.dangerRed
                          : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.bolt_rounded,
                      label: "OBJETIVO",
                      value: "$_score / $_targetScore",
                      color: AppTheme.successGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Equation Card (Panel Holográfico)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildNumberText("$_operand1"),
                      const SizedBox(width: 18),

                      // Slot del Operador
                      Container(
                        width: 65,
                        height: 65,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: AppTheme.accentGold, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accentGold.withOpacity(0.2),
                              blurRadius: 15,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            "?",
                            style: TextStyle(
                              fontSize: 32,
                              color: AppTheme.accentGold,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 18),
                      _buildNumberText("$_operand2"),
                      const SizedBox(width: 15),
                      const Text(
                        "=",
                        style: TextStyle(
                          fontSize: 48,
                          color: Colors.white38,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Text(
                        "$_result",
                        style: const TextStyle(
                          fontSize: 52,
                          color: AppTheme.successGreen,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(
                                color: AppTheme.successGreen, blurRadius: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 50),

              // Botones de Operadores
              Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: [
                  _buildOperatorButton('+', AppTheme.accentGold),
                  _buildOperatorButton('-', AppTheme.dangerRed),
                  _buildOperatorButton('x', Colors.cyanAccent),
                  _buildOperatorButton('/', Colors.deepPurpleAccent),
                ],
              ),
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

  Widget _buildNumberText(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 48,
        color: Colors.white,
        fontWeight: FontWeight.bold,
        letterSpacing: -1.0,
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color.withOpacity(0.6), size: 14),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperatorButton(String op, Color color) {
    return GestureDetector(
      onTap: () => _handleSelection(op),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 75,
        height: 75,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.5), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 15,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Center(
          child: Text(
            op,
            style: TextStyle(
              fontSize: 32,
              color: color,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(color: color, blurRadius: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
