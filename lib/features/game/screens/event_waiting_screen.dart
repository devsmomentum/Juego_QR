import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../game/models/event.dart';
import '../../../shared/widgets/animated_cyber_background.dart';
import '../../admin/services/sponsor_service.dart'; // NEW
import '../../admin/models/sponsor.dart'; // NEW
import '../widgets/sponsor_banner.dart'; // NEW
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/player_provider.dart';
import '../widgets/event_launch_countdown_overlay.dart'; // NEW: 5-second launch overlay

class EventWaitingScreen extends StatefulWidget {
  final GameEvent event;
  final VoidCallback onTimerFinished;

  const EventWaitingScreen(
      {super.key, required this.event, required this.onTimerFinished});

  @override
  State<EventWaitingScreen> createState() => _EventWaitingScreenState();
}

class _EventWaitingScreenState extends State<EventWaitingScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  Timer?
      _statusPollingTimer; // P1: Polling de recuperación como red de seguridad
  Duration? _timeLeft;
  bool _waitingForAdmin =
      false; // True when countdown finished but admin hasn't started event
  bool _isNavigating =
      false; // Guard: evita doble-navegación entre Realtime y Polling
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  // ── Pending online: auto-start + launch overlay state ──────────────────────
  Timer? _autoStartTimer; // polls player count after countdown hits zero
  int _playerCount = 0; // current non-spectator enrolled players
  int _minPlayersToStart = 5; // loaded from config (default 5)
  bool _isShowingLaunchCountdown =
      false; // true while the 5-s launch overlay is on
  // ────────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _calculateTime();
    _timer =
        Timer.periodic(const Duration(seconds: 1), (_) => _calculateTime());

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // P0: Suscripción Realtime inmediata — antes de cualquier operación async
    // (antes estaba dentro de _loadSponsor(), causando una race condition)
    _setupRealtimeSubscription();

    // P1: Polling de recuperación cada 30s como red de seguridad ante fallos de Realtime para no saturar la BD
    _statusPollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkEventStatusFromServer();
    });

    _loadSponsor();
  }

  Sponsor? _eventSponsor;

  Future<void> _loadSponsor() async {
    final service = SponsorService();
    final sponsor = await service.getSponsorForEvent(widget.event.id);
    if (mounted && sponsor != null && sponsor.hasSponsoredByBanner) {
      setState(() {
        _eventSponsor = sponsor;
      });
    }
    // _setupRealtimeSubscription() fue movido a initState() — ver fix P0
  }

  RealtimeChannel? _eventChannel;

  void _setupRealtimeSubscription() {
    try {
      debugPrint(
          "🔍 Setting up realtime subscription for event: ${widget.event.id}");
      _eventChannel = Supabase.instance.client
          .channel('public:events:${widget.event.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'events',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: widget.event.id,
            ),
            callback: (payload) {
              if (payload.eventType == PostgresChangeEvent.delete) {
                debugPrint("❌ Event DELETED via Realtime.");
                _showCancelledDialog();
                return;
              }
              debugPrint("🔔 Event update received: ${payload.newRecord}");
              final newStatus = payload.newRecord['status'];
              if (newStatus == 'active') {
                debugPrint(
                    "✅ Event is now ACTIVE via Realtime! Triggering navigation...");
                _triggerNavigation();
              } else if (newStatus == 'cancelled') {
                debugPrint("❌ Event CANCELLED via Realtime.");
                _showCancelledDialog();
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint("❌ Error setting up realtime subscription: $e");
    }
  }

  /// Centraliza el trigger de navegación para evitar dobles llamadas
  /// entre Realtime y Polling (Bug #5 guard).
  /// For online events: shows the 5-second launch countdown overlay first.
  void _triggerNavigation() {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;
    _timer?.cancel();
    _statusPollingTimer?.cancel();
    _autoStartTimer?.cancel();
    debugPrint("🚀 EventWaiting: _triggerNavigation() called");

    if (widget.event.type == 'online') {
      // Show 5-second launch countdown then navigate
      if (mounted) {
        setState(() => _isShowingLaunchCountdown = true);
      }
      // Navigation happens inside the overlay's onComplete callback (see build)
    } else {
      // Presential events: navigate immediately as before
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onTimerFinished();
      });
    }
  }

  /// P1+P3: Consulta el estado del evento directamente al servidor.
  /// Actúa como red de seguridad cuando Realtime falla, se pierde o llega tarde.
  Future<void> _checkEventStatusFromServer() async {
    if (_isNavigating || !mounted) return;
    try {
      final response = await Supabase.instance.client
          .from('events')
          .select('status')
          .eq('id', widget.event.id)
          .maybeSingle(); // maybeSingle so a missing row doesn't throw
      if (response == null) {
        debugPrint("❌ Polling detected event DELETED.");
        if (mounted) _showCancelledDialog();
        return;
      }
      final status = response['status'] as String?;
      // Se apaga el print de polling para no generar ruido en consola ('⏳ Polling event status: $status')
      if ((status == 'active' || status == 'completed') && mounted) {
        debugPrint(
            "✅ Polling detected event is now ACTIVE! Triggering navigation...");
        _triggerNavigation();
      } else if (status == 'cancelled' && mounted) {
        debugPrint("❌ Polling detected event CANCELLED.");
        _showCancelledDialog();
      }
    } catch (e) {
      debugPrint("❌ Error polling event status: $e");
    }
  }

  // ── Cancellation dialog ─────────────────────────────────────────────────────
  bool _cancelDialogShown = false;

  void _showCancelledDialog() {
    if (_cancelDialogShown || !mounted) return;
    _cancelDialogShown = true;
    // Stop all active timers
    _timer?.cancel();
    _statusPollingTimer?.cancel();
    _autoStartTimer?.cancel();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.cancel_outlined,
            color: Colors.redAccent, size: 48),
        title: const Text(
          'Evento Cancelado',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Orbitron',
          ),
        ),
        content: Text(
          'No se inscribieron suficientes jugadores antes de que finalizara el tiempo.\n\n'
          'Se necesitaban $_minPlayersToStart jugadores y solo se inscribieron $_playerCount.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                Navigator.of(context).pop(); // close dialog
                Navigator.of(context).pop(); // back to scenarios
              },
              child: const Text('VOLVER A SALAS',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
  // ────────────────────────────────────────────────────────────────────────────

  /// Starts polling player count every 3 s once the countdown hits zero.
  /// On each tick: updates [_playerCount] and calls [_tryAutoStart].
  void _startAutoStartPolling() {
    if (widget.event.type != 'online' || !widget.event.isAutomated) return;
    _autoStartTimer?.cancel();
    _tryAutoStart(); // immediate first check
    _autoStartTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _tryAutoStart();
    });
  }

  /// Fetches current player count, updates UI, and attempts to resolve the
  /// event via the `auto_start_online_event` RPC:
  ///   - countdown not expired → no-op (future tick will retry)
  ///   - enough players         → activate (→ launch overlay)
  ///   - not enough players     → server cancels event (→ cancellation dialog)
  Future<void> _tryAutoStart() async {
    if (_isNavigating || !mounted) return;
    try {
      // Count current players for display
      final countResp = await Supabase.instance.client
          .from('game_players')
          .select('id')
          .eq('event_id', widget.event.id)
          .neq('status', 'spectator')
          .neq('status', 'banned')
          .count();
      final count = countResp.count ?? 0;
      if (mounted) setState(() => _playerCount = count);

      // Attempt activation via RPC
      final result = await Supabase.instance.client.rpc(
        'auto_start_online_event',
        params: {'p_event_id': widget.event.id},
      );
      debugPrint('🎯 auto_start_online_event result: $result');

      if (result is Map) {
        final minRequired = result['required'];
        if (minRequired != null && mounted) {
          setState(() => _minPlayersToStart = (minRequired as num).toInt());
        }

        if (result['success'] == true && mounted && !_isNavigating) {
          debugPrint('✅ Event auto-started! Triggering navigation...');
          _triggerNavigation();
        } else if (result['cancelled'] == true && mounted) {
          debugPrint('❌ Event cancelled by server (not enough players).');
          _autoStartTimer?.cancel();
          _showCancelledDialog();
        }
      }
    } catch (e) {
      debugPrint('❌ _tryAutoStart error: $e');
    }
  }
  // ────────────────────────────────────────────────────────────────────────────

  void _calculateTime() {
    // PRIORIDAD AL ESTADO: Si el evento ya está activo o completado, omitir cuenta regresiva
    if (widget.event.status == 'active' || widget.event.status == 'completed') {
      _timer?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onTimerFinished();
      });
      return;
    }
    // Si el evento fue cancelado antes de que el timer calcule, mostrar dialog
    if (widget.event.status == 'cancelled') {
      _timer?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showCancelledDialog();
      });
      return;
    }

    final target = widget.event.date.toLocal();
    final current = DateTime.now();

    if (target.isAfter(current)) {
      // Still counting down
      if (mounted) {
        setState(() {
          _timeLeft = target.difference(current);
          _waitingForAdmin = false;
        });
      }
    } else {
      // Countdown reached zero.
      // For ONLINE events: auto-start when min_players_to_start are enrolled.
      // For PRESENTIAL events: wait for admin via start_event RPC.
      _timer?.cancel();
      if (mounted) {
        setState(() {
          _timeLeft = Duration.zero;
          _waitingForAdmin = true;
        });
      }
      debugPrint("⏳ Countdown finished for event ${widget.event.id}.");
      // P3: Verificar estado en servidor al llegar a cero (puede que el admin ya inició)
      _checkEventStatusFromServer();
      // Only auto-start for automated online events; manual events wait for admin
      if (widget.event.isAutomated) _startAutoStartPolling();
    }
  }

  @override
  void dispose() {
    _eventChannel?.unsubscribe();
    _timer?.cancel();
    _statusPollingTimer?.cancel();
    _autoStartTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = context.watch<PlayerProvider>();
    final isDarkMode = playerProvider.isDarkMode;

    // Determine dynamic content based on state
    final bool isOnlineEvent = widget.event.type == 'online';
    // Automated online events auto-start; manual online events require admin
    final bool isAutomatedOnline = isOnlineEvent && widget.event.isAutomated;
    final bool isWaitingPlayers = _waitingForAdmin && isAutomatedOnline;
    final bool isWaitingAdmin = _waitingForAdmin && !isAutomatedOnline;

    final String headerText = _waitingForAdmin
        ? (isAutomatedOnline ? 'SALA DE ESPERA' : 'CUENTA REGRESIVA FINALIZADA')
        : 'PREÁRATE';
    final String titleText = _waitingForAdmin
        ? (isAutomatedOnline
            ? 'ESPERANDO JUGADORES...'
            : 'ESPERANDO AL ADMINISTRADOR')
        : 'LA AVENTURA COMIENZA PRONTO';
    final String subtitleText = _waitingForAdmin
        ? (isAutomatedOnline
            ? 'Iniciamos cuando lleguen $_minPlayersToStart jugadores\no cuando la sala esté llena.'
            : 'El contador ha terminado.\nEsperando señal del administrador para iniciar el evento...')
        : 'El tesoro aguarda por el más valiente.\nManténte alerta.';
    final IconData iconData = _waitingForAdmin
        ? (isAutomatedOnline ? Icons.people : Icons.admin_panel_settings)
        : Icons.hourglass_empty;

    // LOGIN CLARO STYLE COLORS
    final Color dGoldMain = const Color(0xFFFECB00);
    final Color lBrandMain = const Color(0xFF5A189A);
    final Color lTextPrimary = const Color(0xFF1A1A1D);
    final Color lTextSecondary = const Color(0xFF4A4A5A);

    final Color primaryAccent = isDarkMode ? AppTheme.accentGold : lBrandMain;
    final Color secondaryAccent =
        isDarkMode ? AppTheme.secondaryPink : dGoldMain;

    final Color iconColor =
        _waitingForAdmin ? Colors.orangeAccent : primaryAccent;
    final Color headerColor =
        _waitingForAdmin ? Colors.orangeAccent : primaryAccent;
    final Color glowColor = _waitingForAdmin
        ? Colors.orangeAccent.withOpacity(0.2)
        : secondaryAccent.withOpacity(0.2);
    final Color borderColor = _waitingForAdmin
        ? Colors.orangeAccent.withOpacity(0.5)
        : primaryAccent.withOpacity(0.5);

    final Color currentCardBg = isDarkMode
        ? Colors.white.withOpacity(0.05)
        : Colors.white.withOpacity(0.9);
    final Color currentTitleColor = Colors.white;
    final Color currentSubtitleColor = Colors.white70;
    final Color currentBorderColor =
        (isDarkMode ? secondaryAccent : primaryAccent).withOpacity(0.3);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background Image (hero.png for Dark, loginclaro.png for Light)
          Positioned.fill(
            child: isDarkMode
                ? Image.asset(
                    'assets/images/hero.png',
                    fit: BoxFit.cover,
                  )
                : Image.asset(
                    'assets/images/loginclaro.png',
                    fit: BoxFit.cover,
                  ),
          ),
          // Subtle Overlay
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(isDarkMode ? 0.4 : 0.2),
            ),
          ),

          SafeArea(
            child: Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(30.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Icon with pulse
                          ScaleTransition(
                            scale: _pulseAnimation,
                            child: Container(
                              padding: const EdgeInsets.all(30),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: primaryAccent.withOpacity(0.1),
                                border:
                                    Border.all(color: borderColor, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: glowColor,
                                    blurRadius: 30,
                                    spreadRadius: 10,
                                  ),
                                ],
                              ),
                              child: Icon(iconData, size: 60, color: iconColor),
                            ),
                          ),
                          const SizedBox(height: 50),

                          Text(
                            headerText,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: headerColor,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Orbitron',
                              letterSpacing: 3,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            titleText,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: currentTitleColor,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Orbitron',
                              fontSize: 24,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            subtitleText,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: currentSubtitleColor,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),

                          const SizedBox(height: 60),

                          // Countdown or Admin Wait indicator
                          if (_waitingForAdmin)
                            // Admin-wait state
                            ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0D0D0F)
                                        .withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                        color: Colors.orangeAccent
                                            .withOpacity(0.6),
                                        width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.orangeAccent
                                            .withOpacity(0.05),
                                        blurRadius: 20,
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 30, vertical: 25),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.orangeAccent
                                            .withOpacity(0.2),
                                        width: 1.0,
                                      ),
                                      color:
                                          Colors.orangeAccent.withOpacity(0.02),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          isAutomatedOnline
                                              ? Icons.people
                                              : Icons.sync,
                                          color: Colors.orangeAccent,
                                          size: 32,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          isAutomatedOnline
                                              ? "ESPERANDO JUGADORES"
                                              : "ESPERANDO INICIO MANUAL",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                            fontFamily: 'Orbitron',
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        if (isAutomatedOnline) ...[
                                          // Player count progress bar
                                          RichText(
                                            textAlign: TextAlign.center,
                                            text: TextSpan(
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 14,
                                                fontFamily: 'Orbitron',
                                              ),
                                              children: [
                                                TextSpan(
                                                  text: '$_playerCount',
                                                  style: const TextStyle(
                                                    color: Colors.orangeAccent,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 28,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text:
                                                      ' / $_minPlayersToStart',
                                                  style: const TextStyle(
                                                    color: Colors.white54,
                                                    fontSize: 18,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            _playerCount >= _minPlayersToStart
                                                ? 'Iniciando...'
                                                : 'jugadores mínimos para comenzar',
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ] else ...[
                                          RichText(
                                            textAlign: TextAlign.center,
                                            text: const TextSpan(
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                                fontFamily: 'Roboto',
                                              ),
                                              children: [
                                                TextSpan(
                                                    text:
                                                        "El administrador debe presionar "),
                                                TextSpan(
                                                  text: "PLAY",
                                                  style: TextStyle(
                                                    color: Colors.orangeAccent,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ], // closes else branch
                                      ], // closes Column.children
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else if (_timeLeft != null)
                            // Normal countdown state
                            ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0D0D0F)
                                        .withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                        color: currentBorderColor, width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (isDarkMode
                                                ? secondaryAccent
                                                : primaryAccent)
                                            .withOpacity(0.05),
                                        blurRadius: 20,
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 30, vertical: 25),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: (isDarkMode
                                                ? secondaryAccent
                                                : primaryAccent)
                                            .withOpacity(0.2),
                                        width: 1.0,
                                      ),
                                      color: (isDarkMode
                                              ? secondaryAccent
                                              : primaryAccent)
                                          .withOpacity(0.02),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          "TIEMPO RESTANTE",
                                          style: TextStyle(
                                            color: currentSubtitleColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            fontFamily: 'Orbitron',
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          "${_timeLeft!.inDays}d ${_timeLeft!.inHours % 24}h ${_timeLeft!.inMinutes % 60}m ${_timeLeft!.inSeconds % 60}s",
                                          style: TextStyle(
                                            color: isDarkMode
                                                ? Colors.white
                                                : lBrandMain,
                                            fontSize: 28,
                                            fontWeight: FontWeight.w900,
                                            fontFamily: 'Orbitron',
                                            fontFeatures: const [
                                              FontFeature.tabularFigures()
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // Sponsor Banner (Part of flow now)
                          if (_eventSponsor != null)
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: 20, bottom: 80),
                              child: SponsorBanner(sponsor: _eventSponsor),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Bottom "Back" button
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // DEV BYPASS: Only visible for admin role
                      Consumer<PlayerProvider>(
                        builder: (context, playerProv, _) {
                          final player = playerProv.currentPlayer;
                          if (player == null || !player.isAdmin)
                            return const SizedBox.shrink();
                          return Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 40, vertical: 4),
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade800,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                      color: Colors.orange.shade400,
                                      width: 1.5),
                                ),
                                elevation: 0,
                              ),
                              onPressed: () {
                                _timer?.cancel();
                                widget.onTimerFinished();
                              },
                              icon: const Icon(Icons.developer_mode, size: 18),
                              label: const Text('DEV: Saltar Espera',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                            ),
                          );
                        },
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text("Volver a Escenarios",
                            style: TextStyle(
                                color: isDarkMode
                                    ? Colors.white54
                                    : AppTheme.lBrandMain.withOpacity(0.7))),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ── 5-second launch countdown: shown when online event goes active ──
          if (_isShowingLaunchCountdown)
            Positioned.fill(
              child: EventLaunchCountdownOverlay(
                onComplete: () {
                  if (mounted) widget.onTimerFinished();
                },
              ),
            ),
        ],
      ),
    );
  }
}
