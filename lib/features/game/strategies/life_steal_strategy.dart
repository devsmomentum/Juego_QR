import 'package:flutter/material.dart';
import '../providers/power_effect_provider.dart';
import 'power_strategy.dart';

class LifeStealStrategy implements PowerStrategy {
  @override
  String get slug => 'life_steal';

  @override
  void onActivate(PowerEffectProvider provider) async {
    debugPrint("LifeStealStrategy.onActivate");
    
    final effectId = provider.pendingEffectId;
    final casterId = provider.pendingCasterId;
    final myId = provider.listeningForId;
    final handler = provider.lifeStealVictimHandler;

    if (effectId != null && 
        myId != null && 
        !provider.isEffectProcessed(effectId) && 
        handler != null) {
          
      debugPrint("[DEBUG] 🩸 LIFE_STEAL detectado (Strategy):");
      debugPrint("[DEBUG]    Effect ID: $effectId");
      debugPrint("[DEBUG]    Caster ID: $casterId");

      provider.markEffectAsProcessed(effectId);
      provider.setActiveEffectCasterId(casterId);
      
      await handler(effectId, casterId, myId);
      
      debugPrint("[DEBUG] ✅ LifeStealVictimHandler ejecutado exitosamente (Strategy)");
    }
  }

  @override
  void onTick(PowerEffectProvider provider) {}

  @override
  void onDeactivate(PowerEffectProvider provider) {
    debugPrint("LifeStealStrategy.onDeactivate");
  }
}
