import 'package:flutter/material.dart';
import '../providers/power_effect_provider.dart';
import 'power_response.dart';

abstract class PowerStrategy {
  String get slug;

  Future<PowerUseResponse> execute({
    required String casterId,
    required String targetId,
    List<RivalInfo>? rivals,
    String? eventId,
    bool isSpectator = false,
  });

  void onActivate(PowerEffectProvider provider);
  void onTick(PowerEffectProvider provider);
  void onDeactivate(PowerEffectProvider provider);
}
