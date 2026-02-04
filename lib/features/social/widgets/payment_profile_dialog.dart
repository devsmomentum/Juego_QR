import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../../core/theme/app_theme.dart';

class PaymentProfileDialog extends StatefulWidget {
  const PaymentProfileDialog({super.key});

  @override
  State<PaymentProfileDialog> createState() => _PaymentProfileDialogState();
}

class _PaymentProfileDialogState extends State<PaymentProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  String _documentType = 'V';
  final TextEditingController _dniController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill user data if available
    final player = Provider.of<PlayerProvider>(context, listen: false).currentPlayer;
    if (player != null) {
      if (player.documentType != null) {
         _documentType = player.documentType!;
      }
      if (player.cedula != null) {
         _dniController.text = player.cedula!;
      }
      if (player.phone != null) {
         _phoneController.text = player.phone!;
      }
    }
  }

  @override
  void dispose() {
    _dniController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    final fullDni = '$_documentType${_dniController.text.trim()}';

    try {
      await Provider.of<PlayerProvider>(context, listen: false).updateProfile(
        cedula: fullDni,
        phone: _phoneController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context, true); // Return true on success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil de pago actualizado'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
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
    return AlertDialog(
      backgroundColor: AppTheme.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppTheme.accentGold.withOpacity(0.3)),
      ),
      title: Row(
        children: [
          const Icon(Icons.person_pin, color: AppTheme.accentGold),
          const SizedBox(width: 12),
          const Text(
            'Completar Datos',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Para realizar operaciones de pago móvil, necesitamos completar tu perfil.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 20),
              
              // Document Type & DNI Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Document Type Dropdown
                  Container(
                    width: 70,
                    margin: const EdgeInsets.only(right: 12),
                    child: DropdownButtonFormField<String>(
                      value: _documentType,
                      dropdownColor: AppTheme.cardBg,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Tipo'),
                      items: ['V', 'E', 'J', 'G'].map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _documentType = val);
                      },
                    ),
                  ),
                  
                  // DNI Input
                  Expanded(
                    child: TextFormField(
                      controller: _dniController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Cédula / RIF (Solo números)'),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Requerido';
                        if (value.length < 5) return 'Inválido';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Phone Input
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Teléfono (04141234567)'),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Requerido';
                  if (value.length < 10) return 'Teléfono inválido';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? _saveProfile : _saveProfile,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentGold,
            foregroundColor: Colors.black,
          ),
          child: _isLoading 
            ? const SizedBox(
                width: 20, 
                height: 20, 
                child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)
              )
            : const Text('Guardar y Continuar'),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white60),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppTheme.accentGold),
        borderRadius: BorderRadius.circular(10),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppTheme.dangerRed),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppTheme.dangerRed),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}
