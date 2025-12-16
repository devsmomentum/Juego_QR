import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/clue.dart';
import '../../../auth/providers/player_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/game_provider.dart';

// --- WRAPPER ---
class FindDifferenceWrapper extends StatelessWidget {
  final Clue clue;
  final VoidCallback onFinish;
  const FindDifferenceWrapper({super.key, required this.clue, required this.onFinish});

  @override
  Widget build(BuildContext context) {
    return FindDifferenceMinigame(
      clue: clue,
      onSuccess: () {
        Provider.of<GameProvider>(context, listen: false).completeCurrentClue("WIN", clueId: clue.id);
        onFinish(); // Notificar salida legal
      },
    );
  }
}

// --- MINIGAME LOGIC ---

class FindDifferenceMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const FindDifferenceMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<FindDifferenceMinigame> createState() => _FindDifferenceMinigameState();
}

class _FindDifferenceMinigameState extends State<FindDifferenceMinigame> {
  // Configuración del juego
  final int _numberOfDistractors = 40; // Cantidad de iconos de fondo
  final Random _random = Random();
  
  // Estado del nivel
  late IconData _targetIcon;
  late Color _targetColor;
  late Offset _targetPosition;
  late bool _targetInTopImage; // Si true, el objetivo está arriba. Si false, abajo.
  
  // Distractores (comunes a ambas imágenes)
  late List<_DistractorItem> _distractors;
  
  // Timer & Intentos Locales
  Timer? _timer;
  int _secondsRemaining = 60;
  bool _isGameOver = false;
  int _localAttempts = 3; // Intentos dentro del nivel antes de perder vida real

  @override
  void initState() {
    super.initState();
    _startNewLevel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startNewLevel() {
    setState(() {
      _secondsRemaining = 60;
      _isGameOver = false;
      _localAttempts = 3; // Reiniciar intentos locales
      
      // 1. Definir objetivo
      _targetIcon = _getRandomIcon();
      _targetColor = AppTheme.accentGold; 
      _targetInTopImage = _random.nextBool(); // Aleatorio en cuál aparece

      // 2. Generar posiciones
      // Generamos distractores fijos para ambas imágenes
      _distractors = List.generate(_numberOfDistractors, (index) {
        return _DistractorItem(
          icon: _getRandomIcon(),
          color: Colors.white.withOpacity(0.3 + _random.nextDouble() * 0.4),
          position: Offset(_random.nextDouble(), _random.nextDouble()),
          size: 20 + _random.nextDouble() * 20,
          rotation: _random.nextDouble() * 2 * pi,
        );
      });

      // Posición del objetivo (asegurar que no esté muy cerca de bordes)
      _targetPosition = Offset(
        0.1 + _random.nextDouble() * 0.8,
        0.1 + _random.nextDouble() * 0.8,
      );
      
      _startTimer();
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _handleGameOver("¡Se acabó el tiempo!", timeOut: true);
        }
      });
    });
  }

  void _handleTap(bool isTopImage, TapUpDetails details, BoxConstraints constraints) {
    if (_isGameOver) return;

    // Verificar si tocó en la imagen correcta (donde está el objetivo)
    if (isTopImage != _targetInTopImage) {
        _handleMistake();
        return;
    }

    // Convertir coordenadas relativas
    final double dx = details.localPosition.dx / constraints.maxWidth;
    final double dy = details.localPosition.dy / constraints.maxHeight;
    final Offset tapPos = Offset(dx, dy);
    
    // Distancia simple
    final double distance = (tapPos - _targetPosition).distance;
    
    // Umbral de acierto (ajustar según dificultad)
    if (distance < 0.1) { // ~10% de la pantalla
      _handleWin();
    } else {
      _handleMistake();
    }
  }

  void _handleWin() {
    _timer?.cancel();
    widget.onSuccess();
  }

  void _handleMistake() {
    setState(() {
      _localAttempts--;
    });

    if (_localAttempts <= 0) {
      // Agotó intentos locales -> Pierde vida GLOBAL
      _loseGlobalLife("¡Agotaste tus intentos!");
    } else {
      // Solo feedback visual local
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("¡Ups! Ese no es. Te quedan $_localAttempts intentos."),
          backgroundColor: AppTheme.warningOrange,
          duration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  // Lógica centralizada para perder vida real en Supabase
  void _loseGlobalLife(String reason, {bool timeOut = false}) {
    _timer?.cancel();
    setState(() => _isGameOver = true);

    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    
    if (playerProvider.currentPlayer != null) {
       gameProvider.loseLife(playerProvider.currentPlayer!.id).then((_) {
          if (!mounted) return;
          
          if (gameProvider.lives <= 0) {
             _handleGameOver("¡Te has quedado sin vidas globales!");
          } else {
             _showTryAgainDialog(reason); 
          }
       });
    }
  }

  void _handleGameOver(String reason, {bool timeOut = false}) {
    _timer?.cancel();
    setState(() => _isGameOver = true);
    
    // Si fue por tiempo, también debe restar vida global
    if (timeOut) {
       _loseGlobalLife(reason);
       return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text("GAME OVER", style: TextStyle(color: AppTheme.dangerRed)),
        content: Text(reason, style: const TextStyle(color: Colors.white)),
        actions: [
          ElevatedButton(
            onPressed: () {
               Navigator.pop(context); // Dialog
               Navigator.pop(context); // Screen
            },
            child: const Text("Salir"),
          )
        ],
      ),
    );
  }

  void _showTryAgainDialog(String reason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text("¡Fallaste!", style: TextStyle(color: AppTheme.dangerRed)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(reason, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 10),
            const Text("Has perdido 1 vida ❤️", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGold),
            onPressed: () {
              Navigator.pop(context); 
              _startNewLevel();
            },
            child: const Text("Reintentar", style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Dialog
              Navigator.pop(context); // Screen
            },
            child: const Text("Salir"),
          ),
        ],
      ),
    );
  }

  IconData _getRandomIcon() {
    final icons = [
      Icons.star, Icons.ac_unit, Icons.access_alarm, Icons.directions_bike,
      Icons.flight, Icons.music_note, Icons.wb_sunny, Icons.pets,
      Icons.language, Icons.cake, Icons.emoji_events, Icons.extension,
      Icons.face, Icons.favorite, Icons.fingerprint, Icons.fire_extinguisher,
      Icons.flash_on, Icons.filter_vintage, Icons.camera_alt, Icons.brush,
    ];
    return icons[_random.nextInt(icons.length)];
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (_secondsRemaining / 60).floor().toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');

    return Column(
      children: [
        // --- HEADER INFORMATIVO ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black45,
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Objetivo
              Row(
                children: [
                   const Text("BUSCA:", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                   const SizedBox(width: 8),
                   Container(
                     padding: const EdgeInsets.all(4),
                     decoration: BoxDecoration(
                       color: AppTheme.accentGold.withOpacity(0.2),
                       shape: BoxShape.circle,
                       border: Border.all(color: AppTheme.accentGold)
                     ),
                     child: Icon(_targetIcon, color: AppTheme.accentGold, size: 24),
                   ),
                ],
              ),
              
              // Tiempo central
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _secondsRemaining < 10 ? AppTheme.dangerRed : Colors.white24)
                ),
                child: Text(
                  "$minutes:$seconds",
                  style: TextStyle(
                    color: _secondsRemaining < 10 ? AppTheme.dangerRed : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace'
                  ),
                ),
              ),

              // Intentos Locales (Visual)
              Row(
                children: List.generate(3, (index) => Icon(
                  index < _localAttempts ? Icons.favorite : Icons.favorite_border,
                  color: _localAttempts <= 1 ? AppTheme.dangerRed : AppTheme.secondaryPink,
                  size: 18,
                )),
              ),
            ],
          ),
        ),

        // --- ÁREA DE JUEGO (SPLIT SCREEN) ---
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                children: [
                  // IMAGEN 1 (ARRIBA)
                  Expanded(
                    child: _buildGamePanel(
                      context: context, 
                      isTop: true, 
                      showTarget: _targetInTopImage
                    ),
                  ),
                  
                  // SEPARADOR VISUAL
                  Container(
                    height: 4,
                    width: double.infinity,
                    color: AppTheme.accentGold,
                    alignment: Alignment.center,
                    child: const Text("VS", style: TextStyle(color: Colors.black, fontSize: 3, fontWeight: FontWeight.bold)), // Decorativo
                  ),

                  // IMAGEN 2 (ABAJO)
                  Expanded(
                    child: _buildGamePanel(
                      context: context, 
                      isTop: false, 
                      showTarget: !_targetInTopImage
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGamePanel({required BuildContext context, required bool isTop, required bool showTarget}) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF1E1E1E), 
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onTapUp: (details) => _handleTap(isTop, details, constraints),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                 Positioned.fill(child: Container(color: const Color(0xFF1E1E1E))),

                 // 1. Distractores (Idénticos en ambos paneles)
                 ..._distractors.map((d) => Positioned(
                   left: d.position.dx * constraints.maxWidth,
                   top: d.position.dy * constraints.maxHeight,
                   child: Transform.rotate(
                     angle: d.rotation,
                     child: Icon(
                       d.icon,
                       color: d.color,
                       size: d.size,
                     ),
                   ),
                 )),

                 // 2. Objetivo (Solo si showTarget == true)
                 if (showTarget)
                   Positioned(
                     left: _targetPosition.dx * constraints.maxWidth,
                     top: _targetPosition.dy * constraints.maxHeight,
                     child: Icon(
                        _targetIcon,
                        color: _targetColor,
                        size: 32,
                      ),
                   ),
                   
                 // Indicador visual de qué panel es
                 Positioned(
                   top: 8,
                   left: 8,
                   child: Container(
                     padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                     color: Colors.black26,
                     child: Text(isTop ? "IMG A" : "IMG B", style: const TextStyle(color: Colors.white24, fontSize: 10)),
                   ),
                 ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DistractorItem {
  final IconData icon;
  final Color color;
  final Offset position;
  final double size;
  final double rotation;

  _DistractorItem({
    required this.icon,
    required this.color,
    required this.position,
    required this.size,
    required this.rotation,
  });
}