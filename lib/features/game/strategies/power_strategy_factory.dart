import 'package:supabase_flutter/supabase_flutter.dart';
import 'power_strategy.dart';
import 'shield_strategy.dart';
import 'invisibility_strategy.dart';
import 'freeze_strategy.dart';
import 'life_steal_strategy.dart';
import 'blur_screen_strategy.dart';
import 'return_strategy.dart';
import 'black_screen_strategy.dart';
import 'generic_power_strategy.dart';

class PowerStrategyFactory {
  final SupabaseClient _supabase;
  late final Map<String, PowerStrategy> _strategies;

  PowerStrategyFactory(this._supabase) {
    _strategies = {
      'shield': ShieldStrategy(_supabase),
      'invisibility': InvisibilityStrategy(_supabase),
      'freeze': FreezeStrategy(_supabase),
      'life_steal': LifeStealStrategy(_supabase),
      'blur_screen': BlurScreenStrategy(_supabase),
      'return': ReturnStrategy(_supabase),
      'black_screen': BlackScreenStrategy(_supabase),
    };
  }

  PowerStrategy get(String slug) {
    return _strategies[slug] ?? GenericPowerStrategy(_supabase, slug);
  }
}
