import 'package:flutter/material.dart';
import '../models/power_item.dart';
import '../../../core/theme/app_theme.dart';

class ShopItemCard extends StatefulWidget {
  final PowerItem item;
  final Function(int quantity) onPurchase;
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
  State<ShopItemCard> createState() => _ShopItemCardState();
}

class _ShopItemCardState extends State<ShopItemCard> {
  int _quantity = 1;

  void _increment() {
    final available = widget.maxPerEvent - (widget.ownedCount ?? 0);
    if (_quantity < available || widget.ownedCount == null) {
      setState(() => _quantity++);
    }
  }

  void _decrement() {
    if (_quantity > 1) {
      setState(() => _quantity--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLife = widget.item.id == 'extra_life';
    final int currentOwned = widget.ownedCount ?? 0;
    final int availableToBuy = isLife ? (3 - currentOwned) : (widget.maxPerEvent - currentOwned);
    final bool atLimit = availableToBuy <= 0;
    
    // Color acento dinámico según el tipo
    final Color accentColor = isLife ? AppTheme.dangerRed : AppTheme.primaryPurple;
    final Color glowColor = isLife ? Colors.redAccent.withOpacity(0.5) : Colors.cyanAccent.withOpacity(0.3);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: atLimit ? Colors.white10 : accentColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icono compacto
                  _buildIconFrame(atLimit, accentColor),
                  const SizedBox(width: 14),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.item.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.6),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        _buildStatusBadge(atLimit, currentOwned, isLife),
                      ],
                    ),
                  ),
                ],
              ),
              
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: Colors.white10, height: 1),
              ),
              
              // Footer compacto
              Row(
                children: [
                  if (!atLimit) ...[
                    _buildQuantitySelector(accentColor),
                    const SizedBox(width: 12),
                  ],
                  
                  Expanded(
                    child: _buildBuyButton(atLimit),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconFrame(bool atLimit, Color accentColor) {
    return Container(
      width: 55,
      height: 55,
      decoration: BoxDecoration(
        gradient: atLimit 
          ? LinearGradient(colors: [Colors.grey.shade800, Colors.grey.shade900])
          : AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          widget.item.icon,
          style: const TextStyle(fontSize: 28),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool atLimit, int currentOwned, bool isLife) {
    final Color color = atLimit ? AppTheme.dangerRed : AppTheme.successGreen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        atLimit ? 'AGOTADO' : '$currentOwned/${isLife ? 3 : widget.maxPerEvent}',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }


  Widget _buildQuantitySelector(Color accentColor) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildQtyAction(Icons.remove, _decrement),
          Container(
            width: 28,
            alignment: Alignment.center,
            child: Text(
              '$_quantity',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          _buildQtyAction(Icons.add, _increment),
        ],
      ),
    );
  }

  Widget _buildQtyAction(IconData icon, VoidCallback action) {
    return IconButton(
      onPressed: action,
      icon: Icon(icon, size: 16, color: Colors.white70),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 40),
    );
  }

  Widget _buildBuyButton(bool atLimit) {
    return ElevatedButton(
      onPressed: atLimit ? null : () => widget.onPurchase(_quantity),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.successGreen,
        disabledBackgroundColor: AppTheme.dangerRed,
        disabledForegroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: atLimit
        ? const Text(
            'AGOTADO', 
            style: TextStyle(
              fontWeight: FontWeight.bold, 
              color: Colors.white,
              letterSpacing: 1.2,
            )
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Comprar',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.monetization_on, size: 14, color: AppTheme.accentGold),
              const SizedBox(width: 2),
              Text(
                '${widget.item.cost * _quantity}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
    );
  }
}
