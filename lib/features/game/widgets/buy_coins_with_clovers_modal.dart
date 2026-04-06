import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/player_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/coin_image.dart';

class BuyCoinsWithCloversModal extends StatefulWidget {
  const BuyCoinsWithCloversModal({super.key});

  /// Displays the modal using `showModalBottomSheet`
  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const BuyCoinsWithCloversModal(),
    );
  }

  @override
  State<BuyCoinsWithCloversModal> createState() => _BuyCoinsWithCloversModalState();
}

class _BuyCoinsWithCloversModalState extends State<BuyCoinsWithCloversModal> {
  bool _isLoading = false;

  final List<Map<String, dynamic>> _plans = [
    {'coins': 100, 'clovers': 10},
    {'coins': 500, 'clovers': 45},
    {'coins': 1500, 'clovers': 120},
  ];

  Future<void> _buyPlan(int coins, int cloversCost) async {
    if (_isLoading) return;
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final currentClovers = playerProvider.currentPlayer?.clovers ?? 0;

    if (currentClovers < cloversCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tienes tréboles suficientes para este plan.'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // NOTE: In the absence of a dedicated backend RPC for exchanging clovers to session coins,
      // we apply optimistic UI updates for the prototype.
      // A backend endpoint should be implemented later to ensure secure transaction.
      final newClovers = currentClovers - cloversCost;
      final newCoins = (playerProvider.currentPlayer?.coins ?? 0) + coins;
      
      playerProvider.updateLocalClovers(newClovers);
      playerProvider.updateLocalCoins(newCoins);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Has obtenido $coins monedas!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error en la transacción: $e'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    final clovers = playerProvider.currentPlayer?.clovers ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151517),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AppTheme.accentGold.withOpacity(0.3), width: 1.5),
      ),
      padding: const EdgeInsets.only(top: 12, left: 24, right: 24, bottom: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentGold.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.currency_exchange_rounded, color: AppTheme.accentGold, size: 28),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Comprar Monedas',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Orbitron',
                      ),
                    ),
                    Text(
                      'Usa tus tréboles para obtener monedas',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),

          // Current Clovers balance
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tus Tréboles:',
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Text(
                      '$clovers',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.eco_rounded, color: Color(0xFF10B981), size: 20),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Plans List
          if (_isLoading)
            const SizedBox(height: 150, child: LoadingIndicator())
          else
            Column(
              children: _plans.map((plan) => _buildPlanCard(plan['coins'], plan['clovers'])).toList(),
            ),
            
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPlanCard(int coins, int cloversCost) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _buildConfirmDialog(coins, cloversCost),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                // Coins amount
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const CoinImage(size: 28),
                      const SizedBox(width: 8),
                      Text(
                        '+$coins',
                        style: const TextStyle(
                          color: AppTheme.accentGold,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Price in clovers
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '$cloversCost',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.eco_rounded, color: Colors.white, size: 16),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _buildConfirmDialog(int coins, int cloversCost) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmar Compra', style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Deseas canjear $cloversCost tréboles por $coins monedas?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _buyPlan(coins, cloversCost);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Canjear', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
