import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/player_provider.dart';
import '../../../shared/widgets/animated_cyber_background.dart';
import '../../../shared/widgets/glitch_text.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../models/transaction_item.dart';
import '../repositories/transaction_repository.dart';
import '../providers/wallet_provider.dart'; // Keep for balance refresh only
import '../widgets/payment_webview_modal.dart';
import '../widgets/payment_validation_widget.dart';
import '../widgets/transaction_card.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final ITransactionRepository _repository = SupabaseTransactionRepository();
  late Future<List<TransactionItem>> _transactionsFuture;

  String _selectedFilter =
      'Todos'; // 'Todos', 'Exitoso', 'Pendiente', 'Cancelado', 'Expirado'
  final List<String> _filters = [
    'Todos',
    'Exitoso',
    'Pendiente',
    'Cancelado',
    'Expirado'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _transactionsFuture = _repository.getMyTransactions();
    });
    // Also refresh balance in background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<WalletProvider>(context, listen: false).refreshBalance();
    });
  }

  void _onResumePayment(String url) async {
    final bool? result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.1),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: PaymentWebViewModal(paymentUrl: url),
        ),
      ),
    );

    if (result == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pago completado. Actualizando...'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
      _loadData();
    }
  }

  void _onValidateMpay(TransactionItem item) async {
    final bool? result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: PaymentValidationWidget(
            orderId: item.pagoOrderId!,
            amountVes: item.fiatAmountVes ?? item.fiatAmount,
          ),
        ),
      ),
    );

    if (result == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Pago verificado! Actualizando saldo...'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
      Provider.of<WalletProvider>(context, listen: false).refreshBalance();
      _loadData();
    } else {
      _loadData();
    }
  }

  List<TransactionItem> _filterTransactions(List<TransactionItem> allItems) {
    if (_selectedFilter == 'Todos') {
      return allItems;
    }

    return allItems.where((tx) {
      final status = tx.status.toLowerCase();

      switch (_selectedFilter) {
        case 'Exitoso':
          return status == 'completed' ||
              status == 'success' ||
              status == 'paid';
        case 'Pendiente':
          return status == 'pending';
        case 'Cancelado':
          return status == 'cancelled';
        case 'Expirado':
          return status == 'expired';
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    // Logic for background image (dynamic)
    final isDayNightMode = playerProvider.isDarkMode;
    // Logic for UI components (Always Dark)
    const bool isDarkUI = true;

    return Scaffold(
      backgroundColor: const Color(0xFF151517), // Always dark
      body: Stack(
        children: [
          // Theme-dependent Background Image (Remains dynamic)
          Positioned.fill(
            child: Opacity(
              opacity: 0.4,
              child: Image.asset(
                isDayNightMode
                    ? 'assets/images/fotogrupalnoche.png'
                    : 'assets/images/personajesgrupal.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: isDarkUI ? const Color(0xFF151517) : Colors.white,
                ),
              ),
            ),
          ),
          AnimatedCyberBackground(
            showBackgroundBase: false,
            showParticles: false,
            child: SafeArea(
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        _CyberRingButton(
                          size: 40,
                          icon: Icons.arrow_back_ios_new_rounded,
                          onPressed: () => Navigator.pop(context),
                          color: AppTheme.accentGold,
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'HISTORIAL',
                          style: TextStyle(
                            color: AppTheme.accentGold,
                            fontFamily: 'Orbitron',
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.refresh,
                              color: AppTheme.accentGold),
                          onPressed: _loadData,
                        ),
                      ],
                    ),
                  ),

                  // Filters - REFACTORED TO AVOID SCROLLING (Fixed Row with Expanded children)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 15),
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: _filters.map((filter) {
                        final isSelected = _selectedFilter == filter;

                        IconData icon;
                        Color iconColor;
                        String shortLabel = filter;
                        switch (filter) {
                          case 'Exitoso':
                            icon = Icons.check_circle_outline;
                            iconColor = AppTheme.successGreen;
                            break;
                          case 'Pendiente':
                            icon = Icons.access_time_rounded;
                            iconColor = Colors.orangeAccent;
                            break;
                          case 'Fallido':
                            icon = Icons.error_outline_rounded;
                            iconColor = AppTheme.dangerRed;
                            break;
                          case 'Expirado':
                            icon = Icons.timer_off_outlined;
                            iconColor = Colors.grey;
                            shortLabel = "Expira";
                            break;
                          default:
                            icon = Icons.all_inclusive_rounded;
                            iconColor = AppTheme.accentGold;
                        }

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: InkWell(
                              onTap: () =>
                                  setState(() => _selectedFilter = filter),
                              borderRadius: BorderRadius.circular(10),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.accentGold.withOpacity(0.2)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.accentGold.withOpacity(0.5)
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(icon,
                                        size: 14,
                                        color: isSelected
                                            ? AppTheme.accentGold
                                            : iconColor.withOpacity(0.8)),
                                    const SizedBox(height: 4),
                                    Text(
                                      shortLabel,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.white60,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Transaction List FutureBuilder
                  Expanded(
                    child: FutureBuilder<List<TransactionItem>>(
                      future: _transactionsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator(
                                  color: AppTheme.accentGold));
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error_outline,
                                      size: 48, color: AppTheme.dangerRed),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Error al cargar historial:\n${snapshot.error}',
                                    textAlign: TextAlign.center,
                                    style:
                                        const TextStyle(color: Colors.white70),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _loadData,
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            AppTheme.primaryPurple),
                                    child: const Text("Reintentar"),
                                  )
                                ],
                              ),
                            ),
                          );
                        }

                        final allItems = snapshot.data ?? [];
                        final filteredItems = _filterTransactions(allItems);

                        if (filteredItems.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.history_toggle_off,
                                    size: 60, color: Colors.white24),
                                const SizedBox(height: 16),
                                Text(
                                  allItems.isEmpty
                                      ? 'No tienes movimientos aún.'
                                      : 'No hay transacciones ${_selectedFilter != 'Todos' ? '$_selectedFilter(s)' : ''}',
                                  style: const TextStyle(color: Colors.white54),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            return TransactionCard(
                              item: item,
                              onResumePayment: item.canResumePayment
                                  ? () => _onResumePayment(item.paymentUrl!)
                                  : null,
                              onCancelOrder: item.canCancel
                                  ? () async {
                                      // Confirmation Dialog
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          backgroundColor: AppTheme.cardBg,
                                          title: const Text('Cancelar Orden',
                                              style: TextStyle(
                                                  color: Colors.white)),
                                          content: const Text(
                                            '¿Estás seguro de que quieres cancelar esta orden pendiente?',
                                            style: TextStyle(
                                                color: Colors.white70),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('No',
                                                  style: TextStyle(
                                                      color: Colors.white54)),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text('Sí, Cancelar',
                                                  style: TextStyle(
                                                      color:
                                                          AppTheme.dangerRed)),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirm != true) return;

                                      try {
                                        bool success;
                                        if (item.canCancelWithdrawal) {
                                          LoadingOverlay.show(context, message: 'Cancelando retiro y devolviendo saldo...');
                                          success = await _repository.cancelWithdrawal(item.id);
                                        } else {
                                          LoadingOverlay.show(context, message: 'Cancelando orden...');
                                          success = await _repository.cancelOrder(item.id);
                                        }

                                        if (mounted) LoadingOverlay.hide(context);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(success 
                                                ? (item.canCancelWithdrawal ? 'Retiro cancelado y tréboles devueltos' : 'Orden cancelada exitosamente')
                                                : 'Error al cancelar'),
                                              backgroundColor: success ? AppTheme.successGreen : AppTheme.dangerRed,
                                            ),
                                          );
                                          // Refresh balance in background if withdrawal cancelled
                                          if (success && item.canCancelWithdrawal) {
                                            Provider.of<WalletProvider>(context, listen: false).refreshBalance();
                                          }
                                        }
                                      } catch (e) {
                                        if (mounted) LoadingOverlay.hide(context);
                                        debugPrint('Error in cancellation: $e');
                                      } finally {
                                        _loadData();
                                      }
                                    }
                                  : null,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CyberRingButton extends StatelessWidget {
  final double size;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;

  const _CyberRingButton({
    required this.size,
    required this.icon,
    this.onPressed,
    this.color = const Color(0xFFFECB00),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1.0,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(0.4),
            border: Border.all(
              color: color.withOpacity(0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 8,
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: size * 0.5,
          ),
        ),
      ),
    );
  }
}
