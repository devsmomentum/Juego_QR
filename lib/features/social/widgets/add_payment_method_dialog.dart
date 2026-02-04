import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../auth/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';

class AddPaymentMethodDialog extends StatefulWidget {
  const AddPaymentMethodDialog({super.key});

  @override
  State<AddPaymentMethodDialog> createState() => _AddPaymentMethodDialogState();
}

class _AddPaymentMethodDialogState extends State<AddPaymentMethodDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _bankController = TextEditingController(); // Just bank name/code
  bool _isLoading = false;

  @override
  void dispose() {
    _bankController.dispose();
    super.dispose();
  }

  Future<void> _saveMethod() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Access AuthService directly or via provider if available. 
      // Assuming AuthService is accessible via Provider or direct instance.
      // Usually PlayerProvider wraps AuthService, but for simplicity let's see if we can use PlayerProvider or need to instantiate/get AuthService.
      // Based on previous code, PlayerProvider uses _authService internally.
      // We should probably add `addPaymentMethod` to PlayerProvider to keep consistency, 
      // OR just use AuthService directly here if we can get it.
      // Let's use the Provider pattern if possible.
      
      final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
      // Wait, I haven't added `addPaymentMethod` to PlayerProvider yet. 
      // I should do that. But for now, I can access AuthService if I update PlayerProvider later.
      // Let's mock the call via AuthService directly for now within the widget or assume PlayerProvider has it.
      // I will update PlayerProvider in the next step.
      
      await playerProvider.addPaymentMethod(bankCode: _bankController.text.trim());

      if (mounted) {
        Navigator.pop(context, true); // Return true on success
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Método de pago agregado correctamente'),
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
    final player = Provider.of<PlayerProvider>(context, listen: false).currentPlayer;
    final dni = player?.cedula ?? 'No definido';
    final phone = player?.phone ?? 'No definido';

    return AlertDialog(
      backgroundColor: AppTheme.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppTheme.accentGold.withOpacity(0.3)),
      ),
      title: Row(
        children: [
          const Icon(Icons.credit_card, color: AppTheme.accentGold),
          const SizedBox(width: 12),
          const Text(
            'Agregar Pago Móvil',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
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
                'Se usará tu Cédula y Teléfono del perfil.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),

              // Read-only Info
              _buildInfoRow(Icons.badge, 'Cédula', dni),
              const SizedBox(height: 12),
              _buildInfoRow(Icons.phone_android, 'Teléfono', phone),
              
              const SizedBox(height: 20),
              
              // Bank Input
              TextFormField(
                controller: _bankController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Banco (Ej: 0102 - Venezuela)'),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Requerido';
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
          onPressed: _isLoading ? null : _saveMethod,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentGold,
            foregroundColor: Colors.black,
          ),
          child: _isLoading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
            : const Text('Guardar Método'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
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
