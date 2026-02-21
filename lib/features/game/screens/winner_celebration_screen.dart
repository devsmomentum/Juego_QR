import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../providers/game_provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'scenarios_screen.dart';
import 'game_mode_selector_screen.dart';
import '../models/event.dart';
import '../services/betting_service.dart';
import '../widgets/spectator_betting_pot_widget.dart';
import '../widgets/sponsor_banner.dart';
import 'package:intl/intl.dart';
import '../../auth/screens/login_screen.dart';

class WinnerCelebrationScreen extends StatefulWidget {
  final String eventId;
  final int playerPosition;
  final int totalCluesCompleted;
  final int? prizeWon; // NEW

  const WinnerCelebrationScreen({
    super.key,
    required this.eventId,
    required this.playerPosition,
    required this.totalCluesCompleted,
    this.prizeWon, // NEW
  });

  @override
  State<WinnerCelebrationScreen> createState() =>
      _WinnerCelebrationScreenState();
}

class _WinnerCelebrationScreenState extends State<WinnerCelebrationScreen> {
  late ConfettiController _confettiController;
  late ConfettiController _fireworkLeftController;
  late ConfettiController _fireworkRightController;
  late ConfettiController _fireworkCenterController;
  late int _currentPosition; // Mutable state for position
  bool _isLoading = true; // NEW: Start with loading state
  Map<String, int> _prizes = {};

  // Podium Winners Data (from game_players.final_placement)
  List<Map<String, dynamic>> _podiumWinners = [];

  // Unified Results Data
  GameEvent? _eventDetails;
  int _totalBettingWinners = 0;
  Map<String, dynamic> _myBettingResult = {'won': false, 'amount': 0};
  bool _isLoadingEventData = true;

  @override
  void initState() {
    super.initState();
    debugPrint("🏆 WinnerCelebrationScreen INIT: Prize = ${widget.prizeWon}");
    _currentPosition = widget.playerPosition;
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 10));
    _fireworkLeftController =
        ConfettiController(duration: const Duration(seconds: 2));
    _fireworkRightController =
        ConfettiController(duration: const Duration(seconds: 2));
    _fireworkCenterController =
        ConfettiController(duration: const Duration(seconds: 2));

    // Start loading always to ensure sync
    _isLoading = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      final playerProvider =
          Provider.of<PlayerProvider>(context, listen: false);

      // REFRESH WALLET to ensure balance is current
      await playerProvider.reloadProfile();
      debugPrint(
          "💰 Wallet refreshed on podium. Balance: ${playerProvider.currentPlayer?.clovers}");

      // Fetch prizes for everyone
      _fetchPrizes();
      // Fetch detailed event data (Pot, Betting, etc)
      _loadEventData();

      // Add listener to self-correct position
      gameProvider.addListener(_updatePositionFromLeaderboard);

      // FORCE SYNC: Ensure provider knows the event ID
      if (gameProvider.currentEventId != widget.eventId) {
        debugPrint(
            "🏆 WinnerScreen: EventID Mismatch (Provider: ${gameProvider.currentEventId} vs Widget: ${widget.eventId}). Fixing...");
        // Re-initialize provider context for this event without heavy loading UI
        await gameProvider.fetchClues(eventId: widget.eventId, silent: true);
      }

      // Force a fresh fetch
      await gameProvider.fetchLeaderboard();

      // Try immediate check
      _updatePositionFromLeaderboard();

      // Safety timeout: If after 8 seconds we still loading, force show content
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted && _isLoading) {
          debugPrint("⚠️ Podium timeout: Forcing display with available data.");
          setState(() {
            _isLoading = false;
          });
        }
      });
    });
  }

Future<void> _fetchPrizes() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('prize_distributions')
          .select('user_id, amount')
          .eq('event_id', widget.eventId);

      final Map<String, int> loadedPrizes = {};
      for (final row in response) {
        if (row['user_id'] != null && row['amount'] != null) {
          // Solución: Usar "as num" y luego toInt() evita crashes si Supabase manda un double
          loadedPrizes[row['user_id'].toString()] = (row['amount'] as num).toInt();
        }
      }

      if (mounted) {
        setState(() {
          _prizes = loadedPrizes;
        });
        debugPrint("🏆 Prizes loaded: $_prizes");
      }
    } catch (e) {
      debugPrint("⚠️ Error fetching podium prizes: $e");
    }
  }

  Future<void> _loadEventData() async {
    try {
      final supabase = Supabase.instance.client;
      final playerProvider =
          Provider.of<PlayerProvider>(context, listen: false);
      final userId = playerProvider.currentPlayer?.id;

      // Fetch Event Details
      final eventResponse = await supabase
          .from('events')
          .select()
          .eq('id', widget.eventId)
          .single();
      final event = GameEvent.fromJson(eventResponse);

      // Fetch Betting Data
      final bettingService = BettingService(supabase);
      final bettingWinnersPromise = event.winnerId != null
          ? bettingService.getTotalBettingWinners(
              widget.eventId, event.winnerId!)
          : Future.value(0);

      final myBettingPromise = userId != null
          ? bettingService.getUserEventWinnings(widget.eventId, userId)
          : Future.value({'won': false, 'amount': 0});

      final results =
          await Future.wait([bettingWinnersPromise, myBettingPromise]);

      if (mounted) {
        setState(() {
          _eventDetails = event;
          _totalBettingWinners = results[0] as int;
          _myBettingResult = results[1] as Map<String, dynamic>;
        });
      }

      // Fetch podium winners AFTER event details are available
      await _fetchPodiumWinners();

      if (mounted) {
        setState(() {
          _isLoadingEventData = false;
        });
      }
    } catch (e) {
      debugPrint("⚠️ Error loading event data: $e");
      if (mounted) {
        setState(() {
          _isLoadingEventData = false;
        });
      }
    }
  }

  /// Fetches podium winners directly from game_players.final_placement
  /// filtered by event_id and limited to configuredWinners.
  Future<void> _fetchPodiumWinners() async {
    try {
      final supabase = Supabase.instance.client;
      final int maxWinners = _eventDetails?.configuredWinners ?? 3;

      // Query game_players with final_placement set, ordered by placement
      final List<dynamic> topPlayers = await supabase
          .from('game_players')
          .select('user_id, final_placement, completed_clues_count')
          .eq('event_id', widget.eventId)
          .not('final_placement', 'is', null)
          .neq('status', 'spectator')
          .order('final_placement', ascending: true)
          .limit(maxWinners);

      debugPrint("🏆 Podium: Found ${topPlayers.length} finishers (max: $maxWinners)");

      if (topPlayers.isEmpty) {
        if (mounted) setState(() => _podiumWinners = []);
        return;
      }

      // Fetch profiles for these users
      final List<String> userIds =
          topPlayers.map((p) => p['user_id'].toString()).toList();

      Map<String, Map<String, dynamic>> profilesMap = {};
      if (userIds.isNotEmpty) {
        final profiles = await supabase
            .from('profiles')
            .select('id, name, avatar_id, avatar_url')
            .inFilter('id', userIds);

        for (var p in profiles) {
          profilesMap[p['id'] as String] = p;
        }
      }

      // Build podium data
      final List<Map<String, dynamic>> winners = [];
      for (var p in topPlayers) {
        final uid = p['user_id'] as String;
        final profile = profilesMap[uid] ?? {};
        winners.add({
          'user_id': uid,
          'name': profile['name'] ?? 'Jugador',
          'avatar_id': profile['avatar_id'],
          'avatar_url': profile['avatar_url'] ?? '',
          'final_placement': (p['final_placement'] as num).toInt(),
          'completed_clues_count': (p['completed_clues_count'] as num?)?.toInt() ?? 0,
        });
      }

      if (mounted) {
        setState(() {
          _podiumWinners = winners;
        });
        debugPrint("🏆 Podium winners loaded: ${winners.map((w) => '${w['name']}=#${w['final_placement']}').join(', ')}");
      }
    } catch (e) {
      debugPrint("⚠️ Error fetching podium winners: $e");
    }
  }

  void _updatePositionFromLeaderboard() {
    if (!mounted) return;
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    // 1. If loading, keep waiting
    if (gameProvider.leaderboard.isEmpty && gameProvider.isLoading) return;

    if (gameProvider.leaderboard.isNotEmpty) {
      final currentUser = gameProvider.leaderboard.firstWhere(
          (p) => p.userId == playerProvider.currentPlayer?.userId,
          orElse: () =>
              playerProvider.currentPlayer!); // Fallback to avoid crash

      // 2. STRICT CHECK: Does the leaderboard reflect my completed clues?
      // If the leaderboard says I have fewer clues than I actually completed, it's stale.
      if (currentUser.completedCluesCount < widget.totalCluesCompleted) {
        debugPrint(
            "⏳ Podium Sync: Leaderboard stale (Server: ${currentUser.completedCluesCount} vs Local: ${widget.totalCluesCompleted}). Waiting...");

        // RETRY LOGIC: If data is stale, we MUST force a refresh, even if isLoading is false.
        // We use a debounce to avoid spamming.
        if (!gameProvider.isLoading) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (mounted) {
              debugPrint("🔄 Podium Sync: Retrying fetchLeaderboard...");
              gameProvider.fetchLeaderboard(silent: true);
            }
          });
        }
        return;
      }

      final index = gameProvider.leaderboard
          .indexWhere((p) => p.userId == playerProvider.currentPlayer?.userId);
      final newPos = index >= 0 ? index + 1 : _currentPosition;

      debugPrint("✅ Podium Sync: Data verified. Rank: $newPos");

      // Verify prizes if not loaded cleanly yet
      if (_prizes.isEmpty) {
        _fetchPrizes();
      }

      // Data is consistent, update and show
      if (newPos != _currentPosition || _isLoading) {
        setState(() {
          _currentPosition = newPos;
          _isLoading = false;
        });

        if (newPos >= 1 && newPos <= 3) {
          _confettiController.play();
          _startFireworks();
        } else {
          _confettiController.stop();
        }
      }
    } else {
      // Leaderboard empty/failed?
      if (!gameProvider.isLoading && _isLoading) {
        debugPrint("⚠️ Podium Sync: Leaderboard empty. Retrying...");
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && !gameProvider.isLoading) {
            gameProvider.fetchLeaderboard(silent: true);
          }
        });
      }
    }
  }

  void _startFireworks() {
    // Staggered firework bursts for a spectacular effect
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _fireworkCenterController.play();
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _fireworkLeftController.play();
    });
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) _fireworkRightController.play();
    });
    // Second wave
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) _fireworkCenterController.play();
    });
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) _fireworkRightController.play();
    });
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) _fireworkLeftController.play();
    });
    // Third wave
    Future.delayed(const Duration(milliseconds: 5000), () {
      if (mounted) _fireworkLeftController.play();
    });
    Future.delayed(const Duration(milliseconds: 5500), () {
      if (mounted) _fireworkCenterController.play();
    });
    Future.delayed(const Duration(milliseconds: 6000), () {
      if (mounted) _fireworkRightController.play();
    });
  }

  @override
  void dispose() {
    // Remove listener safely
    try {
      Provider.of<GameProvider>(context, listen: false)
          .removeListener(_updatePositionFromLeaderboard);
    } catch (_) {}

    _confettiController.dispose();
    _fireworkLeftController.dispose();
    _fireworkRightController.dispose();
    _fireworkCenterController.dispose();
    super.dispose();
  }

  String _getMedalEmoji() {
    switch (_currentPosition) {
      case 1:
        return '🏆';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '🏁';
    }
  }

  String _getCelebrationMessage() {
    if (_currentPosition == 1) {
      return '¡Eres el Campeón!';
    } else if (_currentPosition >= 1 && _currentPosition <= 3) {
      return '¡Podio Merecido!';
    } else {
      return '¡Carrera Completada!';
    }
  }

  Color _getPositionColor() {
    switch (_currentPosition) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return AppTheme.accentGold;
    }
  }

  void _showLogoutDialog() {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    const Color currentRed = Color(0xFFE33E5D);
    const Color cardBg = Color(0xFF151517);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: currentRed.withOpacity(0.2),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: currentRed.withOpacity(0.5), width: 1),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: currentRed, width: 2),
              boxShadow: [
                BoxShadow(
                  color: currentRed.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: currentRed, width: 2),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: currentRed,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Cerrar Sesión',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  '¿Estás seguro que deseas cerrar sesión?',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('CANCELAR', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await playerProvider.logout();
                          if (mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                              (route) => false,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: currentRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('SALIR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);
    final playerProvider = Provider.of<PlayerProvider>(context);
    final currentPlayerId = playerProvider.currentPlayer?.userId ?? playerProvider.currentPlayer?.id ?? '';
    final isNightImage = playerProvider.isDarkMode;

    // Determine if user participated
    final isParticipant = _currentPosition > 0;

    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Scaffold(
        backgroundColor: AppTheme.dSurface0,
        body: Stack(
          children: [
            // BACKGROUND IMAGE (day/night)
            Positioned.fill(
              child: isNightImage
                  ? Opacity(
                      opacity: 0.5,
                      child: Image.asset(
                        'assets/images/hero.png',
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                      ),
                    )
                  : Stack(
                      children: [
                        Image.asset(
                          'assets/images/loginclaro.png',
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                        Container(color: Colors.black.withOpacity(0.3)),
                      ],
                    ),
            ),
            // Dark overlay for readability
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.black.withOpacity(0.7),
                      Colors.black.withOpacity(0.5),
                    ],
                  ),
                ),
              ),
            ),
              // Confetti overlay - main rain
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirection: pi / 2, // Down
                  maxBlastForce: 5,
                  minBlastForce: 2,
                  emissionFrequency: 0.03,
                  numberOfParticles: 30,
                  gravity: 0.2,
                  shouldLoop: true,
                  colors: const [
                    Colors.green,
                    Colors.blue,
                    Colors.pink,
                    Colors.orange,
                    Colors.purple,
                    Color(0xFFFFD700),
                    Colors.cyan,
                    Colors.redAccent,
                  ],
                ),
              ),
              // Firework - Left burst
              Align(
                alignment: const Alignment(-0.8, 0.3),
                child: ConfettiWidget(
                  confettiController: _fireworkLeftController,
                  blastDirectionality: BlastDirectionality.explosive,
                  maxBlastForce: 25,
                  minBlastForce: 10,
                  emissionFrequency: 0.0,
                  numberOfParticles: 40,
                  gravity: 0.15,
                  particleDrag: 0.05,
                  colors: const [
                    Color(0xFFFFD700),
                    Colors.orange,
                    Colors.redAccent,
                    Colors.yellowAccent,
                  ],
                ),
              ),
              // Firework - Right burst
              Align(
                alignment: const Alignment(0.8, 0.2),
                child: ConfettiWidget(
                  confettiController: _fireworkRightController,
                  blastDirectionality: BlastDirectionality.explosive,
                  maxBlastForce: 25,
                  minBlastForce: 10,
                  emissionFrequency: 0.0,
                  numberOfParticles: 40,
                  gravity: 0.15,
                  particleDrag: 0.05,
                  colors: const [
                    Colors.cyan,
                    Colors.blue,
                    Colors.purpleAccent,
                    Colors.greenAccent,
                  ],
                ),
              ),
              // Firework - Center burst
              Align(
                alignment: const Alignment(0.0, -0.2),
                child: ConfettiWidget(
                  confettiController: _fireworkCenterController,
                  blastDirectionality: BlastDirectionality.explosive,
                  maxBlastForce: 30,
                  minBlastForce: 12,
                  emissionFrequency: 0.0,
                  numberOfParticles: 50,
                  gravity: 0.12,
                  particleDrag: 0.05,
                  colors: const [
                    Color(0xFFFFD700),
                    Colors.pink,
                    Colors.white,
                    Colors.amber,
                    Colors.deepPurple,
                  ],
                ),
              ),

              if (_isLoading || _isLoadingEventData)
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppTheme.accentGold),
                      SizedBox(height: 20),
                      Text("Cargando resultados...",
                          style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                )
              else
                SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    child: Column(
                      children: [
                        // Header
                        Text(
                          isParticipant
                              ? _getCelebrationMessage()
                              : 'Resultados Finales',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: _getPositionColor(),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),

                        // USER RESULT CARD (Only if participant)
                        if (isParticipant)
                          Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 30, vertical: 15),
                            decoration: BoxDecoration(
                              color: _getPositionColor().withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: _getPositionColor(), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: _getPositionColor().withOpacity(0.2),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Column(children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _getMedalEmoji(),
                                    style: const TextStyle(fontSize: 40),
                                  ),
                                  const SizedBox(width: 15),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'TU POSICIÓN',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                      Text(
                                        '#$_currentPosition',
                                        style: TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.w900,
                                          color: _getPositionColor(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (_prizes.containsKey(currentPlayerId)) ...[
                                const SizedBox(height: 10),
                                _buildPrizeBadge(_prizes[currentPlayerId]!)
                              ] else if (widget.prizeWon != null &&
                                  widget.prizeWon! > 0) ...[
                                const SizedBox(height: 10),
                                _buildPrizeBadge(widget.prizeWon!)
                              ]
                            ]),
                          )
                        else
                          // Non-participant message
                          Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: const Text(
                              'Este evento ha finalizado. Aquí están los resultados oficiales:',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 14),
                            ),
                          ),

                        // PODIUM SECTION (Based on game_players.final_placement)
                        if (_podiumWinners.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.cardBg.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                  color: AppTheme.accentGold.withOpacity(0.2)),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'PODIO CAMPEONES',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Builder(builder: (context) {
                                  // Find winners by placement
                                  final first = _podiumWinners.firstWhere(
                                      (w) => w['final_placement'] == 1,
                                      orElse: () => {});
                                  final second = _podiumWinners.firstWhere(
                                      (w) => w['final_placement'] == 2,
                                      orElse: () => {});
                                  final third = _podiumWinners.firstWhere(
                                      (w) => w['final_placement'] == 3,
                                      orElse: () => {});
                                  final maxWinners = _eventDetails?.configuredWinners ?? 3;

                                  return Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      // 2nd place
                                      if (maxWinners >= 2 && second.isNotEmpty)
                                        _buildPodiumPositionFromMap(
                                          second, 2, 60, Colors.grey,
                                          _prizes[second['user_id']],
                                        )
                                      else if (maxWinners >= 2)
                                        const SizedBox(width: 60),

                                      // 1st place
                                      if (first.isNotEmpty)
                                        _buildPodiumPositionFromMap(
                                          first, 1, 90,
                                          const Color(0xFFFFD700),
                                          _prizes[first['user_id']],
                                        ),

                                      // 3rd place
                                      if (maxWinners >= 3 && third.isNotEmpty)
                                        _buildPodiumPositionFromMap(
                                          third, 3, 50,
                                          const Color(0xFFCD7F32),
                                          _prizes[third['user_id']],
                                        )
                                      else if (maxWinners >= 3)
                                        const SizedBox(width: 60),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ),

                        // FINANCIAL STATS SECTION (Unified)
                        Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'ESTADÍSTICAS DEL EVENTO',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Row 1: Pot & Betting Pot
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Entry Pot
                                  Expanded(
                                    child: _buildStatItem(
                                      "POZO INSCRIPCIÓN",
                                      _eventDetails?.pot != null &&
                                              _eventDetails!.pot > 0
                                          ? NumberFormat.currency(
                                                      locale: 'es_CO',
                                                      symbol: '',
                                                      decimalDigits: 0)
                                                  .format(_eventDetails!.pot) +
                                              " 🍀"
                                          : "Gratis",
                                      Icons.monetization_on,
                                      Colors.amber,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Betting Pot (Using Spectator Widget Logic but customized or direct)
                                  // Since we have the widget, we can use it, but it might include its own layout.
                                  // Let's wrapping it or reuse its logic?
                                  // Actually, the widget is designed for the spectator screen header.
                                  // Let's use a custom display here for consistency, relying on the widget's logic if needed,
                                  // BUT we want to keep it simple.
                                  // Let's just use the SpectatorBettingPotWidget directly if it fits,
                                  // OR just pass the widget.eventId.
                                  // To match the UI, let's wrap it.
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        children: [
                                          // Embed the existing widget but we need to ensure it fits.
                                          // The widget has a Row and text.
                                          // Alternatively, since we are in the results screen, maybe just show it nicely.
                                          SpectatorBettingPotWidget(
                                              eventId: widget.eventId),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Row 2: Winners & Betting Results
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Configured Winners
                                  Expanded(
                                    child: _buildStatItem(
                                      "GANADORES",
                                      _prizes.isNotEmpty 
                                          ? "${_prizes.length}" 
                                          : "${_eventDetails?.configuredWinners ?? 1}",
                                      Icons.emoji_events,
                                      Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Total Betting Winners
                                  Expanded(
                                    child: _buildStatItem(
                                      "GANADORES APUESTA",
                                      "$_totalBettingWinners",
                                      Icons.people,
                                      Colors.greenAccent,
                                    ),
                                  ),
                                ],
                              ),

                              // YOUR BETTING RESULT (If existed)
                              if (_myBettingResult['amount'] > 0 ||
                                  _myBettingResult['won'] == true) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: (_myBettingResult['won'] as bool)
                                        ? Colors.green.withOpacity(0.2)
                                        : Colors.red.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: (_myBettingResult['won'] as bool)
                                          ? Colors.green
                                          : Colors.red,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                          (_myBettingResult['won'] as bool)
                                              ? Icons.check_circle
                                              : Icons.cancel,
                                          color:
                                              (_myBettingResult['won'] as bool)
                                                  ? Colors.green
                                                  : Colors.red,
                                          size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        (_myBettingResult['won'] as bool)
                                            ? "¡Ganaste la apuesta! +${_myBettingResult['amount']} 🍀"
                                            : "Perdiste tu apuesta",
                                        style: TextStyle(
                                          color:
                                              (_myBettingResult['won'] as bool)
                                                  ? Colors.greenAccent
                                                  : Colors.redAccent,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    ],
                                  ),
                                )
                              ]
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Sponsor Banner
                        Consumer<GameProvider>(
                          builder: (context, game, _) {
                            return SponsorBanner(sponsor: game.currentSponsor);
                          },
                        ),
                        const SizedBox(height: 20),
                        // Bottom Actions
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                    builder: (_) => GameModeSelectorScreen()),
                                (route) => false,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentGold,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 8,
                              shadowColor: AppTheme.accentGold.withOpacity(0.5),
                            ),
                            icon: const Icon(Icons.home_rounded, size: 28),
                            label: const Text(
                              'VOLVER AL INICIO',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrizeBadge(int amount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD700)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("💰", style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(
            "+$amount 🍀",
            style: const TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 20,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Colors.black, blurRadius: 2)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getPositionColorForRank(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return Colors.grey.shade700;
    }
  }

  String _getMedalEmojiForRank(int rank) {
    switch (rank) {
      case 1:
        return '🏆';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '';
    }
  }

  /// Builds a podium position from a Map (from _podiumWinners)
  Widget _buildPodiumPositionFromMap(
      Map<String, dynamic> winner, int position, double height, Color color, int? prizeAmount) {
    final String name = winner['name'] ?? 'Jugador';
    final String? rawAvatarId = winner['avatar_id']?.toString();
    final String avatarUrl = winner['avatar_url']?.toString() ?? '';
    final int completedClues = winner['completed_clues_count'] ?? 0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: Builder(
                  builder: (context) {
                    // Sanitize avatarId (remove path and extension if present)
                    String? avatarId = rawAvatarId;
                    if (avatarId != null) {
                      avatarId = avatarId.split('/').last;
                      avatarId = avatarId
                          .replaceAll('.png', '')
                          .replaceAll('.jpg', '');
                    }

                    debugPrint(
                        "🏆 Podium Avatar Build: Original='$rawAvatarId' -> Sanitized='$avatarId'");

                    if (avatarId != null && avatarId.isNotEmpty) {
                      return Image.asset(
                        'assets/images/avatars/$avatarId.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          debugPrint(
                              "⚠️ Failed to load avatar asset: assets/images/avatars/$avatarId.png");
                          return const Icon(Icons.person,
                              color: Colors.white70, size: 25);
                        },
                      );
                    }
                    if (avatarUrl.isNotEmpty && avatarUrl.startsWith('http')) {
                      return Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.person,
                            color: Colors.white70, size: 25),
                      );
                    }
                    return const Icon(Icons.person,
                        color: Colors.white70, size: 25);
                  },
                ),
              ),
            ),
            Positioned(
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$position',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 80,
          child: Text(
            name,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 4),

        // Pedestal bar with position number at the bottom
        Container(
          width: double.infinity,
          height: barHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withOpacity(0.45),
                color.withOpacity(0.12),
              ],
            ),
            border: Border(
              top: BorderSide(color: color, width: 2),
              left: BorderSide(color: color.withOpacity(0.3), width: 0.5),
              right: BorderSide(color: color.withOpacity(0.3), width: 0.5),
            ),
          ),
          child: Center(
            child: Text(
              '$completedClues',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom painter that draws a laurel wreath around the avatar matching the reference design
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

    // Draw U-shaped stem arc (open at the top) - brought closer to avatar
    final rect = Rect.fromCircle(center: center, radius: radius * 0.68);
    // Start at ~1:30 o'clock and sweep through the bottom to ~10:30 o'clock
    canvas.drawArc(rect, -4/14 * pi, 22/14 * pi, false, stemPaint);

    // Draw leaves in a circular "clock" distribution with a gap at the top
    final int totalLeaves = 14; 
    for (int i = 0; i < totalLeaves; i++) {
      // Skip the top 3 positions to leave it open at the top (11, 12, 1 o'clock)
      if (i == 0 || i == 1 || i == totalLeaves - 1) continue;
      
      // Distribute evenly around the circle
      final angle = (2 * pi * i / totalLeaves) - pi / 2;
      
      _drawReferenceLeaf(canvas, center, radius * 0.68, angle, leafPaint, isOuter: true);
      _drawReferenceLeaf(canvas, center, radius * 0.68, angle, leafPaint, isOuter: false);
    }
  }

  void _drawReferenceLeaf(
      Canvas canvas, Offset center, double radius, double angle, Paint paint,
      {required bool isOuter}) {
    final x = center.dx + radius * cos(angle);
    final y = center.dy + radius * sin(angle);

    canvas.save();
    canvas.translate(x, y);

    // Point leaf radially with a strong tilt to the right (+0.5 radians)
    double rotation = isOuter ? angle + 0.5 : angle + pi + 0.5;
    
    canvas.rotate(rotation + pi / 2);

    // Make inner leaves slightly smaller for better aesthetics
    final scale = isOuter ? 1.0 : 0.75;
    canvas.scale(scale, scale);

    final path = Path();
    final len = 13.0;
    final width = 5.0;

    // Pointed oval leaf (wider in middle, sharp tip)
    path.moveTo(0, 0);
    path.quadraticBezierTo(width * 1.2, -len * 0.45, 0, -len); // Outer curve
    path.quadraticBezierTo(-width * 1.2, -len * 0.45, 0, 0); // Inner curve
    path.close();

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

