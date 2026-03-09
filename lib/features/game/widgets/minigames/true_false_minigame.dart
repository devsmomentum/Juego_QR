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

class TrueFalseMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const TrueFalseMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<TrueFalseMinigame> createState() => _TrueFalseMinigameState();
}

class TFStatement {
  final String text;
  final bool isTrue;
  final String
      correction; // Shown if false and user gets it wrong (educational)

  TFStatement(this.text, this.isTrue, {this.correction = ""});
}

class _TrueFalseMinigameState extends State<TrueFalseMinigame> {
  // Config
  static const int _targetScore =
      5; // Streak or total? Let's say total for now.
  static const int _gameDurationSeconds = 45; // Faster pace

  // Data
  List<TFStatement> _allStatements =
      []; // Empty initially, loaded from Supabase

  // State
  int _score = 0;
  int _secondsRemaining = _gameDurationSeconds;
  bool _isGameOver = false;

  List<TFStatement> _shuffledStatements = [];
  int _currentStatementIndex = 0;
  late TFStatement _currentStatement;

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

    // Listado local robusto de preguntas para asegurar variedad inmediata
    final List<TFStatement> localStatements = [
      // CIENCIA Y NATURALEZA
      TFStatement("El Sol es una estrella.", true),
      TFStatement("La Gran Muralla China es visible desde la Luna.", false, correction: "Es un mito; no se ve a simple vista."),
      TFStatement("El agua hierve a 90°C a nivel del mar.", false, correction: "Hierve a 100°C."),
      TFStatement("Los delfines son mamíferos.", true),
      TFStatement("El cuerpo humano adulto tiene 206 huesos.", true),
      TFStatement("El sonido viaja más rápido que la luz.", false, correction: "La luz es 1 millón de veces más rápida."),
      TFStatement("Los pingüinos pueden volar.", false, correction: "Son aves nadadoras, no voladoras."),
      TFStatement("El elemento químico del oro es Au.", true),
      TFStatement("Júpiter es el planeta más grande del Sistema Solar.", true),
      TFStatement("Las nubes están hechas de algodón.", false, correction: "Están hechas de vapor y gotas de agua."),
      TFStatement("El diamante es el material natural más duro.", true),
      TFStatement("La ballena azul es el animal más grande del mundo.", true),
      TFStatement("Los gatos siempre caen de pie.", false, correction: "Tienen gran equilibrio, pero no siempre."),
      TFStatement("La atmósfera tiene más oxígeno que nitrógeno.", false, correction: "Tiene un 78% de nitrógeno."),
      TFStatement("Venus es el planeta más caliente del Sistema Solar.", true),

      // GEOGRAFÍA Y PAÍSES
      TFStatement("París es la capital de Italia.", false, correction: "Es la capital de Francia."),
      TFStatement("La Amazonía es la selva más grande del mundo.", true),
      TFStatement("Viena es la capital de Austria.", true),
      TFStatement("El Everest es la montaña más alta del mundo.", true),
      TFStatement("La capital de Estados Unidos es Nueva York.", false, correction: "Es Washington D.C."),
      TFStatement("Chile es el país más largo y angosto del mundo.", true),
      TFStatement("El desierto del Sahara es el más caluroso.", true),
      TFStatement("Rusia es el país más grande por territorio.", true),
      TFStatement("El río Amazonas es el más caudaloso del mundo.", true),
      TFStatement("Australia es una isla y un continente.", true),
      TFStatement("La capital de Japón es Kioto.", false, correction: "Es Tokio."),
      TFStatement("España limita al sur con Portugal.", false, correction: "Limita al oeste con Portugal."),
      TFStatement("El Vaticano es el país más pequeño del mundo.", true),
      TFStatement("Islandia es un país tropical.", false, correction: "Está cerca del círculo polar ártico."),
      TFStatement("El canal de Panamá une el Atlántico con el Pacífico.", true),

      // HISTORIA Y CULTURA
      TFStatement("Pitágoras fue un famoso pintor.", false, correction: "Fue un matemático griego."),
      TFStatement("Cristóbal Colón llegó a América en 1492.", true),
      TFStatement("La Mona Lisa fue pintada por Van Gogh.", false, correction: "Fue pintada por Leonardo da Vinci."),
      TFStatement("El abecedario español tiene 27 letras.", true),
      TFStatement("Batman pertenece a Marvel.", false, correction: "Pertenece a DC Comics."),
      TFStatement("Los vikingos usaban cascos con cuernos.", false, correction: "Es un mito de óperas y películas."),
      TFStatement("La Revolución Francesa comenzó en 1789.", true),
      TFStatement("El Titanic se hundió en su primer viaje.", true),
      TFStatement("Albert Einstein recibió el Nobel por la relatividad.", false, correction: "Lo recibió por el efecto fotoeléctrico."),
      TFStatement("Julio César fue un emperador romano.", false, correction: "Fue dictador; el primer emperador fue Augusto."),
      TFStatement("La Segunda Guerra Mundial terminó en 1945.", true),
      TFStatement("El Quijote fue escrito por Cervantes.", true),
      TFStatement("Los números romanos usan la letra 'K'.", false, correction: "No existe la K en números romanos."),
      TFStatement("El muro de Berlín cayó en 1989.", true),
      TFStatement("Beethoven era sordo cuando compuso su novena sinfonía.", true),

      // ENTRETENIMIENTO Y GENERAL
      TFStatement("Spider-Man fue creado por Stan Lee.", true),
      TFStatement("El símbolo químico del agua es H2O.", true),
      TFStatement("Mario Bros es un dentista.", false, correction: "Es un fontanero (plomero)."),
      TFStatement("La estatua de la Libertad fue un regalo de Francia.", true),
      TFStatement("Un año bisiesto tiene 366 días.", true),
      TFStatement("El ajedrez se inventó en Rusia.", false, correction: "Se cree que se originó en la India."),
      TFStatement("La miel nunca caduca.", true),
      TFStatement("Los pulpos tienen tres corazones.", true),
      TFStatement("El idioma más hablado del mundo es el inglés.", false, correction: "Es el chino mandarín (nativos)."),
      TFStatement("Facebook fue creado por Mark Zuckerberg.", true),
      TFStatement("Las cebras son blancas con rayas negras.", true, correction: "Su piel es negra bajo el pelo."),
      TFStatement("El Monopoly se inventó durante la Gran Depresión.", true),
      TFStatement("Los mosquitos tienen dientes.", true, correction: "Tienen 47 pequeñas cerdas dentadas."),
      TFStatement("La bandera de Japón tiene un sol rojo.", true),
      TFStatement("El fútbol se juega con 12 jugadores por equipo.", false, correction: "Se juega con 11 jugadores."),
    ];

    // Intentar cargar datos de la base de datos
    if (gameProvider.minigameTFStatements.isEmpty) {
      await gameProvider.loadMinigameData();
    }

    if (mounted) {
      setState(() {
        final dbStatements = gameProvider.minigameTFStatements
            .map((e) => TFStatement(
                e['statement'].toString(), e['isTrue'] as bool,
                correction: e['correction']?.toString() ?? ""))
            .toList();

        // Combinar local + DB y eliminar duplicados de texto simples
        final combined = [...localStatements, ...dbStatements];
        final seen = <String>{};
        _allStatements = combined.where((s) => seen.add(s.text)).toList();

        if (_allStatements.isNotEmpty) {
          _startGame();
        } else {
          _allStatements = localStatements;
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
    _shuffledStatements = List<TFStatement>.from(_allStatements)..shuffle(_random);
    _currentStatementIndex = 0;
    
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
          _endGame(win: false, reason: "Se acabó el tiempo.");
        }
      });
    });
  }

  void _generateRound() {
    if (_shuffledStatements.isEmpty) return;
    
    if (_currentStatementIndex >= _shuffledStatements.length) {
      _shuffledStatements.shuffle(_random);
      _currentStatementIndex = 0;
    }
    
    _currentStatement = _shuffledStatements[_currentStatementIndex];
    _currentStatementIndex++;
  }

  void _handleSelection(bool selectedTrue) {
    if (_isGameOver) return;

    // [FIX] Prevent interaction if offline
    final connectivity =
        Provider.of<ConnectivityProvider>(context, listen: false);
    if (!connectivity.isOnline) return;

    if (selectedTrue == _currentStatement.isTrue) {
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
            reason: "Incorrecto. ${_currentStatement.correction}",
            lives: newLives);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("¡INCORRECTO! -1 Vida"),
              backgroundColor: AppTheme.dangerRed,
              duration: Duration(milliseconds: 1000)),
        );
        _startTimer();
        // Maybe new round?
        _generateRound();
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: _allStatements.isEmpty ||
                  (_allStatements.length == 1 &&
                      _allStatements.first.text.contains("Error"))
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppTheme.accentGold),
                      SizedBox(height: 10),
                      Text("Cargando desafío...",
                          style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Título con Glow Cibernético
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.accentGold.withOpacity(0.5)),
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
                        "DESAFÍO: VERDADERO O FALSO",
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
                            color: _secondsRemaining < 10 ? AppTheme.dangerRed : Colors.white,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _buildStatItem(
                            icon: Icons.bolt_rounded,
                            label: "META",
                            value: "$_score / $_targetScore",
                            color: AppTheme.successGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    
                    // Statement Card (Panel principal)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
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
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.accentGold.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.psychology_outlined, color: AppTheme.accentGold, size: 32),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _currentStatement.text,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 50),
                    
                    // Buttons de Acción
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            label: "FALSO",
                            color: AppTheme.dangerRed,
                            icon: Icons.close_rounded,
                            onPressed: () => _handleSelection(false),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _buildActionButton(
                            label: "VERDAD",
                            color: AppTheme.successGreen,
                            icon: Icons.check_rounded,
                            onPressed: () => _handleSelection(true),
                            darkText: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
        
        // Overlay de Game Over
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

  Widget _buildActionButton({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onPressed,
    bool darkText = false,
  }) {
    return Container(
      height: 68,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.25),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: darkText ? Colors.black : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
