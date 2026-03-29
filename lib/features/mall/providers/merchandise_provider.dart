import 'package:flutter/material.dart';
import '../../admin/models/merchandise_item.dart';
import '../../admin/services/merchandise_service.dart';

class MerchandiseProvider extends ChangeNotifier {
  final MerchandiseService _service;

  List<MerchandiseItem> _items = [];
  List<MerchandiseRedemption> _userRedemptions = [];
  List<MerchandiseRedemption> _adminRedemptions = [];
  bool _isLoading = false;
  String? _error;

  MerchandiseProvider(this._service);

  // Getters
  List<MerchandiseItem> get items => _items;
  List<MerchandiseRedemption> get userRedemptions => _userRedemptions;
  List<MerchandiseRedemption> get adminRedemptions => _adminRedemptions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<MerchandiseItem> getItemsByCategory(String category) {
    if (category.toLowerCase() == 'todos') return _items;
    return _items.where((item) => item.category.toLowerCase() == category.toLowerCase()).toList();
  }

  List<String> get categories {
    final Set<String> cats = {'Todos'};
    for (var item in _items) {
      cats.add(item.category);
    }
    return cats.toList();
  }

  // --- ACTIONS ---

  Future<void> loadItems({bool includeUnavailable = false}) async {
    _setLoading(true);
    try {
      _items = await _service.getItems(includeUnavailable: includeUnavailable);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadUserRedemptions() async {
    _setLoading(true);
    try {
      _userRedemptions = await _service.getRedemptions();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadAdminRedemptions({String? status}) async {
    _setLoading(true);
    try {
      _adminRedemptions = await _service.getRedemptions(status: status);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> redeemItem(String itemId) async {
    _setLoading(true);
    _error = null; // Limpiamos el error anterior para que la notificación sea fresca
    try {
      final result = await _service.redeemItem(itemId);
      if (result['success'] == true) {
        await loadUserRedemptions();
        return true;
      } else {
        _error = result['message'];
        return false;
      }
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateRedemptionStatus(String id, String status, {String? notes}) async {
    _setLoading(true);
    try {
      await _service.updateRedemptionStatus(id, status, notes: notes);
      await loadAdminRedemptions();
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // Admin Item Management
  Future<void> saveItem(MerchandiseItem item) async {
    _setLoading(true);
    try {
      if (item.id.isEmpty || item.id == 'new') {
        await _service.createItem(item);
      } else {
        await _service.updateItem(item);
      }
      await loadItems(includeUnavailable: true);
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteItem(String id) async {
    _setLoading(true);
    try {
      await _service.deleteItem(id);
      await loadItems(includeUnavailable: true);
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void resetState() {
    _items = [];
    _userRedemptions = [];
    _adminRedemptions = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
