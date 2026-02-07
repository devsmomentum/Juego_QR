import 'package:flutter/material.dart';
import '../models/clover_plan.dart';
import '../../../core/theme/app_theme.dart';

/// A selectable card widget for displaying a clover purchase plan.
/// 
/// Shows plan name, clover quantity, and USD price.
/// When selected and a fee percentage is provided, shows estimated total.
class CloverPlanCard extends StatelessWidget {
  final CloverPlan plan;
  final bool isSelected;
  final VoidCallback onTap;
  /// Gateway fee percentage (e.g., 3.0 for 3%). If 0 or null, no fee is shown.
  final double? feePercentage;

  const CloverPlanCard({
    super.key,
    required this.plan,
    required this.isSelected,
    required this.onTap,
    this.feePercentage,
  });

  @override
  Widget build(BuildContext context) {
    final Color accentColor = isSelected 
        ? AppTheme.accentGold 
        : Colors.white.withOpacity(0.5);

    // Calculate fee only if percentage is provided and > 0
    final double fee = (feePercentage != null && feePercentage! > 0)
        ? plan.priceUsd * (feePercentage! / 100)
        : 0.0;
    final double total = plan.priceUsd + fee;
    final bool showFee = isSelected && fee > 0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isSelected
                ? [AppTheme.accentGold.withOpacity(0.3), AppTheme.accentGold.withOpacity(0.1)]
                : [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.accentGold.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon/Emoji
            Text(
              plan.iconUrl ?? '🍀',
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 8),
            
            // Plan Name
            Text(
              plan.name,
              style: TextStyle(
                color: isSelected ? AppTheme.accentGold : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            
            // Clovers Quantity
            Text(
              '${plan.cloversQuantity} Tréboles',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            
            // Price Section (with optional fee breakdown)
            if (showFee) ...[
              // Base Price
              Text(
                'Precio: ${plan.formattedPrice}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              // Fee
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Comisión: +${feePercentage!.toStringAsFixed(1)}% (\$${fee.toStringAsFixed(2)})',
                  style: TextStyle(
                    color: Colors.amber.withOpacity(0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Total
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accentGold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Total: \$${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppTheme.accentGold,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ] else ...[
              // Simple price display (no fee)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? AppTheme.accentGold.withOpacity(0.2) 
                      : Colors.black26,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  plan.formattedPrice,
                  style: TextStyle(
                    color: isSelected ? AppTheme.accentGold : Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
            
            // Selection indicator
            if (isSelected) ...[
              const SizedBox(height: 8),
              const Icon(
                Icons.check_circle,
                color: AppTheme.accentGold,
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
