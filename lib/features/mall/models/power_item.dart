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
  static Map<String, int> _dbCosts = {};

  static void updateGlobalCosts(Map<String, int> costs) {
    _dbCosts = costs;
  }

  static List<PowerItem> getShopItems() {
    int getCost(String id, int defaultCost) {
      return _dbCosts[id] ?? _dbCosts[id.trim().toLowerCase()] ?? defaultCost;
    }

    return [
      // Catálogo oficial (6 poderes) alineado con Supabase
      PowerItem(
        id: 'black_screen',
        name: 'Pantalla Negra',
        description: 'Ciega al rival por 25s',
        type: PowerType.blind,
        cost: getCost('black_screen', 75), // Tier 2: Blur/Black Screen
        icon: '🕶️',
        color: Colors.black87,
        durationMinutes: 0,
      ),

      PowerItem(
        id: 'blur_screen',
        name: 'Pantalla Borrosa',
        description:
            'Aplica un efecto borroso sobre la pantalla de todos los rivales.',
        type: PowerType.blur,
        cost: getCost('blur_screen', 300), // Default 300 or DB override
        icon: '🌫️',
        color: Colors.blueGrey,
        durationMinutes: 0,
      ),

      PowerItem(
        id: 'extra_life',
        name: 'Vida',
        description: 'Recupera una vida perdida',
        type: PowerType.buff,
        cost: getCost('extra_life', 40), // Tier 1: Extra Life
        icon: '❤️',
        color: Colors.red,
        durationMinutes: 0,
      ),

      PowerItem(
        id: 'return',
        name: 'Devolución',
        description: 'Devuelve el ataque al origen',
        type: PowerType.buff, // CAMBIADO: De utility a buff
        cost: getCost('return', 90),
        icon: '↩️',
        color: Colors.purple,
        durationMinutes: 0,
      ),
      PowerItem(
        id: 'freeze',
        name: 'Congelar',
        description: 'Congela al rival por 30s',
        type: PowerType.freeze,
        cost: getCost('freeze', 120), // Tier 3: Freeze/Life Steal
        icon: '❄️',
        color: Colors.cyan,
        durationMinutes: 1,
      ),
      PowerItem(
        id: 'shield',
        name: 'Escudo',
        description: 'Bloquea sabotajes por 120s',
        type: PowerType.shield,
        cost: getCost('shield', 40), // Tier 1: Shield/Invisibility
        icon: '🛡️',
        color: Colors.indigo,
        durationMinutes: 2,
      ),
      PowerItem(
        id: 'life_steal',
        name: 'Robo de Vida',
        description: 'Roba una vida a un rival',
        type: PowerType.lifeSteal,
        cost: getCost('life_steal', 120), // Tier 3: Freeze/Life Steal
        icon: '🧛',
        color: Colors.redAccent,
        durationMinutes: 0,
      ),
      PowerItem(
        id: 'invisibility',
        name: 'Invisibilidad',
        description: 'Te vuelve invisible por 45s',
        type: PowerType.stealth,
        cost: getCost('invisibility', 40), // Tier 1: Shield/Invisibility
        icon: '👻',
        color: Colors.grey,
        durationMinutes: 0,
      ),
    ];
  }

  /// Busca un item por su ID/Slug de forma robusta y con normalización.
  static PowerItem fromId(String id, {List<PowerItem>? customItems}) {
    final List<PowerItem> catalog = customItems ?? getShopItems();
    final String normalized = id.trim().toLowerCase();

    // 1. Intento por ID exacto (ignoring case/trim)
    for (var item in catalog) {
      if (item.id.trim().toLowerCase() == normalized) return item;
    }

    // 2. Mapeo de sinónimos comunes (Para IDs de DB viejos o inconsistentes)
    if (normalized.contains('shield')) {
      return catalog.firstWhere((p) => p.id == 'shield',
          orElse: () => _unknownFallback(id));
    }
    if (normalized.contains('life') || normalized.contains('vida')) {
      return catalog.firstWhere((p) => p.id == 'extra_life',
          orElse: () => _unknownFallback(id));
    }
    if (normalized.contains('black') || normalized.contains('negra')) {
      return catalog.firstWhere((p) => p.id == 'black_screen',
          orElse: () => _unknownFallback(id));
    }
    if (normalized.contains('blur') || normalized.contains('borros')) {
      return catalog.firstWhere((p) => p.id == 'blur_screen',
          orElse: () => _unknownFallback(id));
    }
    if (normalized.contains('freeze') || normalized.contains('hielo')) {
      return catalog.firstWhere((p) => p.id == 'freeze',
          orElse: () => _unknownFallback(id));
    }
    if (normalized.contains('return') || normalized.contains('devolu')) {
      return catalog.firstWhere((p) => p.id == 'return',
          orElse: () => _unknownFallback(id));
    }

    // 3. Fallback final
    return _unknownFallback(id);
  }

  static PowerItem _unknownFallback(String id) {
    return PowerItem(
      id: id,
      name: 'Poder Misterioso',
      description: 'Consultando registro...',
      type: PowerType.buff,
      cost: 0,
      icon: '⚡',
      color: Colors.grey,
    );
  }
}
