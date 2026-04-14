import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/services/auth_service.dart';
import '../../../shared/models/player.dart';
import '../models/admin_stats.dart';
import '../models/audit_log.dart';

/// Servicio de administración que encapsula la lógica de gestión de usuarios.
///
/// Implementa DIP al recibir [SupabaseClient] por constructor en lugar
/// de depender de variables globales.
class AdminService {
  final SupabaseClient _supabase;
  final AuthService _authService;

  AdminService({
    required SupabaseClient supabaseClient,
    required AuthService authService,
  })  : _supabase = supabaseClient,
        _authService = authService;

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

      // 4. Fetch Platform Earnings (Treasury account)
      final treasuryData = await _supabase
          .from('profiles')
          .select('clovers')
          .eq('email', 'tesoreria@maphunter.com')
          .maybeSingle();

      // 5. Fetch Total Gross Income (from clover_orders)
      final ordersResponse = await _supabase
          .from('clover_orders')
          .select('amount')
          .eq('status', 'success')
          .eq('gateway', 'stripe');

      final totalGross = (ordersResponse as List)
          .fold<double>(0.0, (sum, order) => sum + ((order['amount'] as num?)?.toDouble() ?? 0.0));

      return AdminStats(
        activeUsers: usersCount,
        createdEvents: eventsCount,
        pendingRequests: requestsCount.count,
        platformEarnings: (treasuryData?['clovers'] as num?)?.toInt() ?? 0,
        totalGrossIncome: totalGross,
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

      // Si se está baneando, revocar todas sus sesiones activas para expulsarlo inmediatamente
      if (ban) {
        await _supabase.functions.invoke(
          'admin-actions/revoke-sessions',
          body: {'userId': userId},
        );
      }
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
  /// Distribuye los premios del bote acumulado a los ganadores (Server-Side RPC).
  ///
  /// Retorna un mapa con los resultados de la distribución.
  Future<Map<String, dynamic>> distributeCompetitionPrizes(
      String eventId) async {
    try {
      debugPrint(
          'AdminService: Distributing prizes via RPC for event $eventId');

      final response = await _supabase.rpc(
        'distribute_event_prizes',
        params: {'p_event_id': eventId},
      );

      debugPrint('AdminService: RPC Response: $response');

      final data = response as Map<String, dynamic>;
      final bool success = data['success'] ?? false;

      List<Map<String, dynamic>> mappedResults = [];

      // Si fue exitoso, mapeamos los campos y buscamos nombres reales de usuarios
      if (success && data['results'] != null) {
        final List rawResults = data['results'] as List;
        final List<String> userIds =
            rawResults.map((r) => r['user_id'] as String).toList();

        // 1. Buscar nombres de los perfiles para mostrar algo legible en el Admin
        final profiles = await _supabase
            .from('profiles')
            .select('id, name')
            .inFilter('id', userIds);

        final Map<String, String> namesMap = {
          for (var p in profiles) p['id'] as String: p['name'] as String
        };

        // 2. Mapear de [rank, user_id] a [place, user] que espera la UI
        for (var res in rawResults) {
          final uid = res['user_id'] as String;
          mappedResults.add({
            'place': res['rank'] ?? 0,
            'user': namesMap[uid] ?? 'Usuario Desconocido',
            'amount': res['amount'] ?? 0,
          });
        }
      }

      return {
        'success': success,
        'message': data['message'] ??
            (success ? 'Distribución completada' : 'Error desconocido'),
        'pot': data['distributable_pot'] ?? 0.0,
        'results': mappedResults,
        'winners_count': data['winners_count'] ?? 0,
      };
    } catch (e) {
      debugPrint('AdminService: Error distributing prizes via RPC: $e');
      return {
        'success': false,
        'message': 'Error de conexión o RPC: $e',
        'pot': 0.0,
        'results': [],
      };
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
    await _supabase.rpc('admin_credit_clovers', params: {
      'p_user_id': userId,
      'p_amount': amount,
      'p_reason': 'admin_credit',
    });
  }

  Future<bool> checkPrizeDistributionStatus(String eventId) async {
    try {
      final count = await _supabase
          .from('prize_distributions')
          .count(CountOption.exact)
          .eq('event_id', eventId)
          .eq('rpc_success', true);

      return count > 0;
    } catch (e) {
      debugPrint('AdminService: Error checking prize distribution status: $e');
      return false; // Assume false on error to not block UI
    }
  }

  /// Obtiene todos los perfiles con rol de 'admin'.
  Future<List<Player>> fetchAdmins() async {
    try {
      debugPrint('AdminService: Fetching admins...');
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('role', 'admin')
          .order('name', ascending: true);

      final data = response as List;
      debugPrint('AdminService: Found ${data.length} admins.');
      return data.map((json) => Player.fromJson(json)).toList();
    } catch (e) {
      debugPrint('AdminService: Error fetching admins: $e');
      return [];
    }
  }

  /// Recupera los logs de auditoría con paginación y filtros opcionales.
  Future<List<AuditLog>> getAuditLogs({
    int limit = 20,
    int offset = 0,
    String? actionType,
    String? adminId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // 1. Start with select (PostgrestFilterBuilder)
      var query =
          _supabase.from('admin_audit_logs').select('*, profiles(email)');

      // 2. Apply filters
      if (actionType != null && actionType.isNotEmpty) {
        query = query.eq('action_type', actionType);
      }

      if (adminId != null && adminId.isNotEmpty) {
        query = query.eq('admin_id', adminId);
      }

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      // 3. Apply sort and pagination (Returns PostgrestTransformBuilder)
      final transformQuery = query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final response = await transformQuery;
      final data = response as List;

      return data.map((json) => AuditLog.fromJson(json)).toList();
    } catch (e) {
      debugPrint('AdminService: Error fetching audit logs: $e');
      return [];
    }
  }

  /// Obtiene los resultados financieros detallados de un evento.
  /// Usa un RPC SECURITY DEFINER para poder leer prize_distributions
  /// y wallet_ledger de TODOS los usuarios (bypass RLS).
  Future<Map<String, dynamic>> getDetailedEventFinancials(
      String eventId) async {
    debugPrint(
        '💰 AdminService: Getting DETAILED financial results for $eventId');
    try {
      // Use the SECURITY DEFINER RPC that bypasses RLS
      final response = await _supabase.rpc(
        'get_admin_event_financials',
        params: {'p_event_id': eventId},
      );

      if (response == null) {
        debugPrint('💰 RPC returned null');
        return {'pot': 0, 'podium': [], 'bettors': []};
      }

      final data = Map<String, dynamic>.from(response);
      debugPrint('💰 RPC success: ${data['success']}');

      if (data['success'] != true) {
        debugPrint('💰 RPC error: ${data['message']}');
        // Fallback to client-side queries (old behavior)
        return await _getDetailedEventFinancialsClientSide(eventId);
      }

      // Convert podium and bettors from JSONB arrays
      final List<dynamic> podium = data['podium'] is List
          ? (data['podium'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : [];
      final List<dynamic> bettors = data['bettors'] is List
          ? (data['bettors'] as List).map((e) {
              final m = Map<String, dynamic>.from(e as Map);
              // Ensure individual_bets is a proper list of maps
              if (m['individual_bets'] is List) {
                m['individual_bets'] = (m['individual_bets'] as List)
                    .map((ib) => Map<String, dynamic>.from(ib as Map))
                    .toList();
              }
              return m;
            }).toList()
          : [];

      debugPrint('💰 Podium: ${podium.length} entries, Bettors: ${bettors.length} entries');
      for (var p in podium) {
        debugPrint('  🏆 #${p['rank']} ${p['name']}: premio=${p['amount']}, comision=${p['commission']}');
      }
      for (var b in bettors) {
        debugPrint('  🎲 ${b['name']}: apostado=${b['total_bet']}, ganado=${b['total_won']}, bets=${(b['individual_bets'] as List?)?.length ?? 0}');
      }

      return {
        'status': 'completed',
        'pot': (data['pot'] as num?)?.toInt() ?? 0,
        'betting_pot': (data['betting_pot'] as num?)?.toInt() ?? 0,
        'winner_id': data['winner_id'],
        'podium': podium,
        'bettors': bettors,
      };
    } catch (e) {
      debugPrint('💰 AdminService: RPC call failed: $e');
      // Fallback to client-side queries
      return await _getDetailedEventFinancialsClientSide(eventId);
    }
  }

  /// Fallback: client-side queries if the RPC is not yet deployed.
  /// Limited by RLS - only shows admin's own wallet_ledger/prizes.
  Future<Map<String, dynamic>> _getDetailedEventFinancialsClientSide(
      String eventId) async {
    debugPrint(
        '💰 AdminService: FALLBACK client-side financial results for $eventId');
    try {
      // 1. Fetch Prize Distributions (Podium)
      List<dynamic> prizeDistributions = [];
      try {
        prizeDistributions = await _supabase
            .from('prize_distributions')
            .select()
            .eq('event_id', eventId)
            .eq('rpc_success', true)
            .order('position', ascending: true);
        debugPrint(
            '💰 Prize distributions found: ${prizeDistributions.length}');
      } catch (e) {
        debugPrint('💰 Error fetching prize_distributions: $e');
      }

      // 2. Fetch Bets
      List<dynamic> bets = [];
      try {
        bets = await _supabase
            .from('bets')
            .select()
            .eq('event_id', eventId)
            .order('created_at', ascending: false);
        debugPrint('💰 Bets found: ${bets.length}');
      } catch (e) {
        debugPrint('💰 Error fetching bets: $e');
      }

      // 3. Fetch Wallet Ledger (All bet-related entries for this event)
      List<dynamic> allBetLedgerEntries = [];
      try {
        // Primary: search by event_id in JSONB metadata (most reliable)
        allBetLedgerEntries = await _supabase
            .from('wallet_ledger')
            .select()
            .contains('metadata', {'event_id': eventId});
        // Keep only bet-related entries
        allBetLedgerEntries = allBetLedgerEntries.where((p) {
          final meta = p['metadata'];
          if (meta is Map) {
            final type = meta['type']?.toString() ?? '';
            return type == 'bet_payout' || type == 'runner_bet_commission';
          }
          return false;
        }).toList();
        debugPrint(
            '💰 Bet ledger entries found: ${allBetLedgerEntries.length}');
      } catch (e) {
        debugPrint(
            '💰 Error fetching wallet_ledger via contains: $e');
        // Fallback: broader description-based query
        try {
          final allEntries = await _supabase
              .from('wallet_ledger')
              .select()
              .or('description.ilike.%Apuesta%,description.ilike.%Comision%');
          allBetLedgerEntries = allEntries.where((p) {
            final meta = p['metadata'];
            if (meta is Map) {
              return meta['event_id']?.toString() == eventId;
            }
            return false;
          }).toList();
          debugPrint(
              '💰 Bet ledger entries found (fallback): ${allBetLedgerEntries.length}');
        } catch (e2) {
          debugPrint(
              '💰 Error fetching wallet_ledger fallback: $e2');
        }
      }

      // Separate: bet payouts (for bettors) vs runner commissions (for podium winner)
      final List<dynamic> betPayouts = allBetLedgerEntries.where((p) {
        final meta = p['metadata'];
        if (meta is Map) {
          final type = meta['type']?.toString();
          return type == 'bet_payout';
        }
        return false;
      }).toList();
      final List<dynamic> runnerCommissions = allBetLedgerEntries.where((p) {
        final meta = p['metadata'];
        if (meta is Map) {
          final type = meta['type']?.toString();
          return type == 'runner_bet_commission';
        }
        return false;
      }).toList();
      debugPrint('💰 Bet payouts: ${betPayouts.length}, Runner commissions: ${runnerCommissions.length}');

      // 4. Fetch Event data for pot calculation
      int pot = 0;
      String? winnerId;
      try {
        final eventData = await _supabase
            .from('events')
            .select('pot, configured_winners, winner_id')
            .eq('id', eventId)
            .single();

        // Use actual pot from DB (accumulated from real payments)
        final dbPot = (eventData['pot'] as num?)?.toInt() ?? 0;
        pot = (dbPot * 0.70).toInt();
        winnerId = eventData['winner_id'] as String?;
        debugPrint('💰 Pot from DB: $dbPot, distributable (70%): $pot, winner: $winnerId');
      } catch (e) {
        debugPrint('💰 Error calculating pot: $e');
      }

      // 5. Collect User IDs to fetch profiles (bettors + racers)
      final Set<String> userIds = {};
      for (var p in prizeDistributions) userIds.add(p['user_id'] as String);
      for (var b in bets) {
        userIds.add(b['user_id'] as String);
        userIds.add(b['racer_id'] as String); // racer profiles needed for bet details
      }
      for (var p in allBetLedgerEntries) userIds.add(p['user_id'] as String);

      // 6. Fetch Profiles
      Map<String, Map<String, dynamic>> profilesMap = {};
      if (userIds.isNotEmpty) {
        final profiles = await _supabase
            .from('profiles')
            .select('id, name, avatar_id')
            .inFilter('id', userIds.toList());

        for (var p in profiles) {
          profilesMap[p['id'] as String] = p;
        }
      }

      // 7. Build Podium
      List<Map<String, dynamic>> podium = [];

      // Build a map of runner commissions by user_id
      final Map<String, int> runnerCommissionMap = {};
      for (var rc in runnerCommissions) {
        final uid = rc['user_id'] as String;
        final amount = (rc['amount'] as num).toInt();
        runnerCommissionMap[uid] = (runnerCommissionMap[uid] ?? 0) + amount;
      }

      if (prizeDistributions.isNotEmpty) {
        // Primary source: prize_distributions table
        for (var p in prizeDistributions) {
          final uid = p['user_id'] as String;
          final profile = profilesMap[uid] ?? {};
          podium.add({
            'user_id': uid,
            'name': profile['name'] ?? 'Usuario',
            'avatar_id': profile['avatar_id'],
            'rank': p['position'],
            'amount': p['amount'],
            'commission': runnerCommissionMap[uid] ?? 0,
          });
        }
      } else {
        // Fallback: Build podium from game_players.final_placement
        debugPrint(
            '💰 No prize_distributions found, building podium from game_players');
        try {
          final topPlayers = await _supabase
              .from('game_players')
              .select('user_id, final_placement, completed_clues_count')
              .eq('event_id', eventId)
              .not('final_placement', 'is', null)
              .neq('status', 'spectator')
              .order('final_placement', ascending: true)
              .limit(3);

          // Fetch profiles for podium players
          final podiumUserIds =
              topPlayers.map((p) => p['user_id'] as String).toList();
          if (podiumUserIds.isNotEmpty) {
            final podiumProfiles = await _supabase
                .from('profiles')
                .select('id, name, avatar_id')
                .inFilter('id', podiumUserIds);
            for (var p in podiumProfiles) {
              profilesMap[p['id'] as String] = p;
            }
          }

          for (var p in topPlayers) {
            final uid = p['user_id'] as String;
            final profile = profilesMap[uid] ?? {};
            podium.add({
              'user_id': uid,
              'name': profile['name'] ?? 'Usuario',
              'avatar_id': profile['avatar_id'],
              'rank': p['final_placement'],
              'amount': 0,
              'commission': runnerCommissionMap[uid] ?? 0,
            });
          }
        } catch (e) {
          debugPrint('💰 Error building fallback podium: $e');
        }
      }

      // 8. Process Bettors with individual bet details
      final Map<String, Map<String, dynamic>> bettorsMap = {};

      // Sum Bets per user and build individual bet list
      for (var b in bets) {
        final uid = b['user_id'] as String;
        final amount = (b['amount'] as num).toInt();
        final racerId = b['racer_id'] as String;
        final racerProfile = profilesMap[racerId];
        final racerName = racerProfile?['name'] as String? ?? 'Jugador';

        if (!bettorsMap.containsKey(uid)) {
          final profile = profilesMap[uid] ?? {};
          bettorsMap[uid] = {
            'user_id': uid,
            'name': profile['name'] ?? 'Apostador',
            'avatar_id': profile['avatar_id'],
            'total_bet': 0,
            'total_won': 0,
            'bets_count': 0,
            'individual_bets': <Map<String, dynamic>>[],
          };
        }

        bettorsMap[uid]!['total_bet'] += amount;
        bettorsMap[uid]!['bets_count'] += 1;
        (bettorsMap[uid]!['individual_bets'] as List<Map<String, dynamic>>).add({
          'racer_id': racerId,
          'racer_name': racerName,
          'amount': amount,
          'won': racerId == winnerId,
        });
      }

      // Add Payouts from wallet_ledger (bet_payout entries only)
      for (var p in betPayouts) {
        final uid = p['user_id'] as String;
        final amount = (p['amount'] as num).toInt();

        if (bettorsMap.containsKey(uid)) {
          bettorsMap[uid]!['total_won'] += amount;
        } else {
          final profile = profilesMap[uid] ?? {};
          bettorsMap[uid] = {
            'user_id': uid,
            'name': profile['name'] ?? 'Ganador',
            'avatar_id': profile['avatar_id'],
            'total_bet': 0,
            'total_won': amount,
            'bets_count': 0,
            'individual_bets': <Map<String, dynamic>>[],
          };
        }
      }

      // Calculate Net
      for (var uid in bettorsMap.keys) {
        final data = bettorsMap[uid]!;
        data['net'] = (data['total_won'] as int) - (data['total_bet'] as int);
      }

      final bettorsList = bettorsMap.values.toList();
      bettorsList.sort(
          (a, b) => (b['total_won'] as int).compareTo(a['total_won'] as int));

      // 9. Calculate betting pot total (sum of all bets)
      final int bettingPotTotal = bets.fold<int>(
          0, (sum, b) => sum + (b['amount'] as num).toInt());

      return {
        'status': 'completed',
        'pot': pot,
        'betting_pot': bettingPotTotal,
        'winner_id': winnerId,
        'podium': podium,
        'bettors': bettorsList,
      };
    } catch (e) {
      debugPrint(
          '💰 AdminService: Critical error getting DETAILED financial results: $e');
      return {'pot': 0, 'podium': [], 'bettors': []};
    }
  }

  /// DEPRECATED: Use getDetailedEventFinancials
  /// Obtiene los resultados financieros finales de un evento.
  Future<Map<String, dynamic>> getEventFinancialResults(String eventId) async {
    return getDetailedEventFinancials(eventId);
  }

  /// Ajusta las monedas o vidas de un jugador en un evento específico.
  ///
  /// [userId] - ID del jugador.
  /// [eventId] - ID del evento.
  /// [field] - Campo a modificar ('coins' o 'lives').
  /// [delta] - Cambio a aplicar (positivo para agregar, negativo para quitar).
  Future<void> adjustPlayerStats({
    required String userId,
    required String eventId,
    required String field,
    required int delta,
  }) async {
    assert(
        field == 'coins' || field == 'lives', 'Field must be coins or lives');
    try {
      // 1. Read current value
      final row = await _supabase
          .from('game_players')
          .select(field)
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .single();

      final int current = (row[field] as num?)?.toInt() ?? 0;
      int newValue = current + delta;
      if (newValue < 0) newValue = 0;
      // lives has a CHECK constraint <= 3 in the DB
      if (field == 'lives' && newValue > 3) newValue = 3;

      // 2. Update
      await _supabase
          .from('game_players')
          .update({field: newValue})
          .eq('event_id', eventId)
          .eq('user_id', userId);

      debugPrint(
          'AdminService: adjustPlayerStats $field $delta → $newValue for user $userId in event $eventId');
    } catch (e) {
      debugPrint('AdminService: Error adjusting player stats: $e');
      rethrow;
    }
  }

  /// Establece un valor absoluto de monedas o vidas para un jugador en un evento.
  Future<void> setPlayerStat({
    required String userId,
    required String eventId,
    required String field,
    required int value,
  }) async {
    assert(
        field == 'coins' || field == 'lives', 'Field must be coins or lives');
    int safeValue = value < 0 ? 0 : value;
    if (field == 'lives' && safeValue > 3) safeValue = 3;
    try {
      await _supabase
          .from('game_players')
          .update({field: safeValue})
          .eq('event_id', eventId)
          .eq('user_id', userId);

      debugPrint(
          'AdminService: setPlayerStat $field = $safeValue for user $userId in event $eventId');
    } catch (e) {
      debugPrint('AdminService: Error setting player stat: $e');
      rethrow;
    }
  }

  /// Otorga un poder (ítem) al inventario de un jugador.
  Future<void> adminGiftPowerToPlayer({
    required String userId,
    required String eventId,
    required String powerSlug,
    int quantity = 1,
  }) async {
    try {
      final gp = await _supabase
          .from('game_players')
          .select('id')
          .eq('user_id', userId)
          .eq('event_id', eventId)
          .maybeSingle();

      if (gp == null) throw 'Jugador no encontrado en el evento';
      final String gpId = gp['id'];

      final power = await _supabase
          .from('powers')
          .select('id')
          .eq('slug', powerSlug)
          .single();
      final String powerId = power['id'];

      final existingPower = await _supabase
          .from('player_powers')
          .select('id, quantity')
          .eq('game_player_id', gpId)
          .eq('power_id', powerId)
          .maybeSingle();

      if (existingPower != null) {
        await _supabase.from('player_powers').update({
          'quantity': (existingPower['quantity'] ?? 0) + quantity
        }).eq('id', existingPower['id']);
      } else {
        await _supabase.from('player_powers').insert({
          'game_player_id': gpId,
          'power_id': powerId,
          'quantity': quantity,
        });
      }

      debugPrint(
          'AdminService: adminGiftPowerToPlayer $powerSlug x$quantity to user $userId');
    } catch (e) {
      debugPrint('AdminService: Error gifting power: $e');
      rethrow;
    }
  }

  /// Aplica un efecto de poder INMEDIATO a un jugador (congelar, etc).
  Future<void> adminApplyPowerToPlayer({
    required String userId,
    required String eventId,
    required String powerSlug,
  }) async {
    try {
      debugPrint(
          'AdminService: Force applying $powerSlug to user $userId in event $eventId');

      // 1. Intentar usar el RPC (más atómico y seguro)
      try {
        final response =
            await _supabase.rpc('admin_force_apply_power', params: {
          'p_event_id': eventId,
          'p_target_userid': userId,
          'p_power_slug': powerSlug,
        });

        if (response != null && response['success'] == true) {
          debugPrint('AdminService: admin_force_apply_power SUCCESS');
          return;
        }
      } catch (e) {
        debugPrint(
            'AdminService: RPC admin_force_apply_power failed/missing, trying manual fallback: $e');
      }

      // 2. Fallback Manual (si el RPC no está instalado)
      // Nota: Requiere que el admin tenga permisos de insert en active_powers

      // A. Asegurar que el admin tiene un game_player_id en este evento
      final adminUserId = _supabase.auth.currentUser?.id;
      if (adminUserId == null) throw 'No authenticated admin user';

      var adminGp = await _supabase
          .from('game_players')
          .select('id')
          .eq('user_id', adminUserId)
          .eq('event_id', eventId)
          .maybeSingle();

      if (adminGp == null) {
        try {
          adminGp = await _supabase
              .from('game_players')
              .insert({
                'event_id': eventId,
                'user_id': adminUserId,
                'status': 'spectator',
                'lives': 0
              })
              .select('id')
              .maybeSingle();

          if (adminGp == null)
            throw 'Error al registrar al administrador en el evento';
        } catch (e) {
          debugPrint('AdminService: Failed to insert admin as spectator: $e');
          throw 'No se pudo registrar al administrador para realizar esta acción: $e';
        }
      }
      final String adminGpId = adminGp['id'];

      // B. Obtener Target GamePlayer
      final targetGp = await _supabase
          .from('game_players')
          .select('id')
          .eq('user_id', userId)
          .eq('event_id', eventId)
          .maybeSingle();

      if (targetGp == null) {
        throw 'Jugador objetivo no encontrado o no está inscrito en este evento.';
      }

      final String targetGpId = targetGp['id'];

      // C. Obtener Detalles del Poder
      final power = await _supabase
          .from('powers')
          .select('id, duration')
          .eq('slug', powerSlug)
          .maybeSingle();

      if (power == null) {
        throw 'Poder "$powerSlug" no encontrado en la base de datos.';
      }

      final String powerId = power['id'];
      final int duration = power['duration'] ?? 20;

      // D. Insertar Efecto Activo
      await _supabase.from('active_powers').insert({
        'event_id': eventId,
        'caster_id': adminGpId,
        'target_id': targetGpId,
        'power_id': powerId,
        'power_slug': powerSlug,
        'expires_at': DateTime.now()
            .add(Duration(seconds: duration))
            .toUtc()
            .toIso8601String(),
      });

      // E. Caso especial: Robo de Vida (quitar vida)
      if (powerSlug == 'life_steal') {
        try {
          await _supabase
              .rpc('lose_life', params: {'p_game_player_id': targetGpId});
        } catch (e) {
          debugPrint('AdminService: Manual lose_life fallback failed: $e');
        }
      }

      // F. Registrar Evento de Combate
      await _supabase.from('combat_events').insert({
        'event_id': eventId,
        'attacker_id': adminGpId,
        'target_id': targetGpId,
        'power_id': powerId,
        'power_slug': powerSlug,
        'result_type': 'admin_force',
      });

      debugPrint('AdminService: Manual adminApplyPowerToPlayer SUCCESS');
    } catch (e) {
      debugPrint('AdminService: Error applying power effect: $e');
      rethrow;
    }
  }

  /// Actualiza el rol de un usuario.
  Future<void> updateUserRole(String userId, String newRole) async {
    try {
      debugPrint('AdminService: Updating user $userId to role $newRole');
      await _supabase
          .from('profiles')
          .update({'role': newRole})
          .eq('id', userId);
    } catch (e) {
      debugPrint('AdminService: Error updating user role: $e');
      rethrow;
    }
  }
}
