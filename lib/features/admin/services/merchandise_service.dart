import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/merchandise_item.dart';

class MerchandiseService {
  final SupabaseClient _supabase;

  MerchandiseService(this._supabase);

  // --- MERCHANDISE ITEMS ---

  Future<List<MerchandiseItem>> getItems({bool includeUnavailable = false}) async {
    var query = _supabase.from('merchandise_items').select();
    
    if (!includeUnavailable) {
      query = query.eq('is_available', true);
    }
    
    final data = await query.order('created_at', ascending: false);
    return (data as List).map((e) => MerchandiseItem.fromJson(e)).toList();
  }

  Future<void> createItem(MerchandiseItem item) async {
    await _supabase.from('merchandise_items').insert(item.toJson());
  }

  Future<void> updateItem(MerchandiseItem item) async {
    await _supabase
        .from('merchandise_items')
        .update(item.toJson())
        .eq('id', item.id);
  }

  Future<void> deleteItem(String id) async {
    await _supabase.from('merchandise_items').delete().eq('id', id);
  }

  // --- REDEMPTIONS ---

  Future<List<MerchandiseRedemption>> getRedemptions({String? status}) async {
    var query = _supabase
        .from('merchandise_redemptions')
        .select('*, profiles(name), merchandise_items(name, image_url)');
    
    if (status != null) {
      query = query.eq('status', status);
    }
    
    final data = await query.order('created_at', ascending: false);
    return (data as List).map((e) => MerchandiseRedemption.fromJson(e)).toList();
  }

  Future<void> updateRedemptionStatus(String id, String status, {String? notes}) async {
    await _supabase
        .from('merchandise_redemptions')
        .update({
          'status': status,
          if (notes != null) 'admin_notes': notes,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  // --- USER ACTIONS ---

  Future<Map<String, dynamic>> redeemItem(String itemId) async {
    try {
      final response = await _supabase.rpc('redeem_merchandise_item', params: {
        'p_item_id': itemId,
      });
      
      // On Web, response might be a Map or a List containing a Map, or just dynamic
      if (response is Map) {
        return Map<String, dynamic>.from(response);
      } else if (response is List && response.isNotEmpty) {
        return Map<String, dynamic>.from(response.first);
      }
      
      return {'success': true, 'message': 'Operation completed'};
    } catch (e) {
      debugPrint('MerchandiseService: Error redeeming item $e');
      return {'success': false, 'message': e.toString()};
    }
  }
}
