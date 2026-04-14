import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../auth/providers/player_provider.dart';
import '../providers/payment_method_provider.dart';
import '../repositories/payment_method_repository.dart';

class AddWithdrawalMethodDialog extends StatefulWidget {
  final String? initialType;

  const AddWithdrawalMethodDialog({super.key}) : initialType = null;

  const AddWithdrawalMethodDialog.withInitialType({
    super.key,
    required this.initialType,
  });

  @override
  State<AddWithdrawalMethodDialog> createState() => _AddWithdrawalMethodDialogState();
}

class _AddWithdrawalMethodDialogState extends State<AddWithdrawalMethodDialog> {
  final _formKey = GlobalKey<FormState>();
  String _selectedType = 'pago_movil'; // 'pago_movil', 'stripe' or 'paypal'
  String? _selectedBankCode;
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null && widget.initialType!.isNotEmpty) {
      _selectedType = widget.initialType!;
    }
  }

  final List<Map<String, String>> _banks = [
    {'code': '0102', 'name': 'Banco de Venezuela'},
    {'code': '0104', 'name': 'Venezolano de Crédito'},
    {'code': '0105', 'name': 'Banco Mercantil'},
    {'code': '0108', 'name': 'Banco Provincial'},
    {'code': '0114', 'name': 'Bancaribe'},
    {'code': '0115', 'name': 'Banco Exterior'},
    {'code': '0128', 'name': 'Banco Caroní'},
    {'code': '0134', 'name': 'Banesco'},
    {'code': '0137', 'name': 'Banco Sofitasa'},
    {'code': '0138', 'name': 'Banco Plaza'},
    {'code': '0151', 'name': 'BFC Fondo Común'},
    {'code': '0156', 'name': '100% Banco'},
    {'code': '0157', 'name': 'DelSur'},
    {'code': '0163', 'name': 'Banco del Tesoro'},
    {'code': '0166', 'name': 'Banco Agrícola de Venezuela'},
    {'code': '0168', 'name': 'Bancrecer'},
    {'code': '0169', 'name': 'Mi Banco'},
    {'code': '0171', 'name': 'Banco Activo'},
    {'code': '0172', 'name': 'Bancamiga'},
    {'code': '0174', 'name': 'Banplus'},
    {'code': '0175', 'name': 'Banco Bicentenario'},
    {'code': '0177', 'name': 'BANFANB'},
    {'code': '0178', 'name': 'N58 Banco Digital'},
    {'code': '0191', 'name': 'Banco Nacional de Crédito'},
  ];

  Future<void> _saveMethod() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedType == 'pago_movil' && _selectedBankCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un banco')),
      );
      return;
    }

    if (_selectedType == 'stripe' || _selectedType == 'paypal') {
      final email = _emailController.text.trim();
      if (email.isEmpty) {
        final label = _selectedType == 'stripe' ? 'Stripe' : 'PayPal';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ingresa tu email de $label')),
        );
        return;
      }
      final bool emailValid = 
          RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
              .hasMatch(email);
      if (!emailValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ingresa un email válido')),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
      final paymentProvider = Provider.of<PaymentMethodProvider>(context, listen: false);
      final player = playerProvider.currentPlayer;

      if (player == null) throw Exception('Usuario no identificado');
      if (_selectedType == 'pago_movil' && 
          (player.cedula == null || player.phone == null)) {
         throw Exception('Perfil incompleto (DNI y Teléfono requeridos para Pago Móvil)');
      }

      final data = PaymentMethodCreate(
        userId: player.userId,
        type: _selectedType,
        bankCode: _selectedType == 'pago_movil' ? _selectedBankCode : null,
        phoneNumber: _selectedType == 'pago_movil' ? player.phone : null,
        dni: _selectedType == 'pago_movil' ? player.cedula : null,
        identifier: (_selectedType == 'stripe' || _selectedType == 'paypal') ? _emailController.text.trim() : null,
        isDefault: false,
      );

      final success = await paymentProvider.createMethod(data);

      if (mounted) {
        if (success) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Método de retiro agregado'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(paymentProvider.error ?? 'Error desconocido'),
              backgroundColor: AppTheme.dangerRed,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerProvider>(context, listen: false).currentPlayer;
    final dni = player?.cedula ?? '---';
    final phone = player?.phone ?? '---';

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: AppTheme.accentGold.withOpacity(0.1),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.accentGold.withOpacity(0.2), width: 1),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF151517),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.accentGold.withOpacity(0.5), width: 1.5),
          ),
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildTypeSelector(
                        'P. MÓVIL', 
                        AppTheme.secondaryPink, 
                        _selectedType == 'pago_movil',
                        () => setState(() => _selectedType = 'pago_movil'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTypeSelector(
                        'STRIPE', 
                        const Color(0xFF635BFF), 
                        _selectedType == 'stripe',
                        () => setState(() => _selectedType = 'stripe'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTypeSelector(
                        'PAYPAL', 
                        const Color(0xFF0070BA), 
                        _selectedType == 'paypal',
                        () => setState(() => _selectedType = 'paypal'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_selectedType == 'pago_movil') ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryPink.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.secondaryPink.withOpacity(0.3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.lock_outline, color: AppTheme.secondaryPink, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Por seguridad, solo puedes retirar a cuentas asociadas a tu identidad registrada.',
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildReadOnlyField('Cédula de Identidad', dni, Icons.badge),
                        const SizedBox(height: 12),
                        _buildReadOnlyField('Teléfono Móvil', phone, Icons.phone_android),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          dropdownColor: const Color(0xFF1C1C1E),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          hint: const Text(
                            'Selecciona tu banco',
                            style: TextStyle(color: Colors.white60, fontSize: 14),
                          ),
                          decoration: _inputDecoration('Banco'),
                          value: _selectedBankCode,
                          isExpanded: true,
                          menuMaxHeight: 300,
                          selectedItemBuilder: (BuildContext context) {
                            return _banks.map<Widget>((bank) {
                              return Text(
                                '${bank['code']} - ${bank['name']}',
                                style: const TextStyle(color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              );
                            }).toList();
                          },
                          items: _banks.map((bank) {
                            return DropdownMenuItem(
                              value: bank['code'],
                              child: Text(
                                '${bank['code']} - ${bank['name']}',
                                style: const TextStyle(color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedBankCode = val),
                        ),
                      ] else ...[
                        Text(
                          _selectedType == 'stripe' ? 'CONFIGURACIÓN STRIPE' : 'CONFIGURACIÓN PAYPAL',
                          style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: _inputDecoration('Email de tu cuenta ${_selectedType == 'stripe' ? 'Stripe' : 'PayPal'}').copyWith(
                            prefixIcon: Icon(
                              Icons.email_outlined, 
                              color: _selectedType == 'stripe' ? const Color(0xFF635BFF) : const Color(0xFF0070BA), 
                              size: 20
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Por favor ingresa un email';
                            if (!value.contains('@')) return 'Email inválido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (_selectedType == 'stripe' ? const Color(0xFF635BFF) : const Color(0xFF0070BA)).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (_selectedType == 'stripe' ? const Color(0xFF635BFF) : const Color(0xFF0070BA)).withOpacity(0.3)
                            ),
                          ),
                          child: Text(
                            'Asegúrate de que este email corresponde a tu cuenta de ${_selectedType == 'stripe' ? 'Stripe' : 'PayPal'} para evitar retrasos en el procesamiento.',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        child: const Text('CANCELAR', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveMethod,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedType == 'pago_movil' 
                            ? AppTheme.accentGold 
                            : (_selectedType == 'stripe' ? const Color(0xFF635BFF) : const Color(0xFF0070BA)),
                          foregroundColor: _selectedType == 'pago_movil' ? Colors.black : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2, 
                                color: _selectedType == 'pago_movil' ? Colors.black : Colors.white
                              ),
                            )
                          : const Text('GUARDAR', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector(String label, Color color, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : Colors.white.withOpacity(0.1),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white38,
            fontSize: 9, // Reduced font size to fit 3 items
            fontWeight: FontWeight.bold,
            fontFamily: 'Orbitron',
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white38, size: 20),
              const SizedBox(width: 12),
              Text(
                value,
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              const Spacer(),
              const Icon(Icons.lock, color: Colors.white24, size: 16),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white60),
      filled: true,
      fillColor: const Color(0xFF1C1C1E),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppTheme.accentGold),
        borderRadius: BorderRadius.circular(10),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}
