import 'package:flutter/material.dart';

enum PowerType {
  buff,   // Beneficio propio (Escudo, Vida)
  debuff, // Ataque al rival (Congelar, Pantalla negra)
  utility, // Utilidad (Pista, Radar)
  blind, // Específico para pantalla negra
  freeze, // Específico para congelar
  shield, // Específico para escudo
  timePenalty, // Específico para penalización
  hint, // Específico para pista
  speedBoost // Específico para velocidad
}

class PowerItem {
  final String id;
  final String name;
  final String description;
  final PowerType type;
  final int cost;
  final String icon;
  final Color color;
  final int durationMinutes;

  const PowerItem({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.cost,
    required this.icon,
    this.color = Colors.blue,
    this.durationMinutes = 0,
  });

  // ESTA ES LA LISTA MAESTRA QUE DEBE COINCIDIR CON LA BASE DE DATOS
  static List<PowerItem> getShopItems() {
    return [
      // Catálogo oficial (9 poderes) alineado con Supabase
      const PowerItem(
        id: 'black_screen',
        name: 'Pantalla Negra',
        description: 'Ciega al rival por 5s',
        type: PowerType.blind,
        cost: 100,
        icon: '🕶️',
        color: Colors.black87,
        durationMinutes: 0,
      ),
      const PowerItem(
        id: 'slow_motion',
        name: 'Cámara Lenta',
        description: 'Reduce la velocidad del rival por 120s',
        type: PowerType.debuff,
        cost: 80,
        icon: '🐢',
        color: Colors.orange,
        durationMinutes: 2,
      ),
      const PowerItem(
        id: 'time_penalty',
        name: 'Penalización',
        description: 'Resta 3 minutos de progreso',
        type: PowerType.timePenalty,
        cost: 60,
        icon: '⏱️',
        color: Colors.redAccent,
        durationMinutes: 0,
      ),
      const PowerItem(
        id: 'hint',
        name: 'Pista Extra',
        description: 'Revela información clave',
        type: PowerType.hint,
        cost: 30,
        icon: '💡',
        color: Colors.amber,
        durationMinutes: 0,
      ),
      const PowerItem(
        id: 'shield_pro',
        name: 'Escudo Pro',
        description: 'Bloquea sabotajes por 600s',
        type: PowerType.shield,
        cost: 100,
        icon: '🛡️',
        color: Colors.deepPurple,
        durationMinutes: 10,
      ),
      const PowerItem(
        id: 'cure_all',
        name: 'Cura Total',
        description: 'Limpia todos los efectos activos',
        type: PowerType.buff,
        cost: 40,
        icon: '💊',
        color: Colors.teal,
        durationMinutes: 0,
      ),
      const PowerItem(
        id: 'return',
        name: 'Devolución',
        description: 'Devuelve el ataque al origen',
        type: PowerType.utility,
        cost: 60,
        icon: '↩️',
        color: Colors.purple,
        durationMinutes: 0,
      ),
      const PowerItem(
        id: 'freeze',
        name: 'Congelar',
        description: 'Congela al rival por 120s',
        type: PowerType.freeze,
        cost: 50,
        icon: '❄️',
        color: Colors.cyan,
        durationMinutes: 2,
      ),
      const PowerItem(
        id: 'shield',
        name: 'Escudo',
        description: 'Bloquea sabotajes por 300s',
        type: PowerType.shield,
        cost: 75,
        icon: '🛡️',
        color: Colors.indigo,
        durationMinutes: 5,
      ),
    ];
  }
}