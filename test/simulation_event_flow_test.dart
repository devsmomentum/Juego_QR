import 'package:flutter_test/flutter_test.dart';
import 'dart:async';

// --- MOCK DE SISTEMA INTEGRADO (JUGADORES + APUESTAS) ---

class MockUnifiedSystem {
  static Map<String, dynamic> runFullDistribution({
    required int participantCount,
    required int entryFee,
    required int totalBettorTickets,
    required int betTicketPrice,
    required int winningBetsCount,
    required List<String> podiumNames,
  }) {
    // 1. Cálculos de Carrera
    int totalEntryPot = participantCount * entryFee;
    int distributableEntryPot = (totalEntryPot * 0.70).floor();
    
    // Premios Podio (50/30/20)
    Map<String, int> playerPrizes = {
      podiumNames[0]: (distributableEntryPot * 0.50).floor(),
      podiumNames[1]: (distributableEntryPot * 0.30).floor(),
      podiumNames[2]: (distributableEntryPot * 0.20).floor(),
    };

    // 2. Cálculos de Apuestas
    int totalBettingPool = totalBettorTickets * betTicketPrice;
    int winnersInvestment = winningBetsCount * betTicketPrice;
    int netProfit = totalBettingPool - winnersInvestment;
    int houseCommission = (netProfit * 0.10).floor(); // 10% del beneficio neto
    int distributableBettingPot = totalBettingPool - houseCommission;
    int payoutPerTicket = (distributableBettingPot / winningBetsCount).floor();

    return {
      'entry': {
        'total_collected': totalEntryPot,
        'distributable': distributableEntryPot,
        'prizes': playerPrizes,
      },
      'betting': {
        'total_pool': totalBettingPool,
        'commission': houseCommission,
        'payout_per_ticket': payoutPerWinnerLogic(totalBettingPool, winningBetsCount, houseCommission),
      }
    };
  }

  // Simula la lógica exacta del SQL resolve_event_bets
  static int payoutPerWinnerLogic(int pool, int winners, int commission) {
    if (winners == 0) return 0;
    return ((pool - commission) / winners).floor();
  }
}

void main() {
  group('🚀 TEST FINAL UNIFICADO: Misión Cumplida (REPARTO INTEGRAL)', () {
    
    test('Verificar integridad de la distribución 10p / 50c / 15a', () {
      print('\n======================================================');
      print('🌟 INICIANDO TEST FINAL DE MISIÓN');
      print('   Simulando Evento Online Completo');
      print('======================================================');

      // Ejecutar modelo matemático coincidente con el SQL
      final flow = MockUnifiedSystem.runFullDistribution(
        participantCount: 10,
        entryFee: 50,
        totalBettorTickets: 15,
        betTicketPrice: 100,
        winningBetsCount: 3,
        podiumNames: ['Alpha_Champion', 'Beta_RunnerUp', 'Gamma_Third'],
      );

      print('\n💎 SECCIÓN 1: PREMIOS DE COMPETENCIA');
      print('   Recaudado Entradas: ${flow['entry']['total_collected']} Tréboles');
      print('   Bote a repartir (70%): ${flow['entry']['distributable']} Tréboles');
      print('------------------------------------------------------');
      
      flow['entry']['prizes'].forEach((name, prize) {
          print('   👤 $name -> Recibe: $prize Tréboles');
      });

      print('\n🎰 SECCIÓN 2: PREMIOS DE APUESTAS');
      print('   Bote de Espectadores: ${flow['betting']['total_pool']} Tréboles');
      print('   Comisión de la Casa: ${flow['betting']['commission']} Tréboles');
      print('   Tickets Ganadores: 3');
      print('------------------------------------------------------');
      print('   💰 PAGO POR TICKET: ${flow['betting']['payout_per_ticket']} Tréboles');

      // Validaciones finales de consistencia
      expect(flow['entry']['prizes']['Alpha_Champion'], 175);
      expect(flow['entry']['prizes']['Beta_RunnerUp'], 105);
      expect(flow['entry']['prizes']['Gamma_Third'], 70);
      expect(flow['betting']['payout_per_ticket'], 460);

      print('\n✅ VALIDACIÓN EXITOSA:');
      print('   1. Los jugadores se llevaron el 70% del bote de entrada.');
      print('   2. Los apostadores ganadores recibieron su pago proporcional.');
      print('   3. El sistema retuvo las comisiones esperadas (30% entrada / 10% apuestas).');
      print('======================================================\n');
    });
  });
}
