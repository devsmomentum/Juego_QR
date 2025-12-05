import 'package:flutter/material.dart';

class GameRequest {
  final String id;
  final String playerId;
  final String status;

  GameRequest({
    required this.id,
    required this.playerId,
    required this.status,
  });

  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  Color get statusColor {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String get statusText {
    switch (status) {
      case 'approved':
        return 'Aprobado';
      case 'rejected':
        return 'Rechazado';
      default:
        return 'Pendiente';
    }
  }
}
