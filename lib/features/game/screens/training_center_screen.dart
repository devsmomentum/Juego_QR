import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/player.dart';
import '../../auth/providers/player_provider.dart';
import '../models/clue.dart';
import '../models/scenario.dart';
import '../providers/tutorial_provider.dart';
import 'puzzle_screen.dart';
import 'game_mode_selector_screen.dart';
import '../../../shared/widgets/sabotage_overlay.dart';
import '../../../shared/widgets/animated_cyber_background.dart';
import '../../social/widgets/leaderboard_card.dart';
import '../widgets/effects/freeze_effect.dart';
import '../widgets/effects/shield_badge.dart';

class TrainingCenterScreen extends StatefulWidget {
  const TrainingCenterScreen({super.key});

  @override
  State<TrainingCenterScreen> createState() => _TrainingCenterScreenState();
}

class _TrainingCenterScreenState extends State<TrainingCenterScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  final PageController _scenarioPageController = PageController(viewportFraction: 0.8);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TutorialStateProvider(),
      child: Consumer<TutorialStateProvider>(
        builder: (context, tutorial, child) {
          // Si estamos en la fase de selección, mostramos la vista estilo Escenarios
          if (tutorial.currentStage == TutorialStage.scenarioSelection) {
            return _buildScenarioSelectionView(context, tutorial);
          }

          // De lo contrario, mostramos la simulación del juego
          final playerProvider = Provider.of<PlayerProvider>(context);
          final isDarkMode = playerProvider.isDarkMode;
          final bgImage = isDarkMode 
            ? 'assets/images/fotogrupalnoche.png' 
            : 'assets/images/personajesgrupal.png';

          return Scaffold(
            backgroundColor: const Color(0xFF0D0D0F),
            body: Stack(
              children: [
                // Fondo Dinámico para la sección de juego simulado
                Positioned.fill(
                  child: Image.asset(bgImage, fit: BoxFit.cover, alignment: Alignment.center),
                ),
                Positioned.fill(
                  child: Container(color: Colors.black.withOpacity(0.7)),
                ),
                // Animación de nebulosa eliminada por solicitud


                Positioned.fill(
                  child: _buildSimulatedGame(tutorial),
                ),
                // Botón de Retroceso Simple (transparente)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 15,
                  child: CyberRingButton(
                    size: 40,
                    icon: Icons.arrow_back_ios_new_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                _buildTutorialDirector(tutorial),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildScenarioSelectionView(BuildContext context, TutorialStateProvider tutorial) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    final isDarkMode = playerProvider.isDarkMode;
    final bgImage = isDarkMode 
      ? 'assets/images/fotogrupalnoche.png' 
      : 'assets/images/personajesgrupal.png';

    // Colores dinámicos
    final Color currentText = Colors.white;
    final Color currentTextSec = Colors.white70;
    final Color currentAction = AppTheme.dGoldMain;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. Fondo Dinámico
          Positioned.fill(
            child: Image.asset(bgImage, fit: BoxFit.cover, alignment: Alignment.center),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.6)),
          ),

          // Fondo Animado Cyberpunk eliminado


          SafeArea(
            bottom: false,
            child: Stack(
              children: [
                // Botón de Retroceso en Selección
                Positioned(
                  top: 10,
                  left: 15,
                  child: CyberRingButton(
                    size: 40,
                    icon: Icons.arrow_back_ios_new_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),
                Center(
                  child: Image.asset(
                    'assets/images/logo4.1.png',
                    height: 140,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    "Búsqueda del tesoro ☘️",
                    style: TextStyle(
                      fontSize: 14,
                      color: currentTextSec,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Text(
                    '¡Embárcate en una emocionante búsqueda del tesoro resolviendo pistas intrigantes para descubrir el gran premio oculto!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: currentText,
                        fontSize: 15,
                        height: 1.5,
                        fontStyle: FontStyle.italic),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Center(
                    child: Text(
                      "ELIGE TU AVENTURA",
                      style: TextStyle(
                          color: currentAction,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Orbitron'),
                    ),
                  ),
                ),
                const SizedBox(height: 5),

                // FILTROS (Matching exact colors of ScenariosScreen)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildFilterChip("En Curso", true, AppTheme.dGoldMain, Colors.black),
                      const SizedBox(width: 12),
                      _buildFilterChip("Próximos", false, Colors.blueAccent, Colors.white),
                      const SizedBox(width: 12),
                      _buildFilterChip("Finalizados", false, Colors.grey.shade700, Colors.white),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Carrusel de Escenarios
                Expanded(
                  child: PageView.builder(
                    controller: _scenarioPageController,
                    itemCount: 1,
                    itemBuilder: (context, index) {
                      return _buildScenarioCard(tutorial.mockScenario, () {
                        tutorial.setStage(TutorialStage.welcome);
                      });
                    },
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ],
        ),
      ),
    ],
  ),
);
}

  Widget _buildFilterChip(String label, bool isActive, Color activeColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? activeColor : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isActive ? activeColor : Colors.white24),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? textColor : Colors.white70,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildScenarioCard(Scenario scenario, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 5,
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Imagen Fondo Tarjeta
              Positioned.fill(
                child: Image.asset(
                  scenario.imageUrl, 
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback a imagen de personajes si la del centro comercial falla (necesita reinicio)
                    return Image.asset('assets/images/personajesgrupal.png', fit: BoxFit.cover);
                  },
                ),
              ),
              
              // Gradiente
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
                    ),
                  ),
                ),
              ),

              // Badges Superiores
              Positioned(
                top: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGold.withOpacity(0.9), // Gold color for training
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.model_training, color: Colors.black, size: 18),
                        SizedBox(width: 8),
                        Text(
                          "MODO ENTRENAMIENTO",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Info Inferior
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      scenario.name,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Orbitron'),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      scenario.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        _buildStatBadge(Icons.people, "MÁX: ${scenario.maxPlayers}"),
                        const SizedBox(width: 10),
                        _buildStatBadge(Icons.monetization_on, "BOTÍN: 1000"),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: onTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentGold,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: const Text("JUGAR PRÁCTICA", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSimulatedGame(TutorialStateProvider tutorial) {
    return Stack(
      children: [
        Column(
          children: [
            // Header de Evento Simulado
            _buildSimulatedHeader(tutorial),
            
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                children: [
                  _buildCluesTab(tutorial),
                  _buildInventoryTab(tutorial),
                  _buildRankingTab(tutorial),
                ],
              ),
            ),

            // Bottom Nav Simulado
            _buildSimulatedBottomNav(),
          ],
        ),
        if (tutorial.isFrozen)
          const Positioned.fill(
            child: FreezeEffect(),
          ),
      ],
    );
  }

  Widget _buildSimulatedHeader(TutorialStateProvider tutorial) {
    return Container(
      padding: EdgeInsets.fromLTRB(65, MediaQuery.of(context).padding.top + 12, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF151517),
        border: Border(bottom: BorderSide(color: AppTheme.accentGold.withOpacity(0.3))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("MISIÓN: ENTRENAMIENTO", style: TextStyle(color: AppTheme.accentGold, fontFamily: 'Orbitron', fontSize: 12)),
              Text("Arena de Práctica", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          if (tutorial.hasShield || tutorial.isShieldActive)
             const ShieldBadge(),
        ],
      ),
    );
  }

  Widget _buildCluesTab(TutorialStateProvider tutorial) {
    final clue = tutorial.currentClue;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("ESTACIÓN ACTUAL", style: TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.accentGold.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(clue.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Orbitron')),
                const SizedBox(height: 10),
                Text(clue.hint, style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.4)),
              ],
            ),
          ),
          const Spacer(),
          if (tutorial.currentStage == TutorialStage.clueView || tutorial.currentStage == TutorialStage.scanning)
            Center(
              child: ElevatedButton.icon(
                onPressed: () => tutorial.setStage(TutorialStage.scanning),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text("ESCANEANDO ESTACIÓN..."),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildInventoryTab(TutorialStateProvider tutorial) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("TU EQUIPO", style: TextStyle(color: Colors.white, fontSize: 20, fontFamily: 'Orbitron', letterSpacing: 1.5)),
          const SizedBox(height: 8),
          const Text("Selecciona un módulo táctico para activarlo.", style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 24),
          if (tutorial.hasShield)
            _buildItemCard(
              "Escudo Digital", 
              "Bloquea el próximo sabotaje de un oponente.", 
              "🛡️", 
              Colors.blueAccent, 
              () {
                tutorial.useShield();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Módulo de Defensa Activado!")));
              }
            )
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 40),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, color: Colors.white10, size: 64),
                    SizedBox(height: 16),
                    Text("Inventario vacío", style: TextStyle(color: Colors.white24, fontFamily: 'Orbitron', fontSize: 12)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemCard(String title, String desc, String icon, Color color, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        icon,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          desc,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color.withOpacity(0.5)),
                    ),
                    child: const Text(
                      "USAR",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRankingTab(TutorialStateProvider tutorial) {
    final leaderboard = tutorial.mockLeaderboard;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. Podium Section (Only if 3+ players)
          if (leaderboard.length >= 3)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.only(top: 20, bottom: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: SizedBox(
                   height: 300,
                   child: Row(
                     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                     crossAxisAlignment: CrossAxisAlignment.end,
                     children: [
                       Expanded(
                         child: _buildPodiumPosition(
                           leaderboard[1],
                           2,
                           120,
                           const Color(0xFFC0C0C0),
                         ),
                       ),
                       Expanded(
                         child: _buildPodiumPosition(
                           leaderboard[0],
                           1,
                           160,
                           AppTheme.accentGold,
                         ),
                       ),
                       Expanded(
                         child: _buildPodiumPosition(
                           leaderboard[2],
                           3,
                           100,
                           const Color(0xFFCD7F32),
                         ),
                       ),
                     ],
                   ),
                 ),
              ),
            ),

          // 2. List of Players
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final player = leaderboard[index];
                return LeaderboardCard(
                  player: player,
                  rank: index + 1,
                  isTopThree: index < 3,
                );
              },
              childCount: leaderboard.length,
            ),
          ),

          // Extra padding at bottom
          const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
        ],
      ),
    );
  }

  Widget _buildPodiumPosition(Player player, int position, double barHeight, Color color) {
    String? avatarId = player.avatarId;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Avatar with Laurel Wreath
        SizedBox(
          width: 82,
          height: 82,
          child: CustomPaint(
            painter: _LaurelWreathPainter(color: color),
            child: Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                  border: Border.all(color: color, width: 2.0),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Builder(
                    builder: (context) {
                      if (avatarId != null && avatarId.isNotEmpty) {
                        return Image.asset(
                          'assets/images/avatars/$avatarId.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white70, size: 22),
                        );
                      }
                      return const Icon(Icons.person, color: Colors.white70, size: 22);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Name
        SizedBox(
          width: 80,
          child: Text(
            player.name,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 4),
        // Pedestal bar
        Container(
          width: double.infinity,
          height: barHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withOpacity(0.45), color.withOpacity(0.12)],
            ),
            border: Border(
              top: BorderSide(color: color, width: 2),
              left: BorderSide(color: color.withOpacity(0.3), width: 0.5),
              right: BorderSide(color: color.withOpacity(0.3), width: 0.5),
            ),
          ),
          child: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                '$position',
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  height: 0.8,
                  color: color.withOpacity(0.7),
                  shadows: [Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 4)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSimulatedBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF151517),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
        },
        backgroundColor: Colors.transparent,
        selectedItemColor: AppTheme.accentGold,
        unselectedItemColor: Colors.white38,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: "Pistas"),
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: "Inventario"),
          BottomNavigationBarItem(icon: Icon(Icons.leaderboard), label: "Ranking"),
        ],
      ),
    );
  }

  Widget _buildTutorialDirector(TutorialStateProvider tutorial) {
    String text = "";
    String buttonText = "CONTINUAR";
    VoidCallback? onAction;

    switch (tutorial.currentStage) {
      case TutorialStage.scenarioSelection:
        return const SizedBox.shrink();
      case TutorialStage.welcome:
        text = "¡Bienvenido, Recluta! Esta es una simulación de un evento real. Tu objetivo es encontrar estaciones y ganar XP.";
        onAction = () => tutorial.nextStage();
        break;
      case TutorialStage.clueView:
        text = "Primero, lee el acertijo en la pestaña de 'Pistas'. Te dirá dónde está el nodo de red oculto.";
        buttonText = "ENTENDIDO";
        onAction = null; // Espera a que el usuario interactúe
        break;
      case TutorialStage.scanning:
        text = "¡Has llegado a la estación! Simula el escaneo del código QR para desbloquear el minijuego.";
        buttonText = "JUGAR MINIJUEGO";
        onAction = () => _startTutorialMinigame(tutorial);
        break;
      case TutorialStage.minigame:
        text = "Supera este desafío para avanzar. Los bots están jugando al mismo tiempo, ¡no te demores!";
        onAction = null;
        break;
      case TutorialStage.results:
        text = "¡Excelente! Has ganado XP. Mira cómo has subido en el Ranking contra los otros bots.";
        buttonText = "VER RANKING";
        onAction = () {
          tutorial.simulateProgression();
          _pageController.animateToPage(2, duration: const Duration(milliseconds: 500), curve: Curves.ease);
          tutorial.nextStage();
        };
        break;
      case TutorialStage.powers:
        text = "En el juego real, otros pueden atacarte. Te he dado un 'Escudo' en tu inventario. Protégete.";
        buttonText = "OK, VAMOS";
        onAction = () {
          tutorial.giveShield();
          _pageController.animateToPage(1, duration: const Duration(milliseconds: 500), curve: Curves.ease);
          _simulateEnemyAttack(tutorial);
        };
        break;
      case TutorialStage.finished:
        text = "Estás listo para la arena real. Completa tu entrenamiento y domina la red.";
        buttonText = "FINALIZAR Y JUGAR";
        onAction = () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const GameModeSelectorScreen()));
        break;
    }

    return Positioned(
      bottom: 120,
      left: 20,
      right: 20,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.accentGold.withOpacity(0.6), width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentGold.withOpacity(0.2),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGold,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        "SISTEMA",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: AppTheme.accentGold.withOpacity(0.3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
                if (onAction != null) ...[
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: onAction,
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGold, foregroundColor: Colors.black),
                    child: Text(buttonText),
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startTutorialMinigame(TutorialStateProvider tutorial) {
    tutorial.setStage(TutorialStage.minigame);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PuzzleScreen(
          clue: tutorial.currentClue,
          isPractice: true,
        ),
      ),
    ).then((_) {
      tutorial.setStage(TutorialStage.results);
    });
  }

  void _simulateEnemyAttack(TutorialStateProvider tutorial) {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        final bool wasActive = tutorial.isShieldActive;
        tutorial.simulateIncomingSabotage();
        
        if (wasActive) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.blueAccent,
              content: Text("🛡️ ¡SABOTAJE BLOQUEADO! Tu escudo te protegió del ataque."),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text("⚠️ ¡CONGELADO! No te protegiste a tiempo del ataque del bot."),
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    });
    
    // Auto-terminar después de mostrar poderes (dar tiempo para ver el efecto)
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) tutorial.setStage(TutorialStage.finished);
    });
  }
}

class _LaurelWreathPainter extends CustomPainter {
  final Color color;

  _LaurelWreathPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 2;

    final stemPaint = Paint()
      ..color = color.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final leafPaint = Paint()
      ..color = color.withOpacity(0.85)
      ..style = PaintingStyle.fill;

    final rect = Rect.fromCircle(center: center, radius: radius * 0.68);
    canvas.drawArc(rect, -4 / 14 * 3.14159, 22 / 14 * 3.14159, false, stemPaint);

    final int totalLeaves = 14;
    for (int i = 0; i < totalLeaves; i++) {
      if (i == 0 || i == 1 || i == totalLeaves - 1) continue;
      final angle = (2 * 3.14159 * i / totalLeaves) - 3.14159 / 2;
      _drawReferenceLeaf(canvas, center, radius * 0.68, angle, leafPaint, isOuter: true);
      _drawReferenceLeaf(canvas, center, radius * 0.68, angle, leafPaint, isOuter: false);
    }
  }

  void _drawReferenceLeaf(Canvas canvas, Offset center, double radius, double angle, Paint paint, {required bool isOuter}) {
    final x = center.dx + radius * (isOuter ? 1.0 : 1.0) * (3.14159/3.14159) * (3.14159/3.14159) * (3.14159/3.14159) * (3.14159/3.14159) * (3.14159/3.14159) * (3.14159/3.14159) * (3.14159/3.14159) * (3.14159/3.14159) * (3.14159/3.14159) * (3.14159/3.14159) * (3.14159/3.14159) * (3.14159/3.14159) *  math.cos(angle);
    final y = center.dy + radius * math.sin(angle);
    canvas.save();
    canvas.translate(x, y);
    double rotation = isOuter ? angle + 0.5 : angle + 3.14159 + 0.5;
    canvas.rotate(rotation + 3.14159 / 2);
    final scale = isOuter ? 1.0 : 0.75;
    canvas.scale(scale, scale);
    final path = Path();
    const len = 13.0;
    const width = 5.0;
    path.moveTo(0, 0);
    path.quadraticBezierTo(width * 1.2, -len * 0.45, 0, -len);
    path.quadraticBezierTo(-width * 1.2, -len * 0.45, 0, 0);
    path.close();
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CyberRingButton extends StatelessWidget {
  final double size;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;

  const CyberRingButton({
    super.key,
    required this.size,
    required this.icon,
    this.onPressed,
    this.color = const Color(0xFFFECB00),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1.0,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(0.4),
            border: Border.all(
              color: color.withOpacity(0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 8,
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: size * 0.55,
          ),
        ),
      ),
    );
  }
}
