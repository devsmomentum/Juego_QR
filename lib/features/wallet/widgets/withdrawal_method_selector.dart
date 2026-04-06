import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/payment_methods_config_provider.dart';
import '../providers/payment_method_provider.dart';
import '../../auth/providers/player_provider.dart';
import 'add_withdrawal_method_dialog.dart';
import 'edit_payment_method_dialog.dart';

/// Pure UI Widget for selecting withdrawal methods
/// 
/// Responsibilities:
/// - Display list of payment methods
/// - Handle user interactions (select, delete, add)
/// - Delegate all business logic to PaymentMethodProvider
class WithdrawalMethodSelector extends StatefulWidget {
  final Function(Map<String, dynamic>) onMethodSelected;

  const WithdrawalMethodSelector({
    super.key,
    required this.onMethodSelected,
  });

  @override
  State<WithdrawalMethodSelector> createState() => _WithdrawalMethodSelectorState();
}

class _WithdrawalMethodSelectorState extends State<WithdrawalMethodSelector> {
  String? _selectedMethodId;

  @override
  void initState() {
    super.initState();
    _loadMethods();
    final configProvider =
        Provider.of<PaymentMethodsConfigProvider>(context, listen: false);
    configProvider.load();
  }

  Future<void> _loadMethods() async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final paymentProvider = Provider.of<PaymentMethodProvider>(context, listen: false);
    
    final userId = playerProvider.currentPlayer?.userId;
    if (userId != null) {
      await paymentProvider.loadMethods(userId);
    }
  }

  Future<void> _deleteMethod(String id) async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final paymentProvider = Provider.of<PaymentMethodProvider>(context, listen: false);
    
    final userId = playerProvider.currentPlayer?.userId;
    if (userId == null) return;

    final success = await paymentProvider.deleteMethod(id, userId);
    
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(paymentProvider.error ?? 'Error eliminando método')),
      );
    }
    
    if (_selectedMethodId == id) {
      setState(() => _selectedMethodId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Selecciona Método de Retiro',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: AppTheme.accentGold),
                onPressed: () async {
                  final result = await showDialog(
                    context: context,
                    builder: (_) => const AddWithdrawalMethodDialog(),
                  );
                  if (result == true) {
                    _loadMethods();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Consumer<PaymentMethodProvider>(
            builder: (context, provider, child) {
              final configProvider =
                  Provider.of<PaymentMethodsConfigProvider>(context);

              if (provider.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: AppTheme.accentGold),
                );
              }

              final enabledMethods = provider.methods.where((method) {
                final type = method['type'] ?? 'pago_movil';
                return configProvider.isMethodEnabled('withdrawal', type);
              }).toList();

              final stripeEnabled =
                  configProvider.isMethodEnabled('withdrawal', 'stripe');
              
              // Check if user has an automated Stripe Connect account
              final player = Provider.of<PlayerProvider>(context).currentPlayer;
              final hasLinkedConnnect = player?.stripeConnectId != null && 
                                      player?.stripeOnboardingCompleted == true;

              final hasStripeMethod = provider.methods.any((method) {
                final type = method['type'] ?? 'pago_movil';
                return type == 'stripe';
              });

              final displayMethods = [...enabledMethods];
              
              // Add virtual method for linked connect account if it exists and isn't already in the list
              if (hasLinkedConnnect && stripeEnabled) {
                 displayMethods.insert(0, {
                   'id': 'stripe_connected_account',
                   'type': 'stripe',
                   'identifier': 'Cuenta vinculada de Stripe',
                   'is_automated': true,
                 });
              }

              if (displayMethods.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined,
                            size: 48, color: Colors.white24),
                        const SizedBox(height: 12),
                        const Text(
                          'No hay métodos de retiro disponibles',
                          style: TextStyle(color: Colors.white60),
                        ),
                        TextButton(
                          onPressed: () async {
                            final result = await showDialog(
                              context: context,
                              builder: (_) => const AddWithdrawalMethodDialog(),
                            );
                            if (result == true) {
                              _loadMethods();
                            }
                          },
                          child: const Text('Agregar Método',
                              style: TextStyle(color: AppTheme.accentGold)),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: displayMethods.length +
                      (stripeEnabled && !hasStripeMethod && !hasLinkedConnnect ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    if (stripeEnabled && !hasStripeMethod && !hasLinkedConnnect && index == 0) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF635BFF).withOpacity(0.4),
                          ),
                        ),
                        child: ListTile(
                          onTap: () async {
                            final result = await showDialog(
                              context: context,
                              builder: (_) =>
                                  const AddWithdrawalMethodDialog.withInitialType(
                                initialType: 'stripe',
                              ),
                            );
                            if (result == true) {
                              _loadMethods();
                            }
                          },
                          leading: const Icon(Icons.credit_card_rounded,
                              color: Color(0xFF635BFF)),
                          title: const Text(
                            'Agregar Stripe',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text(
                            'Configura tu email para retiros internacionales',
                            style: TextStyle(color: Colors.white70),
                          ),
                          trailing: const Icon(Icons.add_circle_outline,
                              color: Color(0xFF635BFF)),
                        ),
                      );
                    }

                    final methodIndex =
                        (stripeEnabled && !hasStripeMethod && !hasLinkedConnnect) ? index - 1 : index;
                    final method = displayMethods[methodIndex];
                    final isSelected = _selectedMethodId == method['id'];
                    final type = method['type'] ?? 'pago_movil';
                    final isStripe = type == 'stripe';
                    final isAutomated = method['is_automated'] == true;

                    final title = isAutomated
                        ? 'Cuenta Stripe vinculada'
                        : (isStripe
                            ? 'Stripe'
                            : 'Pago Móvil - Banco ${method['bank_code'] ?? '???'}');
                    final subtitle = isAutomated
                        ? 'Transferencia automática directa'
                        : (isStripe
                            ? (method['identifier'] ?? 'Email no configurado')
                            : (method['phone_number'] ?? 'Teléfono no configurado'));
                    final icon = isStripe
                        ? Icons.account_balance_wallet_rounded
                        : Icons.phone_android;
                    final iconColor = isStripe
                        ? const Color(0xFF635BFF)
                        : AppTheme.secondaryPink;

                    return Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.accentGold.withOpacity(0.1)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.accentGold
                              : Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: ListTile(
                        onTap: () {
                          setState(() => _selectedMethodId = method['id']);
                          widget.onMethodSelected(method);
                        },
                        leading: Icon(icon, color: iconColor),
                        title: Text(
                          title,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          subtitle,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        trailing: isAutomated 
                          ? const Icon(Icons.verified_user_rounded, color: AppTheme.successGreen, size: 20)
                          : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () {}, // Bubble block
                                child: IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      color: Colors.white38),
                                  onPressed: () async {
                                    final result = await showDialog(
                                      context: context,
                                      builder: (_) =>
                                          EditPaymentMethodDialog(method: method),
                                    );
                                    if (result == true) {
                                      _loadMethods();
                                    }
                                  },
                                ),
                              ),
                              GestureDetector(
                                onTap: () {}, // Bubble block
                                child: IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.white38),
                                  onPressed: () => _deleteMethod(method['id']),
                                ),
                              ),
                            ],
                          ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
