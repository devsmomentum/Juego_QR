import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_handler.dart';

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

  final _statusOptions = ['all', 'success', 'pending', 'expired', 'error', 'cancelled'];

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

  /// Verifies the PaymentIntent status in Stripe, then marks the order as success.
  /// The DB trigger process_paid_clover_order automatically credits clovers when status = 'success'.
  Future<void> _markOrderComplete(String orderId, Map<String, dynamic> extraData) async {
    final piId = extraData['pi_id'] as String? ?? 
                 (extraData.containsKey('stripe_pi_id') ? extraData['stripe_pi_id'] as String? : null);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verificar y acreditar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Se consultará Stripe en tiempo real para verificar si el pago fue exitoso antes de acreditar los tréboles.'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order: ${orderId.substring(0, 8)}...',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                  if (piId != null)
                    Text(
                      'PI: $piId',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                    ),
                  Text(
                    'Tréboles: ${extraData['clovers_amount'] ?? '?'}',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '⚠️ Si Stripe no confirma el pago, los tréboles NO se acreditarán.',
              style: TextStyle(color: Colors.orange, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Verificar y acreditar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show loading
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 12),
              Text('Verificando con Stripe...'),
            ],
          ),
          duration: Duration(seconds: 10),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    try {
      // Call the Edge Function — it verifies PI in Stripe then credits if confirmed
      final response = await Supabase.instance.client.functions.invoke(
        'stripe-verify-and-credit',
        body: {'clover_order_id': orderId},
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final data = response.data as Map<String, dynamic>?;
      final success = data?['success'] == true;
      final message = data?['message'] as String? ?? data?['error'] as String? ?? 'Error desconocido';
      final stripeStatus = data?['stripe_status'] as String?;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                success ? '✅ Éxito' : '❌ No se pudo acreditar',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(message, style: const TextStyle(fontSize: 12)),
              if (stripeStatus != null && !success)
                Text(
                  'Estado en Stripe: "$stripeStatus"',
                  style: const TextStyle(fontSize: 11, color: Colors.orange),
                ),
            ],
          ),
          backgroundColor: success ? AppTheme.successGreen : AppTheme.dangerRed,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (success) _loadOrders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        // Extract friendly message from FunctionException or fallback
        String errorMsg;
        if (e is FunctionException) {
          final details = e.details;
          if (details is Map && details['error'] is String) {
            errorMsg = details['error'] as String;
          } else if (details is Map && details['message'] is String) {
            errorMsg = details['message'] as String;
          } else {
            errorMsg = ErrorHandler.getFriendlyErrorMessage(e);
          }
          // Also show stripe_status if available
          final stripeStatus = details is Map ? details['stripe_status'] as String? : null;
          if (stripeStatus != null) {
            errorMsg += '\nEstado en Stripe: "$stripeStatus"';
          }
        } else {
          errorMsg = ErrorHandler.getFriendlyErrorMessage(e);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppTheme.dangerRed,
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }


  void _copyToClipboard(String text, String label) {
    // Try Clipboard API first (works on desktop/most browsers)
    Clipboard.setData(ClipboardData(text: text)).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label copiado'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }).catchError((_) {
      // Fallback for mobile web — show dialog with selectable text
      _showCopyDialog(text, label);
    });
  }

  void _showCopyDialog(String text, String label) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mantén presionado para copiar:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: SelectableText(
                text,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'success':
        return AppTheme.successGreen;
      case 'pending':
        return Colors.orange;
      case 'expired':
        return Colors.purple;
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
      case 'expired':
        return '🕐 Expirada';
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
    final expired = _orders.where((o) => o['status'] == 'expired').length;
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
          final bool isNarrow = statsConstraints.maxWidth < 500;
          return Wrap(
            runSpacing: 12,
            alignment: WrapAlignment.spaceAround,
            children: [
              _statChip('Total', total.toString(), textColor?.withOpacity(0.7) ?? Colors.grey, isNarrow),
              _statChip('Exitosas', success.toString(), AppTheme.successGreen, isNarrow),
              _statChip('Pendientes', pending.toString(), Colors.orange, isNarrow),
              _statChip('Expiradas', expired.toString(), Colors.purple, isNarrow),
              _statChip('Errores', failed.toString(), AppTheme.dangerRed, isNarrow),
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
    final orderId = order['id']?.toString() ?? '';

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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              createdAt != null
                  ? '${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}'
                  : '—',
              style: TextStyle(color: textColor?.withOpacity(0.5), fontSize: 11),
            ),
            // Order ID visible directly in collapsed header
            if (orderId.isNotEmpty)
              GestureDetector(
                onTap: () => _copyToClipboard(orderId, 'Order ID'),
                child: Row(
                  children: [
                    Text(
                      '${orderId.substring(0, orderId.length > 8 ? 8 : orderId.length)}...',
                      style: TextStyle(
                        color: textColor?.withOpacity(0.35),
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.copy_rounded,
                        size: 10, color: textColor?.withOpacity(0.3)),
                  ],
                ),
              ),
          ],
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
              '$clovers 🍀',
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
                _detailRow('Email', profile?['email'] ?? '—',
                    textColor?.withOpacity(0.7) ?? Colors.grey),
                _detailRow(
                    'Plan',
                    extraData?['plan_name'] ?? '—',
                    textColor?.withOpacity(0.7) ?? Colors.grey),
                // Full Order ID — tappable to copy
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text('Order ID',
                            style: TextStyle(
                                color: textColor?.withOpacity(0.4),
                                fontSize: 12)),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _copyToClipboard(orderId, 'Order ID'),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  orderId,
                                  style: TextStyle(
                                    color: textColor?.withOpacity(0.7),
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.copy_rounded,
                                  size: 13,
                                  color: textColor?.withOpacity(0.4)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Full PaymentIntent ID — tappable to copy
                if (piId != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 110,
                          child: Text('PaymentIntent',
                              style: TextStyle(
                                  color: textColor?.withOpacity(0.4),
                                  fontSize: 12)),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _copyToClipboard(piId, 'PaymentIntent ID'),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    piId,
                                    style: TextStyle(
                                      color: textColor?.withOpacity(0.5),
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.copy_rounded,
                                    size: 13,
                                    color: textColor?.withOpacity(0.4)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Action button for pending OR expired orders
                if (status == 'pending' || status == 'expired') ...
                  [
                    const SizedBox(height: 8),
                    // Info for expired orders
                    if (status == 'expired')
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.purple.withOpacity(0.25)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, size: 13, color: Colors.purple),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Verifica en Stripe Dashboard si el PaymentIntent está "Succeeded" antes de completar.',
                                style: TextStyle(color: Colors.purple, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _markOrderComplete(
                            orderId, extraData ?? {}),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successGreen.withOpacity(0.15),
                          foregroundColor: AppTheme.successGreen,
                          side: BorderSide(
                              color: AppTheme.successGreen.withOpacity(0.4)),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text(
                          'Acreditar tréboles manualmente',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
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
