import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../game/models/event.dart';
import '../../../game/models/game_request.dart';
import '../../../game/providers/game_request_provider.dart';
import '../request_tile.dart';

class ParticipantsTab extends StatefulWidget {
  final GameEvent event;
  final List<Map<String, dynamic>> leaderboardData;
  final Map<String, String> playerStatuses;
  final VoidCallback onFetchPlayerStatuses;
  final VoidCallback onFetchLeaderboard;
  final Future<void> Function(List<GameRequest>) onApproveAll;

  const ParticipantsTab({
    super.key,
    required this.event,
    required this.leaderboardData,
    required this.playerStatuses,
    required this.onFetchPlayerStatuses,
    required this.onFetchLeaderboard,
    required this.onApproveAll,
  });

  @override
  State<ParticipantsTab> createState() => _ParticipantsTabState();
}

class _ParticipantsTabState extends State<ParticipantsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameRequestProvider>(
      builder: (context, provider, _) {
        // Pending requests from game_requests (for approval workflow)
        var pending = provider.requests
            .where((r) =>
                r.eventId.toString() == widget.event.id.toString() &&
                r.isPending)
            .toList();

        // Registered participants from game_players (via leaderboardData)
        var participants = List<Map<String, dynamic>>.from(widget.leaderboardData);

        // --- SEARCH FILTER ---
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          pending = pending
              .where((r) =>
                  (r.playerName.toLowerCase().contains(query)) ||
                  (r.playerEmail?.toLowerCase().contains(query) ?? false))
              .toList();
          participants = participants
              .where((p) =>
                  ((p['name'] as String?)?.toLowerCase().contains(query) ?? false) ||
                  ((p['email'] as String?)?.toLowerCase().contains(query) ?? false))
              .toList();
        }

        if (pending.isEmpty && participants.isEmpty) {
          return Center(
              child: Text("No hay participantes ni solicitudes.",
                  style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5))));
        }

        // --- SORT: banned/suspended go to bottom ---
        final bannedIds = widget.playerStatuses.entries
            .where((e) => e.value == 'banned' || e.value == 'suspended')
            .map((e) => e.key)
            .toSet();

        final activeLeaderboard = participants
            .where((entry) => !bannedIds.contains(entry['user_id']))
            .toList();

        participants.sort((a, b) {
          final isBannedA = bannedIds.contains(a['user_id']);
          final isBannedB = bannedIds.contains(b['user_id']);
          if (isBannedA && !isBannedB) return 1;
          if (!isBannedA && isBannedB) return -1;
          return 0;
        });

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // --- SEARCH FIELD ---
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).dividerColor.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre o email...',
                  hintStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4)),
                  prefixIcon: Icon(Icons.search, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4)),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: (value) {
                  if (_debounce?.isActive ?? false) _debounce!.cancel();
                  _debounce = Timer(const Duration(milliseconds: 300), () {
                    setState(() => _searchQuery = value);
                  });
                },
              ),
            ),

            if (pending.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text("Solicitudes Pendientes",
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppTheme.lGoldAction,
                            fontSize: 18,
                            fontWeight: FontWeight.w900)),
                  ),
                  if (widget.event.type == 'on_site')
                    TextButton.icon(
                      onPressed: () => widget.onApproveAll(pending),
                      icon:
                          const Icon(Icons.done_all, color: Colors.green),
                      label: const FittedBox(
                        child: Text("ACEPTAR TODOS",
                            style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              ...pending.map((req) => RequestTile(
                    request: req,
                    currentStatus:
                        widget.playerStatuses[req.playerId],
                    onBanToggled: () =>
                        widget.onFetchPlayerStatuses(),
                  )),
              const SizedBox(height: 20),
            ],

            const Text("Participantes Inscritos (Ranking)",
                style: TextStyle(
                    color: AppTheme.lGoldAction,
                    fontSize: 18,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            if (participants.isEmpty)
              Text(
                  "Nadie inscrito aún.",
                  style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4)))
            else
              ...participants.map((player) {
                final userId = player['user_id'] as String;
                final isBanned = bannedIds.contains(userId);
                final activeIndex = !isBanned
                    ? activeLeaderboard
                        .indexWhere((l) => l['user_id'] == userId)
                    : -1;

                // Build a synthetic GameRequest for RequestTile compatibility
                final syntheticRequest = GameRequest(
                  id: userId,
                  userId: userId,
                  eventId: widget.event.id,
                  status: 'approved',
                  userName: player['name'] as String?,
                  userEmail: player['email'] as String?,
                );

                return RequestTile(
                  request: syntheticRequest,
                  isReadOnly: true,
                  rank: activeIndex != -1 ? activeIndex + 1 : null,
                  progress: (player['completed_clues'] as num?)?.toInt() ?? 0,
                  currentStatus: widget.playerStatuses[userId],
                  onBanToggled: () => widget.onFetchPlayerStatuses(),
                  coins: (player['coins'] as num?)?.toInt(),
                  lives: (player['lives'] as num?)?.toInt(),
                  eventId: widget.event.id,
                  onStatsUpdated: () => widget.onFetchLeaderboard(),
                );
              }).toList(),
          ],
        );
      },
    );
  }
}
