import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/services/app_config_service.dart';

/// Provider that exposes the next automated online event time based on the
/// `online_automation_config` stored in `app_config`.
///
/// Supports two modes:
///   - **automatic**: next event = last event + interval_minutes + pending_wait_minutes.
///     Since we don't know the last event time here, [nextEventTime] is null and
///     the UI should rely on existing pending events from EventProvider.
///   - **scheduled**: next event = next occurrence in [scheduledHours] (UTC).
///     This is fully computable client-side.
class OnlineScheduleProvider with ChangeNotifier {
  final AppConfigService _configService;

  Map<String, dynamic> _config = {};
  Timer? _refreshTimer;

  OnlineScheduleProvider({required AppConfigService configService})
      : _configService = configService;

  // ── Public getters ──────────────────────────────────────────────────────────

  bool get isEnabled => _config['enabled'] == true;

  /// "automatic" or "scheduled". Defaults to "automatic".
  String get mode => (_config['mode'] as String?) ?? 'automatic';

  /// List of VET (UTC-4) hour strings, e.g. ["10:00", "16:00", "22:00"].
  List<String> get scheduledHours {
    final raw = _config['scheduled_hours'];
    if (raw is List) return List<String>.from(raw);
    return [];
  }

  int get intervalMinutes => (_config['interval_minutes'] as num?)?.toInt() ?? 60;
  int get pendingWaitMinutes => (_config['pending_wait_minutes'] as num?)?.toInt() ?? 5;

  /// The full raw config map (for admin screens).
  Map<String, dynamic> get config => _config;

  /// Venezuela Time offset: UTC-4 (no DST).
  static const int _vetOffsetHours = -4;

  /// Computes the next event start time based on the active mode.
  ///
  /// - **scheduled**: returns the next scheduled hour (converted from VET to local).
  /// - **automatic**: returns `null` (interval-based; depends on server state).
  DateTime? get nextEventTime {
    if (!isEnabled) return null;
    if (mode != 'scheduled' || scheduledHours.isEmpty) return null;

    final nowUtc = DateTime.now().toUtc();

    final todaySlots = <DateTime>[];
    for (final hourStr in scheduledHours) {
      final parts = hourStr.split(':');
      if (parts.length < 2) continue;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) continue;

      // Hours are in VET (UTC-4), convert to UTC for comparison
      final utcHour = h - _vetOffsetHours; // e.g. 15 VET → 19 UTC
      todaySlots.add(DateTime.utc(
        nowUtc.year, nowUtc.month, nowUtc.day, utcHour, m,
      ));
    }
    todaySlots.sort();

    // Find the first slot still in the future
    for (final slot in todaySlots) {
      if (slot.isAfter(nowUtc)) return slot.toLocal();
    }

    // All today's slots passed → first slot tomorrow
    if (todaySlots.isNotEmpty) {
      return todaySlots.first.add(const Duration(days: 1)).toLocal();
    }

    return null;
  }

  /// Time remaining until [nextEventTime], or null.
  Duration? get timeUntilNextEvent {
    final target = nextEventTime;
    if (target == null) return null;
    final diff = target.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  /// Loads config from Supabase and starts a periodic refresh (every 60 s).
  Future<void> init() async {
    await _fetchConfig();
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _fetchConfig(),
    );
  }

  Future<void> _fetchConfig() async {
    try {
      final settings = await _configService.getAutoEventSettings();
      _config = settings;
      notifyListeners();
    } catch (e) {
      debugPrint('[OnlineScheduleProvider] Error fetching config: $e');
    }
  }

  /// Call when you need a fresh snapshot (e.g. after admin saves).
  Future<void> refresh() => _fetchConfig();

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
