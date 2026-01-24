import 'package:flutter/material.dart';
import '../providers/power_effect_provider.dart';
import 'power_strategy.dart';

class InvisibilityStrategy implements PowerStrategy {
  @override
  String get slug => 'invisibility';

  @override
  void onActivate(PowerEffectProvider provider) {
    debugPrint("InvisibilityStrategy.onActivate");
    // La lógica de invisibilidad es principalmente estado y preservación
    // El provider ya maneja _activePowerSlug asignado en el flujo principal,
    // pero si hay lógica adicional específica, iría aquí.
  }

  @override
  void onTick(PowerEffectProvider provider) {}

  @override
  void onDeactivate(PowerEffectProvider provider) {
     debugPrint("InvisibilityStrategy.onDeactivate");
  }
}
