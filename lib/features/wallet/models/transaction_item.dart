import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class TransactionItem {
  final String id;
  final DateTime date;
  final double amount;
  final String description;
  final String status; // 'completed', 'pending', 'expired', 'failed', 'error'
  final String type; // 'deposit', 'withdrawal', 'purchase_order'
  final String? ledgerType; // wallet_ledger metadata.type (e.g. runner_bet_commission)
  final String? paymentUrl;
  final double? fiatAmount;
  final double? fiatAmountVes;
  final String? pagoOrderId;
  final String? gateway;

  const TransactionItem({
    required this.id,
    required this.date,
    required this.amount,
    required this.description,
    required this.status,
    required this.type,
    this.ledgerType,
    this.paymentUrl,
    this.fiatAmount,
    this.fiatAmountVes,
    this.pagoOrderId,
    this.gateway,
  });

  static DateTime _toVenezuelaTime(DateTime dateTime) {
    // Venezuela is UTC-4 year-round.
    final utc = dateTime.isUtc ? dateTime : dateTime.toUtc();
    return utc.subtract(const Duration(hours: 4));
  }

  factory TransactionItem.fromMap(Map<String, dynamic> map) {
    return TransactionItem(
      id: map['id']?.toString() ?? '',
      date: _toVenezuelaTime(DateTime.parse(map['created_at'])),
      // Map 'clover_quantity' from V2 view to 'amount' (primary display unit)
      amount: ((map['clover_quantity'] ?? map['amount']) as num).toDouble(),
      description: map['description'] ?? 'Transacción',
      status: map['status'] ?? 'unknown',
      type: map['type'] ?? 'unknown',
      ledgerType: map['ledger_type']?.toString(),
      paymentUrl: map['payment_url'],
      fiatAmount: map['fiat_amount'] != null ? (map['fiat_amount'] as num).toDouble() : null,
      fiatAmountVes: map['fiat_amount_ves'] != null ? (map['fiat_amount_ves'] as num).toDouble() : null,
      pagoOrderId: map['pago_pago_order_id']?.toString(),
      gateway: map['gateway']?.toString(),
    );
  }

  // Helpers
  bool get isCredit => type == 'deposit' || type == 'winnings' || type == 'refund';
  
  bool get isPending => status == 'pending';
  
  bool get canResumePayment => isPending && paymentUrl != null && paymentUrl!.isNotEmpty;

  bool get canValidateMpay => isPending && gateway == 'pago_movil' && pagoOrderId != null;
  
  bool get canCancelWithdrawal => isPending && (type == 'withdrawal' || description.toLowerCase().contains('retiro'));

  bool get canCancel => isPending && (type == 'deposit' || type == 'purchase_order' || canCancelWithdrawal);

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'success':
      case 'paid':
        return AppTheme.successGreen;
      case 'pending':
        return Colors.orangeAccent;
      case 'cancelled':
      case 'canceled':
        return Colors.blueGrey;
      case 'failed':
      case 'error':
        return AppTheme.dangerRed;
      case 'expired':
        return Colors.grey;
      default:
        return Colors.white70;
    }
  }
}

