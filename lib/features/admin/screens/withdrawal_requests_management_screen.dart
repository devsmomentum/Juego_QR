import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../models/admin_withdrawal_request.dart';
import '../repositories/withdrawal_request_repository.dart';
import 'package:intl/intl.dart';

class WithdrawalRequestsManagementScreen extends StatefulWidget {
  const WithdrawalRequestsManagementScreen({super.key});

  @override
  State<WithdrawalRequestsManagementScreen> createState() =>
      _WithdrawalRequestsManagementScreenState();
}

class _WithdrawalRequestsManagementScreenState
    extends State<WithdrawalRequestsManagementScreen> {
  late WithdrawalRequestRepository _repository;
  List<AdminWithdrawalRequest> _requests = [];
  bool _isLoading = true;
  String _statusFilter = 'pending';
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = WithdrawalRequestRepository(
        supabaseClient: Supabase.instance.client);
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final requests = await _repository.fetchRequests(status: _statusFilter);
      setState(() {
        _requests = requests;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _processRequest(AdminWithdrawalRequest request, bool approve) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1D),
        title: Text(approve ? 'Confirmar Retiro' : 'Rechazar Retiro',
            style: const TextStyle(color: Colors.white)),
        content: Text(
            '¿Estás seguro de que deseas ${approve ? 'confirmar' : 'rechazar'} este retiro de \$${request.amountUsd.toStringAsFixed(2)} para ${request.userName ?? 'el usuario'}?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: approve ? AppTheme.successGreen : AppTheme.dangerRed,
            ),
            child: Text(approve ? 'Confirmar' : 'Rechazar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    
    final WithdrawalActionResult result = approve
        ? await _repository.markAsCompleted(request.id, {
            'processed_at': DateTime.now().toIso8601String(),
            'notes': 'Procesado manualmente por el admin',
          })
        : await _repository.markAsFailed(request.id, {
            'processed_at': DateTime.now().toIso8601String(),
            'reason': 'Rechazado por el admin',
          }, refund: true);

    if (mounted) {
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        _loadRequests();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header & Filters
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              _buildFilterChip('Pendientes', 'pending'),
              const SizedBox(width: 8),
              _buildFilterChip('Completados', 'completed'),
              const SizedBox(width: 8),
              _buildFilterChip('Fallidos', 'failed'),
              const SizedBox(width: 8),
              _buildFilterChip('Todos', 'all'),
            ],
          ),
        ),

        // List
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadRequests,
            color: AppTheme.lGoldAction,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.lGoldAction))
                : _error != null
                    ? Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)))
                    : _requests.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                              const Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.history, size: 64, color: Colors.white24),
                                    SizedBox(height: 16),
                                    Text('No hay solicitudes', style: TextStyle(color: Colors.white54)),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _requests.length,
                            itemBuilder: (context, index) {
                              return _buildRequestCard(_requests[index]);
                            },
                          ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _statusFilter = value);
        _loadRequests();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.lGoldAction : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.lGoldAction : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(AdminWithdrawalRequest request) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final color = request.isStripe ? const Color(0xFF635BFF) : AppTheme.secondaryPink;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar/Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(request.isStripe ? '💳' : '💸', style: const TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 12),
              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.userName ?? 'Usuario desconocido',
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      request.userEmail ?? request.userId,
                      style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${request.amountUsd.toStringAsFixed(2)}',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    '${request.cloversCost} Tréboles',
                    style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6), fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('MÉTODO', style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(
                    request.isStripe ? 'Stripe (${request.stripeEmail})' : 'Pago Móvil',
                    style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 13),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('FECHA', style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(
                    dateFormat.format(request.createdAt),
                    style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          if (request.isPending) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _processRequest(request, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.dangerRed,
                      side: const BorderSide(color: AppTheme.dangerRed),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Rechazar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _processRequest(request, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Confirmar Pago'),
                  ),
                ),
              ],
            ),
          ] else ...[
             const SizedBox(height: 12),
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
               decoration: BoxDecoration(
                 color: request.isCompleted ? AppTheme.successGreen.withOpacity(0.1) : AppTheme.dangerRed.withOpacity(0.1),
                 borderRadius: BorderRadius.circular(8),
               ),
               child: Row(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Icon(
                     request.isCompleted ? Icons.check_circle : Icons.error,
                     size: 14,
                     color: request.isCompleted ? AppTheme.successGreen : AppTheme.dangerRed,
                   ),
                   const SizedBox(width: 6),
                   Text(
                     request.status.toUpperCase(),
                     style: TextStyle(
                       color: request.isCompleted ? AppTheme.successGreen : AppTheme.dangerRed,
                       fontWeight: FontWeight.bold,
                       fontSize: 12,
                     ),
                   ),
                 ],
               ),
             ),
          ],
        ],
      ),
    );
  }
}
