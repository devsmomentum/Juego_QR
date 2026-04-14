import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:auto_size_text/auto_size_text.dart';
import '../../models/clue.dart';
import '../../providers/game_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../../../core/theme/app_theme.dart';
import 'game_over_overlay.dart';
import '../../utils/minigame_logic_helper.dart';
import '../../../auth/providers/player_provider.dart';
import '../../../mall/screens/mall_screen.dart';
import '../../utils/country_helper.dart';

class CapitalCitiesMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const CapitalCitiesMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<CapitalCitiesMinigame> createState() => _CapitalCitiesMinigameState();
}

class _CapitalCitiesMinigameState extends State<CapitalCitiesMinigame> {
  // Config
  static const int _targetScore = 5;
  static const int _gameDurationSeconds = 30; // Reduced to 30s as requested

  // Data
  Map<String, String> _capitals = {}; // Empty initially, loaded from Supabase

  // State
  int _score = 0;
  int _secondsRemaining = _gameDurationSeconds;
  bool _isGameOver = false;

  List<String> _shuffledCountries = [];
  int _currentCountryIndex = 0;
  late String _currentCountry;
  late String _correctAnswer;
  List<String> _options = [];

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
    _loadDataAndStart();
  }

  Future<void> _loadDataAndStart() async {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);

    // Si no hay datos, cargarlos
    if (gameProvider.minigameCapitals.isEmpty) {
      await gameProvider.loadMinigameData();
    }

    if (mounted) {
      setState(() {
        // Convertir lista a mapa
        _capitals = {
          for (var item in gameProvider.minigameCapitals)
            item['flag']!: item['capital']!
        };

        if (_capitals.isNotEmpty) {
          _startGame();
        } else {
          // Fallback logic if Supabase is empty or fails
          _capitals = {
            "España": "Madrid",
            "Francia": "París",
            "Italia": "Roma",
            "Alemania": "Berlín",
            "Reino Unido": "Londres",
            "Portugal": "Lisboa",
            "EEUU": "Washington D.C.",
            "Canadá": "Ottawa",
            "México": "Ciudad de México",
            "Brasil": "Brasilia",
            "Argentina": "Buenos Aires",
            "Chile": "Santiago",
            "Colombia": "Bogotá",
            "Venezuela": "Caracas",
            "Perú": "Lima",
            "Japón": "Tokio",
            "China": "Pekín",
            "Corea del Sur": "Seúl",
            "Australia": "Camberra",
            "Rusia": "Moscú",
            "Egipto": "El Cairo",
            "Sudáfrica": "Pretoria",
            "India": "Nueva Delhi",
            "Turquía": "Ankara",
          };
          _startGame();
        }
      });
    }
  }

  void _startGame() {
    _score = 0;
    _secondsRemaining = _gameDurationSeconds;
    _isGameOver = false;
    _showOverlay = false;
    
    // Prepare shuffled pool to avoid repeats
    _shuffledCountries = _capitals.keys.toList()..shuffle(_random);
    _currentCountryIndex = 0;
    
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
          _endGame(win: false, reason: "Se acabó el tiempo.");
        }
      });
    });
  }

  void _generateRound() {
    if (_shuffledCountries.isEmpty) return;
    
    // Pick next country from shuffled pool
    if (_currentCountryIndex >= _shuffledCountries.length) {
      _shuffledCountries.shuffle(_random);
      _currentCountryIndex = 0;
    }
    
    _currentCountry = _shuffledCountries[_currentCountryIndex];
    _correctAnswer = _capitals[_currentCountry]!;
    _currentCountryIndex++;

    // Generate 3 distractors (Total 4 options) for better mobile visibility
    Set<String> optionsSet = {_correctAnswer};
    List<String> allCapitals = _capitals.values.toList();

    while (optionsSet.length < 4 && optionsSet.length < allCapitals.length) {
      String distractor = allCapitals[_random.nextInt(allCapitals.length)];
      optionsSet.add(distractor);
    }

    _options = optionsSet.toList();
    _options.shuffle(_random);
  }

  void _handleSelection(String selected) {
    if (_isGameOver) return;

    // [FIX] Prevent interaction if offline
    final connectivity =
        Provider.of<ConnectivityProvider>(context, listen: false);
    if (!connectivity.isOnline) return;

    if (selected == _correctAnswer) {
      setState(() {
        _score++;
        if (_score >= _targetScore) {
          _endGame(win: true);
        } else {
          _generateRound();
        }
      });
    } else {
      _handleMistake();
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
            reason: "Capital incorrecta.\n\nLa respuesta era: $_correctAnswer",
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
                const Text("La capital de esta bandera:",
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 10),
                Text(CountryHelper.getEmoji(_currentCountry) ?? "🏳️",
                    style: const TextStyle(fontSize: 60)),
                const SizedBox(height: 10),
                const Text("es:", style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 10),
                Text(_correctAnswer,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppTheme.accentGold,
                        fontWeight: FontWeight.bold,
                        fontSize: 24)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _generateRound();
                  _startTimer();
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
        _overlayMessage = reason ?? "Capital incorrecta";
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
          padding: const EdgeInsets.all(16.0),
          child: _capitals.isEmpty
              ? const Center(
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      CircularProgressIndicator(color: AppTheme.accentGold),
                      SizedBox(height: 10),
                      Text("Cargando datos...",
                          style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Header Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: EdgeInsets.only(
                          bottom: MediaQuery.of(context).size.height < 700 ? 5 : 15),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.timer, color: AppTheme.accentGold),
                              const SizedBox(width: 8),
                              Text("$_secondsRemaining s",
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
                            child: Text("$_score/$_targetScore",
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),

                    const Text("¿CUÁL ES LA CAPITAL DE ESTA BANDERA?",
                        style: TextStyle(
                            color: Colors.white60,
                            fontSize: 14,
                            letterSpacing: 1.2)),
                    
                    SizedBox(height: MediaQuery.of(context).size.height < 700 ? 5 : 10),
                    
                    Center(
                      child: Container(
                        height: MediaQuery.of(context).size.height < 700 ? 120 : 180,
                        alignment: Alignment.center,
                        child: Builder(
                          builder: (context) {
                            final emoji = CountryHelper.getEmoji(_currentCountry);
                            if (emoji != null) {
                              return FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  emoji,
                                  style: const TextStyle(
                                      fontSize: 100,
                                  ),
                                ),
                              );
                            } else {
                              // FALLBACK: Nombre del país como último recurso
                              return Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: AppTheme.accentGold.withOpacity(0.5)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.accentGold.withOpacity(0.1),
                                      blurRadius: 20,
                                    ),
                                  ],
                                ),
                                child: AutoSizeText(
                                  _currentCountry.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                  ),
                                  maxLines: 1,
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ),

                    SizedBox(height: MediaQuery.of(context).size.height < 700 ? 10 : 20),
                    
                    // Options Grid
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 2.2,
                      children: _options.map((opt) {
                          return ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2C3E50),
                              foregroundColor: Colors.white,
                              elevation: 4,
                              shadowColor: Colors.black45,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  side: const BorderSide(color: Colors.white10)),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            onPressed: () => _handleSelection(opt),
                            child: AutoSizeText(
                              opt,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              minFontSize: 10,
                            ),
                          );
                        }).toList(),
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
}
