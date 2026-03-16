import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum StripePaymentResult { success, cancelled, failed }

class StripeService {
  static bool _initialized = false;

  /// Must be called once at app startup (e.g., in main.dart) on supported platforms.
  static Future<void> init() async {
    if (_initialized) return;

    final publishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'];
    if (publishableKey == null || publishableKey.isEmpty || publishableKey.contains('REEMPLAZAR')) {
      debugPrint('[StripeService] WARNING: STRIPE_PUBLISHABLE_KEY no configurada.');
      return;
    }

    try {
      debugPrint('[StripeService] Intentando inicializar con clave: ${publishableKey.substring(0, 10)}...');
      
      if (kIsWeb) {
        Stripe.publishableKey = publishableKey;
        _initialized = true;
        debugPrint('[StripeService] ✅ Inicializado para Web.');
        return;
      }

      if (_isSupportedPlatform) {
        Stripe.publishableKey = publishableKey;
        await Stripe.instance.applySettings();
        _initialized = true;
        debugPrint('[StripeService] ✅ Inicializado para Móvil.');
      }
    } catch (e) {
      _initialized = false;
      debugPrint('[StripeService] ❌ Error crítico durante la inicialización: $e');
    }
  }

  /// Returns true if Stripe can be used on the current platform.
  static bool get _isSupportedPlatform {
    return kIsWeb || 
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Returns true if Stripe is fully ready to process payments.
  static bool get isAvailable {
    // On Web, we often don't need explicit init if using stripe-js, 
    // but the package handles it if publishableKey is set.
    return _isSupportedPlatform && (kIsWeb || _initialized);
  }

  /// Initiates a Stripe purchase for the given plan ID.
  ///
  /// Flow:
  /// 1. Calls `stripe-create-payment-intent` Edge Function with [planId]
  /// 2. Initializes the Stripe Payment Sheet
  /// 3. Presents the Payment Sheet to the user
  /// 4. Returns a [StripePaymentResult]
  static Future<StripePaymentResult> initiateStripePurchase({
    required String planId,
    required BuildContext context,
  }) async {
    if (!isAvailable) {
      debugPrint('[StripeService] Stripe not available. Init status: $_initialized, Web: $kIsWeb');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El servicio de Stripe no está disponible en este momento. Verifica tu configuración.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return StripePaymentResult.failed;
    }

    try {
      debugPrint('[StripeService] Creating PaymentIntent for plan: $planId');

      // 1. Call the Edge Function to create a PaymentIntent (server-side)
      final FunctionResponse response = await Supabase.instance.client.functions.invoke(
        'stripe-create-payment-intent',
        body: {'plan_id': planId},
      );

      if (response.status != 200) {
        final errorMsg = response.data?['error'] ?? 'Error desconocido del servidor';
        throw Exception('Error al crear pago: $errorMsg (${response.status})');
      }

      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw Exception('Error: ${data['error'] ?? 'Respuesta inválida del servidor'}');
      }

      final paymentData = data['data'] as Map<String, dynamic>;
      final String clientSecret = paymentData['client_secret'] as String;
      final int amountCents = paymentData['amount_cents'] as int;
      final String planName = (paymentData['plan'] as Map<String, dynamic>)['name'] as String;

      debugPrint('[StripeService] PaymentIntent created: ${paymentData['payment_intent_id']}');

      // 2. Initialize the Payment Sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'MapHunter',
          style: ThemeMode.dark,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: Color(0xFFFECB00),       // AppTheme.accentGold
              background: Color(0xFF151517),
              componentBackground: Color(0xFF1E1E21),
              primaryText: Colors.white,
              secondaryText: Color(0xFFAAAAAA),
            ),
            shapes: PaymentSheetShape(
              borderWidth: 1.5,
              borderRadius: 12.0,
            ),
          ),
        ),
      );

      // 3. Present the Payment Sheet
      await Stripe.instance.presentPaymentSheet();

      // If we reach here, payment was successful (no exception thrown)
      debugPrint('[StripeService] ✅ Payment completed successfully!');
      return StripePaymentResult.success;

    } on StripeException catch (e) {
      // Handle Stripe-specific errors
      switch (e.error.code) {
        case FailureCode.Canceled:
          debugPrint('[StripeService] Payment cancelled by user.');
          return StripePaymentResult.cancelled;
        case FailureCode.Failed:
          debugPrint('[StripeService] Payment failed: ${e.error.message}');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Pago fallido: ${e.error.localizedMessage ?? e.error.message ?? "Error desconocido"}'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return StripePaymentResult.failed;
        default:
          debugPrint('[StripeService] Stripe error: ${e.error.code} — ${e.error.message}');
          return StripePaymentResult.failed;
      }
    } catch (e) {
      debugPrint('[StripeService] Unexpected error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error inesperado: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return StripePaymentResult.failed;
    }
  }
}
