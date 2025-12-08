import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_request_provider.dart';
import '../../theme/app_theme.dart';
import '../../models/game_request.dart';

class RequestsManagementScreen extends StatefulWidget {
  const RequestsManagementScreen({super.key});

  @override
  State<RequestsManagementScreen> createState() => _RequestsManagementScreenState();
}

class _RequestsManagementScreenState extends State<RequestsManagementScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    await Provider.of<GameRequestProvider>(context, listen: false).fetchAllRequests();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requests = Provider.of<GameRequestProvider>(context).requests;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Solicitudes de Acceso"),
        backgroundColor: AppTheme.darkBg,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRequests,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.darkGradient,
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : requests.isEmpty
                ? const Center(
                    child: Text(
                      "No hay solicitudes pendientes",
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final request = requests[index];
                      return _RequestCard(request: request);
                    },
                  ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final GameRequest request;

  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final requestProvider = Provider.of<GameRequestProvider>(context, listen: false);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppTheme.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: request.statusColor.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    request.playerName ?? 'Usuario Desconocido',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: request.statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: request.statusColor),
                  ),
                  child: Text(
                    request.statusText,
                    style: TextStyle(
                      color: request.statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Email: ${request.playerEmail ?? "N/A"}',
              style: const TextStyle(color: Colors.white70),
            ),
            Text(
              'Evento: ${request.eventTitle ?? "Evento General"}',
              style: const TextStyle(color: Colors.white70),
            ),
            Text(
              'Fecha: ${request.createdAt.toString().split('.')[0]}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            
            if (request.isPending) ...[
              const Divider(color: Colors.white24, height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      try {
                        await requestProvider.rejectRequest(request.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Solicitud rechazada')),
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
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text('Rechazar', style: TextStyle(color: Colors.red)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await requestProvider.approveRequest(request.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Solicitud aprobada')),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('Aprobar'),
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
