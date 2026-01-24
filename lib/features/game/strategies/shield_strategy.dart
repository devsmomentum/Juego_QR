import 'package:flutter/material.dart';
import '../providers/power_effect_provider.dart';
import 'power_strategy.dart';

class ShieldStrategy implements PowerStrategy {
  @override
  String get slug => 'shield';

  @override
  void onActivate(PowerEffectProvider provider) {
    debugPrint("ShieldStrategy.onActivate");
    // provider.setShielded llama a setShieldState y limpia.
    // Para evitar recursion si setShielded llama a la estrategia, debemos llamar a setShieldState directamente 
    // o el caller de strategy debe ser distinto.
    // La lógica original 'setShielded' tiene side effects (clearEffect).
    // Si movemos esa lógica aquí:
    
    // provider.setShieldState(true);
    // provider.clearActiveEffect();
    
    // PERO setShielded es público y usado por la UI.
    // Modificaremos setShielded para usar la estrategia.
    // Entonces aquí solo ponemos la lógica interna.
    
    provider.setShieldState(true);
    provider.clearActiveEffect();
  }

  @override
  void onTick(PowerEffectProvider provider) {
    // Escudo no tiene tick específico, es un estado
  }

  @override
  void onDeactivate(PowerEffectProvider provider) {
    debugPrint("ShieldStrategy.onDeactivate");
    provider.setShieldState(false);
    provider.notifyListeners(); // Originalmente en el else de setShielded
  }
}
