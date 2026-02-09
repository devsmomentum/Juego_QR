import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/player.dart';
import '../models/admin_stats.dart';

/// Servicio de administración que encapsula la lógica de gestión de usuarios.
///
/// Implementa DIP al recibir [SupabaseClient] por constructor en lugar
/// de depender de variables globales.
class AdminService {
  final SupabaseClient _supabase;

  AdminService({required SupabaseClient supabaseClient})
      : _supabase = supabaseClient;

  /// Obtiene estadísticas generales para el dashboard.
  Future<AdminStats> fetchGeneralStats() async {
    try {
      // 1. Count Users (Profiles)
      final usersCount =
          await _supabase.from('profiles').count(CountOption.exact);

      // 2. Count Events
      final eventsCount =
          await _supabase.from('events').count(CountOption.exact);

      // 3. Count Pending Requests
      final requestsCount = await _supabase
          .from('game_requests')
          .select('*')
          .eq('status', 'pending')
          .count(CountOption.exact);

      return AdminStats(
        activeUsers: usersCount,
        createdEvents: eventsCount,
        pendingRequests: requestsCount.count,
      );
    } catch (e) {
      debugPrint('AdminService: Error fetching stats: $e');
      rethrow;
    }
  }

  /// Obtiene todos los jugadores registrados en el sistema.
  ///
  /// Retorna una lista de [Player] ordenada por nombre.
  Future<List<Player>> fetchAllPlayers() async {
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .order('name', ascending: true);

      return (data as List).map((json) => Player.fromJson(json)).toList();
    } catch (e) {
      debugPrint('AdminService: Error fetching all players: $e');
      rethrow;
    }
  }

  /// Alterna el estado de baneo de un usuario.
  ///
  /// [userId] - ID del usuario a modificar.
  /// [ban] - `true` para banear, `false` para activar.
  Future<void> toggleBanUser(String userId, bool ban) async {
    try {
      await _supabase.rpc(
        'toggle_ban',
        params: {
          'user_id': userId,
          'new_status': ban ? 'banned' : 'active',
        },
      );
    } catch (e) {
      debugPrint('AdminService: Error toggling ban: $e');
      rethrow;
    }
  }

  Future<void> toggleGameBanUser(
      String userId, String eventId, bool ban) async {
    debugPrint(
        'AdminService: toggleGameBanUser (RPC-V2-SUSPENDED) CALLED. User: $userId, Event: $eventId, Ban: $ban');
    try {
      // Usamos la versión V2 NUCLEAR que desactiva triggers
      final success = await _supabase.rpc<bool>(
        'toggle_event_member_ban_v2',
        params: {
          'p_user_id': userId,
          'p_event_id': eventId,
          // CAMBIO CLAVE: Usamos 'suspended' en lugar de 'banned'
          'p_new_status': ban ? 'suspended' : 'active',
        },
      );

      debugPrint('AdminService: toggleGameBanUser RPC Result: $success');

      if (!success) {
        throw Exception(
            "La función RPC retornó false (no se encontró el registro o falló)");
      }
    } catch (e) {
      debugPrint('AdminService: Error toggling game ban via RPC: $e');
      rethrow;
    }
  }

  /// Obtiene un mapa de {userId: status} para todos los participantes de un evento.
  Future<Map<String, String>> fetchEventParticipantStatuses(
      String eventId) async {
    try {
      final data = await _supabase
          .from('game_players')
          .select('user_id, status')
          .eq('event_id', eventId);

      final Map<String, String> result = {};
      for (var row in data) {
        if (row['user_id'] != null && row['status'] != null) {
          result[row['user_id'] as String] = row['status'] as String;
        }
      }
      return result;
    } catch (e) {
      debugPrint('AdminService: Error fetching event statuses: $e');
      return {};
    }
  }

  /// Elimina un usuario del sistema.
  ///
  /// [userId] - ID del usuario a eliminar.
  Future<void> deleteUser(String userId) async {
    try {
      await _supabase.rpc('delete_user', params: {'user_id': userId});
    } catch (e) {
      debugPrint('AdminService: Error deleting user: $e');
      rethrow;
    }
  }

  /// Distribuye los premios del bote acumulado a los ganadores.
  ///
  /// Retorna un mapa con los resultados de la distribución.
  Future<Map<String, dynamic>> distributeCompetitionPrizes(
      String eventId) async {
    try {
      debugPrint('AdminService: Distributing prizes for event $eventId');

      // 1. Obtener detalles del evento (Entry Fee)
      final eventResponse = await _supabase
          .from('events')
          .select('entry_fee, title')
          .eq('id', eventId)
          .single();

      final int entryFee = eventResponse['entry_fee'] ?? 0;

      // 2. Contar Participantes (Solo los que han pagado/jugado)
      // Excluye espectadores y pendientes/rechazados
      final participantsCountResponse = await _supabase
          .from('game_players')
          .count(CountOption.exact)
          .eq('event_id', eventId)
          .inFilter('status', ['active', 'banned', 'suspended', 'eliminated']);

      final int count = participantsCountResponse;
      debugPrint('AdminService: Participants count (paid): $count');

      // 3. Calcular Bote (70% del total)
      final double totalCollection = (count * entryFee).toDouble();
      final double totalPot = totalCollection * 0.70;

      debugPrint('AdminService: Total Collection: $totalCollection');
      debugPrint('AdminService: Pot to distribute (70%): $totalPot');

      if (totalPot <= 0) {
        return {
          'success': false,
          'message':
              'El bote es 0 (Sin participantes suficientes o evento gratuito)',
          'pot': 0.0
        };
      }

      // 4. Obtener Ranking (Top 3)
      final List<dynamic> leaderboard = await _gameLeaderboard(eventId);

      if (leaderboard.isEmpty) {
        return {
          'success': false,
          'message': 'No hay jugadores en el ranking para premiar',
          'pot': totalPot
        };
      }

      // 5. Distribuir Premios (Lógica Dinámica de Tiers)
      final results = <Map<String, dynamic>>[];

      // Tier 1: < 5 Jugadores (1 Ganador - 100% del Bote)
      // Tier 2: 5-9 Jugadores (2 Ganadores - 70% / 30%)
      // Tier 3: 10+ Jugadores (3 Ganadores - 50% / 30% / 20%)

      double p1Share = 0.0;
      double p2Share = 0.0;
      double p3Share = 0.0;
      String tierName = "";

      if (count < 5) {
        // Tier 1
        tierName = "Tier 1 (<5 Jugadores)";
        p1Share = 1.00; // 100%
      } else if (count < 10) {
        // Tier 2
        tierName = "Tier 2 (5-9 Jugadores)";
        p1Share = 0.70; // 70%
        p2Share = 0.30; // 30%
      } else {
        // Tier 3
        tierName = "Tier 3 (10+ Jugadores)";
        p1Share = 0.50; // 50%
        p2Share = 0.30; // 30%
        p3Share = 0.20; // 20%
      }

      debugPrint('AdminService: $tierName');

      // 1er Lugar
      if (leaderboard.isNotEmpty && p1Share > 0) {
        final p1 = leaderboard[0];
        final amount = (totalPot * p1Share).round();
        final userId = p1['user_id'] ?? p1['id'];
        await _addToWallet(userId, amount);
        results.add({'place': 1, 'user': p1['name'], 'amount': amount});
        debugPrint('AdminService: 1st Place ($userId): +$amount');
      }

      // 2do Lugar
      if (leaderboard.length > 1 && p2Share > 0) {
        final p2 = leaderboard[1];
        final amount = (totalPot * p2Share).round();
        final userId = p2['user_id'] ?? p2['id'];
        await _addToWallet(userId, amount);
        results.add({'place': 2, 'user': p2['name'], 'amount': amount});
        debugPrint('AdminService: 2nd Place ($userId): +$amount');
      }

      // 3er Lugar
      if (leaderboard.length > 2 && p3Share > 0) {
        final p3 = leaderboard[2];
        final amount = (totalPot * p3Share).round();
        final userId = p3['user_id'] ?? p3['id'];
        await _addToWallet(userId, amount);
        results.add({'place': 3, 'user': p3['name'], 'amount': amount});
        debugPrint('AdminService: 3rd Place ($userId): +$amount');
      }

      // 6. Marcar Evento como Completado
      await _supabase.from('events').update({
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String()
      }).eq('id', eventId);

      return {
        'success': true,
        'pot': totalPot,
        'results': results,
        'message': 'Premios distribuidos correctamente'
      };
    } catch (e) {
      debugPrint('AdminService: Error distributing prizes: $e');
      rethrow;
    }
  }

  // Helper para obtener ranking (reutiliza lógica similar a GameService pero simplificada)
  Future<List<dynamic>> _gameLeaderboard(String eventId) async {
    return await _supabase
        .from('event_leaderboard')
        .select()
        .eq('event_id', eventId)
        .order('completed_clues', ascending: false, nullsFirst: false)
        .order('last_completion_time', ascending: true)
        .limit(3);
  }

  Future<void> _addToWallet(String userId, int amount) async {
    if (amount <= 0) return;
    // Fetch current
    final res = await _supabase
        .from('profiles')
        .select('clovers')
        .eq('id', userId)
        .single();
    final int current = res['clovers'] ?? 0;
    // Update
    await _supabase
        .from('profiles')
        .update({'clovers': current + amount}).eq('id', userId);
  }
}
