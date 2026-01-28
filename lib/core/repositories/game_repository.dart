import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Callback type for realtime subscription events.
typedef RealtimeCallback = void Function(PostgresChangePayload payload);

/// Repository for game-related Supabase realtime operations.
/// Abstracts direct Supabase realtime calls from UI screens.
class GameRepository {
  final SupabaseClient _client;
  final Map<String, RealtimeChannel> _channels = {};

  GameRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Subscribes to game_requests table changes for a specific user.
  /// Returns a channel ID that can be used to unsubscribe later.
  String subscribeToGameRequests({
    required String userId,
    required RealtimeCallback onRequestChange,
  }) {
    final channelId = 'game_requests_updates_$userId';
    
    if (_channels.containsKey(channelId)) {
      // Already subscribed
      return channelId;
    }

    final channel = _client
        .channel(channelId)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'game_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            debugPrint('[REALTIME] Request Change Detected: ${payload.eventType}');
            onRequestChange(payload);
          },
        )
        .subscribe();

    _channels[channelId] = channel;
    return channelId;
  }

  /// Subscribes to game_players table inserts for a specific user.
  /// Returns a channel ID that can be used to unsubscribe later.
  String subscribeToGamePlayerInserts({
    required String userId,
    required String eventId,
    required RealtimeCallback onPlayerInsert,
  }) {
    final channelId = 'game_players_inserts_$userId';
    
    if (_channels.containsKey(channelId)) {
      return channelId;
    }

    final channel = _client
        .channel(channelId)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'game_players',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            debugPrint('[REALTIME] Player Insert Detected!');
            final newRecord = payload.newRecord;
            if (newRecord['event_id'] == eventId) {
              onPlayerInsert(payload);
            }
          },
        )
        .subscribe();

    _channels[channelId] = channel;
    return channelId;
  }

  /// Unsubscribes from a specific channel by ID.
  void unsubscribe(String channelId) {
    final channel = _channels.remove(channelId);
    channel?.unsubscribe();
  }

  /// Unsubscribes from all active channels.
  void unsubscribeAll() {
    for (final channel in _channels.values) {
      channel.unsubscribe();
    }
    _channels.clear();
  }

  /// Disposes all resources. Call when the repository is no longer needed.
  void dispose() {
    unsubscribeAll();
  }
}
