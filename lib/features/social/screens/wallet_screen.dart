import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/animated_cyber_background.dart';
import 'profile_screen.dart';
import '../../game/screens/scenarios_screen.dart';
import '../../../shared/widgets/glitch_text.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/pago_a_pago_service.dart';
import '../../../core/models/pago_a_pago_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../widgets/payment_profile_dialog.dart';
import '../widgets/payment_method_selector.dart';
import '../widgets/add_payment_method_dialog.dart';

final bcv_dolar = 1;

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);


    final player = playerProvider.currentPlayer;
    final cloverBalance = player?.clovers ?? 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // Custom AppBar
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center, // Center the title
                children: [
                   const GlitchText(
                    text: "MapHunter",
                    fontSize: 22,
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Balance Card with Custom Clover Icon
                    CustomPaint(
                      painter: PixelBorderPainter(color: const Color(0xFF10B981)),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF10B981).withOpacity(0.3),
                              const Color(0xFF10B981).withOpacity(0.1),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.15),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'TRÉBOLES',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                letterSpacing: 4,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            // Clover Icon
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.1),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withOpacity(0.2),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Text(
                                '🍀',
                                style: TextStyle(fontSize: 40),
                              ),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Balance Amount
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  cloverBalance.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 48,
                                    fontWeight: FontWeight.w900,
                                    height: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Massive Conversion info
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.accentGold.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppTheme.accentGold.withOpacity(0.3)),
                              ),
                              child: const Text(
                                '1 🍀 = 1\$',
                                style: TextStyle(
                                  color: AppTheme.accentGold,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.add_circle_outline,
                            label: 'RECARGAR',
                            color: AppTheme.accentGold,
                            onTap: () => _showRechargeDialog(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.remove_circle_outline,
                            label: 'RETIRAR',
                            color: AppTheme.secondaryPink,
                            onTap: () => _showWithdrawDialog(),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // Transaction History Section (Placeholder)
                    CustomPaint(
                      painter: PixelBorderPainter(color: Colors.white.withOpacity(0.3)),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg.withOpacity(0.9),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.history,
                                  color: AppTheme.accentGold,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'HISTORIAL DE TRANSACCIONES',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            const Center(
                              child: Text(
                                'No hay transacciones recientes',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.3),
              color.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withOpacity(0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 15,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRechargeDialog() async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    
    // Refresh profile to ensure we have the latest DNI/Phone data from DB
    // This is critical to skip the form if data exists.
    setState(() => _isLoading = true);
    await playerProvider.refreshProfile();
    setState(() => _isLoading = false);

    final player = playerProvider.currentPlayer;
    if (player == null) return;

    // 1. Validate Profile
    if (!player.hasCompletePaymentProfile) {
       final bool? success = await showDialog(
         context: context,
         barrierDismissible: false,
         builder: (_) => const PaymentProfileDialog()
       );
       
       if (success != true) return; // User cancelled or failed
    }
    
    // 2. Select Method
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PaymentMethodSelector(
        onMethodSelected: (methodId) async {
          Navigator.pop(ctx);
          if (methodId == 'pago_movil') {
            
            setState(() => _isLoading = true);
            try {
              // Check if user has a payment method
              final methods = await Supabase.instance.client
                  .from('user_payment_methods')
                  .select('id')
                  .eq('user_id', player.userId)
                  .limit(1);
                  
              if (!mounted) return;
              setState(() => _isLoading = false);

              if (methods.isEmpty) {
                // Show Add Dialog
                final bool? success = await showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const AddPaymentMethodDialog()
                );
                
                if (success == true) {
                   _showAmountDialog();
                }
              } else {
                 _showAmountDialog();
              }
            } catch (e) {
              if (mounted) setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error validando métodos: $e')),
              );
            }

          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Método no disponible por el momento')),
            );
          }
        }
      )
    );
  }

  void _showAmountDialog() {
    _amountController.clear();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppTheme.cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: AppTheme.accentGold.withOpacity(0.3)),
            ),
            title: Row(
              children: [
                Icon(Icons.add_circle, color: AppTheme.accentGold),
                const SizedBox(width: 12),
                const Text(
                  'Comprar Tréboles',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Text(
                    'Ingresa la cantidad de tréboles que deseas comprar. (1 🍀 = 1\$)',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly], // Only allow integers
                    style: const TextStyle(color: Colors.white),
                    onChanged: (val) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Cantidad (Enteros)',
                      labelStyle: const TextStyle(color: Colors.white60),
                      prefixIcon: const Icon(Icons.star, color: Colors.white60),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: AppTheme.accentGold),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                   // Calculation Display
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Estimado en Bolívares (Tasa Ref: $bcv_dolar):",
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _amountController.text.isEmpty 
                              ? "0.00 VES"
                              : "${(int.tryParse(_amountController.text) ?? 0) * bcv_dolar} VES",
                          style: const TextStyle(
                            color: AppTheme.accentGold, 
                            fontWeight: FontWeight.bold,
                            fontSize: 16
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isLoading)
                   const Padding(
                     padding: EdgeInsets.only(top: 20.0),
                     child: CircularProgressIndicator(color: AppTheme.accentGold),
                   ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isLoading ? null : () => Navigator.pop(ctx),
                child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
              ),
              ElevatedButton(
                onPressed: _isLoading ? null : () async {
                  final amount = int.tryParse(_amountController.text); // Validate Integer
                  if (amount == null || amount <= 0) {
                     ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ingresa un monto entero válido > 0')),
                    );
                    return;
                  }

                  setState(() => _isLoading = true);
                  
                  // Iniciar proceso de pago (cast to double for compatibility)
                  await _initiatePayment(context, amount.toDouble());

                  if (mounted) {
                    setState(() => _isLoading = false);
                    Navigator.pop(ctx);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGold,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Pagar'),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _initiatePayment(BuildContext context, double amount) async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final user = playerProvider.currentPlayer;
    
    if (user == null) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No hay usuario autenticado.')),
      );
      return;
    }

    try {
      // Instanciar servicio
      final apiKey = dotenv.env['PAGO_PAGO_API_KEY'] ?? ''; 
      final service = PagoAPagoService(apiKey: apiKey);

      // Calcular monto en Bolívares
      
      final double amountBs = amount * bcv_dolar;

      // Llamar al nuevo método simplificado
      final response = await service.createSimplePaymentOrder(amountBs: amountBs);

      if (!mounted) return;

      if (response.success && response.paymentUrl != null) {
        final url = Uri.parse(response.paymentUrl!);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(
               content: Text('Abriendo pasarela de pago...'),
               backgroundColor: AppTheme.successGreen,
             ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('No se pudo abrir el link: ${response.paymentUrl}')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text('Error al crear orden: ${response.message}'),
             backgroundColor: AppTheme.dangerRed,
           ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.dangerRed,
        )
      );
    }
  }

  void _showWithdrawDialog() {
    final amountController = TextEditingController();
    final bankController = TextEditingController(); // Código banco (ej: 0102)
    final phoneController = TextEditingController(); // 0424...
    final dniController = TextEditingController(); // V12345678
    
    // Prefill data if available
    final player = Provider.of<PlayerProvider>(context, listen: false).currentPlayer;
    if (player != null) {
      phoneController.text = player.phone ?? '';
      dniController.text = player.cedula ?? '';
    }

    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppTheme.cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: AppTheme.secondaryPink.withOpacity(0.3)),
            ),
            title: Row(
              children: [
                Icon(Icons.remove_circle, color: AppTheme.secondaryPink),
                const SizedBox(width: 12),
                const Text(
                  'Retirar Fondos (Pago Móvil)',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Retira tus tréboles a tu cuenta bancaria vía Pago Móvil.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  
                  // Amount
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly], // Only Digits
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Monto Exacto (Tréboles)', Icons.monetization_on),
                  ),
                  const SizedBox(height: 12),

                  // Bank Code
                  TextField(
                    controller: bankController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Código Banco (ej: 0102)', Icons.account_balance),
                  ),
                  const SizedBox(height: 12),

                  // Phone
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Teléfono (0414...)', Icons.phone_android),
                  ),
                  const SizedBox(height: 12),

                  // DNI
                  TextField(
                    controller: dniController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Cédula (V123...)', Icons.badge),
                  ),

                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16.0),
                      child: CircularProgressIndicator(color: AppTheme.secondaryPink),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
              ),
              ElevatedButton(
                onPressed: isLoading ? null : () async {
                  final amount = int.tryParse(amountController.text); // Validate Integer
                  if (amount == null || amount <= 0) {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Monto inválido (Solo enteros)')));
                     return;
                  }
                  if (bankController.text.isEmpty || phoneController.text.isEmpty || dniController.text.isEmpty) {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Todos los campos son obligatorios')));
                     return;
                  }

                  setState(() => isLoading = true);

                  try {
                    // Check Balance first (client side check)
                    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
                    final balance = playerProvider.currentPlayer?.clovers ?? 0;
                    if (balance < amount) {
                       throw Exception("Saldo insuficiente");
                    }

                    final apiKey = dotenv.env['PAGO_PAGO_API_KEY'] ?? '';
                    final service = PagoAPagoService(apiKey: apiKey);
                    
                    final token = Supabase.instance.client.auth.currentSession?.accessToken;
                    if (token == null) throw Exception("No hay sesión activa");

                    final request = WithdrawalRequest(
                      amount: amount.toDouble(),
                      bank: bankController.text,
                      dni: dniController.text,
                      phone: phoneController.text,
                    );

                    final response = await service.withdrawFunds(request, token);

                    if (!mounted) return;

                    if (response.success) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('¡Retiro exitoso!'),
                          backgroundColor: AppTheme.successGreen,
                        )
                      );
                      // Trigger refresh of profile/balance
                      // This depends on how PlayerProvider refreshes. 
                      // Ideally we reload the user profile.
                      // playerProvider.reloadProfile(); (Assuming something like this exists or happens auto)
                    } else {
                      throw Exception(response.message);
                    }

                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: AppTheme.dangerRed,
                        )
                      );
                    }
                  } finally {
                    if (mounted) setState(() => isLoading = false);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryPink),
                child: const Text('Retirar', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white60),
      prefixIcon: Icon(icon, color: Colors.white60),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppTheme.secondaryPink),
        borderRadius: BorderRadius.circular(10),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.weekend, 'Local'),
            _buildNavItem(1, Icons.explore, 'Escenarios'),
            _buildNavItem(2, Icons.account_balance_wallet, 'Recargas'),
            _buildNavItem(3, Icons.person, 'Perfil'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = index == 2; // Recargas is always selected in this screen
    return GestureDetector(
      onTap: () {
        // Navigation logic
        switch (index) {
          case 0: // Local
            _showComingSoonDialog(label);
            break;
          case 1: // Escenarios
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const ScenariosScreen(),
              ),
            );
            break;
          case 2: // Recargas - already here
            break;
          case 3: // Perfil
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ProfileScreen(),
              ),
            );
            break;
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.accentGold : Colors.white54,
              size: isSelected ? 24 : 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.accentGold,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showComingSoonDialog(String featureName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.accentGold.withOpacity(0.3)),
        ),
        title: Row(
          children: [
            Icon(Icons.construction, color: AppTheme.accentGold),
            const SizedBox(width: 12),
            const Text(
              'Próximamente',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'La sección "$featureName" estará disponible muy pronto. ¡Mantente atento a las actualizaciones!',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Entendido',
              style: TextStyle(color: AppTheme.accentGold),
            ),
          ),
        ],
      ),
    );
  }
}

class PixelBorderPainter extends CustomPainter {
  final Color color;

  PixelBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    const double cornerSize = 15;
    const double pixelSize = 4;

    final path = Path()
      ..moveTo(cornerSize, 0)
      ..lineTo(size.width - cornerSize, 0)
      ..moveTo(size.width, cornerSize)
      ..lineTo(size.width, size.height - cornerSize)
      ..moveTo(size.width - cornerSize, size.height)
      ..lineTo(cornerSize, size.height)
      ..moveTo(0, size.height - cornerSize)
      ..lineTo(0, cornerSize);

    canvas.drawPath(path, paint);

    void drawCorner(double x, double y, bool right, bool bottom) {
      final cp = Paint()..color = color..style = PaintingStyle.fill;
      double dx = right ? -1 : 1;
      double dy = bottom ? -1 : 1;

      canvas.drawRect(Rect.fromLTWH(x, y, pixelSize * dx, cornerSize * dy), cp);
      canvas.drawRect(Rect.fromLTWH(x, y, cornerSize * dx, pixelSize * dy), cp);
      
      canvas.drawRect(Rect.fromLTWH(x + (cornerSize + 5) * dx, y, pixelSize * dx, pixelSize * dy), cp);
      canvas.drawRect(Rect.fromLTWH(x, y + (cornerSize + 5) * dy, pixelSize * dx, pixelSize * dy), cp);
    }

    drawCorner(0, 0, false, false);
    drawCorner(size.width, 0, true, false);
    drawCorner(0, size.height, false, true);
    drawCorner(size.width, size.height, true, true);
    
    canvas.drawRect(Rect.fromLTWH(size.width/2 - 20, 0, 40, pixelSize), paint..style = PaintingStyle.fill);
    canvas.drawRect(Rect.fromLTWH(size.width/2 - 20, size.height - pixelSize, 40, pixelSize), paint..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PixelButtonPainter extends CustomPainter {
  final Color color;

  PixelButtonPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path()
      ..moveTo(10, 0)
      ..lineTo(size.width - 10, 0)
      ..arcToPoint(Offset(size.width, 10), radius: const Radius.circular(5))
      ..lineTo(size.width, size.height - 10)
      ..arcToPoint(Offset(size.width - 10, size.height), radius: const Radius.circular(5))
      ..lineTo(10, size.height)
      ..arcToPoint(Offset(0, size.height - 10), radius: const Radius.circular(5))
      ..lineTo(0, 10)
      ..arcToPoint(const Offset(10, 0), radius: const Radius.circular(5));

    canvas.drawPath(path, paint);
    
    final detailPaint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5;
    
    canvas.drawCircle(const Offset(5, 5), 2, detailPaint);
    canvas.drawCircle(Offset(size.width - 5, 5), 2, detailPaint);
    canvas.drawCircle(Offset(5, size.height - 5), 2, detailPaint);
    canvas.drawCircle(Offset(size.width - 5, size.height - 5), 2, detailPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
