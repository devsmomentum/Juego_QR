import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/app_config_service.dart';
import '../../../shared/widgets/coin_image.dart';
import '../../mall/models/power_item.dart';
import '../../game/providers/online_schedule_provider.dart';

class OnlineAutomationScreen extends StatefulWidget {
  const OnlineAutomationScreen({super.key});

  @override
  State<OnlineAutomationScreen> createState() => _OnlineAutomationScreenState();
}

class _OnlineAutomationScreenState extends State<OnlineAutomationScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _config = {};
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    final configService = AppConfigService(supabaseClient: _supabase);
    final settings = await configService.getAutoEventSettings();
    setState(() {
      _config = settings;
      _isLoading = false;
    });
  }

  Future<void> _saveConfig() async {
    setState(() => _isLoading = true);
    try {
      final configService = AppConfigService(supabaseClient: _supabase);
      final success = await configService.updateAutoEventSettings(_config);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(success ? 'Configuración guardada' : 'Error al guardar'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving config: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _triggerManual() async {
    setState(() => _isLoading = true);
    try {
      // Refresh session to ensure a valid JWT before calling the edge function
      await _supabase.auth.refreshSession();

      final response = await _supabase.functions.invoke(
        'automate-online-events',
        body: {'trigger': 'manual'},
      );

      final data = response.data;
      final bool isSuccess =
          response.status == 200 && (data is Map && data['success'] == true);

      if (mounted) {
        final cluesCount = data is Map ? data['cluesSaved'] ?? 0 : 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isSuccess
                ? 'Evento generado con $cluesCount minijuegos'
                : 'Error: ${data?['error'] ?? 'Fallo en la generación'}'),
            backgroundColor: isSuccess ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error de red: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: [
                  _buildToggleCard(),
                  const SizedBox(height: 20),
                  _buildModeCard(),
                  const SizedBox(height: 20),
                  _buildSettingsCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: const Text(
                'Automatización Online',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const Text(
              'Configura la creación automática de competencias.',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: _triggerManual,
          icon: const Icon(Icons.flash_on),
          label: const Text('Generar Ahora'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.secondaryPink,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleCard() {
    final bool isEnabled = _config['enabled'] == true;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: isEnabled ? AppTheme.primaryPurple : Colors.white10),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome,
              color: isEnabled ? AppTheme.primaryPurple : Colors.white24,
              size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    isEnabled
                        ? 'Automatización ACTIVA'
                        : 'Automatización DESACTIVADA',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const Text(
                  'Si está activa, el sistema generará eventos según el intervalo definido.',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),
          ),
          Switch(
            value: isEnabled,
            onChanged: (val) {
              setState(() => _config['enabled'] = val);
              _saveConfig();
            },
            activeColor: AppTheme.primaryPurple,
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard() {
    final String mode = (_config['mode'] as String?) ?? 'automatic';
    final List<String> hours = (_config['scheduled_hours'] is List)
        ? List<String>.from(_config['scheduled_hours'] as List)
        : [];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Modo de Creación',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Solo un modo puede estar activo. "Automático" usa el intervalo; "Programado" usa horarios fijos (hora Venezuela).',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ModeButton(
                  label: 'Automático',
                  icon: Icons.autorenew,
                  selected: mode == 'automatic',
                  onTap: () {
                    setState(() => _config['mode'] = 'automatic');
                    _saveConfig();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ModeButton(
                  label: 'Programado',
                  icon: Icons.schedule,
                  selected: mode == 'scheduled',
                  onTap: () {
                    setState(() => _config['mode'] = 'scheduled');
                    _saveConfig();
                  },
                ),
              ),
            ],
          ),
          if (mode == 'scheduled') ...[
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Horarios programados (VEN)',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle,
                      color: AppTheme.primaryPurple),
                  onPressed: () => _addScheduledHour(hours),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (hours.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No hay horarios configurados. Presiona + para agregar.',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ),
            ...hours.asMap().entries.map((entry) {
              final idx = entry.key;
              final hour = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time,
                          color: AppTheme.primaryPurple, size: 20),
                      const SizedBox(width: 12),
                      Text(hour,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontFamily: 'Orbitron',
                              fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent, size: 20),
                        onPressed: () {
                          setState(() {
                            hours.removeAt(idx);
                            _config['scheduled_hours'] = hours;
                          });
                          _saveConfig();
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            _buildNextEventPreview(),
          ],
        ],
      ),
    );
  }

  Future<void> _addScheduledHour(List<String> hours) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 12, minute: 0),
      helpText: 'Selecciona hora Venezuela',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryPurple,
              surface: Color(0xFF1A1A1D),
            ),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
        );
      },
    );
    if (picked != null) {
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      if (!hours.contains(formatted)) {
        setState(() {
          hours.add(formatted);
          hours.sort();
          _config['scheduled_hours'] = hours;
        });
        _saveConfig();
      }
    }
  }

  Widget _buildNextEventPreview() {
    final hours = (_config['scheduled_hours'] is List)
        ? List<String>.from(_config['scheduled_hours'] as List)
        : <String>[];
    if (hours.isEmpty) return const SizedBox.shrink();

    // VET = UTC-4 (Venezuela, no DST)
    const vetOffsetHours = -4;
    final nowUtc = DateTime.now().toUtc();
    DateTime? nextSlot;

    final todaySlots = <DateTime>[];
    for (final h in hours) {
      final parts = h.split(':');
      if (parts.length < 2) continue;
      final hr = int.tryParse(parts[0]);
      final mn = int.tryParse(parts[1]);
      if (hr == null || mn == null) continue;
      // Hours stored in VET → convert to UTC for comparison
      final utcHour = hr - vetOffsetHours;
      todaySlots
          .add(DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day, utcHour, mn));
    }
    todaySlots.sort();

    for (final slot in todaySlots) {
      if (slot.isAfter(nowUtc)) {
        nextSlot = slot;
        break;
      }
    }
    nextSlot ??=
        todaySlots.isNotEmpty ? todaySlots.first.add(const Duration(days: 1)) : null;

    if (nextSlot == null) return const SizedBox.shrink();

    final local = nextSlot.toLocal();
    final diff = nextSlot.difference(nowUtc);
    final hh = diff.inHours;
    final mm = diff.inMinutes % 60;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_available,
              color: AppTheme.primaryPurple, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Próximo evento: ${DateFormat('HH:mm').format(local)} (hora VEN) — en ${hh}h ${mm}m',
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard() {
    final String mode = (_config['mode'] as String?) ?? 'automatic';
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Parámetros de Generación',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ),
              IconButton(
                  onPressed: _saveConfig,
                  icon: const Icon(Icons.save, color: AppTheme.primaryPurple)),
            ],
          ),
          const SizedBox(height: 24),
          // Show interval slider only in automatic mode
          if (mode == 'automatic')
            _buildSlider('Intervalo (minutos)', 'interval_minutes', 10, 1440, 1),
          _buildSlider('Copa Mín. Jugadores', 'min_players', 5, 20, 1),
          _buildSlider('Copa Máx. Jugadores', 'max_players', 20, 60, 1),
          _buildSlider('Cant. Mín. Minijuegos', 'min_games', 2, 6, 1),
          _buildSlider('Cant. Máx. Minijuegos', 'max_games', 6, 15, 1),
          _buildSlider('Entry Fee Mín [COIN]', 'min_fee', 0, 50, 5),
          _buildSlider('Entry Fee Máx [COIN]', 'max_fee', 0, 300, 5),
          const Padding(
            padding: EdgeInsets.only(left: 16.0, bottom: 20.0),
            child: Text(
              "💡 Si Mín != Máx, el precio de entrada será aleatorio entre ambos.",
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontStyle: FontStyle.italic),
            ),
          ),
          const Divider(color: Colors.white12, height: 32),
          const Text(
            'Inicio de Sala (Pending → Active)',
            style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          _buildSlider('Espera antes de iniciar (min)', 'pending_wait_minutes',
              1, 120, 1),
          _buildSlider(
              'Jugadores mín. para iniciar', 'min_players_to_start', 2, 20, 1),
          const Divider(color: Colors.white12, height: 32),
          _buildPriceSection(
            'player_prices',
            '🎮 Precios Tienda (Jugadores)',
            AppTheme.primaryPurple,
          ),
          const Divider(color: Colors.white12, height: 32),
          _buildPriceSection(
            'spectator_prices',
            '👁 Precios Tienda (Espectadores)',
            AppTheme.accentGold,
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSection(String configKey, String title, Color color) {
    final Map<String, dynamic> priceMap = (_config[configKey] is Map)
        ? Map<String, dynamic>.from(_config[configKey] as Map)
        : {};
    final powers = PowerItem.getShopItems();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5)),
        const SizedBox(height: 12),
        ...powers.map((power) {
          final currentPrice = priceMap.containsKey(power.id)
              ? (priceMap[power.id] as num).toInt()
              : power.cost;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(power.icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(power.name,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13))),
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    key: ValueKey('$configKey-${power.id}'),
                    initialValue: currentPrice.toString(),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 5),
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none),
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (val) {
                      final newCost = int.tryParse(val);
                      if (newCost != null) {
                        final current = (_config[configKey] is Map)
                            ? Map<String, dynamic>.from(
                                _config[configKey] as Map)
                            : <String, dynamic>{};
                        current[power.id] = newCost;
                        _config[configKey] = current;
                      }
                    },
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSlider(
      String label, String key, double min, double max, double divisions) {
    final value = (_config[key] as num?)?.toDouble() ?? min;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(label.replaceAll('[COIN]', '').trim(),
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 14)),
                if (label.contains('[COIN]')) ...[
                  const SizedBox(width: 4),
                  const CoinImage(size: 14),
                ],
              ],
            ),
            Text(value.toInt().toString(),
                style: const TextStyle(
                    color: AppTheme.primaryPurple,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: ((max - min) / (divisions)).toInt(),
          activeColor: AppTheme.primaryPurple,
          inactiveColor: Colors.white10,
          onChanged: (val) => setState(() => _config[key] = val.toInt()),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryPurple.withOpacity(0.15)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppTheme.primaryPurple
                : Colors.white.withOpacity(0.1),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? AppTheme.primaryPurple : Colors.white38,
                size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white54,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
