import 'package:flutter/material.dart';

enum PowerType {
  buff, // Beneficio propio (Escudo, Vida)
  debuff, // Ataque al rival (Congelar, Pantalla negra)
  utility, // Utilidad (Pista, Radar)
  blind, // Específico para pantalla negra
  freeze, // Específico para congelar
  blur, // Específico para difuminar pantalla
  shield, // Específico para escudo
  lifeSteal, // Específico para robar vida
  stealth, // Específico para invisibilidad
}

/// Extension to classify powers as Attack or Defense for ISP filtering.
extension PowerTypeClassification on PowerType {
  /// Returns true for offensive powers (used against rivals)
  bool get isAttack {
    switch (this) {
      case PowerType.debuff:
      case PowerType.blind:
      case PowerType.freeze:
      case PowerType.blur:
      case PowerType.lifeSteal:
        return true;
      default:
        return false;
    }
  }

  /// Returns true for defensive/buff powers (used on self)
  bool get isDefense {
    switch (this) {
      case PowerType.buff:
      case PowerType.shield:
      case PowerType.utility:
      case PowerType.stealth:
        return true;
      default:
        return false;
    }
  }
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
  final int durationSeconds;

  const PowerItem({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.cost,
    required this.icon,
    this.color = Colors.blue,
    this.durationMinutes = 0,
    this.durationSeconds = 0,
  });

  PowerItem copyWith({
    String? id,
    String? name,
    String? description,
    PowerType? type,
    int? cost,
    String? icon,
    Color? color,
    int? durationMinutes,
    int? durationSeconds,
  }) {
    return PowerItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      cost: cost ?? this.cost,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }

  // ESTA ES LA LISTA MAESTRA QUE DEBE COINCIDIR CON LA BASE DE DATOS
  static List<PowerItem> getShopItems() {
    return [
      // Catálogo oficial (6 poderes) alineado con Supabase
      const PowerItem(
        id: 'black_screen',
        name: 'Pantalla Negra',
        description: 'Ciega al rival por 25s',
        type: PowerType.blind,
        cost: 75, // Tier 2: Blur/Black Screen
        icon: '🕶️',
        color: Colors.black87,
        durationMinutes: 0,
      ),

      const PowerItem(
        id: 'blur_screen',
        name: 'Pantalla Borrosa',
        description: 'Aplica un efecto borroso sobre la pantalla de todos los rivales.',
        type: PowerType.blur,
        cost: 75, // Tier 2: Blur/Black Screen
        icon: '🌫️',
        color: Colors.blueGrey,
        durationMinutes: 0,
      ),

      const PowerItem(
        id: 'extra_life',
        name: 'Vida',
        description: 'Recupera una vida perdida',
        type: PowerType.buff,
        cost: 40, // Tier 1: Extra Life
        icon: '❤️',
        color: Colors.red,
        durationMinutes: 0,
      ),

      const PowerItem(
        id: 'return',
        name: 'Devolución',
        description: 'Devuelve el ataque al origen',
        type: PowerType.buff, // CAMBIADO: De utility a buff
        cost: 90,
        icon: '↩️',
        color: Colors.purple,
        durationMinutes: 0,
      ),
      const PowerItem(
        id: 'freeze',
        name: 'Congelar',
        description: 'Congela al rival por 30s',
        type: PowerType.freeze,
        cost: 120, // Tier 3: Freeze/Life Steal
        icon: '❄️',
        color: Colors.cyan,
        durationMinutes: 1,
      ),
      const PowerItem(
        id: 'shield',
        name: 'Escudo',
        description: 'Bloquea sabotajes por 120s',
        type: PowerType.shield,
        cost: 40, // Tier 1: Shield/Invisibility
        icon: '🛡️',
        color: Colors.indigo,
        durationMinutes: 2,
      ),
      const PowerItem(
        id: 'life_steal',
        name: 'Robo de Vida',
        description: 'Roba una vida a un rival',
        type: PowerType.lifeSteal,
        cost: 120, // Tier 3: Freeze/Life Steal
        icon: '🧛',
        color: Colors.redAccent,
        durationMinutes: 0,
      ),
      const PowerItem(
        id: 'invisibility',
        name: 'Invisibilidad',
        description: 'Te vuelve invisible por 45s',
        type: PowerType.stealth,
        cost: 40, // Tier 1: Shield/Invisibility
        icon: '👻',
        color: Colors.grey,
        durationMinutes: 0,
      ),
    ];
  }
}
