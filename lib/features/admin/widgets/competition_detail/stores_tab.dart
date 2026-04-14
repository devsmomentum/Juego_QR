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
                return const Center(
                    child: CircularProgressIndicator(color: AppTheme.lGoldAction));
              }

              final stores = provider.stores;

              if (stores.isEmpty) {
                return Center(
                  child: Text("No hay tiendas registradas",
                      style: TextStyle(
                          color: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color
                              ?.withOpacity(0.5))),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: stores.length,
                itemBuilder: (context, index) {
                  final store = stores[index];
                  return Card(
                    color: Theme.of(context).cardTheme.color,
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                          color: Theme.of(context).dividerColor.withOpacity(0.1)),
                    ),
                    child: ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Theme.of(context).dividerColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          image: (store.imageUrl.isNotEmpty &&
                                  store.imageUrl.startsWith('http'))
                              ? DecorationImage(
                                  image: NetworkImage(store.imageUrl),
                                  fit: BoxFit.cover)
                              : null,
                        ),
                        child: (store.imageUrl.isEmpty ||
                                !store.imageUrl.startsWith('http'))
                            ? Icon(Icons.store_rounded,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color
                                    ?.withOpacity(0.4),
                                size: 28)
                            : null,
                      ),
                      title: Text(store.name,
                          style: TextStyle(
                              color: Theme.of(context).textTheme.displayLarge?.color,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(store.description,
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color
                                      ?.withOpacity(0.7),
                                  fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: store.products
                                .map((p) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.lGoldAction.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: AppTheme.lGoldAction
                                                .withOpacity(0.2)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(p.icon,
                                              style: const TextStyle(fontSize: 12)),
                                          const SizedBox(width: 4),
                                          Text(
                                            "${p.name} (\$${p.cost})",
                                            style: const TextStyle(
                                                color: AppTheme.lGoldAction,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (event.type != 'online')
                            IconButton(
                                icon: const Icon(Icons.qr_code_rounded,
                                    color: AppTheme.lGoldAction),
                                tooltip: "Ver QR",
                                onPressed: () => onShowQR(
                                      store.qrCodeData,
                                      "QR de Tienda",
                                      store.name,
                                      hint: "Escanear para entrar",
                                    )),
                          IconButton(
                            icon: const Icon(Icons.edit_rounded,
                                color: AppTheme.lGoldAction),
                            onPressed: () => onShowAddStoreDialog(store),
                          ),
                          if (!isEventActive)
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  color: Colors.redAccent),
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
