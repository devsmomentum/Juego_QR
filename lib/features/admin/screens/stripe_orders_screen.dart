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
          .from('clover_orders')
          .select('*, profiles:user_id(name, email)')
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

    final cardColor = Theme.of(context).cardTheme.color;
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, statsConstraints) {
          final bool isNarrow = statsConstraints.maxWidth < 450;
          return Wrap(
            runSpacing: 12,
            alignment: WrapAlignment.spaceAround,
            children: [
              _statChip('Total', total.toString(), textColor?.withOpacity(0.7) ?? Colors.grey, isNarrow),
              _statChip('Exitosas', success.toString(), AppTheme.successGreen,
                  isNarrow),
              _statChip(
                  'Pendientes', pending.toString(), Colors.orange, isNarrow),
              _statChip(
                  'Errores', failed.toString(), AppTheme.dangerRed, isNarrow),
              _statChip(
                'Ingresos',
                '\$${totalRevenue.toStringAsFixed(2)}',
                primaryColor,
                isNarrow,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statChip(String label, String value, Color color, bool isNarrow) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    return SizedBox(
      width: isNarrow ? 80 : 100,
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: isNarrow ? 12 : 14,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: textColor?.withOpacity(0.5),
              fontSize: isNarrow ? 9 : 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final profile = order['profiles'] as Map<String, dynamic>?;
    final extraData = order['extra_data'] as Map<String, dynamic>?;

    final status = order['status'] as String?;
    final statusColor = _statusColor(status);
    final amount = (order['amount'] as num?)?.toDouble() ?? 0.0;
    final clovers = (extraData?['clovers_amount'] as num?)?.toInt() ?? 0;
    final createdAt = order['created_at'] != null
        ? DateTime.parse(order['created_at']).toLocal()
        : null;
    final piId = order['stripe_payment_intent_id'] as String?;

    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final cardColor = Theme.of(context).cardTheme.color;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
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
          profile?['name'] ?? 'Usuario desconocido',
          style: TextStyle(
              color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          createdAt != null
              ? '${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}'
              : '—',
          style: TextStyle(color: textColor?.withOpacity(0.5), fontSize: 12),
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
              style: TextStyle(color: textColor?.withOpacity(0.7), fontSize: 11),
            ),
          ],
        ),
        iconColor: textColor?.withOpacity(0.5),
        collapsedIconColor: textColor?.withOpacity(0.5),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                _detailRow('Estado', _statusLabel(status), statusColor),
                _detailRow('Email', profile?['email'] ?? '—', textColor?.withOpacity(0.7) ?? Colors.grey),
                _detailRow(
                    'Plan', extraData?['plan_name'] ?? '—', textColor?.withOpacity(0.7) ?? Colors.grey),
                _detailRow(
                    'PaymentIntent',
                    piId != null
                        ? piId.substring(0, piId.length > 30 ? 30 : piId.length) + (piId.length > 30 ? '...' : '')
                        : '—',
                    textColor?.withOpacity(0.5) ?? Colors.grey),
                _detailRow(
                    'Order ID', order['id'] != null ? (order['id'].toString().substring(0, order['id'].toString().length > 8 ? 8 : order['id'].toString().length) + (order['id'].toString().length > 8 ? '...' : '')) : '—', textColor?.withOpacity(0.5) ?? Colors.grey),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, Color valueColor) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(color: textColor?.withOpacity(0.4), fontSize: 12)),
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

  Widget _buildFilters() {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final primaryColor = Theme.of(context).primaryColor;

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
                  color: isSelected ? Colors.black : textColor?.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
              selected: isSelected,
              selectedColor: primaryColor,
              backgroundColor: Theme.of(context).cardTheme.color,
              side: BorderSide(
                color: isSelected
                    ? primaryColor
                    : Theme.of(context).dividerColor.withOpacity(0.15),
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

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Órdenes Stripe',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: primaryColor),
            onPressed: _loadOrders,
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: primaryColor))
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
                              backgroundColor: primaryColor,
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
                                        color: textColor?.withOpacity(0.2), size: 64),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No hay órdenes ${_filterStatus != 'all' ? 'con estado "$_filterStatus"' : ''}',
                                      style: TextStyle(
                                          color: textColor?.withOpacity(0.5), fontSize: 14),
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
      ),
    );
  }
}
