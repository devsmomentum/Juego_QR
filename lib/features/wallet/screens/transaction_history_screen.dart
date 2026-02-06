import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/animated_cyber_background.dart';
import '../../../shared/widgets/glitch_text.dart';
import '../models/transaction_item.dart';
import '../repositories/transaction_repository.dart';
import '../providers/wallet_provider.dart'; // Keep for balance refresh only
import '../widgets/payment_webview_modal.dart';
import '../widgets/transaction_card.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final ITransactionRepository _repository = SupabaseTransactionRepository();
  late Future<List<TransactionItem>> _transactionsFuture;
  
  String _selectedFilter = 'Todos'; // 'Todos', 'Exitoso', 'Pendiente', 'Fallido', 'Expirado'
  final List<String> _filters = ['Todos', 'Exitoso', 'Pendiente', 'Fallido', 'Expirado'];

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
      _loadData(); // Reload list
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
          return status == 'completed' || status == 'success' || status == 'paid';
        case 'Pendiente':
          return status == 'pending';
        case 'Fallido':
          return status == 'failed' || status == 'error';
        case 'Expirado':
          return status == 'expired';
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: AnimatedCyberBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const GlitchText(
                      text: "Historial",
                      fontSize: 22,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: AppTheme.accentGold),
                      onPressed: _loadData,
                    ),
                  ],
                ),
              ),

              // Filters
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: _filters.map((filter) {
                    final isSelected = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ChoiceChip(
                        label: Text(
                          filter,
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppTheme.accentGold,
                        backgroundColor: Colors.white10,
                        onSelected: (bool selected) {
                          if (selected) {
                            setState(() => _selectedFilter = filter);
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),

              // Transaction List FutureBuilder
              Expanded(
                child: FutureBuilder<List<TransactionItem>>(
                  future: _transactionsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppTheme.accentGold));
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: AppTheme.dangerRed),
                              const SizedBox(height: 16),
                              Text(
                                'Error al cargar historial:\n${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadData,
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple),
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
                            const Icon(Icons.history_toggle_off, size: 60, color: Colors.white24),
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
    );
  }
}

