import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/coin_image.dart';
import '../../mall/models/power_item.dart';
import '../../auth/providers/player_provider.dart';
import '../providers/game_provider.dart';
import '../providers/power_interfaces.dart';

/// Compact overlay that shows purchasable powers above the race tracker
/// without covering the minigame area.
class QuickPowerShop extends StatefulWidget {
  final VoidCallback onClose;

  const QuickPowerShop({super.key, required this.onClose});

  @override
  State<QuickPowerShop> createState() => _QuickPowerShopState();
}

class _QuickPowerShopState extends State<QuickPowerShop>
    with SingleTickerProviderStateMixin {
  bool _isPurchasing = false;
  String? _purchasingItemId;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _closeWithAnimation() async {
    await _slideController.reverse();
    widget.onClose();
  }

  Future<void> _purchaseItem(PowerItem item) async {
    if (_isPurchasing) return;
    setState(() {
      _isPurchasing = true;
      _purchasingItemId = item.id;
    });

    try {
      final playerProvider = context.read<PlayerProvider>();
      final gameProvider = context.read<GameProvider>();
      final eventId = gameProvider.currentEventId;

      if (eventId == null) {
        _showSnack('Debes estar en un evento para comprar.');
        return;
      }

      final coins = playerProvider.currentPlayer?.coins ?? 0;
      if (coins < item.cost) {
        _showSnack('No tienes suficientes monedas.');
        return;
      }

      final bool isPower =
          item.type != PowerType.utility && item.id != 'extra_life';

      await playerProvider.purchaseItem(item.id, eventId, item.cost,
          isPower: isPower);

      if (!mounted) return;

      // Sync inventory
      final effectProvider = context.read<PowerEffectManager>();
      await playerProvider.fetchInventory(
          playerProvider.currentPlayer!.userId, eventId);
      await playerProvider.syncRealInventory(effectProvider: effectProvider);

      // Update lives if extra_life
      if (item.id == 'extra_life') {
        final newLives = playerProvider.currentPlayer?.lives ?? 3;
        gameProvider.syncLives(newLives);
      }

      if (!mounted) return;
      _showSnack('${item.icon} ${item.name} comprado', isSuccess: true);
    } catch (e) {
      if (mounted) _showSnack('Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
          _purchasingItemId = null;
        });
      }
    }
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12)),
        backgroundColor: isSuccess ? AppTheme.successGreen : AppTheme.dangerRed,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 60, left: 16, right: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = context.watch<PlayerProvider>();
    final gameProvider = context.watch<GameProvider>();
    final eventId = gameProvider.currentEventId;
    final coins = playerProvider.currentPlayer?.coins ?? 0;
    final items = PowerItem.getShopItems();

    return SlideTransition(
      position: _slideAnimation,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.dSurface1.withOpacity(0.92),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(16)),
              border: Border.all(
                color: AppTheme.accentGold.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.storefront_rounded,
                          color: AppTheme.accentGold, size: 18),
                      const SizedBox(width: 6),
                      const Text(
                        'TIENDA RÁPIDA',
                        style: TextStyle(
                          color: AppTheme.accentGold,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      // Coins display
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGold.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.accentGold.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.monetization_on,
                                        size: 14, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              '$coins',
                              style: const TextStyle(
                                color: AppTheme.accentGold,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _closeWithAnimation,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white70, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                // Divider
                Container(
                  height: 1,
                  color: AppTheme.accentGold.withOpacity(0.15),
                ),
                // Items horizontal list
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final bool isLife = item.id == 'extra_life';
                      final int owned = (eventId != null && !isLife)
                          ? (playerProvider.getPowerCount(item.id, eventId))
                          : (isLife ? (gameProvider.lives) : 0);
                      final bool atLimit =
                          isLife ? owned >= 3 : owned >= 3;
                      final bool canAfford = coins >= item.cost;
                      final bool isBuying = _purchasingItemId == item.id;

                      return _QuickShopItem(
                        item: item,
                        owned: owned,
                        atLimit: atLimit,
                        canAfford: canAfford,
                        isBuying: isBuying,
                        onTap: (atLimit || !canAfford || _isPurchasing)
                            ? null
                            : () => _purchaseItem(item),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickShopItem extends StatelessWidget {
  final PowerItem item;
  final int owned;
  final bool atLimit;
  final bool canAfford;
  final bool isBuying;
  final VoidCallback? onTap;

  const _QuickShopItem({
    required this.item,
    required this.owned,
    required this.atLimit,
    required this.canAfford,
    required this.isBuying,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool disabled = atLimit || !canAfford;
    final double opacity = disabled ? 0.4 : 1.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: opacity,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: 72,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: item.color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: disabled
                  ? Colors.white12
                  : item.color.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon + buying indicator
              if (isBuying)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.accentGold,
                  ),
                )
              else
                Text(item.icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 2),
              // Name
              Text(
                item.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              // Price + owned
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (atLimit)
                    const Text(
                      'MAX',
                      style: TextStyle(
                        color: AppTheme.warningOrange,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else ...[
                    const Icon(Icons.monetization_on,
                                        size: 14, color: Colors.amber),
                    const SizedBox(width: 2),
                    Text(
                      '${item.cost}',
                      style: TextStyle(
                        color: canAfford
                            ? AppTheme.accentGold
                            : AppTheme.dangerRed,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  if (owned > 0) ...[
                    const SizedBox(width: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.successGreen.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'x$owned',
                        style: const TextStyle(
                          color: AppTheme.successGreen,
                          fontSize: 7,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
