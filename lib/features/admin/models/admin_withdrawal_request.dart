import 'package:supabase_flutter/supabase_flutter.dart';

class AdminWithdrawalRequest {
  final String id;
  final String userId;
  final String planId;
  final String? paymentMethodId;
  final String gateway;
  final int cloversCost;
  final double amountUsd;
  final double? amountVes;
  final double? bcvRate;
  final String status;
  final Map<String, dynamic> providerData;
  final DateTime createdAt;
  final String? userName;
  final String? userEmail;

  AdminWithdrawalRequest({
    required this.id,
    required this.userId,
    required this.planId,
    this.paymentMethodId,
    required this.gateway,
    required this.cloversCost,
    required this.amountUsd,
    this.amountVes,
    this.bcvRate,
    required this.status,
    required this.providerData,
    required this.createdAt,
    this.userName,
    this.userEmail,
  });

  factory AdminWithdrawalRequest.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'];
    return AdminWithdrawalRequest(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      planId: json['plan_id'] as String,
      paymentMethodId: json['payment_method_id'] as String?,
      gateway: json['gateway'] as String,
      cloversCost: json['clovers_cost'] as int,
      amountUsd: (json['amount_usd'] as num).toDouble(),
      amountVes: (json['amount_ves'] as num?)?.toDouble(),
      bcvRate: (json['bcv_rate'] as num?)?.toDouble(),
      status: json['status'] as String,
      providerData: json['provider_data'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
      userName: (profile?['name'] ?? json['name']) as String?,
      userEmail: (profile?['email'] ?? json['email']) as String?,
    );
  }

  bool get isStripe => gateway == 'stripe';
  bool get isPagoMovil => gateway == 'pago_movil';
  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';

  String get stripeEmail => providerData['stripe_email'] as String? ?? '---';
}
