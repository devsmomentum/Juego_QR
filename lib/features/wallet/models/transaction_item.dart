import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class TransactionItem {
  final String id;
  final DateTime date;
  final double amount;
  final String description;
  final String status; // 'completed', 'pending', 'expired', 'failed', 'error'
  final String type; // 'deposit', 'withdrawal', 'purchase_order'
  final String? paymentUrl;

  const TransactionItem({
    required this.id,
    required this.date,
    required this.amount,
    required this.description,
    required this.status,
    required this.type,
    this.paymentUrl,
  });

  factory TransactionItem.fromMap(Map<String, dynamic> map) {
    return TransactionItem(
      id: map['id']?.toString() ?? '',
      date: DateTime.parse(map['created_at']),
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] ?? 'Transacción',
      status: map['status'] ?? 'unknown',
      type: map['type'] ?? 'unknown',
      paymentUrl: map['payment_url'],
    );
  }

  // Helpers
  bool get isCredit => type == 'deposit' || type == 'winnings' || type == 'refund';
  
  bool get isPending => status == 'pending';
  
  bool get canResumePayment => isPending && paymentUrl != null && paymentUrl!.isNotEmpty;

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'success':
      case 'paid':
        return AppTheme.successGreen;
      case 'pending':
        return Colors.orangeAccent;
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

