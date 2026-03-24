import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../game/models/event.dart';
import '../../../mall/models/mall_store.dart';
import '../../../mall/providers/store_provider.dart';

class StoresTab extends StatelessWidget {
  final GameEvent event;
  final bool isEventActive;
  final Function(MallStore? store) onShowAddStoreDialog;
  final Function(MallStore store) onConfirmDeleteStore;
  final Function(String qrData, String title, String subtitle, {String? hint})
      onShowQR;

  const StoresTab({
    super.key,
    required this.event,
    required this.isEventActive,
    required this.onShowAddStoreDialog,
    required this.onConfirmDeleteStore,
    required this.onShowQR,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Consumer<StoreProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              final stores = provider.stores;

              if (stores.isEmpty) {
                return const Center(
                  child: Text("No hay tiendas registradas",
                      style: TextStyle(color: Colors.white38)),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: stores.length,
                itemBuilder: (context, index) {
                  final store = stores[index];
                  return Card(
                    color: AppTheme.cardBg,
                    elevation: 2,
                    shadowColor: Colors.black.withOpacity(0.2),
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(8),
                          image: (store.imageUrl.isNotEmpty &&
                                  store.imageUrl.startsWith('http'))
                              ? DecorationImage(
                                  image: NetworkImage(store.imageUrl),
                                  fit: BoxFit.cover)
                              : null,
                        ),
                        child: (store.imageUrl.isEmpty ||
                                !store.imageUrl.startsWith('http'))
                            ? const Icon(Icons.store, color: Colors.white54)
                            : null,
                      ),
                      title: Text(store.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(store.description,
                              style: const TextStyle(color: Colors.white70),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: store.products
                                .map((p) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black26,
                                        borderRadius: BorderRadius.circular(8),
                                        border:
                                            Border.all(color: Colors.white12),
                                      ),
                                      child: Text(
                                        "${p.icon} ${p.name} (\$${p.cost})",
                                        style: const TextStyle(
                                            color: Colors.greenAccent,
                                            fontSize: 11),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (event.type != 'online')
                            IconButton(
                                icon: const Icon(Icons.qr_code,
                                    color: Colors.white),
                                tooltip: "Ver QR",
                                onPressed: () => onShowQR(
                                      store.qrCodeData,
                                      "QR de Tienda",
                                      store.name,
                                      hint: "Escanear para entrar",
                                    )),
                          IconButton(
                            icon: const Icon(Icons.edit,
                                color: AppTheme.accentGold),
                            onPressed: () => onShowAddStoreDialog(store),
                          ),
                          if (!isEventActive)
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => onConfirmDeleteStore(store),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
