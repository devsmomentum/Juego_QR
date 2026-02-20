import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../game/models/event.dart';
import '../../../core/theme/app_theme.dart';
import '../services/admin_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

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
  // Stream for live bets
  late final Stream<List<Map<String, dynamic>>> _betsStream;
  
  // Future for finished event results
  Future<Map<String, dynamic>>? _financialResultsFuture;

  @override
  void initState() {
    super.initState();
    _setupStreams();
  }

  void _setupStreams() {
    // Only setup stream if event is not pending (meaning it is active or finished, 
    // but useful mainly for active. For finished we use FutureBuilder, but 
    // we might want to see the latest bets even if finished if we haven't distributed prizes yet)
    
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
    debugPrint('💰 CompetitionFinancialsWidget: Building for event ${widget.event.id}');
    debugPrint('💰 Event Status: ${widget.event.status}');

    // 1. If Event is Active (or Pending/Paused) -> Show Live Stream
    if (widget.event.status != 'completed') {
      debugPrint('💰 Showing Live Bets View');
      return _buildLiveBetsView();
    }

    // 2. If Event is Finished -> Show Final Results
    debugPrint('💰 Showing Final Results View');
    return _buildFinalResultsView();
  }

  Widget _buildLiveBetsView() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _betsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('💰 Stream Error: ${snapshot.error}');
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }
        if (!snapshot.hasData) {
          debugPrint('💰 Stream Waiting for data...');
          return const Center(child: CircularProgressIndicator());
        }

        final bets = snapshot.data!;
        debugPrint('💰 Stream received ${bets.length} bets');
        
        // Calculate Total Pot locally from the stream
        final totalPot = bets.fold<int>(0, (sum, bet) => sum + (bet['amount'] as num).toInt());

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Summary Card
              Card(
                color: AppTheme.cardBg,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'POTE DE APUESTAS EN VIVO',
                        style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$totalPot 🍀',
                        style: const TextStyle(
                            color: AppTheme.accentGold,
                            fontSize: 32,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${bets.length} Apuestas Totales',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Bets List
              const Text(
                'Últimas Apuestas',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: bets.isEmpty 
                  ? const Center(child: Text('Aún no hay apuestas', style: TextStyle(color: Colors.white30)))
                  : ListView.builder(
                    itemCount: bets.length,
                    itemBuilder: (context, index) {
                      final bet = bets[index];
                      // We need to fetch profiles if we want names, but for now lets rely on basic info or if 
                      // the stream join is not possible, we might just show amounts or do a separate fetch.
                      // Note: Supabase Stream doesn't support deep joins easily. 
                      // For a robust implementation, we might need a separate mechanism or accept IDs.
                      // Or simply show the amount and time.
                      
                      // NOTE: 'profiles:racer_id(name)' logic is for simple REST selects.
                      // Streams return raw table data usually. 
                      
                      final amount = bet['amount'];
                      final createdAt = DateTime.parse(bet['created_at']).toLocal();
                      
                      return Card(
                        color: Colors.white.withOpacity(0.05),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.monetization_on, color: Colors.amber, size: 28),
                          title: Text(
                            'Apuesta: $amount 🍀', 
                            style: const TextStyle(color: Colors.white)
                          ),
                          subtitle: Text(
                             DateFormat('HH:mm:ss').format(createdAt),
                             style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          // If we had the user name it would be better, but stream limitations apply.
                          // We can show the user_id for debug or just "Usuario"
                          trailing: Text(bet['user_id'].toString().substring(0,6) + '...', style: TextStyle(color: Colors.white30)),
                        ),
                      );
                    },
                  ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFinalResultsView() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _financialResultsFuture,
      builder: (context, snapshot) {
         if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
         }
         if (snapshot.hasError) {
            debugPrint('💰 Future Error: ${snapshot.error}');
            return Center(child: Text('Error cargando resultados: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
         }
         
         final data = snapshot.data ?? {};
         debugPrint('💰 Financial Data: $data');
         final pot = data['pot'] ?? 0;
         
         // Logic to handle different RPC return structures
         List<dynamic> podium = [];
         List<dynamic> bettors = [];

         if (data['podium'] != null) {
            podium = data['podium'] as List<dynamic>;
         } else if (data['results'] != null) {
             // Fallback for old structure
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
               _buildFinanceCard(
                 title: 'POTE FINAL REPARTIDO',
                 amount: '$pot 🍀',
                 icon: Icons.flag,
                 color: AppTheme.primaryPurple,
               ),
               const SizedBox(height: 20),
               
               // --- PODIUM SECTION ---
               const Text("🏆 Podio de Ganadores", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
               const SizedBox(height: 10),
               if (podium.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8)
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber, size: 30),
                        SizedBox(height: 10),
                        Text(
                          "Los premios aún no han sido distribuidos.", 
                          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 5),
                        Text(
                          "Usa el botón 'Distribuir Premios' en la pestaña 'Detalles' para generar la liquidación final.",
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
               else
                 ...podium.map((r) {
                   final avatarId = r['avatar_id'] as String?;
                   return Card(
                   color: Colors.white10,
                   child: ListTile(
                     leading: CircleAvatar(
                       backgroundColor: r['rank'] == 1 ? Colors.amber : (r['rank'] == 2 ? Colors.grey : Colors.brown),
                       // Use text as fallback if no image logic yet, but if avatarId is present we could use it
                       // safely assuming we don't have the avatar assets logic here imported, fallback to rank
                       child: Text('${r['rank']}'),
                     ),
                     title: Text('${r['name']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                     subtitle: Text('Posición #${r['rank']}', style: const TextStyle(color: Colors.white54)),
                     trailing: Column(
                       mainAxisAlignment: MainAxisAlignment.center,
                       crossAxisAlignment: CrossAxisAlignment.end,
                       children: [
                         const Text('Premio', style: TextStyle(color: Colors.white30, fontSize: 10)),
                         Text('+${r['amount']} 🍀', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                       ],
                     ),
                   ),
                 );
                 }).toList(),
                 
               const SizedBox(height: 30),
               const Divider(color: Colors.white24),
               const SizedBox(height: 10),
               
               // --- BETTORS SECTION ---
               const Text("📊 Desglose de Apuestas", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
               const SizedBox(height: 10),
               
               if (bettors.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        "No hubieron apuestas en este evento.",
                        style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic),
                      ),
                    ),
                  )
               else
                 ...bettors.map((b) {
                    final int net = b['net'] ?? 0;
                    final bool isWinner = net > 0;
                    final int totalWon = b['total_won'] ?? 0;
                    
                    return Card(
                      color: isWinner ? Colors.green.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                         leading: CircleAvatar(
                           backgroundColor: Colors.blueGrey,
                           child: Text((b['name'] as String).substring(0, 1).toUpperCase()),
                         ),
                         title: Text('${b['name']}', style: const TextStyle(color: Colors.white)),
                         subtitle: Text('${b['bets_count']} apuesta(s)', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                         trailing: Row(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             Column(
                               crossAxisAlignment: CrossAxisAlignment.end,
                               mainAxisAlignment: MainAxisAlignment.center,
                               children: [
                                  const Text('Apostado', style: TextStyle(color: Colors.white38, fontSize: 10)),
                                  Text('${b['total_bet']} 🍀', style: const TextStyle(color: Colors.white70)),
                               ],
                             ),
                             const SizedBox(width: 16),
                             Column(
                               crossAxisAlignment: CrossAxisAlignment.end,
                               mainAxisAlignment: MainAxisAlignment.center,
                               children: [
                                  const Text('Ganancia', style: TextStyle(color: Colors.white38, fontSize: 10)),
                                  Text(
                                    totalWon > 0 ? '+$totalWon 🍀' : '0 🍀', 
                                    style: TextStyle(
                                      color: totalWon > 0 ? Colors.greenAccent : Colors.white30, 
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16
                                    )
                                  ),
                               ],
                             ),
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
  
  Widget _buildFinanceCard({required String title, required String amount, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              Text(amount, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }
}
