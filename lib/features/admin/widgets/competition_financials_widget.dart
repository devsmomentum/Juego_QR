import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../game/models/event.dart';
import '../../../core/theme/app_theme.dart';
import '../services/admin_service.dart';
import '../../game/services/betting_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../shared/widgets/coin_image.dart';

class CompetitionFinancialsWidget extends StatefulWidget {
  final GameEvent event;

  const CompetitionFinancialsWidget({Key? key, required this.event})
      : super(key: key);

  @override
  State<CompetitionFinancialsWidget> createState() =>
      _CompetitionFinancialsWidgetState();
}

class _CompetitionFinancialsWidgetState
    extends State<CompetitionFinancialsWidget> {
  late final Stream<List<Map<String, dynamic>>> _betsStream;
  List<Map<String, dynamic>> _enrichedBets = [];
  bool _isLoadingEnriched = false;
  late BettingService _bettingService;
  Future<Map<String, dynamic>>? _financialResultsFuture;

  @override
  void initState() {
    super.initState();
    _bettingService = BettingService(Supabase.instance.client);
    _setupStreams();
  }

  void _setupStreams() {
    _betsStream = Supabase.instance.client
        .from('bets')
        .stream(primaryKey: ['id'])
        .eq('event_id', widget.event.id)
        .order('created_at', ascending: false)
        .map((maps) => maps);

    if (widget.event.status == 'completed') {
       _loadFinancialResults();
    }
  }

  Future<void> _loadEnrichedBets() async {
    if (_isLoadingEnriched) return;
    _isLoadingEnriched = true;
    try {
      final enriched = await _bettingService.fetchEnrichedEventBets(widget.event.id);
      if (mounted) {
        setState(() {
          _enrichedBets = enriched;
          _isLoadingEnriched = false;
        });
      }
    } catch (e) {
      debugPrint('💰 Error loading enriched bets: $e');
      if (mounted) {
        setState(() => _isLoadingEnriched = false);
      }
    }
  }

  void _loadFinancialResults() {
     setState(() {
       _financialResultsFuture = Provider.of<AdminService>(context, listen: false)
          .getEventFinancialResults(widget.event.id);
     });
  }
  
  @override
  void didUpdateWidget(CompetitionFinancialsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.status != widget.event.status) {
       if (widget.event.status == 'completed') {
         _loadFinancialResults();
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.event.status != 'completed') {
      return _buildLiveBetsView();
    }
    return _buildFinalResultsView();
  }

  Widget _buildLiveBetsView() {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final cardColor = Theme.of(context).cardTheme.color;
    final primaryColor = Theme.of(context).primaryColor;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _betsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: primaryColor));
        }

        final rawBets = snapshot.data!;
        if (_enrichedBets.length != rawBets.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadEnrichedBets());
        }
        
        final totalPot = rawBets.fold<int>(0, (sum, bet) => sum + (bet['amount'] as num).toInt());

        final Map<String, _BettorGroup> bettorGroups = {};
        final betsToDisplay = _enrichedBets.isNotEmpty ? _enrichedBets : rawBets;

        for (var bet in betsToDisplay) {
          final userId = bet['user_id'] as String;
          final bettorName = bet['bettor_name'] as String? ?? 'Apostador';
          final bettorAvatarId = bet['bettor_avatar_id'] as String?;
          final amount = (bet['amount'] as num).toInt();

          if (!bettorGroups.containsKey(userId)) {
            bettorGroups[userId] = _BettorGroup(
              userId: userId,
              name: bettorName,
              avatarId: bettorAvatarId,
            );
          }

          bettorGroups[userId]!.totalBet += amount;
          bettorGroups[userId]!.bets.add(bet);
        }

        final sortedBettors = bettorGroups.values.toList()
          ..sort((a, b) => b.totalBet.compareTo(a.totalBet));

        final uniqueBettors = bettorGroups.length;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withOpacity(0.15),
                      cardColor ?? Colors.white,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primaryColor.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'POTE DE APUESTAS EN VIVO',
                      style: TextStyle(color: textColor?.withOpacity(0.6), fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$totalPot ',
                          style: TextStyle(
                              color: textColor,
                              fontSize: 36,
                              fontWeight: FontWeight.bold),
                        ),
                        const CoinImage(size: 28),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildMiniStat(Icons.people, '$uniqueBettors', 'Apostadores'),
                        const SizedBox(width: 24),
                        _buildMiniStat(Icons.receipt_long, '${rawBets.length}', 'Tickets'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              Row(
                children: [
                  Icon(Icons.person_search, color: primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Apostadores',
                    style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (_isLoadingEnriched)
                    SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: sortedBettors.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.casino_outlined, color: textColor?.withOpacity(0.1), size: 48),
                          const SizedBox(height: 12),
                          Text('Aún no hay apuestas', style: TextStyle(color: textColor?.withOpacity(0.3), fontSize: 16)),
                        ],
                      ),
                    )
                  : ListView.builder(
                    itemCount: sortedBettors.length,
                    itemBuilder: (context, index) {
                      final bettor = sortedBettors[index];
                      return _buildBettorCard(bettor, index);
                    },
                  ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniStat(IconData icon, String value, String label) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: textColor?.withOpacity(0.4), size: 16),
            const SizedBox(width: 4),
            Text(value, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: textColor?.withOpacity(0.3), fontSize: 11)),
      ],
    );
  }

  Widget _buildBettorCard(_BettorGroup bettor, int index) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final cardColor = Theme.of(context).cardTheme.color;
    final primaryColor = Theme.of(context).primaryColor;
    final hasEnrichedData = _enrichedBets.isNotEmpty;
    final initial = bettor.name.isNotEmpty ? bettor.name[0].toUpperCase() : '?';

    return Card(
      elevation: 0,
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.05)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
          leading: CircleAvatar(
            backgroundColor: _getBettorColor(index).withOpacity(0.2),
            radius: 20,
            child: Text(initial, style: TextStyle(color: _getBettorColor(index), fontWeight: FontWeight.bold)),
          ),
          title: Text(
            hasEnrichedData ? bettor.name : 'Apostador #${index + 1}',
            style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
          ),
          subtitle: Row(
            children: [
              Text(
                '${bettor.bets.length} apuesta(s) · Total: ${bettor.totalBet} ',
                style: TextStyle(color: textColor?.withOpacity(0.5), fontSize: 12),
              ),
              const CoinImage(size: 12),
            ],
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${bettor.totalBet} ',
                  style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const CoinImage(size: 14),
              ],
            ),
          ),
          iconColor: textColor?.withOpacity(0.5),
          collapsedIconColor: textColor?.withOpacity(0.3),
          children: [
            Divider(color: Theme.of(context).dividerColor.withOpacity(0.1), height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.flag, color: textColor?.withOpacity(0.3), size: 14),
                const SizedBox(width: 6),
                Text('Apostó a:', style: TextStyle(color: textColor?.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            ...bettor.bets.map((bet) {
              final racerName = bet['racer_name'] as String? ?? 'Participante';
              final amount = (bet['amount'] as num).toInt();
              final createdAt = DateTime.tryParse(bet['created_at']?.toString() ?? '')?.toLocal();
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.05)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.directions_run, color: primaryColor.withOpacity(0.7), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasEnrichedData ? racerName : 'Participante',
                              style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            if (createdAt != null)
                              Text(
                                DateFormat('HH:mm:ss').format(createdAt),
                                style: TextStyle(color: textColor?.withOpacity(0.3), fontSize: 11),
                              ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '$amount ',
                            style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          const CoinImage(size: 13),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Color _getBettorColor(int index) {
    const colors = [
      Colors.indigo,
      Colors.teal,
      Colors.deepOrange,
      Colors.purple,
      Colors.blueGrey,
      Colors.brown,
      Colors.cyan,
      Colors.pink,
    ];
    return colors[index % colors.length];
  }

  Widget _buildFinalResultsView() {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final primaryColor = Theme.of(context).primaryColor;

    return FutureBuilder<Map<String, dynamic>>(
      future: _financialResultsFuture,
      builder: (context, snapshot) {
         if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primaryColor));
         }
         if (snapshot.hasError) {
            return Center(child: Text('Error cargando resultados: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
         }
         
         final data = snapshot.data ?? {};
         final pot = data['pot'] ?? 0;
         final bettingPot = data['betting_pot'] ?? 0;
         
         List<dynamic> podium = [];
         List<dynamic> bettors = [];

         if (data['podium'] != null) {
            podium = data['podium'] as List<dynamic>;
         } else if (data['results'] != null) {
            podium = data['results'] as List<dynamic>;
         }

         if (data['bettors'] != null) {
            bettors = data['bettors'] as List<dynamic>;
         }
         
         return SingleChildScrollView(
           padding: const EdgeInsets.all(16),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Row(
                 children: [
                   Expanded(
                     child: _buildFinanceCard(
                       title: 'POTE COMPETENCIA (70%)',
                       amount: '$pot ',
                       icon: Icons.emoji_events,
                       color: primaryColor,
                       showCoin: true,
                     ),
                   ),
                   const SizedBox(width: 10),
                   Expanded(
                     child: _buildFinanceCard(
                       title: 'POTE APUESTAS',
                       amount: '$bettingPot ',
                       icon: Icons.casino,
                       color: const Color(0xFFD4AF37),
                       showCoin: true,
                     ),
                   ),
                 ],
               ),
               const SizedBox(height: 24),
               
               Text("🏆 Podio de Ganadores", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
               const SizedBox(height: 12),
               if (podium.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.info_outline, color: primaryColor.withOpacity(0.5), size: 30),
                        const SizedBox(height: 12),
                        Text(
                          "Los premios aún no han sido distribuidos.", 
                          style: TextStyle(color: textColor?.withOpacity(0.8), fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Usa el botón 'Distribuir Premios' en la pestaña 'Detalles' para generar la liquidación final.",
                          style: TextStyle(color: textColor?.withOpacity(0.5), fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
               else
                 ...podium.map((r) {
                   final int prizeAmount = (r['amount'] as num?)?.toInt() ?? 0;
                   final int commission = (r['commission'] as num?)?.toInt() ?? 0;
                   final int totalEarned = prizeAmount + commission;
                   final bool isWinner = r['rank'] == 1;
                   return Card(
                    color: isWinner ? const Color(0xFFD4AF37).withOpacity(0.08) : Theme.of(context).cardTheme.color,
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: isWinner ? const Color(0xFFD4AF37).withOpacity(0.3) : Theme.of(context).dividerColor.withOpacity(0.08)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: r['rank'] == 1 ? const Color(0xFFD4AF37) : (r['rank'] == 2 ? Colors.grey : Colors.brown),
                            foregroundColor: Colors.white,
                            child: Text('${r['rank']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${r['name']}', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15)),
                                Text('Posición #${r['rank']}', style: TextStyle(color: textColor?.withOpacity(0.5), fontSize: 12)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (prizeAmount > 0) ...[
                                Text('Premio', style: TextStyle(color: textColor?.withOpacity(0.35), fontSize: 10)),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('+$prizeAmount ', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 15)),
                                    const CoinImage(size: 15),
                                  ],
                                ),
                              ],
                              if (commission > 0) ...[
                                const SizedBox(height: 4),
                                Text('Comisión Apuestas', style: TextStyle(color: textColor?.withOpacity(0.35), fontSize: 10)),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('+$commission ', style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 15)),
                                    const CoinImage(size: 15),
                                  ],
                                ),
                              ],
                              if (prizeAmount == 0 && commission == 0) ...[
                                Text('Premio', style: TextStyle(color: textColor?.withOpacity(0.35), fontSize: 10)),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('0 ', style: TextStyle(color: textColor?.withOpacity(0.35), fontWeight: FontWeight.bold, fontSize: 15)),
                                    const CoinImage(size: 15),
                                  ],
                                ),
                              ],
                              if (prizeAmount > 0 && commission > 0) ...[
                                Divider(color: Theme.of(context).dividerColor.withOpacity(0.1), height: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Total: $totalEarned ', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                                    const CoinImage(size: 13),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                  }).toList(),
                  
               const SizedBox(height: 30),
               Divider(color: Theme.of(context).dividerColor.withOpacity(0.1)),
               const SizedBox(height: 12),
               
               Text("📊 Desglose de Apuestas", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
               const SizedBox(height: 12),
               
               if (bettors.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        "No hubieron apuestas en este evento.",
                        style: TextStyle(color: textColor?.withOpacity(0.35), fontStyle: FontStyle.italic),
                      ),
                    ),
                  )
               else
                 ...bettors.map((b) {
                    final int totalBet = (b['total_bet'] as num?)?.toInt() ?? 0;
                    final int totalWon = (b['total_won'] as num?)?.toInt() ?? 0;
                    final bool isWinner = totalWon > 0;
                    final List<dynamic> individualBets = b['individual_bets'] as List<dynamic>? ?? [];
                    final String bettorName = b['name'] as String? ?? 'Apostador';
                    final String initial = bettorName.isNotEmpty ? bettorName[0].toUpperCase() : '?';
                    
                    return Card(
                      color: isWinner ? Colors.green.withOpacity(0.05) : Theme.of(context).cardTheme.color,
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: isWinner ? Colors.green.withOpacity(0.3) : Theme.of(context).dividerColor.withOpacity(0.08)),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                          leading: CircleAvatar(
                            backgroundColor: isWinner ? Colors.green.withOpacity(0.2) : Theme.of(context).dividerColor.withOpacity(0.1),
                            child: Text(initial, style: TextStyle(color: isWinner ? Colors.green : textColor?.withOpacity(0.6), fontWeight: FontWeight.bold)),
                          ),
                          title: Row(
                            children: [
                              Flexible(child: Text(bettorName, style: TextStyle(color: textColor, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                              if (isWinner) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                              ],
                            ],
                          ),
                          subtitle: Text('${b['bets_count']} apuesta(s)', style: TextStyle(color: textColor?.withOpacity(0.5), fontSize: 12)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                    Text('Apostado', style: TextStyle(color: textColor?.withOpacity(0.35), fontSize: 10)),
                                     Row(
                                       mainAxisSize: MainAxisSize.min,
                                       children: [
                                         Text('$totalBet ', style: TextStyle(color: textColor?.withOpacity(0.7), fontSize: 13)),
                                         const CoinImage(size: 12),
                                       ],
                                     ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                    Text('Ganancia', style: TextStyle(color: textColor?.withOpacity(0.35), fontSize: 10)),
                                     Row(
                                       mainAxisSize: MainAxisSize.min,
                                       children: [
                                         Text(
                                           totalWon > 0 ? '+$totalWon ' : '0 ', 
                                           style: TextStyle(
                                             color: totalWon > 0 ? Colors.green : textColor?.withOpacity(0.35), 
                                             fontWeight: FontWeight.bold,
                                             fontSize: 15
                                           )
                                         ),
                                         const CoinImage(size: 15),
                                       ],
                                     ),
                                ],
                              ),
                            ],
                          ),
                          iconColor: textColor?.withOpacity(0.5),
                          collapsedIconColor: textColor?.withOpacity(0.3),
                          children: [
                            Divider(color: Theme.of(context).dividerColor.withOpacity(0.1), height: 1),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.flag, color: textColor?.withOpacity(0.3), size: 14),
                                const SizedBox(width: 6),
                                Text('Apostó a:', style: TextStyle(color: textColor?.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...individualBets.map((bet) {
                              final racerName = bet['racer_name'] as String? ?? 'Jugador';
                              final amount = (bet['amount'] as num?)?.toInt() ?? 0;
                              final bool won = bet['won'] == true;
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: won ? Colors.green.withOpacity(0.05) : Theme.of(context).dividerColor.withOpacity(0.02),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: won ? Colors.green.withOpacity(0.2) : Theme.of(context).dividerColor.withOpacity(0.05)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        won ? Icons.emoji_events : Icons.directions_run,
                                        color: won ? Colors.green : primaryColor.withOpacity(0.6),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          racerName,
                                          style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '$amount ',
                                            style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600, fontSize: 13),
                                          ),
                                          const CoinImage(size: 13),
                                        ],
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: won ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          won ? 'Ganó' : 'Perdió',
                                          style: TextStyle(
                                            color: won ? Colors.green : Colors.redAccent,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                 }).toList(),
                 
               const SizedBox(height: 50),
             ],
           ),
         );
      },
    );
  }
  
  Widget _buildFinanceCard({required String title, required String amount, required IconData icon, required Color color, bool showCoin = false}) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final cardColor = Theme.of(context).cardTheme.color;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 14),
          Text(title, style: TextStyle(color: textColor?.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Row(
            children: [
              Flexible(
                child: Text(amount, style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ),
              if (showCoin) ...[
                const SizedBox(width: 4),
                const CoinImage(size: 20),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _BettorGroup {
  final String userId;
  final String name;
  final String? avatarId;
  int totalBet;
  final List<Map<String, dynamic>> bets;

  _BettorGroup({
    required this.userId,
    required this.name,
    this.avatarId,
    this.totalBet = 0,
    List<Map<String, dynamic>>? bets,
  }) : bets = bets ?? [];
}
