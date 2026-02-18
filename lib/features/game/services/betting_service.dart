import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BettingService {
  final SupabaseClient _supabase;

  BettingService(this._supabase);

  /// Realiza apuestas masivas para un usuario en un evento.
  /// Retorna el resultado del RPC.
  Future<Map<String, dynamic>> placeBetsBatch({
    required String eventId,
    required String userId,
    required List<String> racerIds,
  }) async {
    try {
      final response = await _supabase.rpc('place_bets_batch', params: {
        'p_event_id': eventId,
        'p_user_id': userId,
        'p_racer_ids': racerIds,
      });

      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('BettingService: Error placing bets: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  /// Obtiene las apuestas activas de un usuario en un evento.
  Future<List<Map<String, dynamic>>> fetchUserBets(
      String eventId, String userId) async {
    try {
      final response = await _supabase
          .from('bets')
          .select('id, racer_id, amount, created_at, profiles:racer_id(name)')
          .eq('event_id', eventId)
          .eq('user_id', userId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('BettingService: Error fetching user bets: $e');
      return [];
    }
  }
}
