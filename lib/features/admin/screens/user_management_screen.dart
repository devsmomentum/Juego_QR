import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../../shared/models/player.dart';
import '../../../core/theme/app_theme.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _filterStatus = 'all'; // 'all', 'active', 'banned'

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    final allPlayers = Provider.of<PlayerProvider>(context).allPlayers;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredPlayers = allPlayers.where((player) {
      final searchTerm = _searchController.text.toLowerCase();
      final matchesSearch = player.name.toLowerCase().contains(searchTerm) ||
          player.email.toLowerCase().contains(searchTerm);

      if (player.status == PlayerStatus.pending) return false;

      bool matchesStatus = true;
      if (_filterStatus == 'active') {
        matchesStatus = player.status == PlayerStatus.active;
      } else if (_filterStatus == 'banned') {
        matchesStatus = player.status == PlayerStatus.banned;
      }

      return matchesSearch && matchesStatus;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.people, color: AppTheme.lGoldAction),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Gestión de Usuarios",
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).cardTheme.color,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.lGoldAction),
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          children: [
            // Sección de Filtros
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                   // Buscador
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: MediaQuery.of(context).size.width > 600
                          ? 300
                          : double.infinity,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                        decoration: InputDecoration(
                          hintText: 'Buscar usuario...',
                          hintStyle:
                              TextStyle(color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.5)),
                          prefixIcon: const Icon(Icons.search,
                              color: AppTheme.lGoldAction),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 15),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                  // Filtro de Estado
                  Container(
                    width: MediaQuery.of(context).size.width > 600
                        ? 200
                        : double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _filterStatus,
                        dropdownColor: Theme.of(context).cardTheme.color,
                        icon: const Icon(Icons.filter_list,
                            color: AppTheme.lGoldAction),
                        isExpanded: true,
                        style: TextStyle(
                            color: Theme.of(context).textTheme.bodyLarge?.color, 
                            fontWeight: FontWeight.w500),
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text("Todos"),
                          ),
                          DropdownMenuItem(
                            value: 'active',
                            child: Text("Activos",
                                style: TextStyle(color: Colors.green)),
                          ),
                          DropdownMenuItem(
                            value: 'banned',
                            child: Text("Baneados",
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _filterStatus = value);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Lista de Usuarios
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredPlayers.isEmpty
                      ? Center(
                          child: Text(
                            "No se encontraron usuarios",
                            style:
                                TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: filteredPlayers.length,
                          itemBuilder: (context, index) {
                            final player = filteredPlayers[index];
                            return _UserCard(player: player);
                          },
                        ),
            ),
          ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isBanned ? Colors.red.withOpacity(0.5) : Theme.of(context).dividerColor.withOpacity(0.1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
              backgroundImage: player.avatarUrl.isNotEmpty
                  ? NetworkImage(player.avatarUrl)
                  : null,
              child: player.avatarUrl.isEmpty
                  ? Text(
                      player.name.isNotEmpty
                          ? player.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.name.isNotEmpty ? player.name : 'Sin Nombre',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    player.email,
                    style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
                  ),
                  const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isBanned
                                ? Colors.red.withOpacity(0.12)
                                : AppTheme.lGoldAction.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isBanned ? Colors.red.withOpacity(0.5) : AppTheme.lGoldAction.withOpacity(0.5)
                            )
                          ),
                          child: Text(
                            isBanned ? 'BANEADO' : 'ACTIVO',
                            style: TextStyle(
                              color: isBanned ? Colors.red : AppTheme.lGoldText,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: player.isAdmin 
                                ? Colors.purple.withOpacity(0.12)
                                : player.isStaff
                                    ? Colors.blue.withOpacity(0.12)
                                    : Colors.grey.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: player.isAdmin 
                                  ? Colors.purple.withOpacity(0.5)
                                  : player.isStaff
                                      ? Colors.blue.withOpacity(0.5)
                                      : Colors.grey.withOpacity(0.5)
                            )
                          ),
                          child: Text(
                            player.role.toUpperCase(),
                            style: TextStyle(
                              color: player.isAdmin 
                                  ? Colors.purple 
                                  : player.isStaff
                                      ? Colors.blue
                                      : Colors.grey,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                isBanned ? Icons.lock_open : Icons.block,
                color: isBanned ? Colors.green : Colors.orange,
              ),
              tooltip: isBanned ? 'Desbanear Usuario' : 'Banear Usuario',
              onPressed: () => _confirmBanAction(context, player),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.admin_panel_settings, color: Colors.blue),
              tooltip: 'Cambiar Rol',
              onSelected: (newRole) => _confirmChangeRole(context, player, newRole),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'user', child: Text('Rol: Usuario')),
                const PopupMenuItem(value: 'staff', child: Text('Rol: Staff')),
                const PopupMenuItem(value: 'admin', child: Text('Rol: Administrador')),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              tooltip: 'Eliminar Usuario',
              onPressed: () => _confirmDeleteAction(context, player),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteAction(BuildContext context, Player player) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        title: Text('Eliminar Usuario',
            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
        content: Text(
          '¿Estás seguro de que deseas ELIMINAR DEFINITIVAMENTE a ${player.name}?\n\nEsta acción borrará su cuenta, progreso y autenticación. No se puede deshacer.',
          style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
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
                    .deleteUser(player.id);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Usuario eliminado correctamente')),
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
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmBanAction(BuildContext context, Player player) {
    final isBanned = player.status == PlayerStatus.banned;
    final action = isBanned ? 'desbanear' : 'banear';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        title: Text('Confirmar acción',
            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
        content: Text(
          '¿Estás seguro de que deseas $action a ${player.name}?',
          style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
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

  void _confirmChangeRole(BuildContext context, Player player, String newRole) {
    if (player.role == newRole) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        title: Text('Cambiar Rol',
            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
        content: Text(
          '¿Estás seguro de que deseas cambiar el rol de ${player.name} a "$newRole"?',
          style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
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
                    .updateUserRole(player.userId, newRole);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Rol actualizado a $newRole exitosamente')),
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
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}
