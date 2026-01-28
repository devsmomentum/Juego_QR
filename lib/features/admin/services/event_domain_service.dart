import 'dart:math';
import 'package:uuid/uuid.dart';
import '../../game/models/event.dart';
import '../../mall/models/mall_store.dart';

/// Pure Dart domain service for event business rules.
/// 
/// This service encapsulates:
/// - PIN generation logic (alphanumeric for online, numeric for on-site)
/// - Default online store creation
/// - Clue sanitization for online mode
/// - Event configuration with mode-specific defaults
class EventDomainService {
  
  /// Generates a PIN based on the event mode.
  /// 
  /// - Online Mode: 6 alphanumeric characters (excluding ambiguous chars like 0, O, 1, I)
  /// - On-Site Mode: 6 numeric digits
  static String generatePin({bool isOnline = false}) {
     final random = Random();
     if (isOnline) {
       // Online Mode: Alphanumeric (excluding ambiguous characters)
       const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
       return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
     } else {
       // Presencial Mode: Numeric
       return (100000 + random.nextInt(900000)).toString();
     }
  }

  /// Creates a default MallStore for online events.
  /// 
  /// Online events automatically get a pre-configured store with
  /// standard name and description.
  static MallStore createDefaultOnlineStore(String eventId) {
     return MallStore(
       id: const Uuid().v4(),
       eventId: eventId,
       name: 'Tienda Online Oficial',
       description: 'Tienda oficial para este evento online.',
       imageUrl: '', 
       qrCodeData: 'ONLINE_STORE_$eventId',
       products: [], 
     );
  }

  /// Sanitizes clue data for online mode.
  /// 
  /// Ensures all required fields have valid defaults:
  /// - description: "Pista Online" if empty
  /// - hint: "Pista Online" if empty
  /// - latitude/longitude: 0.0 if null
  static void sanitizeCluesForOnline(List<Map<String, dynamic>> clues) {
     for (var clue in clues) {
        if (clue['description'] == null || clue['description'].toString().trim().isEmpty) {
            clue['description'] = "Pista Online";
        }
        if (clue['hint'] == null || clue['hint'].toString().trim().isEmpty) {
            clue['hint'] = "Pista Online";
        }
        if (clue['latitude'] == null) clue['latitude'] = 0.0;
        if (clue['longitude'] == null) clue['longitude'] = 0.0;
     }
  }

  /// Creates a fully configured GameEvent with mode-specific defaults.
  /// 
  /// Handles the following mode-specific logic:
  /// - Online: locationName='Online', lat/long=0.0, auto-generates PIN
  /// - On-Site: Uses provided location and PIN
  static GameEvent createConfiguredEvent({
    required String id,
    required String title,
    required String description,
    required String? locationName,
    required double? latitude,
    required double? longitude,
    required DateTime date,
    required String clue,
    required int maxParticipants,
    required String pin,
    required String eventType,
    required String imageFileName,
  }) {
    final isOnline = eventType == 'online';
    final finalPin = isOnline ? generatePin(isOnline: true) : pin;
    
    return GameEvent(
      id: id,
      title: title,
      description: description,
      locationName: isOnline ? 'Online' : (locationName ?? 'Unknown'),
      latitude: isOnline ? 0.0 : latitude!,
      longitude: isOnline ? 0.0 : longitude!,
      date: date,
      createdByAdminId: 'admin_1',
      imageUrl: imageFileName,
      clue: clue,
      maxParticipants: maxParticipants,
      pin: finalPin,
      type: eventType,
    );
  }
}
