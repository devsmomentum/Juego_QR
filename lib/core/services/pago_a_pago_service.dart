import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pago_a_pago_models.dart';

/// Service that proxies all payment operations through Supabase Edge Functions.
/// 
/// No API keys or sensitive credentials are handled client-side.
/// All secrets (PAGO_PAGO_API_KEY, etc.) live exclusively in Edge Function env vars.
class PagoAPagoService {
  final SupabaseClient _client;

  PagoAPagoService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Creates a payment order via the `api_pay_orders` Edge Function.
  /// The Edge Function validates the plan server-side and fetches the price from DB.
  Future<PaymentOrderResponse> createPaymentOrder({required String planId}) async {
    try {
      debugPrint('[PagoAPagoService] Invoking api_pay_orders for plan: $planId');

      final response = await _client.functions.invoke(
        'api_pay_orders',
        body: {'plan_id': planId},
      );

      debugPrint('[PagoAPagoService] Response status: ${response.status}');

      if (response.status == 200) {
        return PaymentOrderResponse.fromJson(response.data);
      } else {
        return PaymentOrderResponse(
          success: false,
          message: 'Error ${response.status}: ${response.data}',
        );
      }
    } catch (e) {
      debugPrint('[PagoAPagoService] Exception: $e');
      if (e is FunctionException) {
        return PaymentOrderResponse(
          success: false,
          message: 'Error: ${e.details} (${e.reasonPhrase})',
        );
      }
      return PaymentOrderResponse(success: false, message: 'Excepción: $e');
    }
  }

  /// Cancels a pending order via the `api_cancel_order` Edge Function.
  /// The API key is handled server-side — never sent from the client.
  Future<bool> cancelOrder(String orderId) async {
    try {
      debugPrint('[PagoAPagoService] Cancelling order: $orderId');

      final response = await _client.functions.invoke(
        'api_cancel_order',
        body: {'order_id': orderId},
      );

      return response.status == 200;
    } catch (e) {
      debugPrint('[PagoAPagoService] Cancel error: $e');
      return false;
    }
  }

  /// Processes a withdrawal via the `api_withdraw_funds` Edge Function.
  /// Sends plan_id; the Edge Function validates price/balance server-side.
  Future<WithdrawalResponse> withdrawFunds(WithdrawalRequest request) async {
    try {
      debugPrint('[PagoAPagoService] Invoking api_withdraw_funds...');

      final response = await _client.functions.invoke(
        'api_withdraw_funds',
        body: request.toJson(),
      );

      debugPrint('[PagoAPagoService] Withdrawal status: ${response.status}');

      if (response.status == 200) {
        return WithdrawalResponse.fromJson(response.data);
      } else {
        final errorData = response.data;
        return WithdrawalResponse(
          success: false,
          message: errorData?['error'] ?? errorData?['message'] ?? 'Error ${response.status}',
        );
      }
    } catch (e) {
      debugPrint('[PagoAPagoService] Withdrawal exception: $e');
      if (e is FunctionException) {
        return WithdrawalResponse(
          success: false,
          message: 'Error: ${e.details} (${e.reasonPhrase})',
        );
      }
      return WithdrawalResponse(success: false, message: 'Error de red: $e');
    }
  }

  /// Validates a Pago Móvil payment via the `validate_mpay_api` Edge Function.
  Future<Map<String, dynamic>> validateMpayPayment({
    required String orderId,
    required String phone,
    required String reference,
    required String concept,
  }) async {
    try {
      debugPrint('[PagoAPagoService] Validating mpay for order: $orderId');

      final response = await _client.functions.invoke(
        'validate_mpay_api',
        body: {
          'order_id': orderId,
          'phone': phone,
          'reference': reference,
          'concept': concept,
        },
      );

      debugPrint('[PagoAPagoService] Mpay validation status: ${response.status}');

      if (response.status == 200 && response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return {'success': false, 'message': 'Error ${response.status}: ${response.data}'};
    } catch (e) {
      debugPrint('[PagoAPagoService] Mpay validation exception: $e');
      if (e is FunctionException) {
        return {'success': false, 'message': 'Error: ${e.details} (${e.reasonPhrase})'};
      }
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }
}
