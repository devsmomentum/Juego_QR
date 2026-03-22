import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:math';
import '../../models/clue.dart';
import '../../providers/game_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../../../core/theme/app_theme.dart';
import 'game_over_overlay.dart';
import '../../utils/minigame_logic_helper.dart';
import '../../../auth/providers/player_provider.dart';
import '../../../mall/screens/mall_screen.dart';
import 'package:map_hunter/features/game/services/emoji_movie_service.dart';
import 'package:map_hunter/features/game/models/emoji_movie_problem.dart';
import 'package:auto_size_text/auto_size_text.dart';

class EmojiMovieMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const EmojiMovieMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<EmojiMovieMinigame> createState() => _EmojiMovieMinigameState();
}

class _EmojiMovieMinigameState extends State<EmojiMovieMinigame>
    with SingleTickerProviderStateMixin {
  // Game Config
  static const int _gameDurationSeconds = 45;
  static const int _targetMovies = 5;

  // State
  bool _isGameOver = false;
  bool _showOverlay = false;
  String _overlayTitle = "";
  String _overlayMessage = "";
  bool _canRetry = false;
  bool _showShopButton = false;
  bool _isLoading = true;
  int _secondsRemaining = _gameDurationSeconds;
  int _moviesGuessed = 0;
  Timer? _gameTimer;

  // Game Data
  late String _displayEmojis;
  late List<String> _validAnswers;
  List<String> _options = []; // The 4 options to display

  // Service
  late EmojiMovieService _movieService;
  // Cache fetched movies
  final List<String> _usedEmojiSets = []; // Track used emojis to avoid repeats

  // Animations
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 10.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

    _loadDataAndStart();
  }

  Future<void> _loadDataAndStart() async {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    if (gameProvider.minigameEmojiMovies.isEmpty) {
      await gameProvider.loadMinigameData();
    }
    if (mounted) {
      _initializeGameData();
    }
  }

  void _startGameTimer() {
    if (_gameTimer != null && _gameTimer!.isActive) return;
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      if (gameProvider.isPaused) return;

      final connectivity =
          Provider.of<ConnectivityProvider>(context, listen: false);
      if (!connectivity.isOnline) return;

      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _gameTimer?.cancel();
        _handleMistake("¡Tiempo agotado!");
      }
    });
  }

  void _initializeGameData() {
    setState(() => _isLoading = true);

    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final question = widget.clue.riddleQuestion;
    final answer = widget.clue.riddleAnswer;

    // Custom Data Check
    bool hasCustomData = question != null &&
        question.isNotEmpty &&
        question != "Adivina la película con los emojis" &&
        answer != null &&
        answer.isNotEmpty;

    String correctAnswer;

    if (hasCustomData) {
      _displayEmojis = question!;
      correctAnswer = answer!.trim();
      _validAnswers = [correctAnswer.toLowerCase()];
      _generateOptions(correctAnswer, gameProvider.minigameEmojiMovies);
      setState(() => _isLoading = false);
      _startGameTimer();
    } else {
      final allMovies = gameProvider.minigameEmojiMovies;

      if (allMovies.isNotEmpty) {
        final random = Random();
        final availableMovies =
            allMovies.where((m) => !_usedEmojiSets.contains(m['emojis'])).toList();
        final pool = availableMovies.isEmpty ? allMovies : availableMovies;
        final problem = pool[random.nextInt(pool.length)];

        _usedEmojiSets.add(problem['emojis']);
        _displayEmojis = problem['emojis'];
        _validAnswers = List<String>.from(problem['validAnswers']);
        correctAnswer = _validAnswers.first;

        _generateOptions(correctAnswer, allMovies);
      } else {
        _displayEmojis = "🎬";
        correctAnswer = "Sin datos";
        _validAnswers = ["error"];
        _options = ["Error", "DB", "Offline", "Reintentar"];
      }

      setState(() => _isLoading = false);
      _startGameTimer();
    }
  }

  void _generateOptions(String correctAnswer, List<Map<String, dynamic>> allMovies) {
    Set<String> optionsSet = {correctAnswer};
    final random = Random();

    if (allMovies.isEmpty) {
      _options = [correctAnswer, "Harry Potter", "Titanic", "Avatar"];
      _options.shuffle();
      return;
    }

    int attempts = 0;
    while (optionsSet.length < 4 && attempts < 100) {
      attempts++;
      final problem = allMovies[random.nextInt(allMovies.length)];
      final answers = List<String>.from(problem['validAnswers']);
      if (answers.isEmpty) continue;

      final candidate = answers.first;
      bool isSimilarToCorrect = _validAnswers.any((valid) =>
          candidate.toLowerCase().contains(valid.toLowerCase()) ||
          valid.toLowerCase().contains(candidate.toLowerCase()));

      if (!isSimilarToCorrect && !optionsSet.contains(candidate)) {
        optionsSet.add(candidate);
      }
    }

    while (optionsSet.length < 4) {
      optionsSet.add("Película ${optionsSet.length + 1}");
    }

    _options = optionsSet.toList();
    _options.shuffle();
    _options = _options.map((opt) {
      if (opt.isEmpty) return opt;
      return opt[0].toUpperCase() + opt.substring(1);
    }).toList();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _gameTimer?.cancel();
    super.dispose();
  }

  void _checkAnswer(String selectedOption) {
    if (_isGameOver) return;

    final connectivity =
        Provider.of<ConnectivityProvider>(context, listen: false);
    if (!connectivity.isOnline) return;

    if (_validAnswers.contains("error") && selectedOption == "Reintentar") {
      _resetGame();
      return;
    }

    final normalizedSelection = selectedOption.toLowerCase();
    bool isCorrect =
        _validAnswers.any((ans) => normalizedSelection == ans.toLowerCase());

    if (isCorrect) {
      _handleSuccess();
    } else {
      _shakeController.forward(from: 0.0);
      _handleMistake("Respuesta incorrecta");
    }
  }

  void _handleSuccess() {
    setState(() {
      _moviesGuessed++;
    });

    if (_moviesGuessed >= _targetMovies) {
      _gameTimer?.cancel();
      setState(() {
        _isGameOver = true;
      });
      widget.onSuccess();
    } else {
      _initializeGameData();
    }
  }

  Future<void> _handleMistake(String reason) async {
    _gameTimer?.cancel();
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    if (playerProvider.currentPlayer != null) {
      final newLives = await MinigameLogicHelper.executeLoseLife(context);
      if (!mounted) return;

      final correctAnswerDisplay = _validAnswers.first[0].toUpperCase() + _validAnswers.first.substring(1);

      if (newLives <= 0) {
        _endGame(
            win: false,
            reason: "$reason.\n\nLa respuesta era: $correctAnswerDisplay",
            lives: newLives);
      } else {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.surfaceDark,
            title: const Text("¡RESPUESTA INCORRECTA!",
                style: TextStyle(color: AppTheme.dangerRed, fontSize: 18)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("La película para",
                    style: TextStyle(color: Colors.white70)),
                Text(_displayEmojis,
                    style: const TextStyle(fontSize: 40)),
                const Text("es:", style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 10),
                Text(correctAnswerDisplay,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppTheme.accentGold,
                        fontWeight: FontWeight.bold,
                        fontSize: 22)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _initializeGameData();
                },
                child: const Text("CONTINUAR",
                    style: TextStyle(color: AppTheme.accentGold)),
              ),
            ],
          ),
        );
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
        _overlayTitle = currentLives <= 0 ? "GAME OVER" : "INTENTA DE NUEVO";
        _overlayMessage = reason ?? "Respuesta incorrecta";
        _canRetry = currentLives > 0;
        _showShopButton = true;
      });
    }
  }

  void _resetGame() {
    setState(() {
      _isGameOver = false;
      _showOverlay = false;
      _moviesGuessed = 0;
      _usedEmojiSets.clear();
      _secondsRemaining = _gameDurationSeconds;
    });
    _initializeGameData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.accentGold));
    }

    final minutes = (_secondsRemaining / 60).floor().toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    final isLowTime = _secondsRemaining <= 5;

    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.all(MediaQuery.of(context).size.height < 700 ? 12.0 : 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(12),
                margin: EdgeInsets.only(
                    bottom: MediaQuery.of(context).size.height < 700 ? 5 : 15),
                decoration: BoxDecoration(
                  color: isLowTime
                      ? AppTheme.dangerRed.withOpacity(0.2)
                      : Colors.black26,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                      color: isLowTime ? AppTheme.dangerRed : Colors.white10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.timer, 
                            color: isLowTime ? AppTheme.dangerRed : AppTheme.accentGold),
                        const SizedBox(width: 8),
                        Text("$minutes:$seconds",
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text("$_moviesGuessed/$_targetMovies",
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

              const Text("ADIVINA LA PELÍCULA",
                  style: TextStyle(
                      color: Colors.white60,
                      fontSize: 14,
                      letterSpacing: 1.2)),

              SizedBox(height: MediaQuery.of(context).size.height < 700 ? 2 : 10),

              Center(
                child: Container(
                  height: MediaQuery.of(context).size.height < 700 ? 100 : 160,
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _displayEmojis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 64,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 5))
                        ]
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Options Grid
              AnimatedBuilder(
                animation: _shakeController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_shakeAnimation.value * (_shakeController.status == AnimationStatus.forward ? 1 : -1), 0),
                    child: child,
                  );
                },
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.5,
                  children: _options.map((option) {
                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C3E50),
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: const BorderSide(color: Colors.white10),
                        ),
                      ),
                      onPressed: () => _checkAnswer(option),
                      child: AutoSizeText(
                        option,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        minFontSize: 10,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                ),
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
                      MaterialPageRoute(builder: (_) => const MallScreen()),
                    );
                    if (!context.mounted) return;
                    final player = Provider.of<PlayerProvider>(context, listen: false).currentPlayer;
                    if ((player?.lives ?? 0) > 0) _resetGame();
                  }
                : null,
            onExit: () => Navigator.pop(context),
          ),
      ],
    );
  }
}
