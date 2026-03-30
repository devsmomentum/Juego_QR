import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../mall/providers/merchandise_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/loading_indicator.dart';
import 'package:intl/intl.dart';

class MerchandiseRedemptionsScreen extends StatefulWidget {
  const MerchandiseRedemptionsScreen({super.key});

  @override
  State<MerchandiseRedemptionsScreen> createState() => _MerchandiseRedemptionsScreenState();
}

class _MerchandiseRedemptionsScreenState extends State<MerchandiseRedemptionsScreen> {
  String _selectedStatus = 'pending';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MerchandiseProvider>().loadAdminRedemptions(status: _selectedStatus);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MerchandiseProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color goldColor = isDark ? AppTheme.dGoldMain : AppTheme.lGoldAction;

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Solicitudes de Canje",
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Procesa las solicitudes de productos de los usuarios.",
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                DropdownButton<String>(
                  value: _selectedStatus,
                  items: ['pending', 'approved', 'shipped', 'delivered', 'rejected', 'cancelled']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase())))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedStatus = val);
                      provider.loadAdminRedemptions(status: val);
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: provider.isLoading
                ? const Center(child: LoadingIndicator())
                : provider.adminRedemptions.isEmpty
                    ? const Center(child: Text("No hay solicitudes en este estado."))
                    : _buildRedemptionsList(context, provider),
          ),
        ],
      );
  }

  Widget _buildRedemptionsList(BuildContext context, MerchandiseProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: provider.adminRedemptions.length,
      itemBuilder: (context, index) {
        final r = provider.adminRedemptions[index];
        final dateStr = DateFormat('dd/MM HH:mm').format(r.createdAt);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: r.itemImageUrl != null
                ? Image.network(r.itemImageUrl!, width: 40, height: 40, fit: BoxFit.cover, 
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))
                : const Icon(Icons.shopping_bag),
            title: Text(r.userName ?? 'Usuario desconocido', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${r.itemName} • ${r.ptsPaid} PTS • $dateStr"),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (_selectedStatus == 'pending')
                          ElevatedButton(
                            onPressed: () => provider.updateRedemptionStatus(r.id, 'approved'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: const Text("Aprobar"),
                          ),
                        if (_selectedStatus == 'approved')
                          ElevatedButton(
                            onPressed: () => provider.updateRedemptionStatus(r.id, 'shipped'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                            child: const Text("Marcar Enviado"),
                          ),
                        if (_selectedStatus == 'shipped')
                          ElevatedButton(
                            onPressed: () => provider.updateRedemptionStatus(r.id, 'delivered'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                            child: const Text("Marcar Entregado"),
                          ),
                        if (_selectedStatus == 'pending')
                          TextButton(
                            onPressed: () => provider.updateRedemptionStatus(r.id, 'rejected'),
                            child: const Text("Rechazar", style: TextStyle(color: Colors.red)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
