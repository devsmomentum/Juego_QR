import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../admin/models/sponsor.dart';
import '../../admin/services/sponsor_service.dart';

/// Manages a pool of sponsors for an event and provides weighted random
/// selection. Caches the pool to minimize database calls.
class SponsorRotationManager {
  final SponsorService _sponsorService;
  final Random _random = Random();

  List<Sponsor> _pool = [];
  String? _loadedEventId;
  final Set<String> _impressionsSent = {};

  SponsorRotationManager({SponsorService? sponsorService})
      : _sponsorService = sponsorService ?? SponsorService();

  List<Sponsor> get pool => List.unmodifiable(_pool);
  bool get hasSponsors => _pool.isNotEmpty;

  /// Loads the sponsor pool for an event. If the pool is already loaded
  /// for this event, this is a no-op (use [forceReload] to bypass cache).
  Future<void> loadPool(String eventId, {bool forceReload = false}) async {
    if (!forceReload && _loadedEventId == eventId && _pool.isNotEmpty) return;

    bool sponsorsEnabled = true;
    try {
      final eventRow = await Supabase.instance.client
          .from('events')
          .select('sponsors_enabled')
          .eq('id', eventId)
          .maybeSingle();
      sponsorsEnabled = (eventRow?['sponsors_enabled'] as bool?) ?? true;
    } catch (e) {
      debugPrint('⚠️ SponsorRotation: Failed to read sponsors_enabled: $e');
    }

    if (!sponsorsEnabled) {
      _pool = [];
      _loadedEventId = eventId;
      _impressionsSent.clear();
      debugPrint('✅ SponsorRotation: Sponsors disabled for event $eventId');
      return;
    }

    try {
      _pool = await _sponsorService.getSponsorPoolForEvent(eventId);
      _loadedEventId = eventId;
      _impressionsSent.clear();
      debugPrint(
          '✅ SponsorRotation: Loaded ${_pool.length} sponsors for event $eventId');
    } catch (e) {
      debugPrint('⚠️ SponsorRotation: Failed to load pool: $e');
      _pool = [];
    }

    // Fallback: if pool is empty, try the legacy single-sponsor path
    if (_pool.isEmpty) {
      final fallback = await _sponsorService.getSponsorForEvent(eventId);
      if (fallback != null) {
        _pool = [fallback];
        debugPrint(
            '✅ SponsorRotation: Fallback to legacy sponsor: ${fallback.name}');
      } else {
        final global = await _sponsorService.getActiveSponsor();
        if (global != null) {
          _pool = [global];
          debugPrint(
              '✅ SponsorRotation: Fallback to global sponsor: ${global.name}');
        }
      }
    }
  }

  /// Selects a sponsor from the pool using weighted random choice.
  /// Returns null if the pool is empty.
  Sponsor? selectSponsor() {
    if (_pool.isEmpty) return null;
    if (_pool.length == 1) return _pool.first;

    final totalWeight = _pool.fold<int>(0, (sum, s) => sum + s.weight);
    if (totalWeight <= 0) return _pool.first;

    int roll = _random.nextInt(totalWeight);
    for (final sponsor in _pool) {
      roll -= sponsor.weight;
      if (roll < 0) return sponsor;
    }

    // Should never reach here, but defensive fallback
    return _pool.last;
  }

  /// Records an impression for a sponsor. Deduplicates by sponsor ID
  /// so each sponsor is only tracked once per session/load cycle.
  Future<void> trackImpression(Sponsor sponsor, {String? context}) async {
    final key = '${sponsor.id}_${context ?? 'default'}';
    if (_impressionsSent.contains(key)) return;
    _impressionsSent.add(key);

    // Fire-and-forget, never blocks UI
    _sponsorService.recordSponsorEvent(
      sponsorId: sponsor.id,
      type: 'impression',
      eventId: _loadedEventId,
      context: context,
    );
  }

  /// Records a click for a sponsor. No deduplication — each click counts.
  Future<void> trackClick(Sponsor sponsor, {String? context}) async {
    _sponsorService.recordSponsorEvent(
      sponsorId: sponsor.id,
      type: 'click',
      eventId: _loadedEventId,
      context: context,
    );
  }

  /// Clears the cached pool and impression tracking.
  void reset() {
    _pool = [];
    _loadedEventId = null;
    _impressionsSent.clear();
  }
}
