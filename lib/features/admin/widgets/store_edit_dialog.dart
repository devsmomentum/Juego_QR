import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../mall/models/mall_store.dart';
import '../../mall/models/power_item.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class StoreEditDialog extends StatefulWidget {
  final MallStore? store;
  final String eventId;
  final Map<String, int>? initialPrices;
  final bool isGlobalMode;
  final bool isSpectator; // New flag to distinguish between Coins/Clovers

  const StoreEditDialog({
    super.key,
    this.store,
    required this.eventId,
    this.initialPrices,
    this.isGlobalMode = false,
    this.isSpectator = false,
  });

  @override
  State<StoreEditDialog> createState() => _StoreEditDialogState();
}

class _StoreEditDialogState extends State<StoreEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late String _description;
  XFile? _imageFile;
  Uint8List? _imageBytes; // For preview (Cross-platform)
  Map<String, int> _customCosts = {}; // Track custom costs

  final Set<String> _selectedProductIds = {};

  // Available products to toggle
  final List<PowerItem> _availableItems = PowerItem.getShopItems();

  @override
  void initState() {
    super.initState();
    _name = widget.store?.name ?? '';
    _description = widget.store?.description ?? '';

    if (widget.store != null) {
      for (var p in widget.store!.products) {
        _selectedProductIds.add(p.id);
        _customCosts[p.id] = p.cost;
      }
    } else if (widget.initialPrices != null) {
      // GLOBAL MODE: Load all available items and set custom costs if present
      for (var item in _availableItems) {
        if (widget.initialPrices!.containsKey(item.id)) {
          _selectedProductIds.add(item.id);
          _customCosts[item.id] = widget.initialPrices![item.id]!;
        }
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _imageFile = image;
        _imageBytes = bytes;
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    // IMAGE VALIDATION (Not required for global mode)
    // IMAGE VALIDATION REMOVED AS REQUESTED

    _formKey.currentState!.save();

    if (widget.isGlobalMode) {
      // GLOBAL MODE: Just return the map of slug -> cost
      final Map<String, int> resultPrices = {};
      for (var id in _selectedProductIds) {
        resultPrices[id] = _customCosts[id] ??
            _availableItems.firstWhere((i) => i.id == id).cost;
      }
      Navigator.pop(context, {'customPrices': resultPrices});
      return;
    }

    // Construct products list with custom costs
    final List<PowerItem> selectedProducts = _selectedProductIds.map((id) {
      final baseItem = _availableItems.firstWhere((item) => item.id == id);
      final customCost = _customCosts[id];
      if (customCost != null) {
        return baseItem.copyWith(cost: customCost);
      }
      return baseItem;
    }).toList();

    final newStore = MallStore(
      id: widget.store?.id ?? '',
      eventId: widget.eventId,
      name: _name,
      description: _description,
      imageUrl: widget.store?.imageUrl ?? '',
      qrCodeData: widget.store?.qrCodeData ??
          'STORE:${widget.eventId}:${const Uuid().v4()}',
      products: selectedProducts,
    );

    Navigator.pop(context, {
      'store': newStore,
      'imageFile': _imageFile,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).cardTheme.color,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
          widget.isGlobalMode
              ? 'Precios Globales'
              : (widget.store == null ? 'Nueva Tienda' : 'Editar Tienda'),
          style: TextStyle(color: Theme.of(context).textTheme.displayLarge?.color, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.isGlobalMode) ...[
                  // Image Picker
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                        image: _imageBytes != null
                            ? DecorationImage(
                                image: MemoryImage(_imageBytes!),
                                fit: BoxFit.cover)
                            : (widget.store?.imageUrl.isNotEmpty ?? false)
                                ? DecorationImage(
                                    image: NetworkImage(widget.store!.imageUrl),
                                    fit: BoxFit.cover)
                                : null,
                      ),
                      child: (_imageBytes == null &&
                              (widget.store?.imageUrl.isEmpty ?? true))
                          ? Center(
                              child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo_rounded,
                                    size: 48, color: AppTheme.lGoldAction.withOpacity(0.5)),
                                const SizedBox(height: 12),
                                Text("Imagen de la Tienda",
                                    style: TextStyle(
                                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5), 
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600))
                              ],
                            ))
                          : null,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    initialValue: _name,
                    style: TextStyle(color: Theme.of(context).textTheme.displayLarge?.color, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                        labelText: 'Nombre de la Tienda',
                        labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6)),
                        prefixIcon: const Icon(Icons.store_rounded, color: AppTheme.lGoldAction),
                        filled: true,
                        fillColor: Theme.of(context).dividerColor.withOpacity(0.03),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    validator: (v) => v!.isEmpty ? 'Por favor ingresa un nombre' : null,
                    onSaved: (v) => _name = v!,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: _description,
                    style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                    maxLines: 2,
                    decoration: InputDecoration(
                        labelText: 'Descripción (Opcional)',
                        labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6)),
                        prefixIcon: const Icon(Icons.description_rounded, color: AppTheme.lGoldAction),
                        filled: true,
                        fillColor: Theme.of(context).dividerColor.withOpacity(0.03),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    onSaved: (v) => _description = v!,
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Icon(Icons.inventory_2_rounded, color: AppTheme.lGoldAction, size: 20),
                    const SizedBox(width: 10),
                    Text(
                        widget.isGlobalMode
                            ? "PRECIOS POR DEFECTO"
                            : "PRODUCTOS DISPONIBLES",
                        style: TextStyle(
                            color: Theme.of(context).textTheme.displayLarge?.color?.withOpacity(0.8), 
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2)),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(),
                ),
                ..._availableItems.map((item) {
                  final isSelected = _selectedProductIds.contains(item.id);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.lGoldAction.withOpacity(0.05) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppTheme.lGoldAction.withOpacity(0.2) : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      children: [
                        CheckboxListTile(
                          title: Text(item.name,
                              style: TextStyle(
                                color: Theme.of(context).textTheme.displayLarge?.color,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              )),
                          subtitle: Text(
                              "Precio actual: ${_customCosts[item.id] ?? item.cost}  (Base: ${item.cost})",
                              style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6), fontSize: 12)),
                          secondary: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.lGoldAction.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Text(item.icon,
                                style: const TextStyle(fontSize: 20)),
                          ),
                          value: isSelected,
                          activeColor: AppTheme.lGoldAction,
                          checkColor: Colors.white,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedProductIds.add(item.id);
                                if (!_customCosts.containsKey(item.id)) {
                                  _customCosts[item.id] = item.cost;
                                }
                              } else {
                                _selectedProductIds.remove(item.id);
                              }
                            });
                          },
                        ),
                        if (isSelected)
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 70, right: 16, bottom: 16),
                            child: TextFormField(
                              initialValue: _customCosts[item.id]?.toString(),
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: AppTheme.lGoldAction, fontWeight: FontWeight.bold, fontSize: 16),
                              decoration: InputDecoration(
                                labelText: widget.isSpectator ? 'Costo (Tréboles)' : 'Costo (Monedas)',
                                labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5), fontSize: 12),
                                isDense: true,
                                prefixIcon: const Icon(Icons.monetization_on_rounded, color: AppTheme.lGoldAction, size: 18),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.2))),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: AppTheme.lGoldAction, width: 2)),
                              ),
                              onChanged: (val) {
                                final newCost = int.tryParse(val);
                                if (newCost != null) {
                                  _customCosts[item.id] = newCost;
                                }
                              },
                            ),
                          )
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("CANCELAR", style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6), fontWeight: FontWeight.bold))),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.lGoldAction,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
          ),
          child: const Text("GUARDAR CAMBIOS", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        ),
      ],
    );

  }
}
