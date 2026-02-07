import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/power_effect_provider.dart';
import 'power_strategy.dart';
import 'power_response.dart';

class BlurScreenStrategy implements PowerStrategy {
  final SupabaseClient _supabase;

  BlurScreenStrategy(this._supabase);

  @override
  String get slug => 'blur_screen';

  @override
  Future<PowerUseResponse> execute({
    required String casterId,
    required String targetId,
    List<RivalInfo>? rivals,
    String? eventId,
    bool isSpectator = false,
  }) async {
    // BlurScreen logic via RPC (RPC handles broadcast)
    final response = await _supabase.rpc('use_power_mechanic', params: {
      'p_caster_id': casterId,
      'p_target_id': casterId, // Broadcast power targets self/all via RPC logic
      'p_power_slug': slug,
    });
    
    return PowerUseResponse.fromRpcResponse(response);
  }

  @override
  void onActivate(PowerEffectProvider provider) {
    debugPrint("BlurScreenStrategy.onActivate");
    // UI effect handled by provider observing slug
  }

  @override
  void onTick(PowerEffectProvider provider) {}

  @override
  void onDeactivate(PowerEffectProvider provider) {
     debugPrint("BlurScreenStrategy.onDeactivate");
  }
}
