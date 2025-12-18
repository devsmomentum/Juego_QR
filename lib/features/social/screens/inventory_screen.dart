import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../game/providers/game_provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../mall/models/power_item.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/inventory_item_card.dart';
import '../../mall/screens/mall_screen.dart';
import '../../../shared/utils/game_ui_utils.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}


class _InventoryScreenState extends State<InventoryScreen> {
  bool _isExecuting = false;

  void _setExecuting(bool val) {
    if (mounted) {
      setState(() => _isExecuting = val);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    final player = playerProvider.currentPlayer;
    
    if (player == null) {
      return const Center(child: Text('No player data'));
    }

    // Agrupar items repetidos
    final Map<String, int> inventoryCounts = {};
    for (var itemId in player.inventory) {
      inventoryCounts[itemId] = (inventoryCounts[itemId] ?? 0) + 1;
    }
    final uniqueItems = inventoryCounts.keys.toList();
    
    return Stack(
      children: [
        Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.darkGradient,
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Inventario',
                                style: Theme.of(context).textTheme.displayMedium,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.goldGradient,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.monetization_on,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${player.coins}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // --- BOTONES DEBUG MEJORADOS ---
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      ActionChip(
                                        avatar: const Icon(Icons.add, size: 14, color: Colors.white),
                                        label: const Text('Add 🕶️', style: TextStyle(fontSize: 10, color: Colors.white)),
                                        backgroundColor: AppTheme.primaryPurple,
                                        onPressed: () => playerProvider.debugAddPower('black_screen'),
                                      ),
                                      ActionChip(
                                        avatar: const Icon(Icons.visibility_off, size: 14, color: Colors.white),
                                        label: const Text('Test 🕶️', style: TextStyle(fontSize: 10, color: Colors.white)),
                                        backgroundColor: AppTheme.dangerRed,
                                        onPressed: () => playerProvider.debugToggleStatus('blinded'),
                                      ),
                                      ActionChip(
                                        avatar: const Icon(Icons.all_inclusive, size: 14, color: Colors.white),
                                        label: const Text('Add All', style: TextStyle(fontSize: 10, color: Colors.white)),
                                        backgroundColor: AppTheme.accentGold,
                                        onPressed: () => playerProvider.debugAddAllPowers(),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.inventory_2,
                                color: AppTheme.secondaryPink,
                                size: 28,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${player.inventory.length}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Inventory list
                  Expanded(
                    child: player.inventory.isEmpty
                        ? _buildEmptyState(context)
                        : GridView.builder(
                            padding: const EdgeInsets.all(20),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 32, // More space for description
                              childAspectRatio: 0.75,
                            ),
                            itemCount: uniqueItems.length,
                            itemBuilder: (context, index) {
                              final itemId = uniqueItems[index];
                              final powerItem = PowerItem.getShopItems().firstWhere(
                                (item) => item.id == itemId,
                                orElse: () => PowerItem(
                                  id: itemId,
                                  name: itemId,
                                  description: 'Objeto desconocido',
                                  type: PowerType.utility,
                                  cost: 0,
                                  icon: '📦',
                                  color: Colors.grey,
                                ),
                              );
                              
                              return InventoryItemCard(
                                item: powerItem,
                                count: inventoryCounts[itemId] ?? 1,
                                onUse: () => _handleItemUse(context, powerItem),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MallScreen())),
            label: const Text('Ir al Mall'),
            icon: const Icon(Icons.store),
            backgroundColor: AppTheme.accentGold,
          ),
        ),
        
        // Custom Loading Overlay
        if (_isExecuting)
          Container(
            color: Colors.black.withOpacity(0.7),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppTheme.accentGold),
                  SizedBox(height: 20),
                  Text(
                    'EJECUTANDO PODER...',
                    style: TextStyle(
                      color: AppTheme.accentGold,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _handleItemUse(BuildContext context, PowerItem item) async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    
    // Check if it's an offensive item
    final offensiveItems = ['freeze', 'black_screen', 'slow_motion', 'time_penalty'];
    final isOffensive = offensiveItems.contains(item.id);

    if (isOffensive) {
      _showRivalSelection(context, item);
    } else {
      // FIX: Para items defensivos/utilidad, el objetivo soy yo mismo
      final myId = playerProvider.currentPlayer?.id ?? '';
      if (myId.isNotEmpty) {
        _executePower(item, myId, 'Mí mismo', isOffensive: false);
      } else {
        showGameSnackBar(context, title: 'Error', message: 'Usuario no identificado', isError: true);
      }
    }
  }

  void _showRivalSelection(BuildContext context, PowerItem item) async {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    
    try {
      // 1. Mostrar loader de obtención de rivales
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.accentGold)),
      );

      // 2. Refrescar leaderboard para tener datos frescos
      await gameProvider.fetchLeaderboard();
      
      if (!context.mounted) return;
      Navigator.pop(context); // Cerrar loader

      final rivals = gameProvider.leaderboard
          .where((p) => p.id != Provider.of<PlayerProvider>(context, listen: false).currentPlayer?.id)
          .toList();

      if (rivals.isEmpty) {
        showGameSnackBar(context, title: 'Sin Víctimas', message: 'No hay otros jugadores disponibles para sabotear.', isError: true);
        return;
      }

      showModalBottomSheet(
        context: context,
        backgroundColor: AppTheme.cardBg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (modalContext) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'SELECCIONA TU VÍCTIMA',
                  style: TextStyle(
                    color: AppTheme.accentGold,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: rivals.length,
                  itemBuilder: (context, index) {
                    final rival = rivals[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryPurple,
                        backgroundImage: (rival.avatarUrl.isNotEmpty && rival.avatarUrl.startsWith('http')) 
                            ? NetworkImage(rival.avatarUrl) 
                            : null,
                        child: (rival.avatarUrl.isEmpty || !rival.avatarUrl.startsWith('http'))
                            ? Text(rival.name.isNotEmpty ? rival.name[0] : '?')
                            : null,
                      ),
                      title: Text(rival.name, style: const TextStyle(color: Colors.white)),
                      subtitle: Text('${rival.totalXP} XP', style: const TextStyle(color: Colors.white60)),
                      trailing: const Icon(Icons.bolt, color: AppTheme.secondaryPink),
                      onTap: () {
                        Navigator.pop(modalContext);
                        _executePower(item, rival.id, rival.name, isOffensive: true);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          );
        },
      );
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      debugPrint("Error cargando rivales: $e");
      showGameSnackBar(context, title: 'Error', message: 'Error cargando rivales: $e', isError: true);
    }
  }

  Future<void> _executePower(
    PowerItem item, 
    String targetId, 
    String targetName,
    {required bool isOffensive}
  ) async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    _setExecuting(true);
    debugPrint("_executePower: Iniciando ejecución de ${item.id}");

    try {
      // Ejecutar lógica en backend
      final success = await playerProvider.usePower(
        powerId: item.id,
        targetUserId: targetId,
      );

      debugPrint("_executePower: usePower finalizado: $success");
      
      if (!mounted) return;
      _setExecuting(false);

      if (success) {
        if (mounted) _showAttackSuccessAnimation(context, item, targetName);
      } else {
        if (mounted) {
           showGameSnackBar(context, title: 'Fallo al Usar', message: 'No se pudo usar el objeto. Verifica tu conexión o inventario.', isError: true);
        }
      }
    } catch (e) {
      debugPrint("_executePower: Error fatal: $e");
      if (mounted) {
        _setExecuting(false);
        showGameSnackBar(context, title: 'Error', message: 'Error: ${e.toString()}', isError: true);
      }
    }
  }

  void _showAttackSuccessAnimation(BuildContext context, PowerItem item, String targetName) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) => _AttackSuccessDialog(item: item, targetName: targetName),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 20),
          Text(
            'Inventario vacío',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Visita La Tiendita para comprar poderes',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AttackSuccessDialog extends StatefulWidget {
  final PowerItem item;
  final String targetName;
  const _AttackSuccessDialog({required this.item, required this.targetName});

  @override
  State<_AttackSuccessDialog> createState() => _AttackSuccessDialogState();
}

class _AttackSuccessDialogState extends State<_AttackSuccessDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.5).chain(CurveTween(curve: Curves.elasticOut)), 
        weight: 40
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.5, end: 1.2).chain(CurveTween(curve: Curves.easeInOut)), 
        weight: 20
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.2, end: 5.0).chain(CurveTween(curve: Curves.fastOutSlowIn)), 
        weight: 40
      ),
    ]).animate(_controller);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_controller);

    _controller.forward().then((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.item.icon, style: const TextStyle(fontSize: 80)),
                  const SizedBox(height: 10),
                  Material(
                    color: Colors.transparent,
                    child: Text(
                      '¡${widget.item.id == "extra_life" || widget.item.id == "shield" ? "USADO" : "LANZADO"}!',
                      style: const TextStyle(
                        color: AppTheme.accentGold, 
                        fontSize: 20, 
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Material(
                    color: Colors.transparent,
                    child: Text(
                      widget.targetName.isEmpty ? '' : 'Objetivo: ${widget.targetName}',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
