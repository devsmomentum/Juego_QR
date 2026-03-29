import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../mall/providers/merchandise_provider.dart';
import '../models/merchandise_item.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/loading_indicator.dart';

class MerchandiseManagementScreen extends StatefulWidget {
  const MerchandiseManagementScreen({super.key});

  @override
  State<MerchandiseManagementScreen> createState() => _MerchandiseManagementScreenState();
}

class _MerchandiseManagementScreenState extends State<MerchandiseManagementScreen> {
  late Color goldColor;
  bool _colorsInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MerchandiseProvider>().loadItems(includeUnavailable: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MerchandiseProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    goldColor = isDark ? AppTheme.dGoldMain : AppTheme.lGoldAction;
    _colorsInitialized = true;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showItemDialog(context),
        backgroundColor: goldColor,
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: Column(
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
                        "Gestión de Tienda",
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontSize: 22, // Ligeramente más pequeño para evitar overflow
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Configura los productos que los usuarios pueden canjear.",
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => provider.loadItems(includeUnavailable: true),
                ),
              ],
            ),
          ),
          Expanded(
            child: provider.isLoading
                ? const Center(child: LoadingIndicator())
                : provider.items.isEmpty
                    ? _buildEmptyState(context)
                    : _buildItemsList(context, provider),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.storefront, size: 64, color: Colors.grey.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text("No hay productos configurados aún."),
        ],
      ),
    );
  }

  Widget _buildItemsList(BuildContext context, MerchandiseProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: provider.items.length,
      itemBuilder: (context, index) {
        final item = provider.items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Imagen (Tamaño fijo)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: item.imageUrl != null
                      ? Image.network(item.imageUrl!, width: 60, height: 60, fit: BoxFit.cover, 
                          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))
                      : Container(
                          width: 60, height: 60, color: Colors.grey.withOpacity(0.2),
                          child: const Icon(Icons.image, color: Colors.grey)),
                ),
                const SizedBox(width: 12),
                
                // 2. Información (Expanded para que el texto salte de línea)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        softWrap: true, // Forzar salto de línea por palabra
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${item.category} • ${item.priceClovers} PTS",
                        style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 13),
                      ),
                      Text(
                        "Stock: ${item.stock}",
                        style: TextStyle(
                          color: item.stock <= 5 ? Colors.redAccent : Colors.grey,
                          fontSize: 12,
                          fontWeight: item.stock <= 5 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 3. Acciones (Ancho flexible pero compacto para evitar overflow de 14px)
                Flexible(
                  flex: 0,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Switch de Habilitado
                      SizedBox(
                        height: 30,
                        child: Transform.scale(
                          scale: 0.65,
                          child: Switch(
                            value: item.isAvailable,
                            activeColor: goldColor,
                            onChanged: (val) {
                              provider.saveItem(item.copyWith(isAvailable: val));
                            },
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 16),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _showItemDialog(context, item: item),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent, size: 16),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _confirmDelete(context, item),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showItemDialog(BuildContext context, {MerchandiseItem? item}) {
    showDialog(
      context: context,
      builder: (_) => MerchandiseItemForm(item: item),
    );
  }

  void _confirmDelete(BuildContext context, MerchandiseItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar Producto"),
        content: Text("¿Estás seguro de que deseas eliminar '${item.name}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          TextButton(
            onPressed: () {
              context.read<MerchandiseProvider>().deleteItem(item.id);
              Navigator.pop(ctx);
            },
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class MerchandiseItemForm extends StatefulWidget {
  final MerchandiseItem? item;
  const MerchandiseItemForm({super.key, this.item});

  @override
  State<MerchandiseItemForm> createState() => _MerchandiseItemFormState();
}

class _MerchandiseItemFormState extends State<MerchandiseItemForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _subtitleCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _categoryCtrl;
  late TextEditingController _imageCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _stockCtrl;
  bool _isAvailable = true;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item?.name ?? '');
    _subtitleCtrl = TextEditingController(text: widget.item?.subtitle ?? '');
    _priceCtrl = TextEditingController(text: widget.item?.priceClovers.toString() ?? '1000');
    _categoryCtrl = TextEditingController(text: widget.item?.category ?? 'General');
    _imageCtrl = TextEditingController(text: widget.item?.imageUrl ?? '');
    _descCtrl = TextEditingController(text: widget.item?.description ?? '');
    _stockCtrl = TextEditingController(text: widget.item?.stock.toString() ?? '10');
    _isAvailable = widget.item?.isAvailable ?? true;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? "Nuevo Producto" : "Editar Producto"),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: "Nombre"),
                validator: (v) => v!.isEmpty ? "Campo requerido" : null,
              ),
              TextFormField(
                controller: _subtitleCtrl,
                decoration: const InputDecoration(labelText: "Subtítulo (Opcional)"),
              ),
              TextFormField(
                controller: _categoryCtrl,
                decoration: const InputDecoration(labelText: "Categoría"),
                validator: (v) => v!.isEmpty ? "Campo requerido" : null,
              ),
              TextFormField(
                controller: _priceCtrl,
                decoration: const InputDecoration(labelText: "Precio (PTS)"),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? "Campo requerido" : null,
              ),
              TextFormField(
                controller: _imageCtrl,
                decoration: const InputDecoration(labelText: "URL Imagen"),
              ),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: "Descripción"),
                maxLines: 2,
              ),
              TextFormField(
                controller: _stockCtrl,
                decoration: const InputDecoration(labelText: "Stock Disponible"),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? "Campo requerido" : null,
              ),
              SwitchListTile(
                title: const Text("Disponible"),
                value: _isAvailable,
                onChanged: (v) => setState(() => _isAvailable = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final newItem = MerchandiseItem(
                id: widget.item?.id ?? '',
                name: _nameCtrl.text,
                subtitle: _subtitleCtrl.text,
                category: _categoryCtrl.text,
                priceClovers: int.parse(_priceCtrl.text),
                imageUrl: _imageCtrl.text,
                description: _descCtrl.text,
                stock: int.tryParse(_stockCtrl.text) ?? 0,
                isAvailable: _isAvailable,
                createdAt: widget.item?.createdAt ?? DateTime.now(),
              );
              context.read<MerchandiseProvider>().saveItem(newItem);
              Navigator.pop(context);
            }
          },
          child: const Text("Guardar"),
        ),
      ],
    );
  }
}
