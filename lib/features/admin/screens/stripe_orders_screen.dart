import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';

class StripeOrdersScreen extends StatefulWidget {
  const StripeOrdersScreen({super.key});

  @override
  State<StripeOrdersScreen> createState() => _StripeOrdersScreenState();
}

class _StripeOrdersScreenState extends State<StripeOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _error;
  String _filterStatus = 'all';

  final _statusOptions = ['all', 'success', 'pending', 'error', 'cancelled'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      var query = Supabase.instance.client
          .from('admin_stripe_orders')
          .select()
          .eq('gateway', 'stripe');

      if (_filterStatus != 'all') {
        query = query.eq('status', _filterStatus);
      }

      final response = await query.order('created_at', ascending: false);
      setState(() {
        _orders = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'success':
        return AppTheme.successGreen;
      case 'pending':
        return Colors.orange;
      case 'error':
      case 'cancelled':
        return AppTheme.dangerRed;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'success':
        return '✅ Exitosa';
      case 'pending':
        return '⏳ Pendiente';
      case 'error':
        return '❌ Error';
      case 'cancelled':
        return '🚫 Cancelada';
      default:
        return status ?? 'Desconocido';
    }
  }

  // ─── STATS BAR ───────────────────────────────────────────────────────────
  Widget _buildStatsBar() {
    final total = _orders.length;
    final success = _orders.where((o) => o['status'] == 'success').length;
    final pending = _orders.where((o) => o['status'] == 'pending').length;
    final failed = _orders
        .where((o) => o['status'] == 'error' || o['status'] == 'cancelled')
        .length;
    final totalRevenue = _orders
        .where((o) => o['status'] == 'success')
        .fold<double>(0.0, (sum, o) => sum + ((o['amount'] as num?)?.toDouble() ?? 0.0));

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentGold.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          _statChip('Total', total.toString(), Colors.white54),
          _statChip('Exitosas', success.toString(), AppTheme.successGreen),
          _statChip('Pendientes', pending.toString(), Colors.orange),
          _statChip('Errores', failed.toString(), AppTheme.dangerRed),
          _statChip(
            'Ingresos',
            '\$${totalRevenue.toStringAsFixed(2)}',
            AppTheme.accentGold,
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }

  // ─── ORDER CARD ──────────────────────────────────────────────────────────
  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['status'] as String?;
    final statusColor = _statusColor(status);
    final amount = (order['amount'] as num?)?.toDouble() ?? 0.0;
    final clovers = (order['clovers_amount'] as num?)?.toInt() ?? 0;
    final createdAt = order['created_at'] != null
        ? DateTime.parse(order['created_at']).toLocal()
        : null;
    final piId = order['stripe_payment_intent_id'] as String?;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withOpacity(0.35)),
      ),
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            status == 'success'
                ? Icons.check_circle_outline
                : status == 'pending'
                    ? Icons.hourglass_top
                    : Icons.cancel_outlined,
            color: statusColor,
            size: 22,
          ),
        ),
        title: Text(
          order['user_name'] ?? 'Usuario desconocido',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          createdAt != null
              ? '${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}'
              : '—',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${amount.toStringAsFixed(2)} USD',
              style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
            Text(
              '${clovers} 🍀',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
        iconColor: Colors.white54,
        collapsedIconColor: Colors.white54,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(color: Colors.white12),
                _detailRow('Estado', _statusLabel(status), statusColor),
                _detailRow('Email', order['user_email'] ?? '—', Colors.white70),
                _detailRow(
                    'Plan', order['plan_name'] ?? '—', Colors.white70),
                _detailRow(
                    'PaymentIntent',
                    piId != null
                        ? piId.substring(0, min(piId.length, 30)) + '...'
                        : '—',
                    Colors.white54),
                _detailRow(
                    'Order ID', order['id'] != null ? (order['id'].toString().substring(0, 8) + '...') : '—', Colors.white54),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: valueColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  // ─── FILTER CHIPS ─────────────────────────────────────────────────────────
  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: _statusOptions.map((s) {
          final isSelected = _filterStatus == s;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                s == 'all' ? 'Todas' : _statusLabel(s),
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white70,
                  fontSize: 12,
                ),
              ),
              selected: isSelected,
              selectedColor: AppTheme.accentGold,
              backgroundColor: AppTheme.cardBg,
              side: BorderSide(
                color: isSelected
                    ? AppTheme.accentGold
                    : Colors.white.withOpacity(0.15),
              ),
              onSelected: (_) {
                setState(() => _filterStatus = s);
                _loadOrders();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  int min(int a, int b) => a < b ? a : b;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Órdenes Stripe',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadOrders,
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accentGold))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.redAccent, size: 48),
                      const SizedBox(height: 16),
                      Text(_error!,
                          style: const TextStyle(color: Colors.redAccent),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadOrders,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentGold,
                            foregroundColor: Colors.black),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _buildStatsBar(),
                    _buildFilters(),
                    Expanded(
                      child: _orders.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.credit_card_off_outlined,
                                      color: Colors.white24, size: 64),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No hay órdenes ${_filterStatus != 'all' ? 'con estado "$_filterStatus"' : ''}',
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 14),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _orders.length,
                              padding:
                                  const EdgeInsets.only(top: 4, bottom: 24),
                              itemBuilder: (_, i) =>
                                  _buildOrderCard(_orders[i]),
                            ),
                    ),
                  ],
                ),
    );
  }
}
