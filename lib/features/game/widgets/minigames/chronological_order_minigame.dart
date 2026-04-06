import 'dart:async';
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

class ChronologicalOrderMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const ChronologicalOrderMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<ChronologicalOrderMinigame> createState() =>
      _ChronologicalOrderMinigameState();
}

class HistoricalEvent {
  final String eventName;
  final int year;
  final String description;

  HistoricalEvent(this.eventName, this.year, this.description);

  factory HistoricalEvent.fromMap(Map<String, dynamic> map) {
    return HistoricalEvent(
      map['eventName'] ?? map['event_name'] ?? 'Evento Desconocido',
      map['year'] ?? 0,
      map['description'] ?? '',
    );
  }

  String get yearLabel => year < 0 ? '${year.abs()} a.C.' : '$year d.C.';
}

class _ChronologicalOrderMinigameState
    extends State<ChronologicalOrderMinigame> {
  // Config
  static const int _gameDurationSeconds = 60;

  // State
  int _secondsRemaining = _gameDurationSeconds;
  bool _isGameOver = false;
  List<HistoricalEvent> _events = [];
  int? _selectedIndex; // Track selected item for swap

  // Overlay
  bool _showOverlay = false;
  String _overlayTitle = "";
  String _overlayMessage = "";
  bool _canRetry = false;
  bool _showShopButton = false;

  Timer? _gameTimer;

  // Rich Fallback Repository
  final List<HistoricalEvent> _fallbackEvents = [
    HistoricalEvent("Invención de la Rueda", -3500, "Mesopotamia"),
    HistoricalEvent("Pirámides de Giza", -2560, "Egipto"),
    HistoricalEvent("Caída de Constantinopla", 1453, "Fin del Imperio Bizantino"),
    HistoricalEvent("Descubrimiento de América", 1492, "Cristóbal Colón"),
    HistoricalEvent("Invención de la Imprenta", 1440, "Johannes Gutenberg"),
    HistoricalEvent("Revolución Francesa", 1789, "París"),
    HistoricalEvent("Primer Vuelo Wright", 1903, "Kitty Hawk"),
    HistoricalEvent("Llegada a la Luna", 1969, "Apolo 11"),
    HistoricalEvent("Primer iPhone", 2007, "Apple"),
    HistoricalEvent("Caída Muro de Berlín", 1989, "Alemania"),
    HistoricalEvent("Hundimiento del Titanic", 1912, "Atlántico Norte"),
    HistoricalEvent("Fin 2da Guerra Mundial", 1945, "Rendición de Japón"),
    HistoricalEvent("Transplante Corazón", 1967, "Christian Barnard"),
    HistoricalEvent("Windows 95", 1995, "Microsoft"),
    HistoricalEvent("Ataques 11 de Septiembre", 2001, "Torres Gemelas"),
    HistoricalEvent("Guerra Civil EE.UU.", 1861, "Conflicto Norte-Sur"),
    HistoricalEvent("Publicación Evolución", 1859, "Charles Darwin"),
    HistoricalEvent("Invención Teléfono", 1876, "Graham Bell"),
    HistoricalEvent("Bombilla Eléctrica", 1879, "Thomas Edison"),
    HistoricalEvent("Sputnik 1", 1957, "Era Espacial"),
  ];

  @override
  void initState() {
    super.initState();
    _loadDataAndStart();
  }

  Future<void> _loadDataAndStart() async {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    
    // Fetch data if not loaded
    if (gameProvider.minigameChronologicalEvents.isEmpty) {
      await gameProvider.loadMinigameData();
    }
    
    if (mounted) {
      _startGame();
    }
  }

  void _startGame() {
    _secondsRemaining = _gameDurationSeconds;
    _isGameOver = false;
    _showOverlay = false;
    _selectedIndex = null;
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
        final gameProvider = Provider.of<GameProvider>(context, listen: false);
        final connectivity =
            Provider.of<ConnectivityProvider>(context, listen: false);
        if (!connectivity.isOnline || gameProvider.isPaused) return;

        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _endGame(win: false, reason: "Se acabó el tiempo.");
        }
      });
    });
  }

  void _generateRound() {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    List<HistoricalEvent> source = [];

    if (gameProvider.minigameChronologicalEvents.isNotEmpty) {
      source = gameProvider.minigameChronologicalEvents
          .map((m) => HistoricalEvent.fromMap(m))
          .toList();
    } else {
      source = List.from(_fallbackEvents);
    }

    source.shuffle();
    _events = source.take(4).toList();
    // Shuffle again for the user
    _events.shuffle();
    setState(() {});
  }

  void _handleItemTap(int index) {
    if (_isGameOver) return;

    final connectivity =
        Provider.of<ConnectivityProvider>(context, listen: false);
    if (!connectivity.isOnline) return;

    setState(() {
      if (_selectedIndex == null) {
        _selectedIndex = index;
      } else if (_selectedIndex == index) {
        _selectedIndex = null;
      } else {
        final temp = _events[_selectedIndex!];
        _events[_selectedIndex!] = _events[index];
        _events[index] = temp;
        _selectedIndex = null;
      }
    });
  }

  void _checkOrder() {
    if (_isGameOver) return;

    // Check sorting
    bool correct = true;
    for (int i = 0; i < _events.length - 1; i++) {
      if (_events[i].year > _events[i + 1].year) {
        correct = false;
        break;
      }
    }

    if (correct) {
      _endGame(win: true);
    } else {
      _handleMistake();
    }
  }

  Future<void> _handleMistake() async {
    _gameTimer?.cancel();
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    // Create correction string
    final sortedCorrectly = List<HistoricalEvent>.from(_events)
      ..sort((a, b) => a.year.compareTo(b.year));
    final correctionText = sortedCorrectly
        .map((e) => "${e.eventName} (${e.yearLabel})")
        .join("\n↓\n");

    if (playerProvider.currentPlayer != null) {
      final newLives = await MinigameLogicHelper.executeLoseLife(context);
      if (!mounted) return;

      if (newLives <= 0) {
        _endGame(
            win: false,
            reason: "Orden incorrecto.\n\n$correctionText",
            lives: newLives);
      } else {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.surfaceDark,
            title: const Text("ORDEN INCORRECTO",
                style: TextStyle(color: AppTheme.dangerRed)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("El orden correcto era:",
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 12),
                Text(correctionText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _generateRound();
                  _startTimer();
                },
                child: const Text("REINTENTAR",
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
        _overlayMessage = reason ?? "Orden incorrecto";
        _canRetry = currentLives > 0;
        _showShopButton = true;
      });
    }
  }

  void _resetGame() {
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
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Timer & Header
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                  const Text("ORDENA LOS EVENTOS",
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          letterSpacing: 1.2)),
                ],
              ),
            ),

            const SizedBox(height: 5),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                "Selecciona dos tarjetas para intercambiar su posición.\nEl más antiguo debe ir arriba.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ),

            const SizedBox(height: 15),

            // Events List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _events.length,
              itemBuilder: (context, index) {
                  final isSelected = _selectedIndex == index;
                  final event = _events[index];

                  return GestureDetector(
                    onTap: () => _handleItemTap(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(colors: [
                                AppTheme.primaryPurple,
                                AppTheme.primaryPurple.withOpacity(0.7)
                              ])
                            : const LinearGradient(colors: [
                                Color(0xFF2C3E50),
                                Color(0xFF1A252F)
                              ]),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                    color: AppTheme.accentGold.withOpacity(0.3),
                                    blurRadius: 10,
                                    spreadRadius: 2)
                              ]
                            : [],
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.accentGold
                              : Colors.white10,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              isSelected ? Colors.white24 : Colors.cyan[700],
                          child: Text("${index + 1}",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ),
                        title: AutoSizeText(
                          event.eventName,
                          maxLines: 1,
                          minFontSize: 12,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w500),
                        ),
                        subtitle: event.description.isNotEmpty
                            ? AutoSizeText(
                                event.description,
                                maxLines: 2,
                                minFontSize: 10,
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 12))
                            : null,
                        trailing: Icon(
                          Icons.swap_vert,
                          color: isSelected ? AppTheme.accentGold : Colors.white24,
                        ),
                      ),
                    ),
                  );
                },
              ),

            // Action Button
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 10, 30, 30),
              child: Container(
                width: double.infinity,
                height: 55,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentGold.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentGold,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: _checkOrder,
                  child: const Text("VERIFICAR ORDEN",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1)),
                ),
              ),
            ),
          ],
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
