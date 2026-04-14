import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

enum StripePaymentResult { success, cancelled, failed }

/// Result of a Stripe payment including any new customer data created.
class StripePaymentResultData {
  final StripePaymentResult result;
  final String? stripeCustomerId;

  const StripePaymentResultData({
    required this.result,
    this.stripeCustomerId,
  });
}

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
        // On Web, we don't need Stripe.instance or applySettings() 
        // because we use url_launcher with Stripe Checkout in initiateStripePurchase.
        // Direct package initialization causes "Platform._operatingSystem" errors.
        _initialized = true;
        debugPrint('[StripeService] ✅ Inicializado para Web (Redirect Mode).');
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
    return _isSupportedPlatform && (kIsWeb || _initialized);
  }

  /// Initiates a Stripe purchase for the given plan ID.
  ///
  /// Parameters:
  /// - [planId]: ID of the plan to purchase
  /// - [context]: BuildContext for showing Snackbars
  /// - [saveCard]: Whether to save card for future purchases (default false)
  /// - [stripeCustomerId]: Existing Stripe Customer ID to preload saved card
  ///
  /// Returns [StripePaymentResultData] with the result and any newly created customer ID.
  static Future<StripePaymentResultData> initiateStripePurchase({
    required String planId,
    required BuildContext context,
    bool saveCard = false,
    String? stripeCustomerId,
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
      return const StripePaymentResultData(result: StripePaymentResult.failed);
    }

    try {
      debugPrint('[StripeService] Creating PaymentIntent for plan: $planId, saveCard: $saveCard');

      // 1. Call the Edge Function to create a PaymentIntent (server-side)
      final FunctionResponse response = await Supabase.instance.client.functions.invoke(
        'stripe-create-payment-intent',
        body: {
          'plan_id': planId,
          'is_web': kIsWeb,
          'success_url': kIsWeb ? Uri.base.toString().split('?').first : null,
          'cancel_url': kIsWeb ? Uri.base.toString().split('?').first : null,
          'save_card': saveCard,
        },
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
      final String clientSecret = (paymentData['client_secret'] as String?) ?? '';
      final String checkoutUrl = (paymentData['checkout_url'] as String?) ?? '';
      final int amountCents = paymentData['amount_cents'] as int;
      final String planName = (paymentData['plan'] as Map<String, dynamic>)['name'] as String;

      // Stripe Customer data returned from the Edge Function
      final String? returnedCustomerId = paymentData['stripe_customer_id'] as String?;
      final String? ephemeralKeySecret = paymentData['ephemeral_key_secret'] as String?;

      debugPrint('[StripeService] PaymentIntent created: ${paymentData['payment_intent_id'] ?? 'N/A'}, Customer: ${returnedCustomerId ?? 'none'}');

      if (kIsWeb) {
        if (checkoutUrl.isEmpty) {
          throw Exception('No se recibió URL de Checkout para Web');
        }
        debugPrint('[StripeService] Redirigiendo a Stripe Checkout: $checkoutUrl');
        
        if (await canLaunchUrl(Uri.parse(checkoutUrl))) {
          await launchUrl(
            Uri.parse(checkoutUrl),
            webOnlyWindowName: '_self',
          );
          return StripePaymentResultData(
            result: StripePaymentResult.success,
            stripeCustomerId: returnedCustomerId,
          );
        } else {
          throw Exception('No se pudo abrir la URL de pago');
        }
      }

      // 2. Initialize the Payment Sheet
      // If we have a customer ID + ephemeral key, pass them for a personalized experience
      // (shows saved cards, allows Stripe Link, etc.)
      final SetupPaymentSheetParameters sheetParams = (returnedCustomerId != null && ephemeralKeySecret != null)
          ? SetupPaymentSheetParameters(
              paymentIntentClientSecret: clientSecret,
              merchantDisplayName: 'MapHunter',
              customerId: returnedCustomerId,
              customerEphemeralKeySecret: ephemeralKeySecret,
              style: ThemeMode.dark,
              appearance: const PaymentSheetAppearance(
                colors: PaymentSheetAppearanceColors(
                  primary: Color(0xFFFECB00),
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
            )
          : SetupPaymentSheetParameters(
              paymentIntentClientSecret: clientSecret,
              merchantDisplayName: 'MapHunter',
              style: ThemeMode.dark,
              appearance: const PaymentSheetAppearance(
                colors: PaymentSheetAppearanceColors(
                  primary: Color(0xFFFECB00),
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
            );

      await Stripe.instance.initPaymentSheet(paymentSheetParameters: sheetParams);

      // 3. Present the Payment Sheet
      await Stripe.instance.presentPaymentSheet();

      // If we reach here, payment was successful (no exception thrown)
      debugPrint('[StripeService] ✅ Payment completed successfully! Customer: $returnedCustomerId');
      return StripePaymentResultData(
        result: StripePaymentResult.success,
        stripeCustomerId: returnedCustomerId,
      );

    } on StripeException catch (e) {
      final String code = e.error.code.toString();
      final String? declineCode = e.error.declineCode;
      final String? message = e.error.localizedMessage ?? e.error.message;
      
      debugPrint('[StripeService] ❌ Stripe error: $code');
      if (declineCode != null) debugPrint('[StripeService] 🚩 Decline code: $declineCode');
      debugPrint('[StripeService] 📝 Message: $message');
      debugPrint('[StripeService] 🔍 Full Error Object: ${e.error.toJson()}');

      switch (e.error.code) {
        case FailureCode.Canceled:
          debugPrint('[StripeService] Payment cancelled by user.');
          return const StripePaymentResultData(result: StripePaymentResult.cancelled);
        default:
          // Show detailed error for ANY other Stripe failure, not just FailureCode.Failed
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Pago fallido: $message ${declineCode != null ? "($declineCode)" : ""}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 10),
                action: SnackBarAction(
                  label: 'VER MÁS',
                  textColor: Colors.white,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Detalle del Rechazo'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Código del error: ${e.error.code}'),
                            const SizedBox(height: 8),
                            Text('Motivo técnico (Decline): ${declineCode ?? "No disponible"}'),
                            const SizedBox(height: 8),
                            Text('Mensaje de Stripe: $message'),
                            const SizedBox(height: 12),
                            const Text(
                              'Sugerencia: Si es una tarjeta real, verifica si tiene activadas las compras internacionales/online.',
                              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Entendido'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          }
          return const StripePaymentResultData(result: StripePaymentResult.failed);
      }
    } catch (e) {
      debugPrint('[StripeService] Unexpected error type: ${e.runtimeType}');
      debugPrint('[StripeService] Error details: $e');
      
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Error en el Proceso'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ha ocurrido un error inesperado al procesar el pago.'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.grey[200],
                  child: Text(
                    e.toString(),
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
      return const StripePaymentResultData(result: StripePaymentResult.failed);
    }
  }
}
