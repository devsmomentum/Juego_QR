import 'package:flutter/material.dart';
import '../models/mall_store.dart';
import '../services/store_service.dart';

class StoreProvider extends ChangeNotifier {
  final StoreService _storeService;
  
  List<MallStore> _stores = [];
  bool _isLoading = false;
  String? _errorMessage;

  StoreProvider({required StoreService storeService}) : _storeService = storeService;

  List<MallStore> get stores => _stores;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchStores(String eventId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _stores = await _storeService.fetchStores(eventId);
    } catch (e) {
      debugPrint('Error fetching stores: $e');
      _errorMessage = 'Error cargando tiendas';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createStore(MallStore store, dynamic imageFile) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _storeService.createStore(store, imageFile);

      // Refresh
      if (store.eventId != null) {
        await fetchStores(store.eventId!);
      }
    } catch (e) {
      debugPrint('Error creating store: $e');
      throw e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> updateStore(MallStore store, dynamic newImageFile) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _storeService.updateStore(store, newImageFile);

      if (store.eventId != null) {
        await fetchStores(store.eventId!);
      }
    } catch (e) {
      debugPrint('Error updating store: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteStore(String storeId, String eventId) async {
    try {
      await _storeService.deleteStore(storeId);
      await fetchStores(eventId); // Refresh list
    } catch (e) {
      debugPrint("Error deleting store: $e");
      rethrow;
    }
  }
}
