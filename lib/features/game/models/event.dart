import 'package:latlong2/latlong.dart';

class GameEvent {
  final String id;
  final String title;
  final String description; // Esta sería la "pista para solucionar el puzzle"
  final String locationName;
  final double latitude;
  final double longitude;
  final DateTime date;
  final String createdByAdminId;
  final String imageUrl;
  final String clue;        // <--- CAMBIO: Ahora es obligatorio (Pista de victoria)
  final int maxParticipants;
  final String pin;
  final String status;      // Status: 'pending', 'active', 'completed'
  final DateTime? completedAt;
  final String? winnerId;

  GameEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.date,
    required this.createdByAdminId,
    required this.clue,     // <--- CAMBIO: Ahora es 'required'
    this.imageUrl = '',
    this.maxParticipants = 0,
    this.pin = '',
    this.status = 'pending',
    this.completedAt,
    this.winnerId,
  });

  LatLng get location => LatLng(latitude, longitude);
  
  bool get isCompleted => status == 'completed';
  bool get isActive => status == 'active';
  bool get isPending => status == 'pending';
}