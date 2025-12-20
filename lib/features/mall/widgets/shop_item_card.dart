import 'package:flutter/material.dart';
import '../models/power_item.dart';
import '../../../core/theme/app_theme.dart';

class ShopItemCard extends StatelessWidget {
  final PowerItem item;
  final VoidCallback onPurchase;
  final int? ownedCount;
  final int maxPerEvent;

  const ShopItemCard({
    super.key,
    required this.item,
    required this.onPurchase,
    this.ownedCount,
    this.maxPerEvent = 3,
  });

  @override
  Widget build(BuildContext context) {
    final bool atLimit = ownedCount != null && ownedCount! >= maxPerEvent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryPurple.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                item.icon,
                style: const TextStyle(fontSize: 36),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.monetization_on,
                      size: 16,
                      color: AppTheme.accentGold,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${item.cost}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentGold,
                      ),
                    ),
                    if (ownedCount != null) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (atLimit
                                  ? AppTheme.dangerRed
                                  : AppTheme.primaryPurple)
                              .withOpacity(0.18),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: (atLimit
                                    ? AppTheme.dangerRed
                                    : AppTheme.primaryPurple)
                                .withOpacity(0.55),
                          ),
                        ),
                        child: Text(
                          '$ownedCount/$maxPerEvent',
                          style: TextStyle(
                            color: atLimit ? AppTheme.dangerRed : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Buy button
          ElevatedButton(
            onPressed: atLimit ? null : onPurchase,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
              disabledBackgroundColor: AppTheme.dangerRed,
              disabledForegroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              atLimit ? 'Límite' : 'Comprar',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
