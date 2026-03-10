import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';

/// Modal widget for manual Pago Móvil payment validation.
///
/// Shows the validation code (concept), and allows the user to input
/// their phone number and transfer reference to validate the payment.
class PaymentValidationWidget extends StatefulWidget {
  /// The clover_orders.id (UUID) of the pending order.
  final String orderId;

  /// The validation_code the user must use as "Concepto" in their transfer.
  final String validationCode;

  /// VES amount to display to the user.
  final double? amountVes;

  const PaymentValidationWidget({
    super.key,
    required this.orderId,
    required this.validationCode,
    this.amountVes,
  });

  @override
  State<PaymentValidationWidget> createState() =>
      _PaymentValidationWidgetState();
}

class _PaymentValidationWidgetState extends State<PaymentValidationWidget> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _referenceController = TextEditingController();

  bool _isValidating = false;
  String? _errorMessage;
  bool _codeCopied = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _validate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isValidating = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'validate-mpay-payment',
        body: {
          'order_id': widget.orderId,
          'phone': _phoneController.text.trim(),
          'reference': _referenceController.text.trim(),
          'concept': widget.validationCode,
        },
      );

      if (!mounted) return;

      final data = response.data as Map<String, dynamic>?;

      if (response.status == 200 && data?['success'] == true) {
        // Success — return true to parent
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _errorMessage =
              data?['error'] ?? data?['message'] ?? 'Error desconocido';
        });
      }
    } on FunctionException catch (e) {
      if (!mounted) return;
      // Parse the error from the edge function response
      final details = e.details;
      String message = 'Error al validar el pago';
      if (details is Map) {
        message = (details['error'] ?? details['message'] ?? message).toString();
      }
      setState(() => _errorMessage = message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Error de conexión: $e');
    } finally {
      if (mounted) setState(() => _isValidating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppTheme.accentGold.withOpacity(0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border.all(
          color: AppTheme.accentGold.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        decoration: BoxDecoration(
          color: const Color(0xFF151517),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(
            color: AppTheme.accentGold.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Row(
                  children: [
                    Icon(Icons.phone_android,
                        color: AppTheme.accentGold, size: 22),
                    const SizedBox(width: 12),
                    const Text(
                      'Validar Pago Móvil',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        fontFamily: 'Orbitron',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Validation Code Section
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.accentGold.withOpacity(0.4),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'CONCEPTO DE PAGO',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.validationCode,
                            style: TextStyle(
                              color: AppTheme.accentGold,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Orbitron',
                              letterSpacing: 4,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              _codeCopied ? Icons.check : Icons.copy,
                              color: _codeCopied
                                  ? AppTheme.successGreen
                                  : Colors.white54,
                              size: 20,
                            ),
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: widget.validationCode),
                              );
                              setState(() => _codeCopied = true);
                              Future.delayed(const Duration(seconds: 2), () {
                                if (mounted) {
                                  setState(() => _codeCopied = false);
                                }
                              });
                            },
                            tooltip: 'Copiar código',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Usa este código como concepto al hacer tu transferencia de Pago Móvil',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      if (widget.amountVes != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Monto: ${widget.amountVes!.toStringAsFixed(2)} Bs',
                          style: TextStyle(
                            color: AppTheme.accentGold,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Phone Field
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration(
                    label: 'Teléfono',
                    hint: '04121234567',
                    icon: Icons.phone,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingresa el teléfono';
                    }
                    if (value.length < 10) {
                      return 'Teléfono inválido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Reference Field
                TextFormField(
                  controller: _referenceController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(8),
                  ],
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration(
                    label: 'Referencia',
                    hint: '12345678',
                    icon: Icons.receipt_long,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingresa la referencia';
                    }
                    if (value.length < 4) {
                      return 'Mínimo 4 dígitos';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Error Message
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.dangerRed.withOpacity(0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: AppTheme.dangerRed, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: AppTheme.dangerRed,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed:
                            _isValidating ? null : () => Navigator.pop(context, false),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isValidating ? null : _validate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentGold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isValidating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Text(
                                'Validar Pago',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),

                // Bottom padding for keyboard
                SizedBox(
                    height: MediaQuery.of(context).viewInsets.bottom > 0
                        ? 16
                        : 0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: AppTheme.accentGold.withOpacity(0.7)),
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
      filled: true,
      fillColor: const Color(0xFF1A1A1D),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppTheme.accentGold, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppTheme.dangerRed),
      ),
    );
  }
}
