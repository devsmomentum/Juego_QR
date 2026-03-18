import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/app_config_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/player_provider.dart';
import '../providers/payment_method_provider.dart';
import 'add_withdrawal_method_dialog.dart';

/// Modal widget for manual Pago Móvil payment validation.
///
/// Shows the validation code (concept), lets the user select an existing
/// pago móvil or add a new one, and input the transfer reference.
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
  static const Map<String, String> _bankNames = {
    '0102': 'Banco de Venezuela',
    '0104': 'Venezolano de Crédito',
    '0105': 'Banco Mercantil',
    '0108': 'Banco Provincial',
    '0114': 'Bancaribe',
    '0115': 'Banco Exterior',
    '0128': 'Banco Caroní',
    '0134': 'Banesco',
    '0137': 'Banco Sofitasa',
    '0138': 'Banco Plaza',
    '0151': 'BFC Fondo Común',
    '0156': '100% Banco',
    '0157': 'DelSur',
    '0163': 'Banco del Tesoro',
    '0166': 'Banco Agrícola',
    '0168': 'Bancrecer',
    '0169': 'R4',
    '0171': 'Banco Activo',
    '0172': 'Bancamiga',
    '0174': 'Banplus',
    '0175': 'Banco Bicentenario',
    '0177': 'BANFANB',
    '0178': 'N58 Banco Digital',
    '0191': 'BNC',
  };

  final _formKey = GlobalKey<FormState>();
  final _referenceController = TextEditingController();

  bool _isValidating = false;
  bool _isLoadingMethods = true;
  String? _errorMessage;
  bool _codeCopied = false;
  bool _dataCopied = false;

  List<Map<String, dynamic>> _paymentMethods = [];
  String? _selectedMethodId;
  String? _selectedPhone;

  // Recipient data from app_config
  String _recipientBanco = '';
  String _recipientCedula = '';
  String _recipientTelefono = '';

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
    _loadRecipientData();
  }

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentMethods() async {
    setState(() => _isLoadingMethods = true);
    try {
      final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
      final userId = playerProvider.currentPlayer?.userId;
      if (userId == null) return;

      final methods = await Supabase.instance.client
          .from('user_payment_methods')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _paymentMethods = List<Map<String, dynamic>>.from(methods);
        // Auto-select first method if available
        if (_paymentMethods.isNotEmpty && _selectedMethodId == null) {
          _selectedMethodId = _paymentMethods.first['id']?.toString();
          _selectedPhone = _paymentMethods.first['phone_number']?.toString();
        }
      });
    } catch (e) {
      debugPrint('[PaymentValidation] Error loading methods: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMethods = false);
    }
  }

  Future<void> _loadRecipientData() async {
    try {
      final configService = AppConfigService(supabaseClient: Supabase.instance.client);
      final data = await configService.getPagoMovilRecipient();
      if (!mounted) return;
      setState(() {
        _recipientBanco = data['banco'] ?? '';
        _recipientCedula = data['cedula'] ?? '';
        _recipientTelefono = data['telefono'] ?? '';
      });
    } catch (e) {
      debugPrint('[PaymentValidation] Error loading recipient data: $e');
    }
  }

  Future<void> _openAddMethodDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const AddWithdrawalMethodDialog(),
    );
    if (result == true) {
      await _loadPaymentMethods();
    }
  }

  Future<void> _validate() async {
    if (_selectedPhone == null || _selectedPhone!.isEmpty) {
      setState(() => _errorMessage = 'Selecciona un pago móvil');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isValidating = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'validate_mpay_api',
        body: {
          'order_id': widget.orderId,
          'phone': _selectedPhone!,
          'reference': _referenceController.text.trim(),
          'concept': widget.validationCode,
        },
      );

      if (!mounted) return;

      final data = response.data as Map<String, dynamic>?;

      if (response.status == 200 && data?['success'] == true && data?['claimed'] == true) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _errorMessage =
              data?['error'] ?? data?['message'] ?? 'Error desconocido';
        });
      }
    } on FunctionException catch (e) {
      if (!mounted) return;
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
                const SizedBox(height: 16),

                // Recipient Data Section
                if (_recipientBanco.isNotEmpty || _recipientCedula.isNotEmpty || _recipientTelefono.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.12),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'DATOS DEL DESTINATARIO',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_recipientBanco.isNotEmpty)
                          _buildRecipientRow(
                            Icons.account_balance_rounded,
                            'Banco',
                            _bankNames[_recipientBanco] ?? 'Banco $_recipientBanco',
                          ),
                        if (_recipientCedula.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildRecipientRow(
                            Icons.badge_outlined,
                            'Cédula',
                            'V$_recipientCedula',
                          ),
                        ],
                        if (_recipientTelefono.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildRecipientRow(
                            Icons.phone_rounded,
                            'Teléfono',
                            _recipientTelefono,
                          ),
                        ],
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              final montoStr = widget.amountVes != null
                                  ? widget.amountVes!.toStringAsFixed(2)
                                  : '---';
                              final copyText = '$_recipientBanco\nV$_recipientCedula\n$_recipientTelefono\n$montoStr Bs';
                              Clipboard.setData(ClipboardData(text: copyText));
                              setState(() => _dataCopied = true);
                              Future.delayed(const Duration(seconds: 2), () {
                                if (mounted) setState(() => _dataCopied = false);
                              });
                            },
                            icon: Icon(
                              _dataCopied ? Icons.check : Icons.copy_all_rounded,
                              size: 16,
                              color: _dataCopied ? AppTheme.successGreen : AppTheme.accentGold,
                            ),
                            label: Text(
                              _dataCopied ? 'Copiado' : 'Copiar datos',
                              style: TextStyle(
                                color: _dataCopied ? AppTheme.successGreen : AppTheme.accentGold,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: (_dataCopied ? AppTheme.successGreen : AppTheme.accentGold).withOpacity(0.5),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // Pago Móvil Selector Section
                _buildPaymentMethodSelector(),
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
                        onPressed: (_isValidating || _selectedPhone == null) ? null : _validate,
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

  Widget _buildPaymentMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'PAGO MÓVIL EMISOR',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
            GestureDetector(
              onTap: _isValidating ? null : _openAddMethodDialog,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_circle_outline,
                      color: AppTheme.accentGold, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Añadir nuevo',
                    style: TextStyle(
                      color: AppTheme.accentGold,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_isLoadingMethods)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.accentGold,
                ),
              ),
            ),
          )
        else if (_paymentMethods.isEmpty)
          GestureDetector(
            onTap: _openAddMethodDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.accentGold.withOpacity(0.3),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  Icon(Icons.account_balance_outlined,
                      size: 32, color: Colors.white24),
                  const SizedBox(height: 8),
                  const Text(
                    'No tienes pago móvil registrado',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Toca para añadir uno',
                    style: TextStyle(
                      color: AppTheme.accentGold,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...(_paymentMethods.map((method) {
            final methodId = method['id']?.toString();
            final isSelected = _selectedMethodId == methodId;
            final bankCode = method['bank_code'] ?? '???';
            final phone = method['phone_number'] ?? '???';
            final bankName = _bankNames[bankCode] ?? 'Banco $bankCode';

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: _isValidating
                    ? null
                    : () {
                        setState(() {
                          _selectedMethodId = methodId;
                          _selectedPhone = phone;
                        });
                      },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.accentGold.withOpacity(0.1)
                        : Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.accentGold
                          : Colors.white.withOpacity(0.1),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.accentGold.withOpacity(0.15)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.account_balance_rounded,
                          color: isSelected
                              ? AppTheme.accentGold
                              : Colors.white38,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bankName,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white70,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatPhoneDisplay(phone),
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white70
                                    : Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle,
                            color: AppTheme.accentGold, size: 20),
                    ],
                  ),
                ),
              ),
            );
          })),
      ],
    );
  }

  /// Converts E.164 phone (+584121234567) to local display (04121234567)
  String _formatPhoneDisplay(String phone) {
    if (phone.startsWith('+58')) {
      return '0${phone.substring(3)}';
    }
    if (phone.startsWith('58') && phone.length >= 12) {
      return '0${phone.substring(2)}';
    }
    return phone;
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

  Widget _buildRecipientRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white38, size: 16),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
