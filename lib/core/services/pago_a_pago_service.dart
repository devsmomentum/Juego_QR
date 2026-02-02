import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Added
import '../models/pago_a_pago_models.dart';
import '../../features/social/screens/wallet_screen.dart'; // To access any constants if needed, or moved here.

class PagoAPagoService {
  // BASE URL from documentation (Your Supabase Project)
  static const String _baseUrl = 'https://hyjelngckvqoanckqwep.supabase.co/functions/v1';
  
  // API KEY placeholder - SHOULD BE IN .ENV but hardcoded placeholder for now as requested
  static const String _apiKeyPlaceholder = 'PAGO_PAGO_API_KEY_AQUI'; 

  final String apiKey;

  PagoAPagoService({required this.apiKey});

  Future<PaymentOrderResponse> createPaymentOrder(PaymentOrderRequest request, String authToken) async {
    // Legacy/Full implementation
    final url = Uri.parse('$_baseUrl/api_pay_orders');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode(request.toJson()),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return PaymentOrderResponse.fromJson(jsonDecode(response.body));
      } else {
         return PaymentOrderResponse(success: false, message: 'Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      return PaymentOrderResponse(success: false, message: 'Excepción: $e');
    }
  }

  // New simplified implementation requested by user
  Future<PaymentOrderResponse> createSimplePaymentOrder({required double amountBs}) async {
    // Uses PAGO_PAGO_API_URL from env ideally, but here we can use _baseUrl/api_pay_orders or hardcode if different.
    // The user said PAGO_PAGO_API_URL in .env is .../api_pay_orders.
    // We'll use the .env URL passed or construct it.
    // Since _baseUrl is hardcoded in this file, we might need to rely on that or passed param.
    // But wait, the class is initialized with apiKey. 
    // We should probably pass the full URL to the service or use the one hardcoded if it matches.
    // The .env URL is https://mqlboutjgscjgogqbsjc.supabase.co/functions/v1/api_pay_orders
    // The _baseUrl is https://hyjelngckvqoanckqwep.supabase.co/functions/v1
    // THEY ARE DIFFERENT HOSTS.
    // I must use the PAGO_PAGO_API_URL from .env. 
    // I will allow passing the URL or updating the class to use dotenv.
    
    // For now, I'll allow passing the URL or assume it's passed in constructor? 
    // The current constructor only takes apiKey.
    // I should update the calling side to pass it or read dotenv here.
    // Reading dotenv here is safer if I import it.
    
    // Let's assume the caller will instantiate with the correct URL or I'll read .env here.
    // I'll add dotenv import.
    
    final apiUrl = dotenv.env['PAGO_PAGO_API_URL'];
    if (apiUrl == null) return PaymentOrderResponse(success: false, message: 'PAGO_PAGO_API_URL not found in .env');
    
    final url = Uri.parse(apiUrl);
    
    try {
      debugPrint('PagoAPagoService: Sending simple payment for $amountBs Bs');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'pago_pago_api': apiKey, // Use the apiKey passed in constructor
        },
        body: jsonEncode({
          "amount": amountBs,
        }),
      );

      debugPrint('PagoAPagoService: Response status: ${response.statusCode}');
      debugPrint('PagoAPagoService: Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
         final jsonResponse = jsonDecode(response.body);
         return PaymentOrderResponse.fromJson(jsonResponse);
      } else {
         return PaymentOrderResponse(
          success: false, 
          message: 'Error ${response.statusCode}: ${response.body}'
        );
      }
    } catch (e) {
      debugPrint('PagoAPagoService: Exception: $e');
      return PaymentOrderResponse(success: false, message: 'Excepción: $e');
    }
  }

  Future<bool> cancelOrder(String orderId) async {
    final url = Uri.parse('$_baseUrl/api_cancel_order');
    try {
      final response = await http.put(
        url,
         headers: {
          'Content-Type': 'application/json',
          'pago_pago_api': apiKey,
        },
        body: jsonEncode({'order_id': orderId}),
      );
      
      return response.statusCode == 200;
    } catch (e) {
       debugPrint('PagoAPagoService: Cancel error: $e');
       return false;
    }
  }
  Future<WithdrawalResponse> withdrawFunds(WithdrawalRequest request, String authToken) async {
    final url = Uri.parse('$_baseUrl/api_withdraw_funds');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode(request.toJson()),
      );

      debugPrint('Withdrawal Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return WithdrawalResponse.fromJson(jsonDecode(response.body));
      } else {
         final errorBody = jsonDecode(response.body);
         return WithdrawalResponse(
           success: false, 
           message: errorBody['error'] ?? errorBody['message'] ?? 'Error ${response.statusCode}'
         );
      }
    } catch (e) {
      return WithdrawalResponse(success: false, message: 'Error de red: $e');
    }
  }
}
