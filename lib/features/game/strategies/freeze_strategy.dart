import 'package:flutter/material.dart';
import '../providers/power_effect_provider.dart';
import 'power_strategy.dart';

class FreezeStrategy implements PowerStrategy {
  @override
  String get slug => 'freeze';

  @override
  void onActivate(PowerEffectProvider provider) {
    debugPrint("FreezeStrategy.onActivate");
    // Freeze logic (Overlay) is handled by UI observing the slug.
  }

  @override
  void onTick(PowerEffectProvider provider) {}

  @override
  void onDeactivate(PowerEffectProvider provider) {
    debugPrint("FreezeStrategy.onDeactivate");
  }
}
