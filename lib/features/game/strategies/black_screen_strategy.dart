import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/power_effect_provider.dart';
import 'power_strategy.dart';
import 'power_response.dart';
import 'spectator_helper.dart';

class BlackScreenStrategy implements PowerStrategy {
  final SupabaseClient _supabase;

  BlackScreenStrategy(this._supabase);

  @override
  String get slug => 'black_screen';

  @override
  Future<PowerUseResponse> execute({
    required String casterId,
    required String targetId,
    List<RivalInfo>? rivals,
    String? eventId,
    bool isSpectator = false,
  }) async {
    if (isSpectator) {
      return SpectatorHelper.executeSpectatorPower(
        supabase: _supabase,
        casterId: casterId,
        targetId: targetId,
        powerSlug: slug,
        eventId: eventId,
      );
    }

    final response = await _supabase.rpc('use_power_mechanic', params: {
      'p_caster_id': casterId,
      'p_target_id': targetId,
      'p_power_slug': slug,
    });
    return PowerUseResponse.fromRpcResponse(response);
  }

  @override
  void onActivate(PowerEffectProvider provider) {
    debugPrint("BlackScreenStrategy.onActivate");
  }

  @override
  void onTick(PowerEffectProvider provider) {}

  @override
  void onDeactivate(PowerEffectProvider provider) {
    debugPrint("BlackScreenStrategy.onDeactivate");
  }
}
