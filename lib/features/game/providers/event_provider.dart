import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/event.dart';
import '../models/clue.dart';
import '../../events/services/event_service.dart';

class EventProvider with ChangeNotifier {
  final EventService _eventService;
  List<GameEvent> _events = [];

  EventProvider({required EventService eventService}) : _eventService = eventService;

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
  Future<void> createCluesBatch(String eventId, List<Map<String, dynamic>> cluesData) async {
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
  Future<void> fetchEvents() async {
    try {
      _events = await _eventService.fetchEvents();
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
}