import 'package:flutter/material.dart';
import '../../mall/models/power_item.dart';
import '../../auth/services/inventory_service.dart';
import '../../auth/services/power_service.dart';

/// Provider for managing shop items and purchases
/// Extracted from PlayerProvider as part of SRP refactoring
class ShopProvider extends ChangeNotifier {
  final PowerService _powerService;
  final InventoryService _inventoryService;

  List<PowerItem> _shopItems = [];
  bool _isLoading = false;
  String? _errorMessage;

  ShopProvider({
    required PowerService powerService,
    required InventoryService inventoryService,
  })  : _powerService = powerService,
        _inventoryService = inventoryService {
    _initializeShopItems();
  }

  // Getters
  List<PowerItem> get shopItems => _shopItems;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Initialize default shop items
  void _initializeShopItems() {
    _shopItems = [
      PowerItem(
        id: 'freeze',
        name: 'Congelar',
        description: 'Congela al rival por 10s',
        cost: 50,
        icon: '❄️',
        type: PowerType.freeze,
      ),
      PowerItem(
        id: 'black_screen',
        name: 'Pantalla Negra',
        description: 'Oscurece la pantalla del rival por 10s',
        cost: 40,
        icon: '🌑',
        type: PowerType.blind,
      ),
      PowerItem(
        id: 'return_forward',
        name: 'Retroceder/Avanzar',
        description: 'Retrocede 1 pista o avanza 1 pista',
        cost: 60,
        icon: '🔄',
        type: PowerType.buff,
      ),
      PowerItem(
        id: 'extra_life',
        name: 'Vida Extra',
        description: 'Recupera 1 vida',
        cost: 100,
        icon: '❤️',
        type: PowerType.buff,
      ),
    ];
  }

  /// Load shop items configuration from backend
  Future<void> loadShopItems() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final configs = await _powerService.getPowerConfigs();

      _shopItems = _shopItems.map((item) {
        final matches = configs.where((d) => d['slug'] == item.id);
        final config = matches.isNotEmpty ? matches.first : null;

        if (config != null) {
          final int duration = (config['duration'] as num?)?.toInt() ?? 0;

          String newDesc = item.description;
          if (duration > 0) {
            newDesc = newDesc.replaceAll(RegExp(r'\b\d+\s*s\b'), '${duration}s');
          }

          return item.copyWith(
            durationSeconds: duration,
            description: newDesc,
          );
        }
        return item;
      }).toList();

      _errorMessage = null;
    } catch (e) {
      debugPrint("ShopProvider: Error loading shop items: $e");
      _errorMessage = "Error cargando items de la tienda";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Purchase an item from the shop
  /// Returns true if purchase was successful
  Future<bool> purchaseItem({
    required String userId,
    required String itemId,
    required String eventId,
    required int cost,
    required bool isSpectator,
    bool isPower = true,
  }) async {
    try {
      final PurchaseResult result;

      if (isSpectator) {
        // Spectators use manual flow to bypass restrictive RPC
        result = await _inventoryService.purchaseItemAsSpectator(
          userId: userId,
          eventId: eventId,
          itemId: itemId,
          cost: cost,
        );
      } else {
        result = await _inventoryService.purchaseItem(
          userId: userId,
          eventId: eventId,
          itemId: itemId,
          cost: cost,
          isPower: isPower,
        );
      }

      return result.success;
    } catch (e) {
      debugPrint("ShopProvider: Error purchasing item: $e");
      _errorMessage = "Error al comprar el item";
      notifyListeners();
      rethrow;
    }
  }

  /// Purchase extra life (special handling)
  Future<bool> purchaseExtraLife({
    required String userId,
    required String eventId,
    required int cost,
  }) async {
    try {
      final result = await _inventoryService.purchaseExtraLife(
        userId: userId,
        eventId: eventId,
        cost: cost,
      );

      return result.success;
    } catch (e) {
      debugPrint("ShopProvider: Error purchasing extra life: $e");
      _errorMessage = "Error al comprar vida extra";
      notifyListeners();
      rethrow;
    }
  }

  /// Developer method: Purchase all powers up to max limit (3)
  /// Returns a summary string of what was bought
  Future<String> purchaseFullStock({
    required String userId,
    required String eventId,
    required int currentCoins,
    required int currentLives,
    required Map<String, int> currentPowerCounts,
    required bool isSpectator,
  }) async {
    const int maxPerItem = 3;
    int totalCost = 0;
    Map<PowerItem, int> toBuy = {};

    // 1. Calculate what is needed
    for (final item in _shopItems) {
      int currentCount = 0;
      bool isPower = item.type != PowerType.utility && item.id != 'extra_life';

      if (isPower) {
        currentCount = currentPowerCounts[item.id] ?? 0;
      } else if (item.id == 'extra_life') {
        currentCount = currentLives;
      }

      // Calculate needed
      int needed = maxPerItem - currentCount;
      if (needed > 0) {
        toBuy[item] = needed;
        totalCost += (item.cost * needed);
      }
    }

    if (toBuy.isEmpty) {
      return "¡Ya tienes todo al máximo!";
    }

    // 2. Check funds
    if (currentCoins < totalCost) {
      return "Faltan monedas. Costo: $totalCost, Tienes: $currentCoins";
    }

    // 3. Execute purchases sequentially
    int successCount = 0;

    try {
      for (final entry in toBuy.entries) {
        final item = entry.key;
        final qty = entry.value;
        final bool isPower = item.type != PowerType.utility && item.id != 'extra_life';

        for (int i = 0; i < qty; i++) {
          bool success;
          if (item.id == 'extra_life') {
            success = await purchaseExtraLife(
              userId: userId,
              eventId: eventId,
              cost: item.cost,
            );
          } else {
            success = await purchaseItem(
              userId: userId,
              itemId: item.id,
              eventId: eventId,
              cost: item.cost,
              isSpectator: isSpectator,
              isPower: isPower,
            );
          }
          if (success) successCount++;
        }
      }

      return "Compra masiva completada. Items comprados: $successCount por $totalCost monedas.";
    } catch (e) {
      return "Error durante la compra masiva: $e";
    }
  }

  /// Reset state (for logout)
  void resetState() {
    _initializeShopItems();
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}
