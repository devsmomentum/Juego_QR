import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:map_hunter/features/game/providers/game_provider.dart';
import 'package:map_hunter/features/auth/providers/player_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/animated_cyber_background.dart';
import '../../../shared/widgets/exit_protection_wrapper.dart';
import '../widgets/race_track_widget.dart';
import '../widgets/sponsor_banner.dart'; // NEW
import '../services/sponsor_rotation_manager.dart';
import '../../admin/models/sponsor.dart';
import '../providers/spectator_feed_provider.dart';
import 'scenarios_screen.dart';

import 'winner_celebration_screen.dart';

class WaitingRoomScreen extends StatefulWidget {
  final String eventId;

  const WaitingRoomScreen({super.key, required this.eventId});

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  // Store reference to avoid unsafe lookup in dispose
  GameProvider? _gameProviderRef;
  bool _isNavigating = false; // Guard: evita doble-navegación

  Timer? _pollingTimer;
  Timer? _bannerTimer;
  final SponsorRotationManager _sponsorRotation = SponsorRotationManager();
  Sponsor? _currentSponsor;
  List<Sponsor> _bannerPool = [];
  int _bannerIndex = 0;
  final PageController _bannerController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initWaitingRoom();
    });
    _initBannerRotation();
  }

  Future<void> _initBannerRotation() async {
    await _sponsorRotation.loadPool(widget.eventId);
    if (!mounted) return;
    _bannerPool = _sponsorRotation.pool.toList();
    _bannerIndex = 0;
    if (_bannerPool.isNotEmpty) {
      setState(() => _currentSponsor = _bannerPool.first);
    }
    if (_bannerPool.length <= 1) return;
    _bannerTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (mounted) _setNextSponsor();
    });
  }

  void _setNextSponsor() {
    if (_bannerPool.isEmpty) {
      if (mounted && _currentSponsor != null) {
        setState(() => _currentSponsor = null);
      }
      return;
    }

    _bannerIndex = (_bannerIndex + 1) % _bannerPool.length;
    final next = _bannerPool[_bannerIndex];
    if (next.id != _currentSponsor?.id) {
      setState(() => _currentSponsor = next);
      _bannerController.animateToPage(
        _bannerIndex,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _initWaitingRoom() async {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    _gameProviderRef = gameProvider;

    // Asegurar que las pistas, eventId y leaderboard estén cargados.
    // Pueden estar vacíos después de una salida voluntaria + reingreso
    // donde resetState limpió todo, o si HomeScreen.dispose ejecutó
    // resetState en un post-frame callback posterior.
    final needsFetch = gameProvider.totalClues == 0 ||
        gameProvider.currentEventId != widget.eventId ||
        gameProvider.leaderboard.isEmpty;

    if (needsFetch) {
      final playerProvider =
          Provider.of<PlayerProvider>(context, listen: false);
      await gameProvider.fetchClues(
        eventId: widget.eventId,
        userId: playerProvider.currentPlayer?.userId,
      );
    }
    if (!mounted) return;

    // Ensure we are fetching updates (requiere _currentEventId válido)
    gameProvider.startLeaderboardUpdates();

    // Listen for global completion
    gameProvider.addListener(_onGameProviderChange);

    // Check immediately
    gameProvider.checkRaceStatus();

    // 🟢 START POLLING: Check race status every 5 seconds
    // This acts as a fallback if Realtime fails
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        debugPrint("⏳ WaitingRoom: Polling race status...");
        gameProvider.checkRaceStatus();
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _gameProviderRef?.removeListener(_onGameProviderChange);
    _gameProviderRef?.stopLeaderboardUpdates();
    super.dispose();
  }

  void _onGameProviderChange() {
    if (!mounted) return;
    _checkIfRaceCompleted();
  }

  void _checkIfRaceCompleted() {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    if (gameProvider.isRaceCompleted) {
      _navigateToWinnerScreen();
    }
  }

  void _navigateToWinnerScreen() {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;
    _pollingTimer?.cancel();

    // Navigate to WinnerCelebrationScreen
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    // Calculate final position
    int playerPosition = 0;
    final currentPlayerId = playerProvider.currentPlayer?.id ?? '';
    final leaderboard = gameProvider.leaderboard;

    if (leaderboard.isNotEmpty) {
      final index = leaderboard.indexWhere((p) => p.id == currentPlayerId);
      playerPosition = index >= 0 ? index + 1 : leaderboard.length + 1;
    } else {
      playerPosition = 999;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'WinnerCelebrationScreen'),
        builder: (_) => WinnerCelebrationScreen(
          eventId: widget.eventId,
          playerPosition: playerPosition,
          totalCluesCompleted: gameProvider.completedClues,
          // Prize might be null if we are waiting, or maybe we already got it.
          // We can check GameProvider.currentPrizeWon
          prizeWon: gameProvider.currentPrizeWon,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<PlayerProvider>(context).isDarkMode;
    return ChangeNotifierProvider(
      create: (_) => SpectatorFeedProvider(widget.eventId),
      child: _buildBody(isDarkMode),
    );
  }

  void _handleExitCompetition() {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    // Marcar como salida voluntaria ANTES de cualquier limpieza.
    // Esto evita que GameSessionMonitor muestre el mensaje falso
    // de "expulsado por un administrador".
    gameProvider.markVoluntaryExit();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ScenariosScreen()),
      (route) => false,
    );
  }

  Widget _buildBody(bool isDarkMode) {
    return ExitProtectionWrapper(
      title: '¿Salir de la competencia?',
      message: 'No se perderá tu progreso.',
      onExit: _handleExitCompetition,
      child: Scaffold(
      backgroundColor: AppTheme.dSurface0,
      body: AnimatedCyberBackground(
        child: Stack(
          children: [
            // Background image
            Positioned.fill(
              child: Image.asset(
                isDarkMode
                    ? 'assets/images/fotogrupalnoche.png'
                    : 'assets/images/personajesgrupal.png',
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),

            // Dark overlay for readability
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.72),
              ),
            ),

            // Content
            SafeArea(
              child: Column(
                children: [
                  // ── Header ──────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.dSurface1.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.successGreen.withOpacity(0.6),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.successGreen.withOpacity(0.15),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.successGreen.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_circle_rounded,
                                color: AppTheme.successGreen, size: 26),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "DESAFÍO COMPLETADO",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'Orbitron',
                                    fontSize: 14,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  "Esperando resultados finales...",
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Rank badge inline
                          Consumer<GameProvider>(
                              builder: (context, game, _) {
                            final playerProvider =
                                Provider.of<PlayerProvider>(context,
                                    listen: false);
                            final myId =
                                playerProvider.currentPlayer?.userId;
                            int myRank = 0;
                            if (game.leaderboard.isNotEmpty &&
                                myId != null) {
                              final idx = game.leaderboard.indexWhere(
                                  (p) =>
                                      p.userId == myId || p.id == myId);
                              if (idx >= 0) myRank = idx + 1;
                            }
                            if (myRank == 0) {
                              return const SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(
                                  color: AppTheme.accentGold,
                                  strokeWidth: 2,
                                ),
                              );
                            }
                            return Column(
                              children: [
                                Text(
                                  "#$myRank",
                                  style: const TextStyle(
                                    color: AppTheme.accentGold,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'Orbitron',
                                  ),
                                ),
                                const Text(
                                  "RANK",
                                  style: TextStyle(
                                    color: AppTheme.accentGold,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                  if (_bannerPool.isNotEmpty)
                    SizedBox(
                      height: 86,
                      child: PageView.builder(
                        controller: _bannerController,
                        itemCount: _bannerPool.length,
                        physics: const NeverScrollableScrollPhysics(),
                        itemBuilder: (context, index) {
                          final sponsor = _bannerPool[index];
                          return SponsorBanner(
                            sponsor: sponsor,
                            isCompact: true,
                            onImpression: () =>
                                _sponsorRotation.trackImpression(
                              sponsor,
                              context: 'waiting_room',
                            ),
                            onTap: () => _sponsorRotation.trackClick(
                              sponsor,
                              context: 'waiting_room',
                            ),
                          );
                        },
                      ),
                    ),

                  // ── Race Tracker Label ───────────────────────────────
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 14, 16, 6),
                    child: Row(
                      children: [
                        Container(
                          width: 3,
                          height: 16,
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryPink,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "TABLA DE POSICIONES EN VIVO",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Orbitron',
                            fontSize: 11,
                            letterSpacing: 1.8,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.successGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color:
                                  AppTheme.successGreen.withOpacity(0.4),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppTheme.successGreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Text(
                                "EN VIVO",
                                style: TextStyle(
                                  color: AppTheme.successGreen,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Race Tracker + Live Feed ────────────────────────
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        children: [
                          // Race Tracker — intrinsic height, same as clues_screen
                          Consumer<GameProvider>(
                            builder: (context, gameProvider, child) {
                              final playerProvider =
                                  Provider.of<PlayerProvider>(context,
                                      listen: false);
                              final currentPlayerId =
                                  playerProvider.currentPlayer?.userId ?? '';

                              if (gameProvider.leaderboard.isEmpty) {
                                return const SizedBox(
                                  height: 80,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: AppTheme.accentGold,
                                      strokeWidth: 2.5,
                                    ),
                                  ),
                                );
                              }

                              return RaceTrackWidget(
                                leaderboard: gameProvider.leaderboard,
                                currentPlayerId: currentPlayerId,
                                totalClues: gameProvider.totalClues,
                                compact: true,
                                isReadOnly: true,
                              );
                            },
                          ),

                          const SizedBox(height: 10),

                          // Live Activity Feed — fills remaining space
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                              decoration: BoxDecoration(
                                color: AppTheme.dSurface1.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppTheme.successGreen.withOpacity(0.6),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.successGreen.withOpacity(0.15),
                                    blurRadius: 18,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Feed header
                                Row(
                                  children: [
                                    Container(
                                      width: 3,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentGold,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'ACTIVIDAD EN VIVO',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontFamily: 'Orbitron',
                                        fontSize: 10,
                                        letterSpacing: 1.6,
                                      ),
                                    ),
                                    const Spacer(),
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 10,
                                          height: 10,
                                          child: CircularProgressIndicator(
                                            color: Colors.white.withOpacity(0.35),
                                            strokeWidth: 1.5,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          "Actualizando...",
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.35),
                                            fontSize: 9,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Expanded(
                                  child: Consumer<SpectatorFeedProvider>(
                                    builder: (context, feedProvider, _) {
                                      if (feedProvider.events.isEmpty) {
                                        return Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.bolt_outlined,
                                                size: 28,
                                                color: Colors.white
                                                    .withOpacity(0.15),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                'Sin actividad reciente',
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withOpacity(0.3),
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                      return ListView.builder(
                                        padding: const EdgeInsets.only(top: 4),
                                        itemCount: feedProvider.events.length,
                                        itemBuilder: (ctx, i) =>
                                            _buildFeedCard(feedProvider.events[i]),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ),
                        ],
                      ),
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

  // ── Feed helpers ──────────────────────────────────────────────────────────

  Widget _buildFeedCard(GameFeedEvent event) {
    final color = _eventColor(event.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.28), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                event.icon ?? '⚡',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      event.action,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      DateFormat('HH:mm').format(event.timestamp),
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 9),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  event.detail,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _eventColor(String? type) {
    switch (type) {
      case 'power':
        return Colors.amber;
      case 'clue':
        return Colors.greenAccent;
      case 'life':
        return Colors.redAccent;
      case 'join':
        return Colors.blueAccent;
      case 'shop':
        return Colors.orangeAccent;
      default:
        return Colors.white;
    }
  }
}
