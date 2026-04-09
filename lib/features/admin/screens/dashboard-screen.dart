import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/player_provider.dart';
import '../services/admin_service.dart';
import 'event_creation_screen.dart';
import '../providers/event_creation_provider.dart';
import 'competitions_management_screen.dart';
import 'user_management_screen.dart';
import 'admin_login_screen.dart';
import 'clover_plans_management_screen.dart';
import 'withdrawal_plans_management_screen.dart';
import 'global_game_requests_screen.dart';
import 'global_config_screen.dart';
import '../../auth/screens/login_screen.dart';
import '../../../shared/widgets/animated_cyber_background.dart';
import 'minigames/sequence_config_screen.dart';
import 'minigames/drink_mixer_config_screen.dart';
import 'audit_logs_screen.dart';
import 'sponsors_management_screen.dart';
import 'online_automation_screen.dart';
import '../../game/screens/game_mode_selector_screen.dart';
import 'event_metrics_screen.dart';
import 'stripe_orders_screen.dart';
import 'merchandise_management_screen.dart';
import 'outflow_management_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  // Definición completa de todos los módulos disponibles para 'admin'
  final List<Map<String, dynamic>> _allModules = [
    {
      "title": "Dashboard",
      "icon": Icons.dashboard,
      "view": (VoidCallback goToDashboard, Function(int) setIndex, List<String> currentTitles) => 
          _WelcomeDashboardView(onNavigate: setIndex, moduleTitles: currentTitles),
    },
    {
      "title": "Crear Evento",
      "icon": Icons.add_circle_outline,
      "view": (VoidCallback goToDashboard, Function(int) setIndex, List<String> currentTitles) => ChangeNotifierProvider(
        create: (_) => EventCreationProvider(),
        child: EventCreationScreen(onEventCreated: goToDashboard),
      ),
    },
    {
      "title": "Competencias",
      "icon": Icons.emoji_events,
      "view": (VoidCallback goToDashboard, Function(int) setIndex, List<String> currentTitles) => const CompetitionsManagementScreen(),
    },
    {
      "title": "Modo Online",
      "icon": Icons.cloud_done,
      "view": (VoidCallback goToDashboard, Function(int) setIndex, List<String> currentTitles) => const OnlineAutomationScreen(),
    },
    {
      "title": "Usuarios",
      "icon": Icons.people,
      "view": (VoidCallback goToDashboard, Function(int) setIndex, List<String> currentTitles) => const UserManagementScreen(),
    },
    {
      "title": "Compras",
      "icon": Icons.local_offer,
      "view": (VoidCallback goToDashboard, Function(int) setIndex, List<String> currentTitles) => const CloverPlansManagementScreen(),
      "onlyAdmin": true,
    },
    {
      "title": "Planes Retiro",
      "icon": Icons.money_off,
      "view": (VoidCallback goToDashboard, Function(int) setIndex, List<String> currentTitles) => const WithdrawalPlansManagementScreen(),
      "onlyAdmin": true,
    },
    {
      "title": "Solicitudes",
      "icon": Icons.pending_actions,
      "view": (VoidCallback goToDashboard, Function(int) setIndex, List<String> currentTitles) => const GlobalGameRequestsScreen(),
      "onlyAdmin": true,
    },
    {
      "title": "Retiros y Canjes",
      "icon": Icons.receipt_long,
      "view": (VoidCallback goToDashboard, Function(int) setIndex, List<String> currentTitles) => const OutflowManagementScreen(),
      "onlyAdmin": true,
    },
    {
      "title": "Stripe",
      "icon": Icons.credit_card,
      "view": (VoidCallback goToDashboard, Function(int) setIndex, List<String> currentTitles) => const StripeOrdersScreen(),
      "onlyAdmin": true,
    },
    {
      "title": "Tienda Admin",
      "icon": Icons.storefront,
      "view": (VoidCallback goToDashboard, Function(int) setIndex, List<String> currentTitles) => const MerchandiseManagementScreen(),
      "onlyAdmin": true,
    },
    {
      "title": "Métricas",
      "icon": Icons.analytics,
      "view": (VoidCallback goToDashboard, Function(int) setIndex, List<String> currentTitles) => const EventMetricsScreen(),
    },
    {
      "title": "Minijuegos",
      "icon": Icons.games,
      "view": (VoidCallback goToDashboard, Function(int) setIndex, List<String> currentTitles) => const _MinigamesListView(),
      "onlyAdmin": true,
    },
    {
      "title": "Patrocinadores",
      "icon": Icons.business_center,
      "view": (VoidCallback goToDashboard, Function(int) setIndex, List<String> currentTitles) => const SponsorsManagementScreen(),
      "onlyAdmin": true,
    },
    {
      "title": "Auditoría",
      "icon": Icons.history_edu,
      "view": (VoidCallback goToDashboard, Function(int) setIndex, List<String> currentTitles) => const AuditLogsScreen(),
      "onlyAdmin": true,
    },
    {
      "title": "Configuración",
      "icon": Icons.settings,
      "view": (VoidCallback goToDashboard, Function(int) setIndex, List<String> currentTitles) => const GlobalConfigScreen(),
      "onlyAdmin": true,
    },
  ];

  void _goToDashboard() {
    setState(() {
      _selectedIndex = 0;
    });
  }

  void _handleLogout(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        title: Text('Cerrar Sesión',
            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
        content: Text('¿Estás seguro de que deseas salir?',
            style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldLogout == true && context.mounted) {
      if (!isDark) {
         // If we are in light mode, ensure status bar stays readable
         SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
      }
      await Provider.of<PlayerProvider>(context, listen: false).logout();
      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = context.watch<PlayerProvider>();
    final player = playerProvider.currentPlayer;
    final bool isDarkMode = playerProvider.isDarkMode;
    final Color goldActionColor =
        isDarkMode ? AppTheme.dGoldMain : AppTheme.lGoldAction;
    final Color goldTextColor =
        isDarkMode ? AppTheme.dGoldLight : AppTheme.lGoldText;

    // Filtrar módulos según rol
    final bool isAdmin = player?.isAdmin ?? false;
    final List<Map<String, dynamic>> filteredModules = _allModules.where((m) {
      if (isAdmin) return true;
      return m['onlyAdmin'] != true;
    }).toList();

    // Extraer títulos, iconos y vistas de los módulos filtrados
    final List<String> titles = filteredModules.map((m) => m['title'] as String).toList();
    final List<IconData> icons = filteredModules.map((m) => m['icon'] as IconData).toList();
    
    final List<Widget> views = filteredModules.map((m) {
      final viewBuilder = m['view'] as Widget Function(VoidCallback, Function(int), List<String>);
      return viewBuilder(_goToDashboard, (index) => setState(() => _selectedIndex = index), titles);
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: Column(
              children: [
                // 1. HEADER SUPERIOR
                Container(
                  height: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    border: Border(
                      bottom: BorderSide(
                        color: goldActionColor.withOpacity(isDark ? 0.2 : 0.12),
                        width: 1,
                      ),
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, headerConstraints) {
                      final bool isNarrow = headerConstraints.maxWidth < 450;
                      return Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: goldActionColor.withOpacity(isDark ? 0.22 : 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.admin_panel_settings,
                                color: goldActionColor, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Sistema Admin",
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Theme.of(context).textTheme.bodyLarge?.color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                if (!isNarrow)
                                  Text(
                                    "MapHunter Admin",
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Theme.of(context).textTheme.bodySmall?.color,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isDarkMode
                                        ? Icons.dark_mode
                                        : Icons.light_mode,
                                    color: goldActionColor,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Switch.adaptive(
                                    value: isDarkMode,
                                    onChanged: (value) {
                                      playerProvider.toggleDarkMode(value);
                                    },
                                    activeColor: goldActionColor,
                                    activeTrackColor:
                                        goldActionColor.withOpacity(0.35),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              if (headerConstraints.maxWidth > 650) ...[
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      isAdmin ? "Administrador" : "Staff",
                                      style: TextStyle(
                                          color: Theme.of(context).textTheme.bodyLarge?.color,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                    ),
                                    Text(
                                      player?.email ?? "staff@system.com",
                                      style: TextStyle(
                                        color: Theme.of(context).textTheme.bodySmall?.color,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                              ],
                                CircleAvatar(
                                backgroundColor: goldActionColor,
                                radius: 16,
                                child: Text(isAdmin ? "A" : "S",
                                    style: const TextStyle(
                                        fontSize: 14,
                                    color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                              ),
                              SizedBox(width: isNarrow ? 4 : 8),
                              IconButton(
                                icon: Icon(Icons.sports_esports,
                                  color: goldActionColor, size: 20),
                                tooltip: "Modo Jugador",
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const GameModeSelectorScreen()),
                                    (route) => false,
                                  );
                                },
                              ),
                              SizedBox(width: isNarrow ? 4 : 12),
                              IconButton(
                                icon: Icon(Icons.logout,
                                    color: Theme.of(context).textTheme.bodySmall?.color,
                                    size: 20),
                                tooltip: "Salir",
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _handleLogout(context),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // 2. BARRA DE NAVEGACIÓN HORIZONTAL (CATEGORÍAS)
                Container(
                  height: 60,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    border: Border(
                      bottom: BorderSide(
                        color: goldActionColor.withOpacity(isDark ? 0.22 : 0.15),
                        width: 1,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                        offset: const Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: titles.length,
                    itemBuilder: (context, index) {
                      final isSelected = _selectedIndex == index;

                      return GestureDetector(
                        onTap: () {
                          if (index < views.length) {
                            setState(() => _selectedIndex = index);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text("Módulo en desarrollo")));
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? goldActionColor.withOpacity(0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: isSelected
                                    ? goldActionColor.withOpacity(0.4)
                                    : Colors.transparent),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                icons[index],
                                size: 18,
                                color: isSelected
                                    ? goldActionColor
                                    : goldTextColor.withOpacity(0.6),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                titles[index],
                                style: TextStyle(
                                  color: isSelected
                                      ? goldTextColor
                                      : goldTextColor.withOpacity(0.7),
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  fontSize: 13,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // 3. ÁREA DE CONTENIDO PRINCIPAL
                Expanded(
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: IndexedStack(
                      index: _selectedIndex < views.length ? _selectedIndex : 0,
                      children: views,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      );
  }
}

class _WelcomeDashboardView extends StatefulWidget {
  final void Function(int)? onNavigate;
  final List<String> moduleTitles;
  const _WelcomeDashboardView({this.onNavigate, this.moduleTitles = const []});

  @override
  State<_WelcomeDashboardView> createState() => _WelcomeDashboardViewState();
}

class _WelcomeDashboardViewState extends State<_WelcomeDashboardView> {
  String _activeUsers = "...";
  String _createdEvents = "...";
  String _pendingRequests = "...";

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final adminService = context.read<AdminService>();
      final stats = await adminService.fetchGeneralStats();

      if (mounted) {
        setState(() {
          _activeUsers = stats.activeUsers.toString();
          _createdEvents = stats.createdEvents.toString();
          _pendingRequests = stats.pendingRequests.toString();
        });
      }
    } catch (e) {
      debugPrint('Error fetching dashboard stats: $e');
      if (mounted) {
        setState(() {
          _activeUsers = "-";
          _createdEvents = "-";
          _pendingRequests = "-";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final playerProvider = context.watch<PlayerProvider>();
    final player = playerProvider.currentPlayer;
    final Color accentGold = isDark ? AppTheme.dGoldMain : AppTheme.lGoldAction;

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.analytics_rounded,
                  size: 80, color: accentGold),
              const SizedBox(height: 20),
              Text(
                "Bienvenido al Panel de Administración",
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5),
              ),
              const SizedBox(height: 10),
              Text(
                "Selecciona una opción del menú superior para comenzar.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
              ),
              const SizedBox(height: 40),
              Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: [
                   _SummaryCard(
                       title: "Usuarios Activos",
                       value: _activeUsers,
                       color: accentGold),
                   _SummaryCard(
                       title: "Eventos Creados",
                       value: _createdEvents,
                       color: Colors.blueAccent),
                    if (isDark || player?.isAdmin == true)
                      _SummaryCard(
                        title: "Solicitudes Pendientes",
                        value: _pendingRequests,
                        color: Colors.orangeAccent,
                        onTap: () {
                          // Buscar el índice de 'Competencias' o 'Solicitudes' en la lista filtrada
                          final idx = widget.moduleTitles.indexWhere((t) => t == 'Solicitudes' || t == 'Competencias');
                          if (idx != -1) widget.onNavigate?.call(idx);
                        },
                      ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MinigamesListView extends StatelessWidget {
  const _MinigamesListView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Map<String, dynamic>> minigames = [
      {
        'title': 'Secuencia de Memoria',
        'subtitle': 'Juego tipo Simon Dice con colores neón.',
        'icon': Icons.psychology,
        'color': Colors.cyanAccent,
        'screen': const SequenceConfigScreen(),
      },
      {
        'title': 'Cócteles de Neón',
        'subtitle': 'Mezcla de sabores y colores en el bar.',
        'icon': Icons.local_bar,
        'color': Colors.pinkAccent,
        'screen': const DrinkMixerConfigScreen(),
      },
    ];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Configuración de Minijuegos",
            style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color, 
                fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            "Prueba y ajusta los parámetros de los desafíos del juego.",
            style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 16),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: ListView.builder(
              itemCount: minigames.length,
              itemBuilder: (context, index) {
                final mg = minigames[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.05)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(20),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (mg['color'] as Color).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(mg['icon'], color: mg['color']),
                    ),
                    title: Text(mg['title'],
                        style: TextStyle(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                    subtitle: Text(mg['subtitle'],
                        style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
                    trailing: Icon(Icons.arrow_forward_ios,
                      color: isDark ? Colors.white38 : Colors.black26,
                      size: 16),
                    onTap: () {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => mg['screen']));
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _SummaryCard(
      {required this.title,
      required this.value,
      required this.color,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            border: Border(left: BorderSide(color: color, width: 4)),
            boxShadow: [
              BoxShadow(
                  color: color.withOpacity(isDark ? 0.2 : 0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 5))
            ]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontSize: 28,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
