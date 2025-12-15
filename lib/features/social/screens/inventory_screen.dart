import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../game/providers/game_provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../mall/models/power_item.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/inventory_item_card.dart';
import '../../mall/screens/mall_screen.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    final player = playerProvider.currentPlayer;
    
    if (player == null) {
      return const Center(child: Text('No player data'));
    }
    
    return Scaffold(
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
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Inventory items
              Expanded(
                child: player.inventory.isEmpty
                    ? Center(
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
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: player.inventory.length,
                        itemBuilder: (context, index) {
                          final itemId = player.inventory[index];
                          final item = PowerItem.getShopItems().firstWhere(
                            (item) => item.id == itemId,
                            orElse: () => PowerItem(
                              id: 'unknown',
                              name: 'Desconocido ($itemId)',
                              description: 'Item no encontrado',
                              type: PowerType.debuff,
                              cost: 0,
                              icon: '❓',
                            ),
                          );
                        
                          return InventoryItemCard(
                            item: item,
                            onUse: () async {
                              final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
                              
                              // Check if item is a sabotage (requires target)
                              // Assuming all items here are sabotages/buffs that might need target or self.
                              // For simplicity, let's treat "freeze_screen" and others as targetable.
                              // Buffs like "shield" might be self-cast.
                              
                              if (item.id == 'black_screen' || item.id == 'freeze' || item.id == 'time_penalty' || item.id == 'slow_motion') {
                                final gameProvider = Provider.of<GameProvider>(context, listen: false);
                                
                                // Determinar la lista de jugadores base
                                List<dynamic> sourcePlayers = [];
                                
                                if (gameProvider.currentEventId != null) {
                                  // Si hay evento activo, usar leaderboard (participantes del evento)
                                  await gameProvider.fetchLeaderboard();
                                  sourcePlayers = gameProvider.leaderboard;
                                } else {
                                  // Fallback: Si no hay evento, usar todos (para pruebas)
                                  if (playerProvider.allPlayers.isEmpty) {
                                    await playerProvider.fetchAllPlayers();
                                  }
                                  sourcePlayers = playerProvider.allPlayers;
                                }

                                // Filtrar el jugador actual
                                final rivals = sourcePlayers
                                    .where((p) => p.id != player.id)
                                    .toList();

                                if (!context.mounted) return;

                                if (rivals.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('No hay rivales disponibles')),
                                  );
                                  return;
                                }

                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: AppTheme.cardBg,
                                    title: Text(
                                      'Usar ${item.name}',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                    content: SizedBox(
                                      width: double.maxFinite,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            'Selecciona un rival:',
                                            style: TextStyle(color: Colors.white70),
                                          ),
                                          const SizedBox(height: 10),
                                          Flexible(
                                            child: ListView.builder(
                                              shrinkWrap: true,
                                              itemCount: rivals.length,
                                              itemBuilder: (context, i) {
                                                final rival = rivals[i];
                                                return ListTile(
                                                  leading: CircleAvatar(
                                                    backgroundColor: AppTheme.accentGold,
                                                    child: Text(rival.name.isEmpty ? '?' : rival.name[0].toUpperCase()),
                                                  ),
                                                  title: Text(
                                                    rival.name.isEmpty ? 'Jugador' : rival.name,
                                                    style: const TextStyle(color: Colors.white),
                                                  ),
                                                  onTap: () async {
                                                    Navigator.pop(context); // Close dialog
                                                    
                                                    final success = await playerProvider.applySabotage(rival.id, item.id);
                                                    
                                                    if (!context.mounted) return;
                                                    
                                                    if (success) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text('¡Saboteaste a ${rival.name}!'),
                                                          backgroundColor: AppTheme.successGreen,
                                                        ),
                                                      );
                                                    } else {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(
                                                          content: Text('Error al aplicar sabotaje'),
                                                          backgroundColor: AppTheme.dangerRed,
                                                        ),
                                                      );
                                                    }
                                                  },
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancelar'),
                                      ),
                                    ],
                                  ),
                                );
                              } else {
                                // Self-cast items (shield, speed_boost, etc.)
                                playerProvider.useItemFromInventory(itemId);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${item.name} usado!'),
                                    backgroundColor: AppTheme.successGreen,
                                  ),
                                );
                              }
                            },
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
    );
  }
}
