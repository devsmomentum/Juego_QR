import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';
import '../../models/player.dart';
import '../../theme/app_theme.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    await Provider.of<PlayerProvider>(context, listen: false).fetchAllPlayers();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final players = Provider.of<PlayerProvider>(context).allPlayers;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestión de Usuarios"),
        backgroundColor: AppTheme.darkBg,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.darkGradient,
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : players.isEmpty
                ? const Center(
                    child: Text(
                      "No hay usuarios registrados",
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: players.length,
                    itemBuilder: (context, index) {
                      final player = players[index];
                      return _UserCard(player: player);
                    },
                  ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final Player player;

  const _UserCard({required this.player});

  @override
  Widget build(BuildContext context) {
    final isBanned = player.status == PlayerStatus.banned;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppTheme.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isBanned ? Colors.red : Colors.green.withOpacity(0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.grey[800],
              backgroundImage: player.avatarUrl.isNotEmpty
                  ? NetworkImage(player.avatarUrl)
                  : null,
              child: player.avatarUrl.isEmpty
                  ? Text(
                      player.name.isNotEmpty
                          ? player.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(color: Colors.white))
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.name.isNotEmpty ? player.name : 'Sin Nombre',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    player.email,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isBanned
                          ? Colors.red.withOpacity(0.2)
                          : Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isBanned ? 'BANEADO' : 'ACTIVO',
                      style: TextStyle(
                        color: isBanned ? Colors.red : Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                isBanned ? Icons.lock_open : Icons.block,
                color: isBanned ? Colors.green : Colors.red,
              ),
              tooltip: isBanned ? 'Desbanear Usuario' : 'Banear Usuario',
              onPressed: () => _confirmBanAction(context, player),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmBanAction(BuildContext context, Player player) {
    final isBanned = player.status == PlayerStatus.banned;
    final action = isBanned ? 'desbanear' : 'banear';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Text('Confirmar acción',
            style: const TextStyle(color: Colors.white)),
        content: Text(
          '¿Estás seguro de que deseas $action a ${player.name}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await Provider.of<PlayerProvider>(context, listen: false)
                    .toggleBanUser(player.id, !isBanned);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Usuario ${isBanned ? 'desbaneado' : 'baneado'} exitosamente')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: Text(
              isBanned ? 'Desbanear' : 'Banear',
              style: TextStyle(color: isBanned ? Colors.green : Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
