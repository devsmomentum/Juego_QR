import 'package:flutter/material.dart';

class Event {
  final String id;
  final String title;
  final String description;
  final String location;
  final DateTime date;
  final String createdByAdminId;

  // Nuevas propiedades del evento/competencia:
  final String imageUrl; // URL donde se guarda la imagen del evento
  final String clue;     // La pista que lleva al evento
  final int maxParticipants; // Capacidad máxima

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.date,
    required this.createdByAdminId,
    required this.imageUrl, // AÑADIDO
    required this.clue,     // AÑADIDO
    required this.maxParticipants, // AÑADIDO
  });

  // Método toMap actualizado para incluir las nuevas propiedades
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'location': location,
      'date': date.toIso8601String(),
      'createdByAdminId': createdByAdminId,
      'imageUrl': imageUrl,
      'clue': clue,
      'maxParticipants': maxParticipants,
    };
  }
}