import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/clue.dart';
import '../../utils/minigame_logic_helper.dart';
import '../../../auth/providers/player_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/game_provider.dart';
import '../../providers/connectivity_provider.dart';

import 'game_over_overlay.dart';

import '../../../mall/screens/mall_screen.dart';

class HangmanMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const HangmanMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<HangmanMinigame> createState() => _HangmanMinigameState();
}

class _HangmanMinigameState extends State<HangmanMinigame> {
  // Configuración
  late String _word;
  final Set<String> _guessedLetters = {};
  static const int _maxAttempts = 8; // Cambiado a 8 intentos

  // Estado
  int _wrongAttempts = 0;
  bool _isGameOver = false;

  // Timer
  Timer? _timer;
  int _secondsRemaining = 120;

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

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  void _initializeGame() {
    _word = (widget.clue.riddleAnswer?.toUpperCase() ?? "FLUTTER").trim();
    _guessedLetters.clear();
    _wrongAttempts = 0;
    _isGameOver = false;
    _secondsRemaining = 120;
    _startTimer();
  }

  void _startTimer() {
    _stopTimer();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      // Check for freeze state
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      if (gameProvider.isFrozen) return; // Pause timer

      if (gameProvider.isFrozen) return; // Pause timer

      // [FIX] Pause timer if connectivity is bad
      final connectivityByProvider =
          Provider.of<ConnectivityProvider>(context, listen: false);
      if (!connectivityByProvider.isOnline) {
        return; // Skip tick
      }

      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _stopTimer();
          _loseLife("¡Se acabó el tiempo!");
        }
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _onLetterGuess(String letter) {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    if (gameProvider.isFrozen) return; // Ignore input if frozen

    if (gameProvider.isFrozen) return; // Ignore input if frozen

    // [FIX] Prevent interaction if offline
    final connectivity =
        Provider.of<ConnectivityProvider>(context, listen: false);
    if (!connectivity.isOnline) return;

    if (_isGameOver || _guessedLetters.contains(letter)) return;

    setState(() {
      _guessedLetters.add(letter);

      if (!_word.contains(letter)) {
        _wrongAttempts++;
      }
    });

    _checkGameContent();
  }

  void _checkGameContent() {
    // Check Win
    bool won = true;
    for (int i = 0; i < _word.length; i++) {
      if (!_guessedLetters.contains(_word[i]) && _word[i] != ' ') {
        won = false;
        break;
      }
    }

    if (won) {
      _stopTimer();
      _isGameOver = true;
      Future.delayed(const Duration(milliseconds: 500), widget.onSuccess);
      return;
    }

    // Check Lose
    if (_wrongAttempts >= _maxAttempts) {
      _stopTimer();
      _isGameOver = true;
      // Do not reveal the word so the user can retry without knowing safely
      _loseLife("¡Te han ahorcado!");
    }
  }

  void _handleGiveUp() {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    if (gameProvider.isFrozen) return; // Ignore input if frozen

    _stopTimer();
    _loseLife("Te has rendido.");
  }

  // hangman_minigame.dart

  void _loseLife(String reason) async {
    if (!mounted) return;
    _stopTimer();
    setState(() => _isGameOver = true);

    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    final userId = playerProvider.currentPlayer?.userId;

    if (userId != null) {
      if (gameProvider.currentEventId == null) {
        debugPrint("WARN: Minijuego sin Event ID");
      }

      final newLives = await MinigameLogicHelper.executeLoseLife(context);

      if (!mounted) return;

      if (newLives <= 0) {
        _showOverlayState(
            title: "GAME OVER",
            message:
                "Te has quedado sin vidas. No puedes continuar en este minijuego.",
            retry: false,
            showShop: true);
      } else {
        _showOverlayState(
            title: "AHORCADO", message: "", retry: true, showShop: false);
      }
    }
  }

  // DIALOGS REMOVED

  @override
  Widget build(BuildContext context) {
    // final player = Provider.of<PlayerProvider>(context).currentPlayer; // unused in build

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {},
      child: Stack(
        children: [
          // GAME CONTENT
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              children: [
                // Reduced Status Bar (Timer & Attempts only)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Timer
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: _secondsRemaining <= 10
                                ? AppTheme.dangerRed.withOpacity(0.2)
                                : Colors.white10,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: _secondsRemaining <= 10
                                    ? AppTheme.dangerRed
                                    : Colors.white24)),
                        child: Row(
                          children: [
                            Icon(Icons.timer,
                                size: 14,
                                color: _secondsRemaining <= 10
                                    ? AppTheme.dangerRed
                                    : Colors.white),
                            const SizedBox(width: 5),
                            Text(
                              "$_secondsRemaining s",
                              style: TextStyle(
                                  color: _secondsRemaining <= 10
                                      ? AppTheme.dangerRed
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Intentos
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: _wrongAttempts >= _maxAttempts - 1
                                    ? AppTheme.dangerRed
                                    : Colors.white24)),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                size: 14, color: AppTheme.warningOrange),
                            const SizedBox(width: 5),
                            Text(
                              "$_wrongAttempts/$_maxAttempts",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: ShaderMask(
                    shaderCallback: (bounds) => AppTheme.goldGradient.createShader(bounds),
                    child: const Text(
                      "AHORCADO",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w900),
                    ),
                  ),
                ),

                // Pista
                if (widget.clue.riddleQuestion != null &&
                    widget.clue.riddleQuestion!.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGold.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.accentGold.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lightbulb_outline,
                              color: AppTheme.accentGold, size: 18),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              "Pista: ${widget.clue.riddleQuestion}",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Área de Dibujo y Palabra
                Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4), // Minimal vertical margin
                  padding: const EdgeInsets.all(8), // Minimal padding
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Dibujo del Ahorcado
                      SizedBox(
                        height: 140,
                        width:
                            180, // Explicit width to prevent stretching distortion if parent is wide
                        child: CustomPaint(
                          painter: HangmanPainter(_wrongAttempts),
                        ),
                      ),

                      const SizedBox(height: 10), // Reduced spacing

                      // Palabra Oculta
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: _word.split(' ').map((word) {
                          return Wrap(
                            spacing: 1,
                            runSpacing: 4,
                            children: word.split('').map((char) {
                              final isGuessed = _guessedLetters.contains(char);
                              return Container(
                                width: 26,
                                height: 34,
                                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                decoration: BoxDecoration(
                                  color: isGuessed
                                      ? AppTheme.accentGold.withOpacity(0.15)
                                      : Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isGuessed
                                        ? AppTheme.accentGold
                                        : Colors.white10,
                                    width: 1.5,
                                  ),
                                  boxShadow: isGuessed
                                      ? [
                                          BoxShadow(
                                            color: AppTheme.accentGold.withOpacity(0.2),
                                            blurRadius: 4,
                                          )
                                        ]
                                      : [],
                                ),
                                child: Center(
                                  child: Text(
                                    isGuessed ? char : '',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

                // Teclado QWERTY Premium
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: Column(
                    children: [
                      _buildKeyboardRow(['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P']),
                      const SizedBox(height: 8),
                      _buildKeyboardRow(['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L']),
                      const SizedBox(height: 8),
                      _buildKeyboardRow(['Z', 'X', 'C', 'V', 'B', 'N', 'M']),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Botón Rendirse eliminado según solicitud
                const SizedBox(height: 20), // Spacing for bottom safety
              ],
            ),
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
                        _initializeGame();
                      });
                    }
                  : null,
              onGoToShop: _showShopButton
                  ? () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const MallScreen()),
                      );
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

  Widget _buildKeyboardRow(List<String> letters) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: letters.map((letter) => _buildKey(letter)).toList(),
    );
  }

  Widget _buildKey(String letter) {
    final isGuessed = _guessedLetters.contains(letter);
    final isCorrect = _word.contains(letter);

    Color bgColor = Colors.white.withOpacity(0.05);
    Color borderColor = Colors.white.withOpacity(0.15);
    Color textColor = Colors.white;

    if (isGuessed) {
      if (isCorrect) {
        bgColor = AppTheme.successGreen.withOpacity(0.9);
        borderColor = AppTheme.successGreen;
        textColor = Colors.black;
      } else {
        bgColor = Colors.white10;
        borderColor = Colors.transparent;
        textColor = Colors.white24;
      }
    }

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.5),
        child: GestureDetector(
          onTap: isGuessed ? null : () => _onLetterGuess(letter),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            height: 48,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: isGuessed
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 3),
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.05),
                        blurRadius: 1,
                        offset: const Offset(0, -1),
                      ),
                    ],
            ),
            child: Center(
              child: Text(
                letter,
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  shadows: isGuessed && isCorrect
                      ? []
                      : [
                          const Shadow(
                            color: Colors.black26,
                            offset: Offset(0, 1),
                            blurRadius: 2,
                          )
                        ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HangmanPainter extends CustomPainter {
  final int wrongAttempts;

  HangmanPainter(this.wrongAttempts);

  @override
  void paint(Canvas canvas, Size size) {
    // Paints for different parts
    final gallowsPaint = Paint()
      ..color = Colors.white54
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0 // Thicker
      ..strokeCap = StrokeCap.round;

    final bodyPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0 // Thicker
      ..strokeCap = StrokeCap.round;

    final double w = size.width;
    final double h = size.height;

    // 8 Intentos - Dibujo Progresivo

    // 1. Base Suelo (Base)
    if (wrongAttempts >= 1)
      canvas.drawLine(
          Offset(w * 0.15, h * 0.9), Offset(w * 0.85, h * 0.9), gallowsPaint);

    // 2. Poste Vertical (Poste 1)
    if (wrongAttempts >= 2)
      canvas.drawLine(
          Offset(w * 0.25, h * 0.9), Offset(w * 0.25, h * 0.1), gallowsPaint);

    // 3. Poste Horizontal + Soporte (Poste 2)
    if (wrongAttempts >= 3) {
      canvas.drawLine(
          Offset(w * 0.25, h * 0.1), Offset(w * 0.65, h * 0.1), gallowsPaint);
      canvas.drawLine(Offset(w * 0.25, h * 0.2), Offset(w * 0.4, h * 0.1),
          gallowsPaint); // Soporte
    }

    // 4. Cuerda
    if (wrongAttempts >= 4) {
      canvas.drawLine(
          Offset(w * 0.65, h * 0.1), Offset(w * 0.65, h * 0.2), gallowsPaint);
    }

    // 5. Cabeza
    if (wrongAttempts >= 5)
      canvas.drawCircle(Offset(w * 0.65, h * 0.3), h * 0.1, bodyPaint);

    // 6. Cuerpo
    if (wrongAttempts >= 6)
      canvas.drawLine(
          Offset(w * 0.65, h * 0.4), Offset(w * 0.65, h * 0.7), bodyPaint);

    // 7. Brazos (Ambos)
    if (wrongAttempts >= 7) {
      canvas.drawLine(Offset(w * 0.65, h * 0.45), Offset(w * 0.55, h * 0.55),
          bodyPaint); // Izq
      canvas.drawLine(Offset(w * 0.65, h * 0.45), Offset(w * 0.75, h * 0.55),
          bodyPaint); // Der
    }

    // 8. Piernas (Ambas) + Ojos (Game Over)
    if (wrongAttempts >= 8) {
      canvas.drawLine(Offset(w * 0.65, h * 0.7), Offset(w * 0.55, h * 0.85),
          bodyPaint); // Izq
      canvas.drawLine(Offset(w * 0.65, h * 0.7), Offset(w * 0.75, h * 0.85),
          bodyPaint); // Der

      final eyePaint = Paint()
        ..color = AppTheme.dangerRed
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawLine(
          Offset(w * 0.62, h * 0.28), Offset(w * 0.64, h * 0.30), eyePaint);
      canvas.drawLine(
          Offset(w * 0.64, h * 0.28), Offset(w * 0.62, h * 0.30), eyePaint);

      canvas.drawLine(
          Offset(w * 0.66, h * 0.28), Offset(w * 0.68, h * 0.30), eyePaint);
      canvas.drawLine(
          Offset(w * 0.68, h * 0.28), Offset(w * 0.66, h * 0.30), eyePaint);
    }
  }

  @override
  bool shouldRepaint(HangmanPainter oldDelegate) =>
      oldDelegate.wrongAttempts != wrongAttempts;
}
