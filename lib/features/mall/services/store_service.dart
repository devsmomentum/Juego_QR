import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../models/mall_store.dart';

class StoreService {
  final SupabaseClient _supabase;

  StoreService(this._supabase);

  /// Fetch stores for a specific event
  Future<List<MallStore>> fetchStores(String eventId) async {
    try {
      final response = await _supabase
          .from('mall_stores')
          .select()
          .eq('event_id', eventId)
          .order('created_at');

      return (response as List).map((e) => MallStore.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error fetching stores: $e');
      rethrow;
    }
  }

  /// Create a new store, optionally uploading an image
  Future<void> createStore(MallStore store, dynamic imageFile) async {
    try {
      String? imageUrl;

      // 1. Upload Image if exists
      if (imageFile != null) {
        final fileExt = 'jpg'; // Default extension
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = 'store-images/$fileName';
        
        if (imageFile is XFile) {
            final bytes = await imageFile.readAsBytes();
             await _supabase.storage
              .from('events-images')
              .uploadBinary(filePath, bytes, fileOptions: const FileOptions(upsert: true));
             
             imageUrl = _supabase.storage.from('events-images').getPublicUrl(filePath);
        }
      }

      // 2. Insert Store
      final storeData = store.toMap();
      if (imageUrl != null) {
        storeData['image_url'] = imageUrl;
      }

      await _supabase.from('mall_stores').insert(storeData);
    } catch (e) {
      debugPrint('Error creating store: $e');
      rethrow;
    }
  }

  /// Update an existing store
  Future<void> updateStore(MallStore store, dynamic newImageFile) async {
    try {
      String? imageUrl = store.imageUrl;

      if (newImageFile != null) {
         final fileExt = 'jpg'; 
         final fileName = '${DateTime.now().millisecondsSinceEpoch}_updated.$fileExt';
         final filePath = 'store-images/$fileName';
         
         if (newImageFile is XFile) {
             final bytes = await newImageFile.readAsBytes();
             await _supabase.storage
              .from('events-images')
              .uploadBinary(filePath, bytes, fileOptions: const FileOptions(upsert: true));
              
             imageUrl = _supabase.storage.from('events-images').getPublicUrl(filePath);
         }
      }

      final data = store.toMap();
      data['image_url'] = imageUrl;

      await _supabase
          .from('mall_stores')
          .update(data)
          .eq('id', store.id);
    } catch (e) {
      debugPrint('Error updating store: $e');
      rethrow;
    }
  }

  /// Delete a store
  Future<void> deleteStore(String storeId) async {
    try {
      await _supabase.from('mall_stores').delete().eq('id', storeId);
    } catch (e) {
      debugPrint("Error deleting store: $e");
      rethrow;
    }
  }
}
