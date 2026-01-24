import 'package:flutter/material.dart';
import '../providers/power_effect_provider.dart';

abstract class PowerStrategy {
  String get slug;

  void onActivate(PowerEffectProvider provider);
  void onTick(PowerEffectProvider provider);
  void onDeactivate(PowerEffectProvider provider);
}
