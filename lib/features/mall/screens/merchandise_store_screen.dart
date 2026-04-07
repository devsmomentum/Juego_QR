import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../admin/models/merchandise_item.dart';
import '../providers/merchandise_provider.dart';
import 'package:intl/intl.dart';
import '../../auth/providers/player_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/coin_image.dart';
import '../../../shared/widgets/animated_cyber_background.dart';

class MerchandiseStoreScreen extends StatefulWidget {
  const MerchandiseStoreScreen({super.key});

  @override
  State<MerchandiseStoreScreen> createState() => _MerchandiseStoreScreenState();
}

class _MerchandiseStoreScreenState extends State<MerchandiseStoreScreen> {
  String _selectedCategory = 'Todos';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MerchandiseProvider>().loadItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MerchandiseProvider>();
    final player = context.watch<PlayerProvider>().currentPlayer;
    final isMobile = MediaQuery.of(context).size.width < 800;
    
    final isDayNightMode = context.watch<PlayerProvider>().isDarkMode;
    
    return AnimatedCyberBackground(
      child: Stack(
        children: [
          // Dynamic Day/Night Background
          Positioned.fill(
            child: Image.asset(
              isDayNightMode
                  ? 'assets/images/fotogrupalnoche.png'
                  : 'assets/images/personajesgrupal.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          // Consistent 0.6 opacity overlay (same as scenarios screen)
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.6)),
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            drawer: isMobile ? Drawer(
              backgroundColor: const Color(0xFF151517),
              child: _buildSidebarContent(context, provider),
            ) : null,
            appBar: isMobile ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: const Text("TIENDA", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white)),
              iconTheme: const IconThemeData(color: Colors.white),
              actions: [
                _buildCoinBalance(player?.clovers ?? 0),
                const SizedBox(width: 16),
              ],
            ) : null,
            body: Row(
              children: [
                // 1. SIDEBAR (Solo en Desktop)
                if (!isMobile) _buildSidebarContent(context, provider),
                
                // 2. MAIN CONTENT
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isMobile) _buildHeader(context, player?.clovers ?? 0),
                      
                      // Grid or Loading
                      Expanded(
                        child: provider.isLoading
                            ? const Center(child: LoadingIndicator())
                            : _buildStoreGrid(context, provider, isMobile),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarContent(BuildContext context, MerchandiseProvider provider) {
    return Container(
      width: 260,
      color: const Color(0xFF151517).withOpacity(0.95),
      child: Column(
        children: [
          const SizedBox(height: 60),
          const Text(
            "CATEGORÍAS",
            style: TextStyle(
              color: AppTheme.accentGold,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white10),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: provider.categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedCategory = cat);
                    if (MediaQuery.of(context).size.width < 800) Navigator.pop(context);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: isSelected ? LinearGradient(
                        colors: [AppTheme.accentGold.withOpacity(0.2), Colors.transparent],
                      ) : null,
                      color: isSelected ? Colors.white.withOpacity(0.02) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected ? Border.all(color: AppTheme.accentGold.withOpacity(0.3)) : null,
                    ),
                    child: Text(
                      cat.toUpperCase(),
                      style: TextStyle(
                        color: isSelected ? AppTheme.accentGold : Colors.white60,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoinBalance(int amount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accentGold.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CoinImage(size: 26),
          const SizedBox(width: 8),
          Text(
            NumberFormat('#,###').format(amount),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int balance) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "PREMIUM STORE",
                style: TextStyle(
                  color: AppTheme.accentGold,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4.0,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "Canjea tus Tréboles",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          _buildCoinBalance(balance),
        ],
      ),
    );
  }

  Widget _buildStoreGrid(BuildContext context, MerchandiseProvider provider, bool isMobile) {
    final filteredItems = provider.getItemsByCategory(_selectedCategory);
    
    if (filteredItems.isEmpty) {
      return const Center(child: Text("No hay productos en esta categoría.", style: TextStyle(color: Colors.white24)));
    }

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 30, 
        10, 
        isMobile ? 16 : 30, 
        140 // Aumentamos más el padding inferior para evitar la barra de navegación
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 2 : (MediaQuery.of(context).size.width > 1200 ? 3 : 2),
        childAspectRatio: isMobile ? 0.52 : 0.68,
        crossAxisSpacing: isMobile ? 12 : 20,
        mainAxisSpacing: isMobile ? 12 : 20,
      ),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        return _StoreItemCard(item: item);
      },
    );
  }
}

class _StoreItemCard extends StatelessWidget {
  final MerchandiseItem item;
  const _StoreItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final userClovers = context.watch<PlayerProvider>().currentPlayer?.clovers ?? 0;
    final isOutOfStock = item.stock <= 0;
    final canAfford = userClovers >= item.priceClovers && !isOutOfStock;
    
    return Stack(
      children: [
        // Container EXTERIOR - borde sutil (same as inventory cards)
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppTheme.primaryPurple.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.primaryPurple.withOpacity(0.2),
              width: 1,
            ),
          ),
          // Container INTERIOR con blur
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF150826).withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.primaryPurple.withOpacity(0.6),
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Product Image
                    Expanded(
                      flex: 5,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                        child: Container(
                          color: Colors.black.withOpacity(0.3),
                          child: item.imageUrl != null
                              ? Image.network(
                                  item.imageUrl!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  colorBlendMode: isOutOfStock ? BlendMode.saturation : null,
                                  color: isOutOfStock ? Colors.grey : null,
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.shopping_bag_outlined, color: Colors.white12, size: 50),
                                  ),
                                )
                              : const Center(
                                  child: Icon(Icons.shopping_bag_outlined, color: Colors.white12, size: 50),
                                ),
                        ),
                      ),
                    ),

                    // Info Area
                    Expanded(
                      flex: 6,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Category Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.accentGold.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.accentGold.withOpacity(0.4), width: 0.5),
                              ),
                              child: Text(
                                item.category.toUpperCase(),
                                style: const TextStyle(
                                  color: AppTheme.accentGold,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            
                            // Product Name
                            Text(
                              item.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (item.subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                item.subtitle!,
                                style: const TextStyle(color: Colors.white38, fontSize: 10),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            
                            const Spacer(),
                            
                            // Price Row
                            Row(
                              children: [
                                const CoinImage(size: 20),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      NumberFormat('#,###').format(item.priceClovers),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    isOutOfStock
                                        ? "AGOTADO"
                                        : (canAfford ? "DISPONIBLE" : "FALTAN ${item.priceClovers - userClovers}"),
                                    style: TextStyle(
                                      color: isOutOfStock
                                          ? AppTheme.dangerRed
                                          : (canAfford ? Colors.greenAccent : Colors.white24),
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            
                            // Buy Button (matching inventory card style)
                            SizedBox(
                              width: double.infinity,
                              height: 34,
                              child: ElevatedButton(
                                onPressed: (canAfford && !context.watch<MerchandiseProvider>().isLoading)
                                    ? () => _confirmRedemption(context)
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: canAfford
                                      ? AppTheme.accentGold
                                      : Colors.grey.withOpacity(0.3),
                                  foregroundColor: Colors.black,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: canAfford ? 4 : 0,
                                ),
                                child: context.watch<MerchandiseProvider>().isLoading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                      )
                                    : Text(
                                        isOutOfStock
                                            ? "AGOTADO"
                                            : (canAfford ? "CANJEAR" : "BLOQUEADO"),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1,
                                          color: canAfford ? Colors.black : Colors.white38,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Stock Badge (top-right, glassmorphism style)
        Positioned(
          right: 8,
          top: 8,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D0F).withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.accentGold.withOpacity(0.6),
                    width: 1,
                  ),
                ),
                child: Text(
                  "x${item.stock}",
                  style: const TextStyle(
                    color: AppTheme.accentGold,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmRedemption(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const CoinImage(size: 30),
            const SizedBox(width: 12),
            const Text("Confirmar Canje", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("¿Deseas canjear '${item.name}'?", style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Costo:", style: TextStyle(color: Colors.white60)),
                  Row(
                    children: [
                      const CoinImage(size: 22),
                      const SizedBox(width: 6),
                      Text(
                        NumberFormat('#,###').format(item.priceClovers),
                        style: const TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), 
            child: const Text("CANCELAR", style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGold,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("SÍ, CANJEAR", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final success = await context.read<MerchandiseProvider>().redeemItem(item.id);
      
      if (success) {
        // Notificamos inmediatamente
        messenger.showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
            content: Text(
              "⏳ Solicitud enviada. Un administrador revisará tu canje pronto.",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        );
        
        // Refrescamos en segundo plano
        if (context.mounted) {
          context.read<PlayerProvider>().reloadProfile();
        }
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Error: ${context.read<MerchandiseProvider>().error}")),
        );
      }
    }
  }
}
