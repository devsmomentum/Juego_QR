import 'power_strategy.dart';
import 'shield_strategy.dart';
import 'invisibility_strategy.dart';
import 'freeze_strategy.dart';
import 'life_steal_strategy.dart';

class PowerStrategyFactory {
  static final Map<String, PowerStrategy> _strategies = {
    'shield': ShieldStrategy(),
    'invisibility': InvisibilityStrategy(),
    'freeze': FreezeStrategy(),
    'life_steal': LifeStealStrategy(),
  };

  static PowerStrategy? get(String slug) {
    return _strategies[slug];
  }
}
