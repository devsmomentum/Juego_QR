import 'dart:math' as math;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../core/services/terms_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:ui';
import 'dart:async'; // Added back
import '../models/scenario.dart';
import '../providers/event_provider.dart';
import '../providers/game_provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../social/screens/profile_screen.dart';
import '../../wallet/providers/payment_method_provider.dart';
import '../../auth/providers/player_inventory_provider.dart';
import '../../../shared/widgets/coin_image.dart';
import '../../../shared/widgets/cyber_tutorial_overlay.dart';
import '../../../shared/widgets/master_tutorial_content.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/power_interfaces.dart';
import '../../../core/providers/app_mode_provider.dart';
import '../providers/game_request_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'code_finder_screen.dart';
import 'game_request_screen.dart';
import '../../auth/screens/avatar_selection_screen.dart';
import 'event_waiting_screen.dart';
import '../models/event.dart';
import '../widgets/safe_image.dart';
import '../../mall/screens/mall_screen.dart';
import '../../mall/screens/merchandise_store_screen.dart';
import '../../auth/screens/login_screen.dart';
import '../../layouts/screens/home_screen.dart';
import '../widgets/scenario_countdown.dart';
import '../../../shared/widgets/animated_cyber_background.dart';
import '../../../core/services/video_preload_service.dart';
import 'winner_celebration_screen.dart';
import 'spectator_mode_screen.dart';
import '../services/game_access_service.dart';
import 'game_mode_selector_screen.dart';
import '../../../shared/widgets/loading_overlay.dart';
import 'training_center_screen.dart';
import '../mappers/scenario_mapper.dart';
import '../../../core/enums/user_role.dart';
import '../../social/screens/wallet_screen.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/utils/global_keys.dart';
import '../services/betting_service.dart';
import '../../../core/services/app_config_service.dart';

class ScenariosScreen extends StatefulWidget {
  final bool isOnline;

  const ScenariosScreen({
    super.key,
    this.isOnline = false, // Default to false (Presential)
  });

  @override
  State<ScenariosScreen> createState() => _ScenariosScreenState();
}

class _ScenariosScreenState extends State<ScenariosScreen>
    with TickerProviderStateMixin, RouteAware {
  late PageController _pageController;
  late AnimationController _hoverController;
  late Animation<Offset> _hoverAnimation;

  // New Controllers
  late AnimationController _shimmerController;
  late AnimationController _glitchController;

  int _currentPage = 0;
  bool _isLoading = true;
  bool _isProcessing = false; // Prevents double taps
  int _navIndex = 1; // Default to Escenarios (index 1)
  String _selectedFilter = 'all'; // Filter state: 'all', 'active', 'pending', 'completed'
  String _selectedModality = 'all'; // Modality: 'all', 'presencial', 'online'
  bool _isShowingModality = true; // Toggle for filter row: true = Modality, false = Status

  // Cache for participant status to show "Entering..." vs "Request Access"
  Map<String, bool> _participantStatusMap = {};

  // Cache for user role to determine button state (Player vs Spectator)
  Map<String, String> _eventRoleMap = {}; // NEW

  // Cache for ban status to show banned button
  Map<String, String?> _banStatusMap = {}; // NEW

  late BettingService _bettingService;
  final Map<String, int> _bettingPotMap = {};
  final Map<String, int> _bettingCountMap = {};
  final Set<String> _bettingLoadingEvents = {};

  // Merchandise store (Tienda) visibility flag
  bool _isMerchandiseStoreEnabled = false;

  // The default user role for scenario selection
  UserRole get role => UserRole.player;
  bool get isDarkMode => true /* always dark UI */;

  void _showLogoutDialog() {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final isDarkMode = playerProvider.isDarkMode;

    _showPremiumExitDialog(
      title: '¿Qué deseas hacer?',
      subtitle: 'Puedes cambiar de modo de juego o cerrar tu sesión.',
      isDarkMode: isDarkMode,
      options: [
        _DialogOption(
          icon: Icons.swap_horiz_rounded,
          label: 'CAMBIAR MODO',
          gradientColors: [AppTheme.dGoldMain, const Color(0xFFE5A700)],
          textColor: Colors.black,
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const GameModeSelectorScreen()),
              (route) => false,
            );
          },
        ),
        _DialogOption(
          icon: Icons.logout_rounded,
          label: 'CERRAR SESIÓN',
          gradientColors: [AppTheme.dangerRed, const Color(0xFFB71C1C)],
          textColor: Colors.white,
          onTap: () async {
            // [FIX] Cerrar el diálogo primero y esperar un instante para evitar "congestion"
            // de animaciones en el Navigator mientras AuthMonitor actúa sobre el Root.
            Navigator.pop(context);
            
            // Un pequeño delay para que la animación de pop comience antes del barrido del monitor
            await Future.delayed(const Duration(milliseconds: 100));
            
            if (context.mounted) {
              playerProvider.logout();
            }
          },
        ),
      ],
    );
  }

  void _showJoinOptionDialog(Scenario scenario) {
    // --- EMAIL VERIFICATION GATE ---
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final player = playerProvider.currentPlayer;
    if (player != null && !player.emailVerified) {
      _showPremiumExitDialog(
        title: 'VERIFICACIÓN REQUERIDA',
        subtitle:
            'Debes verificar tu correo electrónico antes de participar en eventos. '
            'Revisa tu bandeja de entrada.',
        isDarkMode: true,
        options: [
          _DialogOption(
            icon: Icons.edit_outlined,
            label: 'EDITAR CORREO',
            gradientColors: [AppTheme.dGoldMain, const Color(0xFFE5A700)],
            textColor: Colors.black,
            onTap: () {
              Navigator.pop(context);
              // Navigate to profile screen to edit email
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          _DialogOption(
            icon: Icons.refresh_rounded,
            label: 'YA VERIFIQUÉ',
            gradientColors: [AppTheme.dBrandMain, const Color(0xFF7B2CBF)],
            textColor: Colors.white,
            onTap: () async {
              Navigator.pop(context);
              // Consult the profile from DB via provider to check if email was verified
              await playerProvider.reloadProfile();
              if (mounted) {
                final updatedPlayer = playerProvider.currentPlayer;
                if (updatedPlayer != null && updatedPlayer.emailVerified) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('¡Email verificado! Ya puedes participar.'),
                      backgroundColor: AppTheme.successGreen,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Tu email aún no está verificado. Revisa tu bandeja.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              }
            },
          ),
        ],
      );
      return;
    }

    // FORCED TO TRUE: Scenarios screen is always dark
    const isDarkMode = true;
    final isPaid = scenario.entryFee > 0;

    _showPremiumExitDialog(
      title: scenario.name.toUpperCase(),
      subtitle: '¿Cómo deseas participar en esta aventura?',
      isDarkMode: isDarkMode,
      options: [
        _DialogOption(
          icon: isPaid ? Icons.payments_rounded : Icons.sports_esports_rounded,
          label: isPaid ? 'INSCRIBIRSE JUGADOR' : 'MODO JUGADOR',
          gradientColors: [AppTheme.dGoldMain, const Color(0xFFE5A700)],
          textColor: Colors.black,
          onTap: () {
            Navigator.pop(context);
            _onScenarioSelected(scenario);
          },
        ),
        _DialogOption(
          icon: Icons.visibility_rounded,
          label: 'MODO ESPECTADOR',
          gradientColors: [AppTheme.dBrandMain, const Color(0xFF7B2CBF)],
          textColor: Colors.white,
          onTap: () {
            Navigator.pop(context);
            _showSpectatorWarningDialog(scenario);
          },
        ),
      ],
    );
  }

  void _showSpectatorWarningDialog(Scenario scenario) {
    const isDarkMode = true;
    _showPremiumExitDialog(
      title: '¡ADVERTENCIA!',
      subtitle:
          'Si ingresas como espectador, no podrás inscribirte como participante después en este evento.',
      isDarkMode: isDarkMode,
      options: [
        _DialogOption(
          icon: Icons.visibility_rounded,
          label: 'ENTRAR COMO ESPECTADOR',
          gradientColors: [AppTheme.dangerRed, const Color(0xFFB71C1C)],
          textColor: Colors.white,
          onTap: () {
            Navigator.pop(context);
            _onSpectatorSelected(scenario);
          },
        ),
      ],
    );
  }

  /// Reusable premium dialog with glassmorphism and game-style buttons.
  void _showPremiumExitDialog({
    required String title,
    required String subtitle,
    required bool isDarkMode,
    required List<_DialogOption> options,
  }) {
    // FORCED DARK: Always use dark cyberpunk styling for this dialog
    final Color surfaceColor = const Color(0xFF151517).withOpacity(0.95);
    final Color textColor = Colors.white;
    final Color textSecColor = Colors.white70;
    final Color accentColor = AppTheme.dGoldMain;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: anim1,
              curve: Curves.easeOutBack,
            ),
            child: child,
          ),
        );
      },
      pageBuilder: (context, _, __) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: accentColor.withOpacity(0.5),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.15),
                    blurRadius: 30,
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF151517),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: accentColor, width: 2),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon with glow
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              accentColor.withOpacity(0.2),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Icon(
                          Icons.games_rounded,
                          color: accentColor,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Title
                      Text(
                        title,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      // Accent line
                      Container(
                        width: 40,
                        height: 3,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accentColor.withOpacity(0.3),
                              accentColor,
                              accentColor.withOpacity(0.3)
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Subtitle
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: textSecColor,
                          fontSize: 14,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      // Option buttons
                      ...options.map((opt) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                      colors: opt.gradientColors),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: opt.gradientColors.first
                                          .withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton.icon(
                                  icon: Icon(opt.icon, size: 20),
                                  label: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(opt.label,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            letterSpacing: 1)),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    foregroundColor: opt.textColor,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                  ),
                                  onPressed: opt.onTap,
                                ),
                              ),
                            ),
                          )),
                      // Cancel
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancelar',
                          style: TextStyle(
                            color: textSecColor.withOpacity(0.5),
                            fontSize: 13,
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
      },
    );
  }

  void _showAboutDialog() {
    const Color currentOrange = Color(0xFFFF9800);
    const Color cardBg = Color(0xFF151517);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: currentOrange.withOpacity(0.2),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: currentOrange.withOpacity(0.5), width: 1),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: currentOrange, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline, color: currentOrange, size: 40),
                const SizedBox(height: 16),
                const Text('Conócenos',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text(
                  'MapHunter es una experiencia de búsqueda del tesoro con realidad aumentada. ¡Explora, resuelve pistas y compite por premios increíbles!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('ENTENDIDO',
                      style: TextStyle(
                          color: currentOrange, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showTermsDialog() async {
    try {
      final baseUrl =
          dotenv.env['SUPABASE_URL']?.replaceAll(RegExp(r'/$'), '') ?? '';
      final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

      // Usamos el servicio centralizado que maneja el enmascaramiento (Blob URLs)
      final termsService = getTermsService();
      await termsService.launchTerms(baseUrl, anonKey);
    } catch (e) {
      debugPrint('Error al abrir términos: $e');
    }
  }

  void _showSupportDialog() {
    const Color currentOrange = Color(0xFFFF9800);
    const Color cardBg = Color(0xFF151517);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: currentOrange.withOpacity(0.2),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: currentOrange.withOpacity(0.5), width: 1),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: currentOrange, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.support_agent_outlined,
                    color: currentOrange, size: 40),
                const SizedBox(height: 16),
                const Text('Soporte',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text(
                  '¿Necesitas ayuda? Contáctanos a través de nuestro correo de soporte: soporte@maphunter.com',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('ENTENDIDO',
                      style: TextStyle(
                          color: currentOrange, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    print("DEBUG: ScenariosScreen initState");
    // Online mode: show pending (lobby) events by default
    if (widget.isOnline) {
      _selectedFilter = 'all';
      _selectedModality = 'online';
    }

    _bettingService = BettingService(Supabase.instance.client);

    _pageController = PageController(viewportFraction: 0.78);

    // 1. Levitation (Hover) Animation
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _hoverAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -0.05),
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeInOutSine,
    ));

    // 2. Shimmer Border Animation
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // 3. Glitch Text Animation
    _glitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000), // Occurs every 4 seconds
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

      // Tutorial check
      _checkFirstTime();

      // CLEANUP: Ensure we are disconnected from any previous game
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      final playerProvider =
          Provider.of<PlayerProvider>(context, listen: false);
      final powerProvider =
          Provider.of<PowerEffectManager>(context, listen: false);

      debugPrint("🧹 ScenariosScreen: Forcing Game State Cleanup...");
      _cleanupGameState();

      _refreshData();
      // Check merchandise store visibility
      _loadMerchandiseStoreFlag();
      // Empezar a precargar el video del primer avatar para que sea instantáneo
      VideoPreloadService()
          .preloadVideo('assets/escenarios.avatar/explorer_m_scene.mp4');
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route observer to detect when returning to this screen
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route as ModalRoute<void>);
    }

    // Precargar imágenes de fondo para transiciones suaves (con límites de memoria)
    precacheImage(
        const ResizeImage(AssetImage('assets/images/personajesgrupal.png'),
            width: 1024),
        context);
    precacheImage(
        const ResizeImage(AssetImage('assets/images/fotogrupalnoche.png'),
            width: 1024),
        context);
  }

  Future<void> _checkFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    final bool hasSeenTutorial = prefs.getBool('seen_home_tutorial') ?? false;
    if (!hasSeenTutorial) {
      // Eliminar el tutorial inicial de bienvenida según requerimiento
      await prefs.setBool('seen_home_tutorial', true);
    }
  }

  // El tutorial inicial ha sido eliminado a petición.

  /// Cleans up any active game session data to prevent ghost effects or state leaks.
  void _cleanupGameState() {
    if (!mounted) return;
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final powerProvider =
        Provider.of<PowerEffectManager>(context, listen: false);

    debugPrint("🧹 ScenariosScreen: Forcing Game State Cleanup...");

    // Schedule to avoid frame collision during navigation pop
    WidgetsBinding.instance.addPostFrameCallback((_) {
      gameProvider.resetState();
      playerProvider.clearGameContext();
      powerProvider.startListening(null, forceRestart: true);
    });
  }

  Future<void> _loadEvents() async {
    if (!mounted) return;
    print("DEBUG: _loadEvents start");
    setState(() => _isLoading = true);

    try {
      final eventProvider = Provider.of<EventProvider>(context, listen: false);
      final playerProvider =
          Provider.of<PlayerProvider>(context, listen: false);
      final requestProvider =
          Provider.of<GameRequestProvider>(context, listen: false);

      await eventProvider.fetchEvents();

      // Load participation status and ban status for each event
      final userId = playerProvider.currentPlayer?.userId;
      if (userId != null) {
        final Map<String, bool> statusMap = {};
        final Map<String, String?> banMap = {}; // NEW
        final Map<String, String> roleMap = {}; // NEW - Role tracking

        // Fetch all participations in a single query to prevent N+1 bottleneck
        try {
          final allParticipations =
              await requestProvider.getAllUserParticipations(userId);

          // Pre-fill defaults
          for (final event in eventProvider.events) {
            statusMap[event.id] = false;
            banMap[event.id] = null;
            roleMap[event.id] = 'none';
          }

          // Apply actual data
          for (final participation in allParticipations) {
            final eventId = participation['event_id'] as String;
            final status = participation['status'] as String?;

            statusMap[eventId] = true;
            banMap[eventId] = status;

            if (status == 'spectator') {
              roleMap[eventId] = 'spectator';
            } else {
              roleMap[eventId] = 'player';
            }
          }
        } catch (e) {
          debugPrint('Error loading all participations: $e');
          for (final event in eventProvider.events) {
            statusMap[event.id] = false;
            banMap[event.id] = null;
            roleMap[event.id] = 'none';
          }
        }
        if (mounted) {
          setState(() {
            _participantStatusMap = statusMap;
            _banStatusMap = banMap; // NEW
            _eventRoleMap = roleMap; // NEW
          });
        }
      }
    } catch (e) {
      debugPrint('Error in _loadEvents: $e');
    } finally {
      print("DEBUG: _loadEvents end. Mounted: $mounted");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Show tutorial if first time viewing scenarios
        _showScenariosTutorial();
      }
    }
  }

  Future<void> _refreshData() async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    // ⚡ CRÍTICO: Recargar perfil para ver compras recientes (vidas/monedas)
    await playerProvider.reloadProfile();
    await _loadEvents();
  }

  Future<void> _loadMerchandiseStoreFlag() async {
    final configService =
        AppConfigService(supabaseClient: Supabase.instance.client);
    final enabled = await configService.isMerchandiseStoreEnabled();
    if (mounted) {
      setState(() => _isMerchandiseStoreEnabled = enabled);
    }
  }

  String _formatCompactAmount(int amount) {
    if (amount >= 1000000) {
      final value = amount / 1000000.0;
      final compact = value.toStringAsFixed(1);
      return compact.endsWith('.0')
          ? '${compact.substring(0, compact.length - 2)}M'
          : '${compact}M';
    }
    if (amount >= 1000) {
      final value = amount / 1000.0;
      final compact = value.toStringAsFixed(1);
      return compact.endsWith('.0')
          ? '${compact.substring(0, compact.length - 2)}K'
          : '${compact}K';
    }
    return amount.toString();
  }

  Future<void> _ensureBettingStats(String eventId) async {
    if (_bettingPotMap.containsKey(eventId) ||
        _bettingLoadingEvents.contains(eventId)) {
      return;
    }
    _bettingLoadingEvents.add(eventId);
    try {
      final stats = await _bettingService.getEventBettingStats(eventId);
      if (!mounted) return;
      setState(() {
        _bettingPotMap[eventId] = stats['totalPot'] ?? 0;
        _bettingCountMap[eventId] = stats['totalBets'] ?? 0;
      });
    } finally {
      _bettingLoadingEvents.remove(eventId);
    }
  }

  void _showScenariosTutorial() async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    if (!playerProvider.isNewlyRegistered) return;

    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('has_seen_tutorial_SCENARIOS') ?? false;
    if (hasSeen) return;

    final steps =
        MasterTutorialContent.getStepsForSection('SCENARIOS', context);
    if (steps.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => CyberTutorialOverlay(
          steps: steps,
          onFinish: () {
            Navigator.pop(context);
            prefs.setBool('has_seen_tutorial_SCENARIOS', true);
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this); // Unsubscribe from route observer
    _pageController.dispose();
    _hoverController.dispose();
    _shimmerController.dispose();
    _glitchController.dispose();
    // SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge); // REMOVED: Conflicts with Logout transition
    super.dispose();
  }

  @override
  void didPopNext() {
    // This is called when the top route has been popped off, and this route shows up.
    debugPrint("🔄 ScenariosScreen: didPopNext - Refreshing data...");
    _refreshData();
  }

  Future<void> _onScenarioSelected(Scenario scenario) async {
    final isDarkMode = true /* always dark UI */;
    if (_isProcessing) return;

    if (scenario.isCompleted) {
      // Get playerProvider BEFORE async gap
      final playerProvider =
          Provider.of<PlayerProvider>(context, listen: false);

      // RETRIEVE PRIZE from SharedPreferences for completed events
      final prefs = await SharedPreferences.getInstance();
      final prizeWon = prefs.getInt('prize_won_${scenario.id}');
      debugPrint(
          "🏆 Retrieved prize for completed event ${scenario.id}: $prizeWon");

      // Refresh wallet balance to ensure it's current
      await playerProvider.reloadProfile();
      debugPrint(
          "💰 Wallet refreshed. Balance: ${playerProvider.currentPlayer?.clovers}");

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: 'WinnerCelebrationScreen'),
            builder: (_) => WinnerCelebrationScreen(
              eventId: scenario.id,
              playerPosition: 0, // Will be corrected by screen if participant
              totalCluesCompleted: 0,
              prizeWon: prizeWon ?? 0, // Pass 0 if null
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Mostrar diálogo de carga
      LoadingOverlay.show(context);

      final playerProvider =
          Provider.of<PlayerProvider>(context, listen: false);
      final requestProvider =
          Provider.of<GameRequestProvider>(context, listen: false);
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      final inventoryProvider =
          Provider.of<PlayerInventoryProvider>(context, listen: false); // NEW

      // CRITICAL: Clear spectator mode flag before checking access as PLAYER
      // This ensures that users who previously viewed as spectators (including unbanned users)
      // can now enter as normal players
      playerProvider.setSpectatorRole(false);

      final accessService = GameAccessService();

      final result = await accessService.checkAccess(
        context: context,
        scenario: scenario,
        playerProvider: playerProvider,
        requestProvider: requestProvider,
        entryFee: (scenario.entryFee > 0) ? scenario.entryFee.toDouble() : null,
        role: role,
      );

      // Artificial delay for better UX (so loading doesn't flicker)
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;
      LoadingOverlay.hide(context); // Close loading overlay

      // DEBUG: Log the access result type
      debugPrint('🔍 GameAccessService returned type: ${result.type}');
      debugPrint('   - Message: ${result.message}');
      debugPrint('   - Role: ${result.role}');
      debugPrint('   - IsReadOnly: ${result.isReadOnly}');
      debugPrint('   - Data: ${result.data}');

      switch (result.type) {
        case AccessResultType.allowed:
          final isParticipant = result.data?['isParticipant'] ?? false;
          final isApproved = result.data?['isApproved'] ?? false;

          if (isParticipant || isApproved) {
            // Check Avatar
            if (playerProvider.currentPlayer?.avatarId == null ||
                playerProvider.currentPlayer!.avatarId!.isEmpty) {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          AvatarSelectionScreen(eventId: scenario.id)));
            } else {
              // Initialize if needed
              bool success = true;
              if (!isParticipant && isApproved) {
                LoadingOverlay.show(context);
                success = await gameProvider.initializeGameForApprovedUser(
                    playerProvider.currentPlayer!.userId, scenario.id);
                if (mounted) LoadingOverlay.hide(context);
              }

              if (success) {
                // CLEANUP: Prevent Inventory Leak
                if (gameProvider.currentEventId != scenario.id) {
                  debugPrint(
                      '🚫 Event Switch: Cleaning up old state for ${scenario.id}...');
                  inventoryProvider
                      .resetEventState(); // Clean inventory lists (Provider)
                  playerProvider
                      .clearCurrentInventory(); // Clean active inventory (Player model)
                }

                await gameProvider.fetchClues(eventId: scenario.id);
                if (mounted) {
                  Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => HomeScreen(eventId: scenario.id)))
                      .then((_) {
                    _cleanupGameState();
                  });
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Error al inicializar el juego.')));
              }
            }
          }
          break;

        case AccessResultType.deniedPermissions:
        case AccessResultType.deniedForever:
        case AccessResultType.fakeGps:
        case AccessResultType.sessionInvalid:
        case AccessResultType.suspended:
          if (result.message != null) {
            if (result.type == AccessResultType.fakeGps ||
                result.type == AccessResultType.suspended) {
              _showErrorDialog(result.message!,
                  title: result.type == AccessResultType.suspended
                      ? '⛔ Acceso Denegado'
                      : '⛔ Ubicación Falsa');
            } else {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(result.message!)));
            }
          }
          break;

        case AccessResultType.bannedSpectator:
          // CRITICAL: Clear game context to prevent power effects
          // This sets gamePlayerId = null, which triggers the hard gate in SabotageOverlay
          playerProvider.clearGameContext();

          // Navigate directly to spectator mode for banned users
          await gameProvider.fetchClues(eventId: scenario.id);
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SpectatorModeScreen(eventId: scenario.id),
              ),
            );
          }
          break;

        case AccessResultType.requestPendingOrRejected:
          Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => GameRequestScreen(
                      eventId: scenario.id,
                      eventTitle: scenario.name,
                    )),
          );
          break;

        case AccessResultType.needsCode:
          if (scenario.type == 'online') {
            // Online event: Skip CodeFinderScreen entirely
            if (scenario.entryFee > 0) {
              // Online PAID: Handle payment first
              final userClovers = playerProvider.currentPlayer?.clovers ?? 0;
              if (userClovers >= scenario.entryFee) {
                // Has enough -> Confirm payment
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppTheme.cardBg,
                    title: const Text('💰 Evento de Pago',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    content: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Este evento cuesta ${scenario.entryFee} ',
                            style: const TextStyle(color: Colors.white70)),
                        const CoinImage(size: 16),
                        Text('.\n\nTu saldo: $userClovers ',
                            style: const TextStyle(color: Colors.white70)),
                        const CoinImage(size: 16),
                      ],
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar',
                              style: TextStyle(color: Colors.white54))),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentGold,
                            foregroundColor: Colors.black),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('PAGAR Y ENTRAR'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  setState(() => _isProcessing = true);
                  LoadingOverlay.show(context);

                  final result = await requestProvider.joinOnlinePaidEvent(
                      playerProvider.currentPlayer!.userId,
                      scenario.id,
                      scenario.entryFee);

                  // Artificial delay for specific online join action
                  await Future.delayed(const Duration(seconds: 2));

                  if (!mounted) return;
                  LoadingOverlay.hide(context);

                  final success = result['success'] == true;
                  if (success) {
                    final newBalance = (result['new_balance'] as num?)?.toInt();
                    if (newBalance != null) {
                      playerProvider.updateLocalClovers(newBalance);
                    } else {
                      playerProvider
                          .updateLocalClovers(userClovers - scenario.entryFee);
                    }
                    await playerProvider.refreshProfile();
                    setState(() {
                      _participantStatusMap[scenario.id] = true;
                    });

                    await gameProvider.fetchClues(eventId: scenario.id);
                    if (mounted) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  HomeScreen(eventId: scenario.id)));
                    }
                  } else {
                    final error = result['error'] ?? 'Error desconocido';
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(error == 'PAYMENT_FAILED'
                            ? 'Saldo insuficiente al procesar el pago.'
                            : 'Error procesando el pago.')));
                  }
                  setState(() => _isProcessing = false);
                }
              } else {
                // Insufficient funds
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppTheme.cardBg,
                    title: const Text('Saldo Insuficiente',
                        style: TextStyle(
                            color: AppTheme.dangerRed,
                            fontWeight: FontWeight.bold)),
                    content: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Este evento cuesta ${scenario.entryFee} ',
                            style: const TextStyle(color: Colors.white70)),
                        const CoinImage(size: 16),
                        Text('.\nSolo tienes $userClovers ',
                            style: const TextStyle(color: Colors.white70)),
                        const CoinImage(size: 16),
                        const Text('.',
                            style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cerrar')),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryPurple),
                        icon: const Icon(Icons.account_balance_wallet),
                        label: const Text('IR A BILLETERA'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const WalletScreen()));
                        },
                      ),
                    ],
                  ),
                );
              }
            } else {
              // Online FREE: Join directly and enter game
              LoadingOverlay.show(context);

              try {
                // Create game_player record for free online event
                await requestProvider.joinFreeOnlineEvent(
                    playerProvider.currentPlayer!.userId, scenario.id);

                // Artificial delay for specific online join action
                await Future.delayed(const Duration(seconds: 2));

                setState(() {
                  _participantStatusMap[scenario.id] = true;
                });

                await gameProvider.fetchClues(eventId: scenario.id);
                if (mounted) {
                  LoadingOverlay.hide(context); // Close loading
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => HomeScreen(eventId: scenario.id)));
                }
              } catch (e) {
                if (mounted)
                  LoadingOverlay.hide(
                      context); // Close loading despite error so we can show snackbar
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al ingresar: $e')));
              }
            }
          } else {
            // Presencial event: Show CodeFinderScreen (thermometer + QR)
            Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => CodeFinderScreen(scenario: scenario)),
            );
          }
          break;

        case AccessResultType.needsAvatar:
          // Should be handled in allowed logic usually, but if separated:
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => AvatarSelectionScreen(eventId: scenario.id)));
          break;

        case AccessResultType.approvedWait:
          break;

        case AccessResultType.needsPayment:
          final entryFee = (result.data?['entryFee'] as num?)?.toInt() ?? 0;
          final userClovers = playerProvider.currentPlayer?.clovers ?? 0;

          if (userClovers >= entryFee) {
            if (scenario.type == 'online') {
              // ── ONLINE PAID: Atomic payment + join via RPC ──
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppTheme.cardBg,
                  title: const Text('Confirmar Inscripción',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Este evento tiene un costo de $entryFee ',
                              style: const TextStyle(color: Colors.white70)),
                          const CoinImage(size: 16),
                          const Text('.',
                              style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('Tu saldo: $userClovers ',
                              style: const TextStyle(color: Colors.white70)),
                          const CoinImage(size: 16),
                        ],
                      ),
                      Row(
                        children: [
                          Text('Despues del pago: ${userClovers - entryFee} ',
                              style: const TextStyle(color: Colors.white70)),
                          const CoinImage(size: 16),
                        ],
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar',
                          style: TextStyle(color: Colors.white54)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentGold,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('PAGAR Y ENTRAR'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                setState(() => _isProcessing = true);
                LoadingOverlay.show(context);

                final joinResult = await requestProvider.joinOnlinePaidEvent(
                    playerProvider.currentPlayer!.userId,
                    scenario.id,
                    entryFee);

                if (!mounted) return;
                LoadingOverlay.hide(context);

                if (joinResult['success'] == true) {
                  final newBalance =
                      (joinResult['new_balance'] as num?)?.toInt();
                  if (newBalance != null) {
                    playerProvider.updateLocalClovers(newBalance);
                  } else {
                    playerProvider.updateLocalClovers(userClovers - entryFee);
                  }
                  await playerProvider.refreshProfile();

                  setState(() {
                    _participantStatusMap[scenario.id] = true;
                  });

                  if (mounted) {
                    final gameProvider =
                        Provider.of<GameProvider>(context, listen: false);
                    await gameProvider.fetchClues(eventId: scenario.id);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => HomeScreen(eventId: scenario.id)),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(joinResult['error'] == 'PAYMENT_FAILED'
                            ? 'Saldo insuficiente al procesar.'
                            : 'Error al inscribirse. Intenta de nuevo.')),
                  );
                }
                setState(() => _isProcessing = false);
              }
            } else {
              // ── ON-SITE PAID: Navigate directly to CodeFinder ──
              // Payment warning and request submission will happen AFTER scanning the QR code.
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => CodeFinderScreen(scenario: scenario)),
              );
            }
          } else {
            // Caso 2: Saldo Insuficiente -> Redirigir Wallet
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppTheme.cardBg,
                title: const Text('Saldo Insuficiente',
                    style: TextStyle(
                        color: AppTheme.dangerRed,
                        fontWeight: FontWeight.bold)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Este evento cuesta $entryFee ',
                            style: const TextStyle(color: Colors.white70)),
                        const CoinImage(size: 16),
                        const Text('.',
                            style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                    Row(
                      children: [
                        Text('Solo tienes $userClovers ',
                            style: const TextStyle(color: Colors.white70)),
                        const CoinImage(size: 16),
                        const Text(' disponibles.',
                            style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar',
                        style: TextStyle(color: Colors.white54)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPurple,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.account_balance_wallet),
                    label: const Text('IR A BILLETERA'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WalletScreen()),
                      );
                    },
                  ),
                ],
              ),
            );
          }
          break;

        case AccessResultType.spectatorAllowed:
          // Si el usuario quería entrar como jugador (rol default) pero el servicio
          // devolvió espectador, significa que el evento está lleno (u otra razón).
          // Mostramos diálogo de confirmación.
          if (role == UserRole.player) {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) {
                final isDarkMode = Theme.of(ctx).brightness == Brightness.dark;
                return BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Dialog(
                    backgroundColor: Colors.transparent,
                    insetPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 24),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryPink.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                            color: AppTheme.secondaryPink.withOpacity(0.5),
                            width: 1),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF151517),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: AppTheme.secondaryPink, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.secondaryPink.withOpacity(0.1),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header area with a subtle glow (Restaurado)
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: AppTheme.secondaryPink
                                        .withOpacity(0.05),
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(22)),
                                  ),
                                ),
                                Column(
                                  children: [
                                    const SizedBox(height: 20),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            AppTheme.secondaryPink,
                                            AppTheme.secondaryPink
                                                .withOpacity(0.7),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppTheme.secondaryPink
                                                .withOpacity(0.4),
                                            blurRadius: 15,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.group_off_rounded,
                                        color: Colors.white,
                                        size: 36,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            Text(
                              '¡EVENTO LLENO!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.0,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Content
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 30),
                              child: Column(
                                children: [
                                  Text(
                                    result.message ??
                                        'El cupo de jugadores activos (${scenario.maxPlayers}) ha sido alcanzado.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No te preocupes, aún puedes vivir la experiencia desde el modo espectador.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      height: 1.6,
                                    ),
                                  ),
                                  const SizedBox(height: 32),

                                  // Main Button (Restaurado con degradado original)
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            AppTheme.secondaryPink,
                                            Color(0xFFFF4081)
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppTheme.secondaryPink
                                                .withOpacity(0.35),
                                            blurRadius: 12,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.visibility_rounded,
                                                color: Colors.white),
                                            SizedBox(width: 12),
                                            Text(
                                              'MODO ESPECTADOR',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 1.2,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Cancel Button (Restaurado)
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white38,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12, horizontal: 24),
                                    ),
                                    child: const Text(
                                      'VOLVER AL INICIO',
                                      style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );

            if (confirm != true) return;
          }

          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SpectatorModeScreen(eventId: scenario.id),
            ),
          );
          break;
      }
    } catch (e, stackTrace) {
      debugPrint('ScenariosScreen: CRITICAL ERROR: $e');
      debugPrint(stackTrace.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _onSpectatorSelected(Scenario scenario) async {
    if (_isProcessing) return;

    if (scenario.isCompleted) {
      // Direct navigation to results screen for finished events
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: 'WinnerCelebrationScreen'),
            builder: (_) => WinnerCelebrationScreen(
              eventId: scenario.id,
              playerPosition: 0,
              totalCluesCompleted: 0,
              prizeWon: 0,
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final playerProvider =
          Provider.of<PlayerProvider>(context, listen: false);

      // Diálogo de carga
      LoadingOverlay.show(context);

      // 1. Set role to spectator (local)
      playerProvider.setSpectatorRole(true);

      // 2. Join as ghost player
      await playerProvider.joinAsSpectator(scenario.id);

      if (!mounted) return;
      LoadingOverlay.hide(context); // Close loading overlay

      // 3. Navigate to Spectator Screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SpectatorModeScreen(eventId: scenario.id),
        ),
      );
    } catch (e) {
      debugPrint('Error joining spectator mode: $e');
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted)
        setState(() {
          _isProcessing = false;
        });
    }
  }

  void _showErrorDialog(String msg, {String title = 'Atención'}) {
    // FORCED TO TRUE: Scenarios screen is always dark
    const isDarkMode = true;
    final Color currentText =
        isDarkMode ? Colors.white : const Color(0xFF1A1A1D);
    final Color currentCard =
        isDarkMode ? AppTheme.dSurface1 : AppTheme.lSurface1;

    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: currentCard,
              title: Text(title,
                  style: const TextStyle(
                      color: AppTheme.dangerRed, fontWeight: FontWeight.bold)),
              content: Text(
                msg,
                style: TextStyle(color: currentText),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Entendido',
                        style: TextStyle(
                            color: isDarkMode
                                ? AppTheme.dGoldMain
                                : AppTheme.lBrandMain)))
              ],
            ));
  }

  void _showComingSoonDialog(String featureName) {
    const Color purpleAccent = Color(0xFF9D4EDD);
    const Color cardBg = Color(0xFF151517);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: purpleAccent.withOpacity(0.2),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: purpleAccent.withOpacity(0.5), width: 1),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: purpleAccent, width: 2),
              boxShadow: [
                BoxShadow(
                  color: purpleAccent.withOpacity(0.1),
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
                    border: Border.all(color: purpleAccent, width: 2),
                    color: purpleAccent.withOpacity(0.1),
                  ),
                  child: const Icon(Icons.construction,
                      color: purpleAccent, size: 32),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Próximamente',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Orbitron',
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'La sección "$featureName" estará disponible muy pronto. ¡Mantente atento a las actualizaciones!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: purpleAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'ENTENDIDO',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Orbitron',
                        letterSpacing: 1.2,
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

  Widget _buildBottomNavBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF000000).withOpacity(0.4),
            border: const Border(
              top: BorderSide(
                color: AppTheme.dGoldMain,
                width: 1.0, // Moderately thicker as requested
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(
                  left: 16, right: 16, top: 4, bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, Icons.sports_esports_outlined, 'Modos'),
                  _buildNavItem(1, Icons.explore_outlined, 'Escenarios'),
                  _buildNavItem(
                      2, Icons.account_balance_wallet_outlined, 'Wallet'),
                  if (_isMerchandiseStoreEnabled)
                    _buildNavItem(3, Icons.storefront_outlined, 'Tienda'),
                  _buildNavItem(4, Icons.person_outline, 'Perfil'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _navIndex == index;
    final activeColor = AppTheme.dGoldMain;

    if (isSelected) {
      // SELECTED STATE - Restored Cyberpunk Style
      return GestureDetector(
        onTap: () {
          // Refresh data if switching to Scenarios tab (index 1) from another tab
          if (index == 1 && _navIndex != 1) {
            _loadEvents();
          }
          setState(() => _navIndex = index);
        },
        child: Container(
          width: 85,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: activeColor.withOpacity(0.1),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(5),
              bottomRight: Radius.circular(5),
            ),
            border: Border.all(
              color: activeColor,
              width: 1.0, // Matching line thickness
            ),
            boxShadow: [
              BoxShadow(
                color: activeColor.withOpacity(0.4),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: activeColor,
                size: 20,
                shadows: [
                  Shadow(color: activeColor.withOpacity(0.8), blurRadius: 8)
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                    color: activeColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 9,
                    fontFamily: 'Avenir',
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(color: activeColor.withOpacity(0.5), blurRadius: 4)
                    ]),
              ),
            ],
          ),
        ),
      );
    } else {
      // UNSELECTED STATE
      return GestureDetector(
        onTap: () {
          // Refresh data if switching to Scenarios tab (index 1) from another tab
          if (index == 1 && _navIndex != 1) {
            _loadEvents();
          }
          setState(() => _navIndex = index);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.transparent,
          child: Icon(
            icon,
            color: Colors.white70,
            size: 22,
          ),
        ),
      );
    }
  }

  /// Builds a custom button for banned users that navigates to spectator mode
  Widget _buildBannedButton(Scenario scenario) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.shade900.withOpacity(0.9),
            Colors.orange.shade800.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.red.shade300.withOpacity(0.8),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () async {
          // CRITICAL: Navigate directly without validation flow
          final playerProvider =
              Provider.of<PlayerProvider>(context, listen: false);
          final gameProvider =
              Provider.of<GameProvider>(context, listen: false);

          // Clear game context to prevent power effects
          playerProvider.clearGameContext();

          // Fetch clues for spectator view
          await gameProvider.fetchClues(eventId: scenario.id);

          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SpectatorModeScreen(eventId: scenario.id),
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_outlined, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              "🚫 SUSPENDIDO - OBSERVAR",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print("DEBUG: ScenariosScreen build. isLoading: $_isLoading");
    final eventProvider = Provider.of<EventProvider>(context);
    final appMode = Provider.of<AppModeProvider>(context);
    final playerProvider = Provider.of<PlayerProvider>(context);
    // FORCED TO TRUE: Always use dark mode colors in scenarios section (including dialogs)
    final isDarkMode = true; // Previously: playerProvider.isDarkMode;

    // Colores según el modo
    final Color currentBg =
        isDarkMode ? AppTheme.dSurface0 : AppTheme.lSurface0;
    final Color currentText =
        isDarkMode ? Colors.white : const Color(0xFF1A1A1D);

    // FILTRAR EVENTOS SEGÚN LA MODALIDAD SELECCIONADA
    List<GameEvent> visibleEvents = eventProvider.events;
    if (_selectedModality == 'online') {
      visibleEvents = visibleEvents.where((e) => e.type.toLowerCase() == 'online').toList();
    } else if (_selectedModality == 'presencial') {
      visibleEvents = visibleEvents.where((e) => e.type.toLowerCase() != 'online').toList();
    }

    // APLICAR FILTRO DE ESTADO
    visibleEvents = visibleEvents.where((e) {
      if (_selectedFilter == 'all') return true; // Mostrar todos los activos y pendientes
      if (_selectedFilter == 'completed') return e.status == 'completed';
      if (_selectedFilter == 'active') return e.status == 'active';
      if (_selectedFilter == 'pending') return e.status == 'pending';
      return false;
    }).toList();

    // Si el filtro es "Todos", ocultamos los ya finalizados para mantener el lobby limpio
    if (_selectedFilter == 'all') {
      visibleEvents = visibleEvents.where((e) => e.status != 'completed').toList();
    }

    if (_selectedFilter == 'completed') {
      visibleEvents = visibleEvents.take(5).toList();
    }

    // Convertir Eventos a Escenarios usando Mapper
    final List<Scenario> scenarios = ScenarioMapper.fromEvents(visibleEvents);

    final Color currentBrandDeep =
        isDarkMode ? AppTheme.dBrandDeep : AppTheme.lBrandSurface;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        _showPremiumExitDialog(
          title: '¿Qué deseas hacer?',
          subtitle: 'Puedes cambiar de modo de juego o salir de la aplicación.',
          isDarkMode: isDarkMode,
          options: [
            _DialogOption(
              icon: Icons.swap_horiz_rounded,
              label: 'CAMBIAR MODO',
              gradientColors: [AppTheme.dGoldMain, const Color(0xFFE5A700)],
              textColor: Colors.black,
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (_) => const GameModeSelectorScreen()),
                  (route) => false,
                );
              },
            ),
            _DialogOption(
              icon: Icons.exit_to_app_rounded,
              label: 'SALIR DE LA APP',
              gradientColors: [AppTheme.dangerRed, const Color(0xFFB71C1C)],
              textColor: Colors.white,
              onTap: () {
                Navigator.pop(context);
                SystemNavigator.pop();
              },
            ),
          ],
        );
      },
      child: AnimatedCyberBackground(
        child: Stack(
          children: [
            // Fondo con imagen dinámica (Diferente para Día y Noche)
            Positioned.fill(
              child: Image.asset(
                playerProvider.isDarkMode
                    ? 'assets/images/fotogrupalnoche.png'
                    : 'assets/images/personajesgrupal.png',
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
            // Overlay oscuro para mejorar legibilidad sobre la imagen
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.6),
              ),
            ),
            Scaffold(
              backgroundColor:
                  Colors.transparent, // Transparente para ver el fondo animado
              extendBody: true,
              bottomNavigationBar: SafeArea(
                bottom: true,
                child: _buildBottomNavBar(),
              ),
              body: (playerProvider.currentPlayer != null &&
                      !playerProvider.currentPlayer!.emailVerified &&
                      _navIndex != 4)
                  ? _buildVerificationBlock()
                  : IndexedStack(
                      index: _navIndex,
                      children: [
                        _buildLocalSection(),
                        _buildScenariosContent(scenarios),
                        // WalletScreen and ProfileScreen are separate widgets,
                        // their RefreshIndicators should be implemented within their own files.
                        WalletScreen(hideScaffold: true),
                        if (_isMerchandiseStoreEnabled)
                          const MerchandiseStoreScreen()
                        else
                          const SizedBox.shrink(),
                        const ProfileScreen(hideScaffold: true),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationBlock() {
    final currentAction = AppTheme.dGoldMain;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.mark_email_unread_outlined,
              color: AppTheme.accentGold, size: 80),
          const SizedBox(height: 24),
          const Text(
            "VERIFICACIÓN REQUERIDA",
            style: TextStyle(
              fontFamily: 'Orbitron',
              color: AppTheme.accentGold,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            "Debes verificar tu correo electrónico antes de acceder a las diferentes secciones.\n\nRevisa tu bandeja de entrada o dirígete a tu perfil para actualizar o reenviar el enlace de verificación.",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: () => setState(() => _navIndex = 4),
            icon: const Icon(Icons.person),
            label: const Text('IR A MI PERFIL'),
            style: ElevatedButton.styleFrom(
              backgroundColor: currentAction,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () async {
              final playerProvider =
                  Provider.of<PlayerProvider>(context, listen: false);

              // Just consult the provider which re-fetches from DB
              await playerProvider.reloadProfile();
              if (mounted) {
                final updatedPlayer = playerProvider.currentPlayer;
                if (updatedPlayer != null && updatedPlayer.emailVerified) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text("Email verificado correctamente. ¡Bienvenido!"),
                      backgroundColor: AppTheme.successGreen,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Aún no has verificado tu email."),
                      backgroundColor: AppTheme.dangerRed,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.refresh),
            label: const Text('YA VERIFIQUÉ'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        children: [
          const Text(
            "MODOS",
            style: TextStyle(
              fontFamily: 'Orbitron',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.dGoldMain,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "¿Cómo deseas jugar hoy?",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 40),
          _buildModeCard(
            title: "MODO PRESENCIAL",
            description: "Aventura real con GPS y códigos QR.",
            icon: Icons.location_on_outlined,
            color: AppTheme.dGoldMain,
            onTap: () {
              // ACTUALIZAR PROVIDER GLOBAL
              context.read<AppModeProvider>().setMode(GameMode.presencial);

              // Navegar a escenarios (flujo normal)
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ScenariosScreen(isOnline: false)));
            },
          ),
          const SizedBox(height: 16),
          _buildModeCard(
            title: "MODO ONLINE",
            description: "Juega desde cualquier lugar con PIN.",
            icon: Icons.wifi,
            color: const Color(0xFF00F0FF),
            onTap: () {
              // ACTUALIZAR PROVIDER GLOBAL
              context.read<AppModeProvider>().setMode(GameMode.online);

              // Navegar a escenarios o input de PIN
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ScenariosScreen(isOnline: true)));
            },
          ),
          const SizedBox(height: 16),
          /*_buildModeCard(
            title: "MODO ENTRENAMIENTO",
            description: "Practica los minijuegos sin riesgo.",
            icon: Icons.model_training,
            color: AppTheme.successGreen,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TrainingCenterScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),*/
          _buildModeCard(
            title: "MODO LOCAL",
            description: "Juega en casa con amigos. Próximamente.",
            icon: Icons.home_outlined,
            color: const Color(0xFF9D4EDD),
            onTap: () => _showComingSoonDialog("Modo Local"),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(4), // Space for double border effect
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF150826).withOpacity(0.5),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: color.withOpacity(0.6),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.1),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withOpacity(0.1),
                      border:
                          Border.all(color: color.withOpacity(0.3), width: 1.5),
                    ),
                    child: Icon(icon, color: color, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Orbitron',
                            fontSize: 15,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: color.withOpacity(0.6), size: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComingSoonContent(String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.construction, color: AppTheme.accentGold, size: 80),
          const SizedBox(height: 24),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.accentGold,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 24),
          const Text("PRÓXIMAMENTE",
              style: TextStyle(
                color: Colors.white70,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              )),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => setState(() => _navIndex = 1),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGold,
              foregroundColor: Colors.black,
            ),
            child: const Text('VOLVER A ESCENARIOS'),
          ),
        ],
      ),
    );
  }

  /*Widget _buildTrainingSwipeCard(BoxConstraints constraints) {
    const isDarkMode = true;
    final Color currentAction = AppTheme.successGreen;

    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        double value = 1.0;
        if (_pageController.position.haveDimensions) {
          value = (_pageController.page! - 0).abs();
          value = (1 - (value * 0.3)).clamp(0.0, 1.0);
        } else {
          value = _currentPage == 0 ? 1.0 : 0.7;
        }
        return Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height:
                Curves.easeOut.transform(value) * constraints.maxHeight * 0.88,
            width: Curves.easeOut.transform(value) * 300,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TrainingCenterScreen()),
          );
        },
        child: Stack(
          children: [
            // Background Image (Using a clear group photo for training context)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/images/mision_iniciacion.jpg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.85),
                    ],
                  ),
                ),
              ),
            ),

            // Status Badge
            Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.successGreen.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.model_training, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'MODO ENTRENAMIENTO',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Text Content
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(16.0), // Reduced from 24
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      "CENTRO DE PRÁCTICA",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.0, // Slightly reduced from 22
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Orbitron',
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 2), // Even smaller
                    const Text(
                      "Domina los minijuegos antes de ir por el tesoro real.",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11, // Reduced font
                        height: 1.2,
                      ),
                      maxLines: 1, // Only 1 line
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8), // Reduced spacing

                    // Main Action Button
                    SizedBox(
                      height: 44, // Reduced from 50
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const TrainingCenterScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 8,
                          shadowColor: AppTheme.successGreen.withOpacity(0.5),
                        ),
                        child: const Text(
                          "ENTRENAR AHORA",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
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
    );
  }*/


  Widget _buildScenariosContent(List<Scenario> scenarios) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    // FORCED TO TRUE: Always use dark mode colors in scenarios/simulator section
    final isDarkMode = true; // Previously: playerProvider.isDarkMode;

    // Colores dinámicos (ahora siempre serán los del modo oscuro)
    final Color currentSurface =
        isDarkMode ? AppTheme.dSurface1 : AppTheme.lSurface1;
    final Color currentText =
        isDarkMode ? Colors.white : const Color(0xFF1A1A1D);
    final Color currentTextSec =
        isDarkMode ? Colors.white70 : const Color(0xFF4A4A5A);
    final Color currentBrand =
        isDarkMode ? AppTheme.dBrandMain : AppTheme.lBrandMain;
    final Color currentBrandDeep =
        isDarkMode ? AppTheme.dBrandDeep : AppTheme.lBrandSurface;
    final Color currentAction =
        isDarkMode ? AppTheme.dGoldMain : AppTheme.lBrandMain;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, viewportConstraints) {
          return RefreshIndicator(
            onRefresh: _loadEvents,
            color: currentAction,
            backgroundColor: currentSurface,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: viewportConstraints.maxHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Custom AppBar
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                          20, MediaQuery.of(context).padding.top + 20, 20, 0),
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          const SizedBox(height: 50), // Reduced header space
                          // Removed "Búsqueda del tesoro" from here to move it lower
                          Positioned(
                            left: 0,
                            top: 0,
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                dividerTheme: DividerThemeData(
                                  color: currentText.withOpacity(0.1),
                                  thickness: 1,
                                ),
                              ),
                              child: PopupMenuButton<String>(
                                icon: Icon(Icons.menu,
                                    color: currentText, size: 28),
                                color: currentSurface.withOpacity(0.95),
                                elevation: 15,
                                offset: const Offset(0, 45),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                      color: currentAction, width: 1.5),
                                ),
                                onSelected: (value) {
                                  switch (value) {
                                    case 'profile':
                                      setState(() {
                                        _navIndex = 4;
                                      });
                                      break;
                                    case 'about':
                                      _showAboutDialog();
                                      break;
                                    case 'terms':
                                      _showTermsDialog();
                                      break;
                                    case 'support':
                                      _showSupportDialog();
                                      break;
                                    case 'logout':
                                      _showLogoutDialog();
                                      break;
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                      value: 'profile',
                                      child: Row(children: [
                                        Icon(Icons.person, color: currentBrand),
                                        const SizedBox(width: 12),
                                        Text('Perfil',
                                            style:
                                                TextStyle(color: currentText))
                                      ])),
                                  PopupMenuItem(
                                      value: 'about',
                                      child: Row(children: [
                                        Icon(Icons.info_outline,
                                            color: currentBrand),
                                        const SizedBox(width: 12),
                                        Text('Conócenos',
                                            style:
                                                TextStyle(color: currentText))
                                      ])),
                                  PopupMenuItem(
                                      value: 'terms',
                                      child: Row(children: [
                                        Icon(Icons.description_outlined,
                                            color: currentBrand),
                                        const SizedBox(width: 12),
                                        Text('Términos',
                                            style:
                                                TextStyle(color: currentText))
                                      ])),
                                  PopupMenuItem(
                                      value: 'support',
                                      child: Row(children: [
                                        Icon(Icons.support_agent_outlined,
                                            color: currentBrand),
                                        const SizedBox(width: 12),
                                        Text('Soporte',
                                            style:
                                                TextStyle(color: currentText))
                                      ])),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            right: 50, // Adjusted to make space for refresh
                            top: 10,
                            child: GestureDetector(
                              onTap: _showLogoutDialog,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppTheme.dangerRed.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.dangerRed.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppTheme.dangerRed,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            AppTheme.dangerRed.withOpacity(0.3),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      )
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.logout_rounded,
                                    color: AppTheme.dangerRed,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: 10,
                            child: GestureDetector(
                              onTap:
                                  _refreshData, // Call _refreshData to refresh
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: currentAction.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: currentAction.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: currentAction,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: currentAction.withOpacity(0.3),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      )
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.refresh_rounded,
                                    color: currentAction,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Center(
                      child: Image.asset(
                        'assets/images/logo4.1.png',
                        height: 110, // Further reduced to free vertical space
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 4), // Reduced spacer

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

                    const SizedBox(height: 8), // Gap between both texts

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Center(
                        child: Text(
                          "ELIGE TU AVENTURA",
                          style: TextStyle(
                              color: currentAction,
                              fontSize: 18, // Reduced size
                              fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                                 // CONTROLES DE FILTRO INTERACTIVOS Y CENTRADOS
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // BOTÓN SELECTOR (IZQUIERDA)
                          GestureDetector(
                            onTap: () {
                              setState(() => _isShowingModality = !_isShowingModality);
                              HapticFeedback.mediumImpact();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _isShowingModality 
                                  ? AppTheme.dGoldMain.withOpacity(0.1) 
                                  : AppTheme.primaryPurple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _isShowingModality ? AppTheme.dGoldMain : AppTheme.primaryPurple,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_isShowingModality ? AppTheme.dGoldMain : AppTheme.primaryPurple).withOpacity(0.2),
                                    blurRadius: 8,
                                  )
                                ],
                              ),
                              child: Icon(
                                _isShowingModality ? Icons.tune_rounded : Icons.layers_outlined,
                                color: _isShowingModality ? AppTheme.dGoldMain : AppTheme.primaryPurple,
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          
                          // LISTADO DE CHIPS (ANIMADO)
                          Flexible(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              transitionBuilder: (Widget child, Animation<double> animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0.1, 0),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              child: _isShowingModality 
                                ? Row(
                                    key: const ValueKey('modality_filters'),
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildFilterChip(
                                        label: 'Todos',
                                        isActive: _selectedModality == 'all',
                                        onTap: () => setState(() => _selectedModality = 'all'),
                                        activeColor: AppTheme.dGoldMain,
                                        textColor: Colors.black,
                                        fontSize: 10,
                                      ),
                                      const SizedBox(width: 6),
                                      _buildFilterChip(
                                        label: 'Presencial',
                                        isActive: _selectedModality == 'presencial',
                                        onTap: () => setState(() => _selectedModality = 'presencial'),
                                        activeColor: AppTheme.dBrandMain,
                                        textColor: Colors.white,
                                        fontSize: 10,
                                      ),
                                      const SizedBox(width: 6),
                                      _buildFilterChip(
                                        label: 'Online',
                                        isActive: _selectedModality == 'online',
                                        onTap: () => setState(() => _selectedModality = 'online'),
                                        activeColor: AppTheme.primaryPurple,
                                        textColor: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ],
                                  )
                                : Row(
                                    key: const ValueKey('status_filters'),
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildFilterChip(
                                        label: 'Todos',
                                        isActive: _selectedFilter == 'all',
                                        onTap: () => setState(() => _selectedFilter = 'all'),
                                        activeColor: AppTheme.dGoldMain,
                                        textColor: Colors.black,
                                        fontSize: 10,
                                      ),
                                      const SizedBox(width: 6),
                                      _buildFilterChip(
                                        label: 'En curso',
                                        isActive: _selectedFilter == 'active',
                                        onTap: () => setState(() => _selectedFilter = 'active'),
                                        activeColor: AppTheme.successGreen,
                                        textColor: Colors.white,
                                        fontSize: 10,
                                      ),
                                      const SizedBox(width: 6),
                                      _buildFilterChip(
                                        label: 'Próximos',
                                        isActive: _selectedFilter == 'pending',
                                        onTap: () => setState(() => _selectedFilter = 'pending'),
                                        activeColor: Colors.blueAccent,
                                        textColor: Colors.white,
                                        fontSize: 10,
                                      ),
                                      const SizedBox(width: 6),
                                      _buildFilterChip(
                                        label: 'Finalizados',
                                        isActive: _selectedFilter == 'completed',
                                        onTap: () => setState(() => _selectedFilter = 'completed'),
                                        activeColor: Colors.grey.shade700,
                                        textColor: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ],
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return _isLoading
                              ? const Center(child: LoadingIndicator())
                              : scenarios.isEmpty
                                  ? Center(
                                      child: Text(
                                          "No hay competencias disponibles",
                                          style:
                                              TextStyle(color: currentTextSec)))
                                  : ScrollConfiguration(
                                      behavior: ScrollConfiguration.of(context)
                                          .copyWith(dragDevices: {
                                        PointerDeviceKind.touch,
                                        PointerDeviceKind.mouse
                                      }),
                                      child: RefreshIndicator(
                                        onRefresh: _refreshData,
                                        color: AppTheme.accentGold,
                                        backgroundColor:
                                            const Color(0xFF151517),
                                        child: PageView.builder(
                                          controller: _pageController,
                                          onPageChanged: (index) => setState(
                                              () => _currentPage = index),
                                          itemCount: scenarios.length, // + 1
                                          itemBuilder: (context, index) {
                                            /*if (index == 0) {
                                              return _buildTrainingSwipeCard(
                                                  constraints);
                                            }*/
                                            final scenarioIndex = index; // - 1
                                            final scenario =
                                                scenarios[scenarioIndex];
                                            _ensureBettingStats(scenario.id);
                                            return AnimatedBuilder(
                                              animation: _pageController,
                                              builder: (context, child) {
                                                double value = 1.0;
                                                if (_pageController
                                                    .position.haveDimensions) {
                                                  value =
                                                      (_pageController.page! -
                                                              index)
                                                          .abs();
                                                  value = (1 - (value * 0.3))
                                                      .clamp(0.0, 1.0);
                                                } else {
                                                  value = index == _currentPage
                                                      ? 1.0
                                                      : 0.7;
                                                }
                                                return Align(
                                                  alignment:
                                                      Alignment.bottomCenter,
                                                  child: SizedBox(
                                                    height: Curves.easeOut
                                                            .transform(value) *
                                                        constraints.maxHeight *
                                                        0.88,
                                                    width: Curves.easeOut
                                                            .transform(value) *
                                                        300,
                                                    child: child,
                                                  ),
                                                );
                                              },
                                              child: GestureDetector(
                                                onTap: () {
                                                  if (_banStatusMap[
                                                              scenario.id] !=
                                                          'banned' &&
                                                      _banStatusMap[
                                                              scenario.id] !=
                                                          'suspended') {
                                                    if (scenario.isCompleted) {
                                                      _onScenarioSelected(
                                                          scenario);
                                                    } else {
                                                      final role =
                                                          _eventRoleMap[
                                                              scenario.id];
                                                      if (role == 'player') {
                                                        _onScenarioSelected(
                                                            scenario);
                                                      } else if (role ==
                                                          'spectator') {
                                                        _onSpectatorSelected(
                                                            scenario);
                                                      } else {
                                                        _showJoinOptionDialog(
                                                            scenario);
                                                      }
                                                    }
                                                  }
                                                },
                                                child: Stack(
                                                  children: [
                                                    // Background Image and Gradient
                                                    Positioned.fill(
                                                      child: ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(24),
                                                        child: SafeNetworkImage(
                                                          url: scenario.imageUrl,
                                                          height: double.infinity,
                                                          fit: BoxFit.cover,
                                                        ),
                                                      ),
                                                    ),
                                                    Positioned.fill(
                                                      child: DecoratedBox(
                                                        decoration: BoxDecoration(
                                                          borderRadius:
                                                              BorderRadius.circular(24),
                                                          gradient: LinearGradient(
                                                            begin: Alignment.topCenter,
                                                            end: Alignment.bottomCenter,
                                                            colors: [
                                                              Colors.transparent,
                                                              Colors.black.withOpacity(0.8)
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    // Status Badges
                                                    Positioned(
                                                      top: 20,
                                                      left: 0,
                                                      right: 0,
                                                      child: Center(
                                                        child: Column(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            if (scenario.status == 'active')
                                                              Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                                decoration: BoxDecoration(
                                                                  color: AppTheme.successGreen.withOpacity(0.85),
                                                                  borderRadius: BorderRadius.circular(20),
                                                                  border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                                                                ),
                                                                child: const Row(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: [
                                                                    Icon(Icons.play_arrow, color: Colors.white, size: 16),
                                                                    SizedBox(width: 6),
                                                                    Text('EN CURSO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
                                                                  ],
                                                                ),
                                                              )
                                                            else if (scenario.date != null && !scenario.isCompleted && scenario.date!.isBefore(DateTime.now()))
                                                              Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                                decoration: BoxDecoration(
                                                                  color: Colors.orangeAccent.withOpacity(0.85),
                                                                  borderRadius: BorderRadius.circular(20),
                                                                  border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                                                                ),
                                                                child: const Row(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: [
                                                                    Icon(Icons.admin_panel_settings, color: Colors.white, size: 16),
                                                                    SizedBox(width: 6),
                                                                    Text('ESPERANDO ADMIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
                                                                  ],
                                                                ),
                                                              )
                                                            else if (scenario.date != null && !scenario.isCompleted)
                                                              ScenarioCountdown(targetDate: scenario.date!, eventStatus: scenario.status),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    Align(
                                                      alignment: Alignment.bottomCenter,
                                                      child: SingleChildScrollView(
                                                        padding: const EdgeInsets.all(24.0),
                                                        child: Column(
                                                          mainAxisSize: MainAxisSize.min,
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(scenario.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 18.0, fontWeight: FontWeight.bold)),
                                                            const SizedBox(height: 4),
                                                            Text(scenario.description, style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                                                            const SizedBox(height: 12),
                                                            SingleChildScrollView(
                                                              scrollDirection: Axis.horizontal,
                                                              child: Row(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  Container(
                                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                                    decoration: BoxDecoration(
                                                                      color: scenario.isCompleted ? AppTheme.dangerRed.withOpacity(0.8) : Colors.black.withOpacity(0.6),
                                                                      borderRadius: BorderRadius.circular(20),
                                                                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                                                                    ),
                                                                    child: Row(
                                                                      mainAxisSize: MainAxisSize.min,
                                                                      children: [
                                                                        const Icon(Icons.people_outline, color: Colors.white, size: 14),
                                                                        const SizedBox(width: 4),
                                                                        Text(scenario.isCompleted ? 'FINALIZADA' : 'MÁX: ${scenario.maxPlayers}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5)),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                  if (scenario.pot > 0) ...[
                                                                    const SizedBox(width: 8),
                                                                    Container(
                                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                                      decoration: BoxDecoration(
                                                                        gradient: LinearGradient(colors: [AppTheme.accentGold.withOpacity(0.4), AppTheme.accentGold.withOpacity(0.1)]),
                                                                        borderRadius: BorderRadius.circular(20),
                                                                        border: Border.all(color: AppTheme.accentGold.withOpacity(0.5), width: 1),
                                                                      ),
                                                                      child: Row(
                                                                        mainAxisSize: MainAxisSize.min,
                                                                        children: [
                                                                          const Icon(Icons.workspace_premium, color: AppTheme.accentGold, size: 14),
                                                                          const SizedBox(width: 4),
                                                                          Text("BOTÍN: ${_formatCompactAmount((scenario.pot * 0.70).round())} ", style: const TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5)),
                                                                          const CoinImage(size: 10),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ],
                                                                  if ((_bettingCountMap[scenario.id] ?? 0) > 0) ...[
                                                                    const SizedBox(width: 8),
                                                                    Container(
                                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                                      decoration: BoxDecoration(
                                                                        color: Colors.black.withOpacity(0.6),
                                                                        borderRadius: BorderRadius.circular(20),
                                                                        border: Border.all(color: AppTheme.dBrandMain.withOpacity(0.5), width: 1),
                                                                      ),
                                                                      child: Row(
                                                                        mainAxisSize: MainAxisSize.min,
                                                                        children: [
                                                                          const Icon(Icons.casino, color: AppTheme.dBrandMain, size: 14),
                                                                          const SizedBox(width: 4),
                                                                          Text("APUESTAS: ${_formatCompactAmount(_bettingPotMap[scenario.id] ?? 0)} ", style: const TextStyle(color: AppTheme.dBrandMain, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5)),
                                                                          const CoinImage(size: 10),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ],
                                                              ),
                                                            ),
                                                            const SizedBox(height: 10),
                                                            if (scenario.isCompleted)
                                                              Center(
                                                                child: SizedBox(
                                                                  width: 250,
                                                                  child: ElevatedButton(
                                                                    onPressed: () => _onScenarioSelected(scenario),
                                                                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGold, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                                                                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.emoji_events, size: 18), SizedBox(width: 8), Text('VER PODIO', style: TextStyle(fontWeight: FontWeight.bold))]),
                                                                  ),
                                                                ),
                                                              )
                                                            else if (_banStatusMap[scenario.id] == 'banned' || _banStatusMap[scenario.id] == 'suspended')
                                                              Center(child: SizedBox(width: 250, child: _buildBannedButton(scenario)))
                                                            else if (_eventRoleMap[scenario.id] == 'spectator')
                                                              Center(
                                                                child: SizedBox(
                                                                  width: 250,
                                                                  child: ElevatedButton(
                                                                    onPressed: () => _onSpectatorSelected(scenario),
                                                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white, side: const BorderSide(color: Colors.white60, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 0),
                                                                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.visibility), SizedBox(width: 8), Text("MODO ESPECTADOR", style: TextStyle(fontWeight: FontWeight.bold))]),
                                                                  ),
                                                                ),
                                                              )
                                                            else
                                                              Column(
                                                                children: [
                                                                  Center(
                                                                    child: SizedBox(
                                                                      width: 250,
                                                                      child: ElevatedButton(
                                                                        onPressed: () => _onScenarioSelected(scenario),
                                                                        style: ElevatedButton.styleFrom(backgroundColor: currentAction, foregroundColor: (isDarkMode && currentAction == AppTheme.dGoldMain) ? Colors.black : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                                                                        child: scenario.isCompleted ? const Text("VER PODIO", style: TextStyle(fontWeight: FontWeight.bold)) : _participantStatusMap[scenario.id] == true ? const Text("ENTRAR AL EVENTO", style: TextStyle(fontWeight: FontWeight.bold)) : scenario.entryFee == 0 ? const Text("INSCRIBETE (GRATIS)", style: TextStyle(fontWeight: FontWeight.bold)) : Row(mainAxisSize: MainAxisSize.min, children: [Text("INSCRIBETE (${scenario.entryFee} ", style: const TextStyle(fontWeight: FontWeight.bold)), const CoinImage(size: 16), const Text(")", style: TextStyle(fontWeight: FontWeight.bold))]),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  if (!scenario.isCompleted && _participantStatusMap[scenario.id] != true) ...[
                                                                    const SizedBox(height: 8),
                                                                    Center(
                                                                      child: SizedBox(
                                                                        width: 250,
                                                                        child: TextButton(
                                                                          onPressed: () => _showSpectatorWarningDialog(scenario),
                                                                          style: TextButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white30), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), backgroundColor: Colors.black26),
                                                                          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.visibility, size: 16), SizedBox(width: 8), Text("MODO ESPECTADOR", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ],
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                    if (scenarios.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(
                            bottom: 5, top: 10), // Lowered dots
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children:
                              List.generate(scenarios.length + 1, (index) {
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              height: 8,
                              width: _currentPage == index ? 24 : 8,
                              decoration: BoxDecoration(
                                color: _currentPage == index
                                    ? currentAction
                                    : currentAction.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            );
                          }),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required Color activeColor,
    required Color textColor,
    double fontSize = 12,
  }) {
    // Determine colors based on state
    final backgroundColor = isActive ? activeColor : Colors.transparent;
    final borderColor = isActive
        ? activeColor
        : Colors
            .white24; // Siempre usar color claro para el borde ya que el fondo es oscuro
    final labelColor = isActive
        ? textColor
        : Colors
            .white60; // Siempre usar color claro para el texto ya que el fondo es oscuro
    final fontWeight = isActive ? FontWeight.bold : FontWeight.normal;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontWeight: fontWeight,
            fontSize: fontSize,
          ),
        ),
      ),
    );
  }
}

/// Simple data class for premium dialog options.
class _DialogOption {
  final IconData icon;
  final String label;
  final List<Color> gradientColors;
  final Color textColor;
  final VoidCallback onTap;

  const _DialogOption({
    required this.icon,
    required this.label,
    required this.gradientColors,
    required this.textColor,
    required this.onTap,
  });
}
