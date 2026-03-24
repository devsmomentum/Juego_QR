import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../../core/providers/payment_methods_config_provider.dart';

class PaymentMethodSelector extends StatefulWidget {
  final Function(String) onMethodSelected;

  const PaymentMethodSelector({
    super.key, 
    required this.onMethodSelected,
  });

  @override
  State<PaymentMethodSelector> createState() => _PaymentMethodSelectorState();
}

class _PaymentMethodSelectorState extends State<PaymentMethodSelector> {
  @override
  void initState() {
    super.initState();
    final configProvider =
        Provider.of<PaymentMethodsConfigProvider>(context, listen: false);
    configProvider.load();
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    final isDarkMode = playerProvider.isDarkMode;
    final configProvider = Provider.of<PaymentMethodsConfigProvider>(context);

    final allMethods = <_PaymentMethodUiSpec>[
      _PaymentMethodUiSpec(
        id: 'pago_movil',
        name: 'Pago Movil / Transferencia',
        icon: Icons.phone_android,
        color: AppTheme.accentGold,
        description: 'Recarga instantanea en Bolivares',
      ),
      _PaymentMethodUiSpec(
        id: 'stripe',
        name: 'Tarjeta de Credito / Debito',
        icon: Icons.credit_card_rounded,
        color: AppTheme.accentGold,
        description: 'Visa, Mastercard, Amex — pago en USD',
      ),
      _PaymentMethodUiSpec(
        id: 'zelle',
        name: 'Zelle',
        icon: Icons.attach_money,
        color: Colors.grey,
        description: 'Recarga en Dolares',
      ),
      _PaymentMethodUiSpec(
        id: 'cash',
        name: 'Efectivo',
        icon: Icons.payments_rounded,
        color: Colors.grey,
        description: 'Pago presencial en efectivo',
      ),
    ];

    final enabledMethods = allMethods
        .where((method) =>
            configProvider.isMethodEnabled('purchase', method.id))
        .toList();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF151517),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border(top: BorderSide(color: AppTheme.accentGold.withOpacity(0.3))),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Selecciona el Método de Pago',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 20),
            
            if (configProvider.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(color: AppTheme.accentGold),
                ),
              )
            else if (enabledMethods.isEmpty)
              _buildEmptyState()
            else
              ...enabledMethods.expand((method) sync* {
                yield _buildMethodTile(
                  context,
                  isDarkMode: isDarkMode,
                  id: method.id,
                  name: method.name,
                  icon: method.icon,
                  color: method.color,
                  description: method.description,
                );
                yield const SizedBox(height: 12);
              }).toList(),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: const [
          Icon(Icons.info_outline, size: 48, color: Colors.white24),
          SizedBox(height: 12),
          Text(
            'No hay metodos de pago disponibles por ahora',
            style: TextStyle(color: Colors.white60),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMethodTile(BuildContext context, {
    required bool isDarkMode,
    required String id,
    required String name,
    required IconData icon,
    required Color color,
    required String description,
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
                  onTap: enabled ? () => widget.onMethodSelected(id) : null,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: enabled ? color.withOpacity(0.3) : (isDarkMode ? Colors.white10 : Colors.black12),
              ),
              borderRadius: BorderRadius.circular(15),
              color: enabled ? color.withOpacity(0.05) : Colors.transparent,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: enabled ? color.withOpacity(0.2) : Colors.white10,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: enabled ? color : Colors.white24, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: enabled ? Colors.white : Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(
                            color: enabled ? Colors.white70 : Colors.white24,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                if (enabled)
                  Icon(Icons.arrow_forward_ios, color: color.withOpacity(0.5), size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentMethodUiSpec {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final String description;

  const _PaymentMethodUiSpec({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.description,
  });
}
