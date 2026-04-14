import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/minigame_logic_helper.dart';
import '../../models/clue.dart';
import '../../../auth/providers/player_provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../../../core/theme/app_theme.dart';
import 'game_over_overlay.dart';
import '../../../mall/screens/mall_screen.dart';

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
  final Random _random = Random();

  // Game Logic
  late List<_DistractorItem> _distractors;
  late IconData _targetIcon;
  late Offset _targetPosition;
  late bool _targetInTopImage;

  // State
  Timer? _timer;
  int _secondsRemaining = 40;
  bool _isGameOver = false;
  int _localAttempts = 3;

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

  @override
  void initState() {
    super.initState();
    _generateGame();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _generateGame() {
    final icons = [
      Icons.star_outline,
      Icons.ac_unit,
      Icons.wb_sunny_outlined,
      Icons.pets_outlined,
      Icons.favorite_outline,
      Icons.flash_on_outlined,
      Icons.filter_vintage_outlined,
      Icons.camera_outlined,
      Icons.brush_outlined,
      Icons.anchor_outlined,
      Icons.eco_outlined,
      Icons.lightbulb_outline,
      Icons.extension_outlined,
    ];

    // Pick 30 random distractors to populate the field
    icons.shuffle();
    _distractors = List.generate(30, (index) {
      return _DistractorItem(
        icon: icons[index % icons.length],
        position: Offset(0.05 + _random.nextDouble() * 0.9,
            0.05 + _random.nextDouble() * 0.9),
        rotation: _random.nextDouble() * pi * 2,
        size: 15.0 + _random.nextDouble() * 10,
      );
    });

    // Pick a random target icon that looks like the distractors
    _targetIcon = icons[_random.nextInt(icons.length)];
    _targetPosition = Offset(
        0.1 + _random.nextDouble() * 0.8, 0.1 + _random.nextDouble() * 0.8);
    _targetInTopImage = _random.nextBool();

    setState(() {});
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      // Check for freeze state
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      if (gameProvider.isPaused) return; // Pause timer

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
        _handleFailure("Tiempo agotado");
      }
    });
  }

  // Feedback State
  Offset? _foundPosition; // Stores the relative position of the found target
  bool _foundInTop = false;

  void _handleTap(bool isTop, TapDownDetails? details, double panelWidth,
      double panelHeight) {
    if (_isGameOver) return;

    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    if (gameProvider.isPaused) return; // Ignore input if frozen

    // [FIX] Prevent interaction if offline
    final connectivity =
        Provider.of<ConnectivityProvider>(context, listen: false);
    if (!connectivity.isOnline) return;

    // 1. Check if we are in the correct panel
    if (isTop == _targetInTopImage) {
      // 2. Exact Hit Detection
      if (details != null) {
        // Re-calculate target position in pixels exactly as rendered
        final double renderWidth = MediaQuery.of(context).size.width - 80;
        final double renderHeight = panelHeight;

        final double targetX = _targetPosition.dx * renderWidth;
        final double targetY = _targetPosition.dy * renderHeight;

        // Icon is size 22 roughly. Center is +11.
        final double centerX = targetX + 11;
        final double centerY = targetY + 11;

        final double tapX = details.localPosition.dx;
        final double tapY = details.localPosition.dy;

        // Euclidean distance
        final double dist =
            sqrt(pow(tapX - centerX, 2) + pow(tapY - centerY, 2));

        // Threshold: 28px radius
        if (dist < 28.0) {
          _winGame(Offset(targetX, targetY), isTop);
          return;
        }
      }
    }

    // If we reached here, it's a miss
    _handleMiss();
  }

  void _winGame(Offset pixelPosition, bool isTop) {
    _timer?.cancel();
    _isGameOver = true;

    // Show visual feedback
    setState(() {
      _foundPosition = pixelPosition;
      _foundInTop = isTop;
    });

    // Wait so user sees the box
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) widget.onSuccess();
    });
  }

  // ... (existing _handleMiss, _handleFailure methods) ...
  void _handleMiss() {
    if (_isGameOver) return;
    setState(() {
      _localAttempts--;
    });
    // Shake or visual feedback could go here
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("¡Fallaste! Sigue buscando."),
        duration: Duration(milliseconds: 500),
        backgroundColor: Colors.redAccent));

    if (_localAttempts <= 0) {
      _handleFailure("Demasiados errores");
    }
  }

  void _handleFailure(String reason) async {
    _timer?.cancel();
    _isGameOver = true;

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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {},
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Column(
              children: [
                // 1. Header: Glass Top Bar
                _buildTopBar(),

                const SizedBox(height: 8),

                // 2. Instructions
                const Text(
                  "ENCUENTRA EL ICONO DIFERENTE",
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                  ),
                ),

                const SizedBox(height: 8),

                // 3. Game Panels
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final panelHeight = constraints.maxHeight * 0.38;
                      return Column(
                        children: [
                          _buildPanelLabel("SENSOR_A"),
                          const SizedBox(height: 4),
                          _buildModernPanel(
                            isTop: true,
                            maxHeight: panelHeight,
                          ),
                          const Spacer(),
                          _buildPanelLabel("SENSOR_B"),
                          const SizedBox(height: 4),
                          _buildModernPanel(
                            isTop: false,
                            maxHeight: panelHeight,
                          ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 10),

                // 4. Lives Indicator
                _buildLivesIndicator(),
              ],
            ),
          ),

          // OVERLAY
          if (_showOverlay)
            GameOverOverlay(
              title: _overlayTitle,
              message: _overlayMessage,
              onRetry: _canRetry
                  ? () {
                      setState(() {
                        _showOverlay = false;
                        _secondsRemaining = 40;
                        _localAttempts = 3;
                        _isGameOver = false;
                        _foundPosition = null;
                        _generateGame();
                        _startTimer();
                      });
                    }
                  : null,
              onGoToShop: _showShopButton
                  ? () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MallScreen()),
                      );
                      if (!context.mounted) return;
                      final player = Provider.of<PlayerProvider>(context, listen: false).currentPlayer;
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
              onExit: () => Navigator.pop(context),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined, color: AppTheme.accentGold, size: 16),
              const SizedBox(width: 8),
              Text(
                "00:$_secondsRemaining",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          Container(height: 20, width: 1, color: Colors.white12),
          const Text(
            "MODO ANOMALÍA",
            style: TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernPanel({required bool isTop, required double maxHeight}) {
    bool hasTarget = isTop == _targetInTopImage;
    bool showHighlight = _foundPosition != null && _foundInTop == isTop;

    return Container(
      height: maxHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0F172A),
            const Color(0xFF1E293B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: (_foundPosition != null && isTop == _targetInTopImage) 
                 ? AppTheme.accentGold 
                 : (isTop ? AppTheme.accentGold.withOpacity(0.5) : Colors.white.withOpacity(0.4)), 
          width: (_foundPosition != null && isTop == _targetInTopImage) ? 3.5 : 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
          // Persistent Subtle Glow to identify sensors
          BoxShadow(
            color: (isTop ? AppTheme.accentGold : Colors.white).withOpacity(0.1),
            blurRadius: 12,
            spreadRadius: 1,
          ),
          if (_foundPosition != null && isTop == _targetInTopImage)
            BoxShadow(
              color: AppTheme.accentGold.withOpacity(0.4),
              blurRadius: 25,
              spreadRadius: 3,
            )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: GestureDetector(
          onTapDown: (details) => _handleTap(isTop, details, MediaQuery.of(context).size.width, maxHeight),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            color: (_foundPosition != null && isTop == _targetInTopImage) 
                   ? AppTheme.accentGold.withOpacity(0.08) 
                   : Colors.transparent,
            child: Stack(
              children: [
                // Distractors
                ..._distractors.map((d) => Positioned(
                      left: d.position.dx * (MediaQuery.of(context).size.width - 80),
                      top: d.position.dy * (maxHeight - 35),
                      child: Opacity(
                        opacity: 0.7,
                        child: Transform.rotate(
                          angle: d.rotation,
                          child: Icon(d.icon, color: Colors.white, size: d.size),
                        ),
                      ),
                    )),

                // Target
                if (hasTarget)
                  Positioned(
                    left: _targetPosition.dx * (MediaQuery.of(context).size.width - 80),
                    top: _targetPosition.dy * (maxHeight - 35),
                    child: Opacity(
                      opacity: 0.7,
                      child: Icon(_targetIcon, color: Colors.white, size: 22),
                    ),
                  ),

                // Found Highlight (Show on both panels with specific states)
                if (_foundPosition != null)
                  Positioned(
                    left: _targetPosition.dx * (MediaQuery.of(context).size.width - 80) - 9,
                    top: _targetPosition.dy * (maxHeight - 35) - 9,
                    child: _buildSuccessBox(
                      isAnomaly: isTop == _targetInTopImage,
                    ),
                  ),

                // Found Message Overlay
                if (_foundPosition != null && isTop == _targetInTopImage)
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGold,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: AppTheme.accentGold.withOpacity(0.5), blurRadius: 30)
                          ],
                        ),
                        child: const Text(
                          "ANOMALÍA DETECTADA",
                          style: TextStyle(
                            color: Color(0xFF150826),
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanelLabel(String label) {
    final bool isA = label.contains("A");
    final Color color = isA ? AppTheme.accentGold : Colors.white60;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isA ? Icons.security_rounded : Icons.radar_rounded, color: color, size: 10),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessBox({required bool isAnomaly}) {
    final Color color = isAnomaly ? AppTheme.accentGold : AppTheme.successGreen;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        border: Border.all(color: color, width: 2.5),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.3), blurRadius: 15)
        ],
      ),
      child: Center(
        child: Icon(
          isAnomaly ? Icons.priority_high_rounded : Icons.check_rounded,
          color: color,
          size: 30,
        ),
      ),
    );
  }

  Widget _buildLivesIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        bool isActive = index < _localAttempts;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: isActive ? 20 : 10,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.accentGold : Colors.white10,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive ? [BoxShadow(color: AppTheme.accentGold.withOpacity(0.4), blurRadius: 8)] : [],
          ),
        );
      }),
    );
  }
}

class _DistractorItem {
  final IconData icon;
  final Offset position;
  final double rotation;
  final double size;

  _DistractorItem({required this.icon, required this.position, required this.rotation, required this.size});
}
