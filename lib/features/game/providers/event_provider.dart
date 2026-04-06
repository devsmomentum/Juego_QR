import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event.dart';
import '../models/clue.dart';
import '../../events/services/event_service.dart';

class EventProvider with ChangeNotifier {
  final EventService _eventService;
  List<GameEvent> _events = [];
  RealtimeChannel?
      _eventsChannel; // P2: Suscripción Realtime a cambios del evento

  EventProvider({required EventService eventService})
      : _eventService = eventService;

  List<GameEvent> get events => _events;

  // Crear evento
  Future<String?> createEvent(GameEvent event, XFile? imageFile) async {
    try {
      final newEvent = await _eventService.createEvent(event, imageFile);
      _events.add(newEvent);
      notifyListeners();
      return newEvent.id;
    } catch (e) {
      debugPrint('Error creando evento: $e');
      rethrow;
    }
  }

  // Crear CLUES en Lote (Client Side)
  Future<void> createCluesBatch(
      String eventId, List<Map<String, dynamic>> cluesData) async {
    try {
      await _eventService.createCluesBatch(eventId, cluesData);
      debugPrint("✅ Pistas creadas exitosamente para el evento $eventId");
    } catch (e) {
      debugPrint("❌ Error creando lote de pistas: $e");
      rethrow;
    }
  }

  // Actualizar evento
  Future<void> updateEvent(GameEvent event, XFile? imageFile) async {
    try {
      final updatedEvent = await _eventService.updateEvent(event, imageFile);

      final index = _events.indexWhere((e) => e.id == event.id);
      if (index != -1) {
        _events[index] = updatedEvent;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error actualizando evento: $e');
      rethrow;
    }
  }

  // Update ONLY store prices
  Future<void> updateEventStorePrices(
      String eventId, Map<String, int> prices) async {
    try {
      await _eventService.updateEventStorePrices(eventId, prices);
      final index = _events.indexWhere((e) => e.id == eventId);
      if (index != -1) {
        _events[index] = _events[index].copyWith(storePrices: prices);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating store prices: $e');
      rethrow;
    }
  }

  // Update ONLY spectator config
  Future<void> updateEventSpectatorConfig(
      String eventId, Map<String, dynamic> config) async {
    try {
      await _eventService.updateEventSpectatorConfig(eventId, config);
      final index = _events.indexWhere((e) => e.id == eventId);
      if (index != -1) {
        _events[index] = _events[index].copyWith(spectatorConfig: config);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating spectator config: $e');
      rethrow;
    }
  }

  // Actualizar status del evento
  Future<void> updateEventStatus(String eventId, String status) async {
    try {
      await _eventService.updateEventStatus(eventId, status);

      final index = _events.indexWhere((e) => e.id == eventId);
      if (index != -1) {
        final old = _events[index];
        _events[index] = old.copyWith(status: status);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating event status: $e');
      rethrow;
    }
  }

  /// Secure admin-only event start via RPC.
  /// The ONLY way to transition an event from 'pending' to 'active'.
  Future<void> startEvent(String eventId) async {
    try {
      await _eventService.startEvent(eventId);

      // Optimistic local update
      final index = _events.indexWhere((e) => e.id == eventId);
      if (index != -1) {
        _events[index] = _events[index].copyWith(status: 'active');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error starting event via RPC: $e');
      rethrow;
    }
  }

  // Eliminar evento
  Future<void> deleteEvent(String eventId) async {
    try {
      final index = _events.indexWhere((e) => e.id == eventId);
      if (index != -1) {
        final event = _events[index];
        // Pass image URL to ensure cleanup
        await _eventService.deleteEvent(eventId, event.imageUrl);
        _events.removeAt(index);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error eliminando evento: $e');
      rethrow;
    }
  }

  // Obtener eventos
  Future<void> fetchEvents({String? type}) async {
    try {
      _events = await _eventService.fetchEvents(type: type);
      notifyListeners();
    } catch (e) {
      debugPrint('Error obteniendo eventos: $e');
    }
  }

  // --- GESTIÓN DE PISTAS (ADMIN) ---

  Future<List<Clue>> fetchCluesForEvent(String eventId) async {
    return await _eventService.fetchCluesForEvent(eventId);
  }

  Future<void> updateClue(Clue clue) async {
    try {
      await _eventService.updateClue(clue);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addClue(String eventId, Clue clue) async {
    try {
      await _eventService.addClue(eventId, clue);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Safely resets an event. Returns summary with integrity verification.
  Future<Map<String, dynamic>> safeResetEvent(String eventId) async {
    try {
      final result = await _eventService.safeResetEvent(eventId);
      await fetchEvents();
      notifyListeners();
      return result;
    } catch (e) {
      debugPrint('Error al reiniciar competencia: $e');
      rethrow;
    }
  }

  /// @deprecated Use [safeResetEvent] instead.
  Future<void> restartCompetition(String eventId) async {
    try {
      await _eventService.restartCompetition(eventId);
      await fetchEvents();
      notifyListeners();
    } catch (e) {
      debugPrint('Error al reiniciar competencia: $e');
      rethrow;
    }
  }

  Future<void> deleteClue(String clueId) async {
    try {
      await _eventService.deleteClue(clueId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting clue: $e');
      rethrow;
    }
  }

  // ── P2: Realtime suscripción a la tabla events ──────────────────────────────

  /// Suscribe al canal Realtime de Supabase para recibir cambios del evento.
  /// Cuando el admin activa el evento, el caché local se actualiza y
  /// HomeScreen.build() hace rebuild automático mostrando el juego.
  Future<void> subscribeToEventUpdates(String eventId) async {
    // P2: Si el evento no está en la lista local (común en el player), lo buscamos primero
    final existingIndex = _events.indexWhere((e) => e.id == eventId);
    if (existingIndex == -1) {
      debugPrint(
          '[EventProvider] 🔍 Event $eventId not found in local list. Fetching...');
      try {
        final allEvents = await _eventService.fetchEvents();
        final serverEvent = allEvents.firstWhere((e) => e.id == eventId);
        _events.add(serverEvent);
        debugPrint('[EventProvider] ✅ Event $eventId added to local list');
        notifyListeners();
      } catch (e) {
        debugPrint('[EventProvider] ⚠️ Error fetching event $eventId: $e');
        // Continuamos con la suscripción de todos modos por si acaso
      }
    }

    _eventsChannel?.unsubscribe();
    _eventsChannel = Supabase.instance.client
        .channel('event_status_changes:$eventId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: eventId,
          ),
          callback: (payload) {
            debugPrint('[EventProvider] 🔔 Realtime: event update received');
            final record = payload.newRecord;
            final index = _events.indexWhere((e) => e.id == eventId);

            if (index != -1) {
              final old = _events[index];

              // Map dynamic json to fields
              final String? newStatus = record['status'];
              final Map<String, dynamic>? newStorePricesRaw =
                  record['store_prices'];
              final Map<String, dynamic>? newSpectatorConfig =
                  record['spectator_config'];
              final int? newPot = record['pot'];
              final int? newConfiguredWinners =
                  (record['configured_winners'] as num?)?.toInt();

              _events[index] = old.copyWith(
                status: newStatus,
                pot: newPot,
                configuredWinners: newConfiguredWinners,
                spectatorConfig: newSpectatorConfig,
                storePrices: newStorePricesRaw
                    ?.map((k, v) => MapEntry(k, (v as num).toInt())),
              );

              debugPrint(
                  '[EventProvider] ✅ Local event updated via Realtime: ${newStorePricesRaw ?? 'no prices'}');
              notifyListeners();
            } else {
              debugPrint(
                  '[EventProvider] ⚠️ Received realtime update for event $eventId but it is STILL not in list!');
            }
          },
        )
        .subscribe();
    debugPrint(
        '[EventProvider] 🔧 Subscribed to Realtime updates for event $eventId');
  }

  /// Cancela la suscripción Realtime activa.
  void unsubscribeFromEventUpdates() {
    _eventsChannel?.unsubscribe();
    _eventsChannel = null;
    debugPrint('[EventProvider] 🛑 Unsubscribed from event Realtime updates');
  }

  @override
  void dispose() {
    unsubscribeFromEventUpdates();
    super.dispose();
  }
}
