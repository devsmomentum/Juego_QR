import 'package:supabase_flutter/supabase_flutter.dart';

class StripeConnectService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Crea una cuenta Express de Stripe para el usuario si no existe
  Future<String?> createAccount() async {
    try {
      final response = await _supabase.functions.invoke(
        'stripe-connect-flow',
        body: {'action': 'create_account'},
      );

      if (response.status == 200) {
        return response.data['account_id'];
      }
      return null;
    } catch (e) {
      print('Error creating Stripe account: $e');
      return null;
    }
  }

  /// Genera un enlace de onboarding para que el usuario complete sus datos
  Future<String?> createOnboardingLink() async {
    try {
      final response = await _supabase.functions.invoke(
        'stripe-connect-flow',
        body: {'action': 'create_link'},
      );

      if (response.status == 200) {
        return response.data['url'];
      }
      return null;
    } catch (e) {
      print('Error creating onboarding link: $e');
      return null;
    }
  }

  /// Obtiene el estado actual de la cuenta conectada
  Future<Map<String, dynamic>?> getAccountStatus() async {
    try {
      final response = await _supabase.functions.invoke(
        'stripe-connect-flow',
        body: {'action': 'get_status'},
      );

      if (response.status == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      print('Error getting account status: $e');
      return null;
    }
  }
}
