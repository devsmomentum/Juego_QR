import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../game/providers/game_request_provider.dart';
import '../../game/models/game_request.dart';
import '../../../core/theme/app_theme.dart';
import 'package:intl/intl.dart';

class GlobalGameRequestsScreen extends StatefulWidget {
  const GlobalGameRequestsScreen({super.key});

  @override
  State<GlobalGameRequestsScreen> createState() => _GlobalGameRequestsScreenState();
}

class _GlobalGameRequestsScreenState extends State<GlobalGameRequestsScreen> {
  bool _isLoading = false;
  String _filterStatus = 'pending';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchRequests();
    });
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);
    await Provider.of<GameRequestProvider>(context, listen: false).fetchAllRequests();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handleAction(GameRequest request, bool approve) async {
    final actionName = approve ? "Aprobar" : "Rechazar";
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        title: Text("$actionName Inscripción",
            style: TextStyle(color: Theme.of(context).textTheme.displayLarge?.color)),
        content: Text(
          "¿Estás seguro de que deseas $actionName a ${request.playerName} para el evento \"${request.eventName}\"?",
          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: approve ? AppTheme.successGreen : AppTheme.dangerRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(actionName.toUpperCase()),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<GameRequestProvider>(context, listen: false);
      if (approve) {
        final result = await provider.approveRequest(request.id);
        if (mounted) {
          if (result['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ Inscripción aprobada'), backgroundColor: AppTheme.successGreen),
            );
          } else {
             ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('❌ Error: ${result['error']}'), backgroundColor: AppTheme.dangerRed),
            );
          }
        }
      } else {
        await provider.rejectRequest(request.id);
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🚫 Inscripción rechazada'), backgroundColor: AppTheme.dangerRed),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error crítico: $e'), backgroundColor: AppTheme.dangerRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameRequestProvider>();
    final allRequests = provider.requests;
    
    // Filter locally
    final filteredRequests = allRequests.where((r) {
      if (_filterStatus == 'all') return true;
      return r.status == _filterStatus;
    }).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Header Stats & Filter
          Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                   _buildFilterChip('Pendientes', 'pending'),
                   const SizedBox(width: 8),
                   _buildFilterChip('Aprobados', 'approved'),
                   const SizedBox(width: 8),
                   _buildFilterChip('Pagados', 'paid'),
                   const SizedBox(width: 8),
                   _buildFilterChip('Rechazados', 'rejected'),
                   const SizedBox(width: 8),
                   _buildFilterChip('Todos', 'all'),
                ],
              ),
            ),
          ),

          // List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchRequests,
              color: AppTheme.lGoldAction,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.lGoldAction))
                  : filteredRequests.isEmpty
                      ? ListView( // Use ListView so Pull-to-refresh works even if empty
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.person_add_disabled, size: 64, color: Colors.white.withOpacity(0.2)),
                                  const SizedBox(height: 16),
                                  Text("No hay solicitudes con este filtro", 
                                      style: TextStyle(color: Colors.white.withOpacity(0.5))),
                                  const SizedBox(height: 8),
                                  Text("Desliza hacia abajo para actualizar", 
                                      style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredRequests.length,
                          itemBuilder: (context, index) {
                            final req = filteredRequests[index];
                            return _buildRequestCard(req);
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _filterStatus = value);
      },
      selectedColor: AppTheme.lGoldAction,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.white.withOpacity(0.05),
    );
  }

  Widget _buildRequestCard(GameRequest request) {
    final dateFormat = DateFormat('dd/MM HH:mm');
    final date = request.createdAt != null ? dateFormat.format(request.createdAt!) : '—';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.lGoldAction.withOpacity(0.1),
                  child: const Icon(Icons.person, color: AppTheme.lGoldAction),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.playerName, 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(request.playerEmail ?? 'Sin email', 
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: request.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    request.statusText,
                    style: TextStyle(color: request.statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.emoji_events, size: 14, color: Colors.amber),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(request.eventName ?? 'Evento desconocido', 
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                ),
                Text(date, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
              ],
            ),
            if (request.isPending) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.dangerRed,
                        side: const BorderSide(color: AppTheme.dangerRed),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _handleAction(request, false),
                      child: const Text("Rechazar"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _handleAction(request, true),
                      child: const Text("Aprobar"),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
