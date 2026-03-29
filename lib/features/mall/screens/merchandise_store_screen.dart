import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../admin/models/merchandise_item.dart';
import '../providers/merchandise_provider.dart';
import 'package:intl/intl.dart';
import '../../auth/providers/player_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/loading_indicator.dart';

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
    
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
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
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0D0D0F),
                    Color(0xFF1A1A1E),
                  ],
                ),
              ),
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
          Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/coin.png', 
                width: 20, 
                height: 20,
                color: Colors.white.withOpacity(0.9),
                colorBlendMode: BlendMode.modulate,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            NumberFormat('#,###').format(amount),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarContent(BuildContext context, MerchandiseProvider provider) {
    return Container(
      width: 260,
      color: const Color(0xFF151517),
      child: Column(
        children: [
          const SizedBox(height: 60),
          const Text(
            "CATEGORÍAS",
            style: TextStyle(color: AppTheme.accentGold, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
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
        crossAxisCount: isMobile ? 1 : (MediaQuery.of(context).size.width > 1200 ? 3 : 2),
        childAspectRatio: isMobile ? 1.2 : 0.75,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
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
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Area
              Expanded(
                flex: 5,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    image: item.imageUrl != null ? DecorationImage(
                      image: NetworkImage(item.imageUrl!),
                      fit: BoxFit.cover,
                      colorFilter: isOutOfStock ? ColorFilter.mode(Colors.black.withOpacity(0.7), BlendMode.darken) : null,
                    ) : null,
                  ),
                  child: item.imageUrl == null 
                    ? const Center(child: Icon(Icons.shopping_bag_outlined, color: Colors.white12, size: 60))
                    : Image.network(
                        item.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Icon(Icons.broken_image_outlined, color: Colors.white12, size: 60),
                        ),
                        // Ocultamos el widget hijo si la decoración ya muestra la imagen correctamente
                        color: Colors.transparent, 
                        colorBlendMode: BlendMode.dst,
                      ),
                ),
              ),
              
              // Info Area
              Expanded(
                flex: 6,
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.0),
                        Colors.black.withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Category Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGold.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.accentGold.withOpacity(0.5), width: 0.5),
                        ),
                        child: Text(
                          item.category.toUpperCase(),
                          style: const TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold, fontSize: 9, letterSpacing: 1),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.name,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, height: 1.1),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (item.subtitle != null)
                        Text(item.subtitle!, style: const TextStyle(color: Colors.white38, fontSize: 11), maxLines: 1),
                      
                      const Spacer(),
                      
                      // Price & Button Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Aplicamos un clip circular y un filtro para disimular el fondo blanco
                                  Container(
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                    ),
                                    child: ClipOval(
                                      child: Image.asset(
                                        'assets/images/coin.png', 
                                        width: 18, 
                                        height: 18,
                                        color: Colors.white.withOpacity(0.9),
                                        colorBlendMode: BlendMode.modulate,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    NumberFormat('#,###').format(item.priceClovers),
                                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Text(
                                isOutOfStock 
                                  ? "AGOTADO" 
                                  : (canAfford ? "DISPONIBLE" : "FALTAN ${item.priceClovers - userClovers}"),
                                style: TextStyle(
                                  color: isOutOfStock 
                                    ? AppTheme.dangerRed 
                                    : (canAfford ? Colors.greenAccent : Colors.white24),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: (canAfford && !context.watch<MerchandiseProvider>().isLoading) 
                              ? () => _confirmRedemption(context) 
                              : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: canAfford ? AppTheme.accentGold : Colors.white.withOpacity(0.05),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: canAfford ? 4 : 0,
                            ),
                            child: context.watch<MerchandiseProvider>().isLoading 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : Icon(
                                  isOutOfStock ? Icons.block : (canAfford ? Icons.shopping_cart : Icons.lock_outline),
                                  size: 20,
                                  color: canAfford ? Colors.black : Colors.white24,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // Stock indicator top right
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: Text(
                "STOCK: ${item.stock}",
                style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
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
            Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/coin.png', 
                  width: 28, 
                  height: 28,
                  color: Colors.white.withOpacity(0.9),
                  colorBlendMode: BlendMode.modulate,
                ),
              ),
            ),
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
                      Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/coin.png', 
                            width: 16, 
                            height: 16,
                            color: Colors.white.withOpacity(0.9),
                            colorBlendMode: BlendMode.modulate,
                          ),
                        ),
                      ),
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
