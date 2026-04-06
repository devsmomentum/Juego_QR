import 'package:flutter/material.dart';
import '../../../../shared/models/player.dart';
import '../../../../shared/extensions/player_extensions.dart';
import '../models/race_view_data.dart';
import '../models/power_effect.dart';
import '../models/i_targetable.dart';
import '../models/progress_group.dart';

/// Maximum number of participants to display in the race track
const int kMaxRaceParticipants = 10;

/// Number of players to show ahead of the current user
const int kPlayersAhead = 4;

/// Number of players to show behind the current user
const int kPlayersBehind = 5;

class RaceLogicService {
  /// Generates the pure view data for the race track.
  ///
  /// Principles:
  /// - Filtering: Max 10 participants (4 ahead + 5 behind + me)
  /// - Sorting: Based on `completed_clues_count` (totalXP).
  /// - Visibility: Invisible rivals are excluded.
  /// - Grouping: Players at same progress are grouped.
  /// - Status: Visual states (icons, opacity) calculated here.
  RaceViewData buildRaceView({
    required List<Player> leaderboard,
    required String currentUserId,
    required List<PowerEffect> activePowers,
    required int totalClues,
  }) {
    // Normalize current user ID for comparison (Expects userId)
    final normalizedCurrentUserId = _normalizeId(currentUserId);

    // 1. Find Me using userId (more robust than generic id)
    final myIndex = leaderboard
        .indexWhere((p) => _normalizeId(p.userId) == normalizedCurrentUserId);
    Player? me = myIndex != -1 ? leaderboard[myIndex] : null;

    // 2. Sort leaderboard explicitly by progress (completed_clues_count)
    // [FIX] Usar mismos criterios que game_service.dart (Ranking):
    //       1. completed_clues DESC
    //       2. last_completion_time ASC (quien terminó primero gana)
    final sortedPlayers = List<Player>.from(leaderboard);
    sortedPlayers.sort((a, b) {
      // Primary: Completed Clues (Descending)
      final progressCompare =
          b.completedCluesCount.compareTo(a.completedCluesCount);
      if (progressCompare != 0) return progressCompare;

      // Secondary: Last Completion Time (Ascending - menor = terminó primero = líder)
      final aTime =
          a.lastCompletionTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime =
          b.lastCompletionTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aTime.compareTo(bTime);
    });

    // Re-find me in sorted list
    final meSortedIndex = sortedPlayers
        .indexWhere((p) => _normalizeId(p.userId) == normalizedCurrentUserId);

    // 3. Helper to check visibility
    bool isVisible(Player p) {
      if (_normalizeId(p.userId) == normalizedCurrentUserId)
        return true; // I always see myself

      // Check active powers for invisibility
      // FIX: Check against BOTH userId and gamePlayerId to ensure we catch all cases
      final isStealthed = activePowers.any((e) {
        final targetId = _normalizeId(e.targetId);
        final playerId = _normalizeId(p.userId); // Use userId (UUID)
        final playerGameId = _normalizeId(p.gamePlayerId); // Use gamePlayerId (INT)
        
        // Match against EITHER id or gamePlayerId
        final isMatch = (targetId == playerId || targetId == playerGameId);
        
        return isMatch &&
            (e.powerSlug == 'invisibility' || e.powerSlug == 'stealth') &&
            !e.isExpired;
      });

      if (isStealthed) return false;
      if (p.isInvisible) return false;
      
      return true;
    }

    // 4. Filter for visibility
    final visibleRacers = sortedPlayers.where(isVisible).toList();

    // 5. Apply 10-participant limit: 4 ahead + me + 5 behind
    final filteredRacers = _filterParticipants(
      visibleRacers: visibleRacers,
      currentUserId: normalizedCurrentUserId,
    );

    // 6. Identify Leader from filtered list
    Player? leader = filteredRacers.isNotEmpty ? filteredRacers.first : null;

    // 8. Generate Progress Groups for UI overlap detection & vertical spreading
    final progressGroups = _buildProgressGroups(filteredRacers, totalClues);

    // 9. Assign lanes using the distribution logic
    final List<RacerViewModel> viewModels = [];
    final Set<String> addedIds = {};

    for (final group in progressGroups) {
      // Members are sorted by leaderboard rank in the group
      final members = group.members;
      
      // Vertical distribution within the group
      for (int i = 0; i < members.length; i++) {
        final p = members[i];
        final normalizedUserId = _normalizeId(p.userId);
        
        final bool isMe = normalizedUserId == normalizedCurrentUserId;
        final bool isLeader = (leader != null && 
            _normalizeId(p.userId) == _normalizeId(leader.userId));

        // LANE LOGIC:
        // System spreads members of the group vertically. 
        // 0 is the center line. 
        // Small stagger: -1, 1, -2, 2...
        int laneIndex = 0;
        
        if (members.length > 1) {
           // If I am in the group, I MUST be lane 0
           final meInGroupIdx = members.indexWhere((m) => _normalizeId(m.userId) == normalizedCurrentUserId);
           
           if (meInGroupIdx != -1) {
             if (isMe) {
               laneIndex = 0;
             } else {
               // Offset others from me: 1, -1, 2, -2...
               int offsetFromMe = i - meInGroupIdx;
               if (offsetFromMe > 0) {
                 laneIndex = offsetFromMe;
               } else {
                 laneIndex = offsetFromMe; // -1, -2...
               }
             }
           } else {
             // Group doesn't contain me. Use position relative to me to pick a base "sector"
             // meIndex is original leaderboard index
             final firstInGroupIdx = sortedPlayers.indexWhere((m) => _normalizeId(m.userId) == _normalizeId(members.first.userId));
             final myOriginalIdx = sortedPlayers.indexWhere((m) => _normalizeId(m.userId) == normalizedCurrentUserId);
             
             final bool groupIsAhead = firstInGroupIdx < myOriginalIdx || myOriginalIdx == -1;
             
             // Stagger around -1 if ahead, and around 1 if behind
             if (groupIsAhead) {
                // Ahead: -1, -2, -3...
                laneIndex = -(i + 1);
             } else {
                // Behind: 1, 2, 3...
                laneIndex = (i + 1);
             }
           }
        } else {
          // Single member: standard lane
          final myOriginalIdx = sortedPlayers.indexWhere((m) => _normalizeId(m.userId) == normalizedCurrentUserId);
          final playerIdx = sortedPlayers.indexWhere((m) => _normalizeId(m.userId) == normalizedUserId);
          
          if (isMe) laneIndex = 0;
          else if (playerIdx < myOriginalIdx || myOriginalIdx == -1) laneIndex = -1;
          else laneIndex = 1;
        }

        // Clamp laneIndex to avoid going too far out of bounds (max +/- 3 lanes)
        laneIndex = laneIndex.clamp(-3, 3);

        // Calculate visual state
        double opacity = 1.0;
        if (isMe) {
          final amInvisible = activePowers.any((e) =>
              _normalizeId(e.targetId) == _normalizeId(p.id) &&
              (e.powerSlug == 'invisibility' || e.powerSlug == 'stealth') &&
              !e.isExpired);
          if (amInvisible || p.isInvisible) opacity = 0.5;
        }

        IconData? statusIcon;
        Color? statusColor;

        final activeDebuffs = activePowers
            .where((e) =>
                _normalizeId(e.targetId) == _normalizeId(p.id) && !e.isExpired)
            .toList();

        if (activeDebuffs.any((e) => e.powerSlug == 'freeze')) {
          statusIcon = Icons.ac_unit;
          statusColor = Colors.cyanAccent;
        } else if (activeDebuffs.any(
            (e) => e.powerSlug == 'black_screen' || e.powerSlug == 'blind')) {
          statusIcon = Icons.visibility_off;
          statusColor = Colors.black;
        } else if (p.status == PlayerStatus.shielded || p.isProtected) {
          statusIcon = Icons.shield;
          statusColor = Colors.indigoAccent;
        }

        viewModels.add(RacerViewModel(
          data: p,
          lane: laneIndex,
          isMe: isMe,
          isLeader: isLeader,
          isTargetable: isVisible(p),
          opacity: opacity,
          statusIcon: statusIcon,
          statusColor: statusColor,
        ));
      }
    }

    // 10. Finalize result
    // 11. Motivation Text
    String motivation = "";
    if (me != null) {
      if (me.completedCluesCount == 0)
        motivation = "¡La carrera comienza! 🏃💨";
      else if (me.completedCluesCount >= totalClues && totalClues > 0)
        motivation = "¡META ALCANZADA! 🎉";
      else if (leader != null && _normalizeId(me.id) == _normalizeId(leader.id))
        motivation = "¡Vas LÍDER! 🏆";
      else
        motivation =
            "Pista ${me.completedCluesCount} de $totalClues. ¡Sigue así! 🚀";
    }

    return RaceViewData(
      racers: viewModels,
      motivationText: motivation,
      progressGroups: progressGroups,
    );
  }

  /// Filters participants to max 10: 4 ahead + current user + 5 behind
  List<Player> _filterParticipants({
    required List<Player> visibleRacers,
    required String currentUserId,
  }) {
    if (visibleRacers.length <= kMaxRaceParticipants) {
      return visibleRacers;
    }

    final meIndex =
        visibleRacers.indexWhere((p) => _normalizeId(p.id) == currentUserId);

    if (meIndex == -1) {
      // User not in list, return first 10
      return visibleRacers.take(kMaxRaceParticipants).toList();
    }

    // Calculate range: up to 4 ahead, up to 5 behind
    int startIndex =
        (meIndex - kPlayersAhead).clamp(0, visibleRacers.length - 1);
    int endIndex =
        (meIndex + kPlayersBehind + 1).clamp(0, visibleRacers.length);

    // Adjust if we have room on one side but not the other
    final aheadCount = meIndex - startIndex;
    final behindCount = endIndex - meIndex - 1;

    if (aheadCount < kPlayersAhead &&
        behindCount < visibleRacers.length - meIndex - 1) {
      // Room to expand behind
      final extraBehind = kPlayersAhead - aheadCount;
      endIndex = (endIndex + extraBehind).clamp(0, visibleRacers.length);
    }

    if (behindCount < kPlayersBehind && aheadCount < meIndex) {
      // Room to expand ahead
      final extraAhead = kPlayersBehind - behindCount;
      startIndex = (startIndex - extraAhead).clamp(0, visibleRacers.length - 1);
    }

    // Ensure max 10 total
    final result = visibleRacers.sublist(startIndex, endIndex);
    if (result.length > kMaxRaceParticipants) {
      // Trim from behind if over limit
      return result.take(kMaxRaceParticipants).toList();
    }

    return result;
  }

  /// Groups players by their integer progress count for overlap detection
  List<ProgressGroup> _buildProgressGroups(
      List<Player> players, int totalClues) {
    final Map<int, List<Player>> grouped = {};

    for (final player in players) {
      final progressCount = player.completedCluesCount;
      grouped.putIfAbsent(progressCount, () => []).add(player);
    }

    return grouped.entries.map((entry) {
      final progress = totalClues > 0 ? entry.key / totalClues : 0.0;
      return ProgressGroup(
        progress: progress.clamp(0.0, 1.0),
        progressCount: entry.key,
        memberIds: entry.value.map((p) => p.userId).toList(),
        members: entry.value,
      );
    }).toList()
      ..sort((a, b) => b.progressCount.compareTo(a.progressCount));
  }

  /// Normalizes an ID for consistent comparison (handles UUID type mismatches)
  String _normalizeId(String? id) {
    if (id == null) return '';
    return id.toString().trim().toLowerCase();
  }
}
