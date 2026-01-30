import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/spectator_feed_provider.dart';
import '../providers/game_provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../auth/services/power_service.dart';
import '../widgets/race_track_widget.dart';
import '../models/race_view_data.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../mall/models/power_item.dart';

class SpectatorModeScreen extends StatefulWidget {
  final String eventId;

  const SpectatorModeScreen({super.key, required this.eventId});

  @override
  State<SpectatorModeScreen> createState() => _SpectatorModeScreenState();
}

class _SpectatorModeScreenState extends State<SpectatorModeScreen> {
  int _selectedTab = 0; // 0: Actividad, 1: Apuestas, 2: Tienda

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      // Los espectadores no necesitan inicializar el juego (startGame), solo ver los datos
      gameProvider.fetchClues(eventId: widget.eventId); 
      gameProvider.startLeaderboardUpdates();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SpectatorFeedProvider(widget.eventId),
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E27),
        appBar: AppBar(
          backgroundColor: AppTheme.cardBg,
          elevation: 0,
          title: Row(
            children: [
              const Icon(Icons.visibility, color: AppTheme.secondaryPink),
              const SizedBox(width: 8),
              Expanded(
                child: const Text(
                  'MODO ESPECTADOR',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.circle, color: Colors.red, size: 8),
                    SizedBox(width: 4),
                    Text(
                      'EN VIVO',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Vista de la carrera (Cabezal dinámico - Ajustado para evitar overflow)
              SizedBox(
                height: 300, // Aumentado a 300 por seguridad para evitar overflow en cualquier dispositivo
                child: _buildRaceView(),
              ),
              
              // Sección inferior con tabs (Más espacio para interacción)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg.withOpacity(0.9),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // El tab de inventario ahora es una pequeña franja superior si estamos en Actividad
                      if (_selectedTab == 0) _buildMiniInventoryHeader(),

                      // Tabs selector principal
                      _buildTabSelector(),
                      
                      // Contenido del tab
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _selectedTab == 2
                              ? _buildStoreView()
                              : _selectedTab == 1
                                  ? _buildBettingView()
                                  : _buildLiveFeed(),
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
    );
  }

  Widget _buildRaceView() {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
        
        if (gameProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.secondaryPink),
          );
        }

        final leaderboard = gameProvider.leaderboard;
        final totalClues = gameProvider.totalClues;
        final currentPlayerId = playerProvider.currentPlayer?.userId ?? '';
        
        if (leaderboard.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.hourglass_empty,
                  size: 60,
                  color: Colors.white.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'Esperando que comience la carrera...',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: RaceTrackWidget(
            leaderboard: leaderboard,
            currentPlayerId: currentPlayerId,
            totalClues: totalClues,
            compact: false, // Usamos la versión completa que ya tiene estilo premium
          ),
        );
      },
    );
  }

  Widget _buildTabSelector() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTab(
              icon: Icons.notifications_active,
              label: 'Actividad',
              isSelected: _selectedTab == 0,
              onTap: () => setState(() => _selectedTab = 0),
            ),
          ),
          Expanded(
            child: _buildTab(
              icon: Icons.monetization_on,
              label: 'Apuestas',
              isSelected: _selectedTab == 1,
              onTap: () => setState(() => _selectedTab = 1),
            ),
          ),
          Expanded(
            child: _buildTab(
              icon: Icons.shopping_bag,
              label: 'Tienda',
              isSelected: _selectedTab == 2,
              onTap: () => setState(() => _selectedTab = 2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.primaryGradient : null,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white54,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniInventoryHeader() {
    return Consumer<PlayerProvider>(
      builder: (context, playerProvider, child) {
        final inventoryList = playerProvider.currentPlayer?.inventory ?? [];
        if (inventoryList.isEmpty) return const SizedBox.shrink();

        // Contar items para mostrar cantidades
        final inventoryMap = <String, int>{};
        for (var slug in inventoryList) {
          inventoryMap[slug] = (inventoryMap[slug] ?? 0) + 1;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 20, top: 10),
              child: Text(
                'MIS PODERES',
                style: TextStyle(
                  color: AppTheme.accentGold,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: inventoryMap.length,
                itemBuilder: (context, index) {
                  final entry = inventoryMap.entries.elementAt(index);
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_getPowerIcon(entry.key), style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(
                          'x${entry.value}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLiveFeed() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ACTIVIDAD EN VIVO',
            style: TextStyle(
              color: AppTheme.accentGold,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Consumer<SpectatorFeedProvider>(
              builder: (context, provider, child) {
                if (provider.events.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 40,
                          color: Colors.white.withOpacity(0.1),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Esperando actividad...',
                          style: TextStyle(color: Colors.white24, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: provider.events.length,
                  itemBuilder: (context, index) {
                    final event = provider.events[index];
                    return _buildFeedEventCard(event);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedEventCard(GameFeedEvent event) {
    final color = _getEventColor(event.type);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                event.icon ?? '⚡',
                style: const TextStyle(fontSize: 16),
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
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      DateFormat('HH:mm:ss').format(event.timestamp),
                      style: const TextStyle(color: Colors.white38, fontSize: 9),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  event.detail,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBettingView() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monetization_on, color: AppTheme.accentGold, size: 20),
              const SizedBox(width: 8),
              const Text(
                'APUESTAS EN VIVO',
                style: TextStyle(
                  color: AppTheme.accentGold,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Consumer<PlayerProvider>(
                builder: (context, playerProvider, child) {
                  final coins = playerProvider.currentPlayer?.coins ?? 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '$coins',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Apuesta por el ganador de la carrera. Monto fijo: 100 monedas.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Consumer<GameProvider>(
              builder: (context, gameProvider, child) {
                final players = gameProvider.leaderboard;
                
                if (players.isEmpty) {
                  return Center(
                    child: Text(
                      'No hay jugadores activos',
                      style: TextStyle(color: Colors.white.withOpacity(0.5)),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: players.length,
                  itemBuilder: (context, index) {
                    final player = players[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.secondaryPink.withOpacity(0.2),
                          backgroundImage: player.avatarUrl.isNotEmpty 
                              ? NetworkImage(player.avatarUrl) 
                              : null,
                          child: player.avatarUrl.isEmpty 
                              ? Text(player.name[0].toUpperCase(), style: const TextStyle(color: Colors.white))
                              : null,
                        ),
                        title: Text(
                          player.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Nivel ${player.level} • XP: ${player.totalXP}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => _showBetDialog(player.name, 100),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentGold,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: const Text('Apostar'),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showBetDialog(String playerName, int amount) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A1F3A), Color(0xFF0A0E27)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.accentGold.withOpacity(0.5), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.monetization_on, color: AppTheme.accentGold, size: 50),
              const SizedBox(height: 16),
              Text(
                '¿Apostar por $playerName?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Monto de apuesta: $amount monedas',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: Implement actual betting logic
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('¡Apuesta realizada con éxito!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentGold,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Confirmar',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildStoreView() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_bag, color: AppTheme.accentGold, size: 20),
              const SizedBox(width: 8),
              const Text(
                'TIENDA DE PODERES',
                style: TextStyle(
                  color: AppTheme.accentGold,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Consumer<PlayerProvider>(
                builder: (context, playerProvider, child) {
                  final coins = playerProvider.currentPlayer?.coins ?? 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '$coins',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Consumer<PlayerProvider>(
              builder: (context, playerProvider, child) {
                final powers = playerProvider.shopItems;
                
                if (powers.isEmpty) {
                  return Center(
                    child: Text(
                      'No hay poderes disponibles',
                      style: TextStyle(color: Colors.white.withOpacity(0.5)),
                    ),
                  );
                }

                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: powers.length,
                  itemBuilder: (context, index) {
                    final power = powers[index];
                    return _buildPowerCard(power);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPowerCard(PowerItem power) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryPurple.withOpacity(0.3),
            AppTheme.cardBg.withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.5)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showPurchaseDialog(power),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  power.icon,
                  style: const TextStyle(fontSize: 40),
                ),
                Text(
                  power.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  power.description,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accentGold),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.monetization_on, color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${power.cost}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPurchaseDialog(PowerItem power) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A1F3A), Color(0xFF0A0E27)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.accentGold.withOpacity(0.5), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                power.icon,
                style: const TextStyle(fontSize: 60),
              ),
              const SizedBox(height: 16),
              Text(
                '¿Comprar ${power.name}?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    '${power.cost} monedas',
                    style: const TextStyle(
                      color: AppTheme.accentGold,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _purchasePower(power.id, power.name, power.cost);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentGold,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Comprar',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _purchasePower(String powerId, String powerName, int price) async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final currentCoins = playerProvider.currentPlayer?.coins ?? 0;

    if (currentCoins < price) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tienes suficientes monedas'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final success = await playerProvider.purchaseItem(
        powerId,
        widget.eventId,
        price,
        isPower: true,
      );

      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡$powerName comprado exitosamente!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        throw 'La transacción no pudo completarse';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al comprar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getEventColor(String? type) {
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

  String _getPowerIcon(String slug) {
    switch (slug) {
      case 'freeze':
        return '❄️';
      case 'shield':
        return '🛡️';
      case 'invisibility':
        return '👻';
      case 'life_steal':
        return '🧛';
      case 'blur_screen':
        return '🌫️';
      case 'return':
        return '🔄';
      default:
        return '⚡';
    }
  }

  String _getPowerName(String slug) {
    switch (slug) {
      case 'freeze':
        return 'Congelar';
      case 'shield':
        return 'Escudo';
      case 'invisibility':
        return 'Invisible';
      case 'life_steal':
        return 'Robar Vida';
      case 'blur_screen':
        return 'Difuminar';
      case 'return':
        return 'Retornar';
      default:
        return slug;
    }
  }
}
