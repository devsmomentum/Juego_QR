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
  List<EmojiMovieProblem> _allMovies = []; // Cache fetched movies
  final List<String> _usedEmojiSets = []; // Track used emojis to avoid repeats

  // Animations
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _movieService = EmojiMovieService(Supabase.instance.client);

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 10.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

    _initializeGameData();
  }

  void _startGameTimer() {
    if (_gameTimer != null && _gameTimer!.isActive) return;
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      if (gameProvider.isFrozen) return;

      // [FIX] Pause timer if connectivity is bad
      final connectivityByProvider =
          Provider.of<ConnectivityProvider>(context, listen: false);
      if (!connectivityByProvider.isOnline) {
        return; // Skip tick
      }

      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _gameTimer?.cancel();
        _loseLife("¡Tiempo agotado!");
      }
    });
  }

  Future<void> _initializeGameData() async {
    setState(() => _isLoading = true);

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
      // Use Admin configured data
      _displayEmojis = question!;
      correctAnswer = answer!.trim();
      _validAnswers = [correctAnswer.toLowerCase()];

      // Even if using custom data, we need fetched data for WRONG options
      if (_allMovies.isEmpty) {
        _allMovies = await _movieService.fetchAllMovies();
      }

      _generateOptions(correctAnswer);
      setState(() => _isLoading = false);
      _startGameTimer();
    } else {
      // Use Random Data (Fetched from DB)
      if (_allMovies.isEmpty) {
        _allMovies = await _movieService.fetchAllMovies();
      }

      if (_allMovies.isNotEmpty) {
        final random = Random();
        
        // Filter out movies already used in this round
        final availableMovies = _allMovies.where((m) => !_usedEmojiSets.contains(m.emojis)).toList();
        
        // If we ran out of movies (unlikely with fallback), clear used history
        final pool = availableMovies.isEmpty ? _allMovies : availableMovies;
        
        final problem = pool[random.nextInt(pool.length)];
        _usedEmojiSets.add(problem.emojis);

        _displayEmojis = problem.emojis;
        if (problem.validAnswers.isEmpty) {
          _displayEmojis = "❓❓";
          correctAnswer = "error";
          _validAnswers = ["error"];
        } else {
          correctAnswer = problem.validAnswers.first;
          _validAnswers = problem.validAnswers;
        }

        _generateOptions(correctAnswer);
      } else {
        // DB is empty or offline, and no local fallback
        _displayEmojis = "⚠️";
        correctAnswer = "Sin conexión";
        _validAnswers = ["error"];
        _options = ["Reintentar", "Sin Datos", "Error DB", "Offline"];
      }

      setState(() => _isLoading = false);
      _startGameTimer();
    }
  }

  void _generateOptions(String correctAnswer) {
    Set<String> optionsSet = {correctAnswer};
    final random = Random();

    // If no movies are loaded, provide default options
    if (_allMovies.isEmpty) {
      _options = [correctAnswer, "Option 1", "Option 2", "Option 3", "Option 4", "Option 5"];
      _options.shuffle();
      return;
    }

    // Use all movies in db as potential distractors
    // Increase to 6 options for higher difficulty
    // Ensure we have enough unique options from _allMovies
    int attempts = 0;
    while (optionsSet.length < 6 && attempts < 100) {
      attempts++;
      final problem = _allMovies[random.nextInt(_allMovies.length)];
      if (problem.validAnswers.isEmpty) continue;

      final candidate = problem.validAnswers.first;

      // Avoid adding the correct answer or very similar answers
      bool isSimilarToCorrect = _validAnswers.any((valid) =>
          candidate.toLowerCase().contains(valid.toLowerCase()) ||
          valid.toLowerCase().contains(candidate.toLowerCase()));

      if (!isSimilarToCorrect && !optionsSet.contains(candidate)) {
        optionsSet.add(candidate);
      }
    }

    // If we still don't have 6 options, fill with generic ones
    while (optionsSet.length < 6) {
      optionsSet.add("Opción ${optionsSet.length + 1}");
    }

    _options = optionsSet.toList();
    _options.shuffle();

    // Capitalize first letter of each option
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

    // [FIX] Prevent interaction if offline
    final connectivity =
        Provider.of<ConnectivityProvider>(context, listen: false);
    if (!connectivity.isOnline) return;

    // Safety check for options like "Sin Datos"
    if (_validAnswers.contains("error") && selectedOption == "Reintentar") {
      _resetGame();
      return;
    }

    final normalizedSelection = selectedOption.toLowerCase();

    // Normalize logic
    bool isCorrect =
        _validAnswers.any((ans) => normalizedSelection == ans.toLowerCase());

    if (isCorrect) {
      _handleSuccess();
    } else {
      _shakeController.forward(from: 0.0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Incorrecto"),
          backgroundColor: AppTheme.dangerRed,
          duration: Duration(milliseconds: 500),
        ),
      );
      _loseLife("Respuesta incorrecta");
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
      // Soft reset for next movie
      _initializeGameData();
    }
  }

  Future<void> _loseLife(String reason) async {
    _gameTimer?.cancel();
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
            title: "¡FALLASTE!", message: reason, retry: true, showShop: false);
      }
    }
  }

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

  void _resetGame() {
    setState(() {
      _isGameOver = false;
      _showOverlay = false;
      _moviesGuessed = 0;
      _usedEmojiSets.clear(); // Clear used history on reset
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
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Timer
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isLowTime
                      ? AppTheme.dangerRed.withOpacity(0.2)
                      : Colors.black45,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color:
                          isLowTime ? AppTheme.dangerRed : AppTheme.accentGold),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.movie, color: AppTheme.accentGold, size: 16),
                    const SizedBox(width: 5),
                    Text("$_moviesGuessed/$_targetMovies",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(width: 15),
                    Icon(Icons.timer,
                        color: isLowTime
                            ? AppTheme.dangerRed
                            : AppTheme.accentGold),
                    const SizedBox(width: 5),
                    Text("$minutes:$seconds",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontFamily: 'monospace')),
                  ],
                ),
              ),

              // Emojis Display
              Text(
                _displayEmojis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 48,
                  letterSpacing: 4,
                ),
              ),

              const SizedBox(height: 40),

              // MULTIPLE CHOICE BUTTONS (2x2 GRID)
              if (_options.length >= 4)
                AnimatedBuilder(
                  animation: _shakeController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(
                          _shakeAnimation.value *
                              (_shakeController.status ==
                                      AnimationStatus.forward
                                  ? 1
                                  : -1),
                          0),
                      child: child,
                    );
                  },
                  child:
                      // Options Grid (Higher difficulty with more options)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 2.5, // Adjusted for more options
                          ),
                          itemCount: _options.length,
                          itemBuilder: (context, index) {
                            final option = _options[index];
                            return ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white10,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  side: const BorderSide(color: Colors.white24),
                                ),
                              ),
                              onPressed: () => _checkAnswer(option),
                              child: Text(
                                option,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          },
                        ),
                      ),
                ),
            ],
          ),
        ),

        // Overlay
        if (_showOverlay)
          GameOverOverlay(
            title: _overlayTitle,
            message: _overlayMessage,
            onRetry: _canRetry ? _resetGame : null,
            onGoToShop: _showShopButton
                ? () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MallScreen()),
                    );
                    if (!context.mounted) return;
                    final player =
                        Provider.of<PlayerProvider>(context, listen: false)
                            .currentPlayer;
                    if ((player?.lives ?? 0) > 0) {
                      _resetGame();
                      setState(() {
                        _showOverlay = false;
                      });
                    }
                  }
                : null,
            onExit: () => Navigator.pop(context),
          ),
      ],
    );
  }

  Widget _buildOptionButton(String text) {
    return SizedBox(
      height: 85, // Fixed height for consistency
      child: ElevatedButton(
        onPressed: () => _checkAnswer(text),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black54,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          side: const BorderSide(color: AppTheme.accentGold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 4,
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15, // Slightly smaller to fit
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
