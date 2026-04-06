import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/animated_cyber_background.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../wallet/widgets/payment_validation_widget.dart';
import 'profile_screen.dart';
import '../../game/screens/scenarios_screen.dart';
import '../../../shared/widgets/glitch_text.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/payment_profile_dialog.dart';
import '../widgets/payment_method_selector.dart';
import '../widgets/add_payment_method_dialog.dart';
import '../../wallet/widgets/withdrawal_method_selector.dart';
import '../../wallet/screens/transaction_history_screen.dart';
import '../../wallet/models/clover_plan.dart';
import '../../wallet/services/clover_plan_service.dart';
import '../../wallet/widgets/clover_plan_card.dart';
import '../../wallet/models/withdrawal_plan.dart';
import '../../wallet/services/withdrawal_plan_service.dart';
import '../../../core/services/app_config_service.dart';
import '../../wallet/models/transaction_item.dart';
import '../../wallet/repositories/transaction_repository.dart';
import '../../wallet/widgets/transaction_card.dart';
import '../../wallet/providers/payment_method_provider.dart';
import '../../wallet/widgets/edit_payment_method_dialog.dart';
import '../../../core/services/stripe_service.dart';
import '../../../shared/widgets/coin_image.dart';
import '../../wallet/services/stripe_connect_service.dart';

class WalletScreen extends StatefulWidget {
  final bool hideScaffold;
  const WalletScreen({super.key, this.hideScaffold = false});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = false;
  
  // Stripe Connect State
  final StripeConnectService _stripeConnectService = StripeConnectService();
  String _stripeStatus = 'loading'; // loading, not_started, pending, completed
  bool _isStripeLoading = false;

  // Recharge availability (null = still loading)
  bool? _rechargeEnabled;
  late final AppConfigService _appConfigService;

  // History State
  final ITransactionRepository _transactionRepository =
      SupabaseTransactionRepository();
  List<TransactionItem> _recentTransactions = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _appConfigService = AppConfigService(
      supabaseClient: Supabase.instance.client,
    );
    _loadRechargeFlag();
    _loadRecentTransactions();
    _loadPaymentMethods();
    _loadStripeStatus();
  }

  Future<void> _loadRechargeFlag() async {
    final enabled = await _appConfigService.isRechargeEnabled();
    if (mounted) setState(() => _rechargeEnabled = enabled);
  }

  Future<void> _loadPaymentMethods() async {
    final userId = Provider.of<PlayerProvider>(context, listen: false)
        .currentPlayer
        ?.userId;
    if (userId != null) {
      await Provider.of<PaymentMethodProvider>(context, listen: false)
          .loadMethods(userId);
    }
  }

  Future<void> _loadRecentTransactions() async {
    setState(() => _isLoadingHistory = true);
    try {
      final txs = await _transactionRepository.getMyTransactions(limit: 5);
      if (mounted) {
        setState(() {
          _recentTransactions = txs;
        });
      }
    } catch (e) {
      debugPrint("Error loading history: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadStripeStatus() async {
    if (!mounted) return;
    setState(() => _isStripeLoading = true);
    try {
      final data = await _stripeConnectService.getAccountStatus();
      if (mounted) {
        setState(() {
          _stripeStatus = data?['status'] ?? 'not_started';
        });
      }
    } catch (e) {
      debugPrint("Error loading stripe status: $e");
      if (mounted) {
        setState(() {
          _stripeStatus = 'not_started';
        });
      }
    } finally {
      if (mounted) setState(() => _isStripeLoading = false);
    }
  }

  Future<void> _handleStripeSetup() async {
    setState(() => _isStripeLoading = true);
    try {
      // 1. Create account if not exists
      if (_stripeStatus == 'not_started') {
        final accId = await _stripeConnectService.createAccount();
        if (accId == null) throw "No se pudo crear la cuenta de Stripe";
      }

      // 2. Generate Link
      final url = await _stripeConnectService.createOnboardingLink();
      if (url == null) throw "No se pudo generar el enlace de registro";

      // 3. Launch
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw "No se pudo abrir el navegador";
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.dangerRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isStripeLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    // Logic for background image (dynamic) - to match TransactionHistory
    final isDayNightMode = playerProvider.isDarkMode;
    // FORCED TO TRUE: Always use dark mode aesthetic in the wallet section
    const bool isDarkMode = true;
    final player = playerProvider.currentPlayer;
    final cloverBalance = player?.clovers ?? 0;

    final mainColumn = SafeArea(
      child: Column(
        children: [
          // Custom AppBar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: SizedBox(
              height: 60,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Back Button on the left
                  if (!widget.hideScaffold)
                    Positioned(
                      left: 0,
                      child: _CyberRingButton(
                        size: 40,
                        icon: Icons.arrow_back_ios_new_rounded,
                        onPressed: () => Navigator.pop(context),
                        color: AppTheme.accentGold,
                      ),
                    ),

                  // WALLET TITLE - Restored to center
                  const Text(
                    'WALLET',
                    style: TextStyle(
                      color: AppTheme.accentGold,
                      fontFamily: 'Orbitron',
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                final playerProvider =
                    Provider.of<PlayerProvider>(context, listen: false);
                await playerProvider.refreshProfile();
                await _loadRecentTransactions();
                await _loadRechargeFlag();
                await _loadPaymentMethods();
                await _loadStripeStatus();
              },
              color: AppTheme.accentGold,
              backgroundColor: const Color(0xFF151517),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    // Balance Card with Custom Clover Icon - GLASSMORPISM STYLE
                    ClipRRect(
                      borderRadius: BorderRadius.circular(34),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.25),
                            borderRadius: BorderRadius.circular(34),
                            border: Border.all(
                              color: const Color(0xFF10B981).withOpacity(0.6),
                              width: 1.5,
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: const Color(0xFF10B981).withOpacity(0.2),
                                width: 1.0,
                              ),
                              color: const Color(0xFF10B981).withOpacity(0.02),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'TRÉBOLES:',
                                      style: TextStyle(
                                        color: isDarkMode
                                            ? Colors.white
                                            : Colors.black87,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.2,
                                        fontFamily: 'Orbitron',
                                      ),
                                    ),
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerRight,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              cloverBalance.toString(),
                                              style: TextStyle(
                                                color: isDarkMode
                                                    ? Colors.white
                                                    : Colors.black87,
                                                fontSize: 42,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const CoinImage(
                                              size: 28,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: Opacity(
                            opacity: _isLoading ? 0.5 : 1.0,
                            child: _buildActionButton(
                              icon: _rechargeEnabled == false
                                  ? Icons.construction
                                  : Icons.add_circle_outline,
                              label: 'RECARGAR',
                              color: _rechargeEnabled == false
                                  ? Colors.grey
                                  : AppTheme.accentGold,
                              onTap: _isLoading
                                  ? () {}
                                  : () {
                                      if (_rechargeEnabled == false) {
                                        _showRechargeMaintenance();
                                      } else {
                                        _showRechargeDialog();
                                      }
                                    },
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Opacity(
                            opacity: _isLoading ? 0.5 : 1.0,
                            child: _buildActionButton(
                              icon: Icons.remove_circle_outline,
                              label: 'RETIRAR',
                              color: AppTheme.secondaryPink,
                              onTap: _isLoading
                                  ? () {}
                                  : () => _showWithdrawDialog(),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // Stripe Connect Onboarding Section
                    // _buildStripeConnectSection(isDarkMode),

                    // const SizedBox(height: 40),

                    // Recent Transactions Section - PREVIOUS STYLE (DOUBLE BORDER)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentGold.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: AppTheme.accentGold
                                            .withOpacity(0.2)),
                                  ),
                                  child: const Icon(
                                    Icons.history,
                                    color: AppTheme.accentGold,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'HISTORIAL RECIENTE',
                                  style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black87,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Orbitron',
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        pageBuilder: (context, animation,
                                                secondaryAnimation) =>
                                            const TransactionHistoryScreen(),
                                        transitionsBuilder: (context, animation,
                                            secondaryAnimation, child) {
                                          return FadeTransition(
                                              opacity: animation, child: child);
                                        },
                                      ),
                                    ).then((_) => _loadRecentTransactions());
                                  },
                                  child: const Text(
                                    'Ver Todo',
                                    style: TextStyle(
                                      color: AppTheme.accentGold,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            if (_isLoadingHistory)
                              const Center(
                                  child: LoadingIndicator(fontSize: 14))
                            else if (_recentTransactions.isEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 20.0),
                                  child: Text(
                                    'No hay transacciones recientes',
                                    style: TextStyle(
                                        color: isDarkMode
                                            ? Colors.white38
                                            : Colors.black38),
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _recentTransactions.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  return TransactionCard(
                                    item: _recentTransactions[index],
                                    onResumePayment: _recentTransactions[index].canResumePayment
                                        ? () async {
                                            Navigator.push(
                                              context,
                                              PageRouteBuilder(
                                                pageBuilder: (context, animation, secondaryAnimation) => 
                                                    const TransactionHistoryScreen(),
                                                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                                  return FadeTransition(opacity: animation, child: child);
                                                },
                                              ),
                                            ).then((_) => _loadRecentTransactions());
                                          }
                                        : null,
                                    onValidateMpay: _recentTransactions[index]
                                            .canValidateMpay
                                        ? () => _openMpayValidation(
                                            _recentTransactions[index])
                                        : null,
                                    onCancelOrder: _recentTransactions[index].canCancel
                                        ? () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                backgroundColor: isDarkMode ? AppTheme.cardBg : Colors.white,
                                                title: Text('Cancelar Orden', style: TextStyle(color: isDarkMode ? Colors.white : const Color(0xFF1A1A1D))),
                                                content: Text(
                                                  '¿Estás seguro de que quieres cancelar esta orden pendiente?',
                                                  style: TextStyle(color: isDarkMode ? Colors.white70 : const Color(0xFF4A4A5A)),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context, false),
                                                    child: const Text('No', style: TextStyle(color: Colors.white54)),
                                                  ),
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context, true),
                                                    child: const Text('Sí, Cancelar', style: TextStyle(color: AppTheme.dangerRed)),
                                                  ),
                                                ],
                                              ),
                                            );
                                            
                                            if (confirm != true) return;

                                            try {
                                              bool success;
                                              final currentItem = _recentTransactions[index];
                                              if (currentItem.canCancelWithdrawal) {
                                                LoadingOverlay.show(context, message: 'Cancelando retiro y devolviendo saldo...');
                                                success = await _transactionRepository.cancelWithdrawal(currentItem.id);
                                              } else {
                                                LoadingOverlay.show(context, message: 'Cancelando orden...');
                                                success = await _transactionRepository.cancelOrder(currentItem.id);
                                              }
                                              
                                              if (mounted) LoadingOverlay.hide(context);
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(success 
                                                      ? (currentItem.canCancelWithdrawal ? 'Retiro cancelado y tréboles devueltos' : 'Orden cancelada') 
                                                      : 'Error al cancelar'),
                                                    backgroundColor: success ? AppTheme.successGreen : AppTheme.dangerRed,
                                                  ),
                                                );
                                                // Refresh balance if withdrawal was cancelled
                                                if (success && currentItem.canCancelWithdrawal) {
                                                  Provider.of<PlayerProvider>(context, listen: false).refreshProfile();
                                                }
                                              }
                                            } catch (e) {
                                              debugPrint('Error in cancellation: $e');
                                              if (mounted) LoadingOverlay.hide(context);
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.dangerRed),
                                                );
                                              }
                                            } finally {
                                              if (mounted) _loadRecentTransactions();
                                            }
                                          }
                                        : null,
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final content = Stack(
      children: [
        if (!widget.hideScaffold)
          Positioned.fill(
            child: Opacity(
              opacity: 0.4,
              child: Image.asset(
                isDayNightMode
                    ? 'assets/images/fotogrupalnoche.png'
                    : 'assets/images/personajesgrupal.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        AnimatedCyberBackground(
          showBackgroundBase: false, // Match TransactionHistory
          showParticles: false, // Unified static look
          child: mainColumn,
        ),
      ],
    );

    if (widget.hideScaffold) return mainColumn;

    return Scaffold(
      backgroundColor: const Color(0xFF151517),
      extendBody: true,
      bottomNavigationBar: _buildBottomNavBar(),
      body: content,
    );
  }

  Widget _buildCustomCloverIcon() {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Top leaf
          Positioned(
            top: 0,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF10B981),
                    const Color(0xFF059669),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.6),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ),
          // Right leaf
          Positioned(
            right: 0,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF10B981),
                    const Color(0xFF059669),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.6),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ),
          // Bottom leaf
          Positioned(
            bottom: 0,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF10B981),
                    const Color(0xFF059669),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.6),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ),
          // Left leaf
          Positioned(
            left: 0,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF10B981),
                    const Color(0xFF059669),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.6),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ),
          // Center
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF34D399),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.8),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ],
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: color.withOpacity(0.6),
                width: 1.5,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: color.withOpacity(0.2),
                  width: 1.0,
                ),
                color: color.withOpacity(0.02),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: color.withOpacity(0.4)),
                    ),
                    child: Icon(icon, color: color, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Orbitron',
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openMpayValidation(TransactionItem item) async {
    final bool? result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: PaymentValidationWidget(
            orderId: item.pagoOrderId!,
            amountVes: item.fiatAmountVes ?? item.fiatAmount,
          ),
        ),
      ),
    );

    if (result == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Pago verificado! Actualizando saldo...'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        await Provider.of<PlayerProvider>(context, listen: false)
            .refreshProfile();
        await _loadRecentTransactions();
      }
    } else {
      if (mounted) _loadRecentTransactions();
    }
  }

  void _showRechargeMaintenance() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.construction, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text(
              'En Mantenimiento',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontFamily: 'Orbitron',
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: const Text(
          'El sistema de recargas está temporalmente en mantenimiento.\n\n'
          'Pronto estará disponible nuevamente. Disculpa las molestias.',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('ENTENDIDO'),
          ),
        ],
      ),
    );
  }

  void _showRechargeDialog() async {
    if (_isLoading) return; // Debounce prevention
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    // Refresh profile to ensure we have the latest DNI/Phone data from DB
    // This is critical to skip the form if data exists.
    LoadingOverlay.show(context);
    await playerProvider.refreshProfile();
    if (mounted) LoadingOverlay.hide(context);

    final player = playerProvider.currentPlayer;
    if (player == null) return;

    // 1. Validate Profile
    if (!player.hasCompletePaymentProfile) {
      final bool? success = await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const PaymentProfileDialog());

      if (success != true) return; // User cancelled or failed
    }

    // 2. Select Method
    if (!mounted) return;

    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) =>
            PaymentMethodSelector(onMethodSelected: (methodId) async {
              Navigator.pop(ctx);

              // if (methodId == 'pago_movil') {
              //   LoadingOverlay.show(context);
              //   try {
              //     // Check if user has a payment method
              //     final methods = await Supabase.instance.client
              //         .from('user_payment_methods')
              //         .select('id')
              //         .eq('user_id', player.userId)
              //         .limit(1);

              //     if (!mounted) return;
              //     LoadingOverlay.hide(context);

              //     if (methods.isEmpty) {
              //       // Show Add Dialog
              //       final bool? success = await showDialog(
              //           context: context,
              //           barrierDismissible: false,
              //           builder: (_) => const AddPaymentMethodDialog());

              //       if (success == true) {
              //         _showPlanSelectorDialog();
              //       }
              //     } else {
              //       _showPlanSelectorDialog();
              //     }
              //   } catch (e) {
              //     if (mounted) setState(() => _isLoading = false);
              //     ScaffoldMessenger.of(context).showSnackBar(
              //       SnackBar(content: Text('Error validando métodos: $e')),
              //     );
              //   }
              // } else if (methodId == 'stripe') {
               if (methodId == 'stripe') { // Stripe: show plan selector with card payment
                _showStripePlanSelectorDialog();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Método no disponible por el momento')),
                );
              }
            }));
  }

  void _showPlanSelectorDialog() {
    String? selectedPlanId;
    final walletContext = context; // Capture WalletScreen context before dialog

    // Combined future to fetch plans and gateway fee together
    final configService =
        AppConfigService(supabaseClient: Supabase.instance.client);
    final combinedFuture = Future.wait([
      CloverPlanService(supabaseClient: Supabase.instance.client)
          .fetchActivePlans(),
      configService.getGatewayFeePercentage(),
    ]);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setState) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: AppTheme.accentGold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                  color: AppTheme.accentGold.withOpacity(0.2), width: 1),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF151517),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppTheme.accentGold.withOpacity(0.5), width: 1.5),
              ),
              constraints: const BoxConstraints(maxWidth: 400),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title
                    Row(
                      children: [
                        Icon(Icons.add_circle,
                            color: AppTheme.accentGold, size: 22),
                        const SizedBox(width: 12),
                        const Text(
                          'Comprar Tréboles',
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

                    const Text(
                      'Selecciona un plan de tréboles:',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 16),

                    FutureBuilder<List<dynamic>>(
                      future: combinedFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const SizedBox(
                            height: 150,
                            child: LoadingIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error: ${snapshot.error}',
                              style: const TextStyle(
                                  color: Colors.redAccent, fontSize: 12),
                            ),
                          );
                        }

                        final plans =
                            (snapshot.data?[0] as List<CloverPlan>?) ?? [];

                        // Ensure specific order: Basico, Pro (top) and Elite (bottom)
                        // Sorting by quantity: 50, 150, 500
                        plans.sort((a, b) =>
                            a.cloversQuantity.compareTo(b.cloversQuantity));

                        final gatewayFee =
                            (snapshot.data?[1] as double?) ?? 0.0;

                        // Helper to build a plan card with consistent styling
                        Widget buildPlanItem(CloverPlan plan) {
                          return CloverPlanCard(
                            plan: plan,
                            isSelected: selectedPlanId == plan.id,
                            feePercentage: gatewayFee,
                            onTap: () {
                              setState(() => selectedPlanId = plan.id);
                            },
                          );
                        }

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (plans.length >= 3)
                              Column(
                                children: [
                                  // Row 1: Basico & Pro
                                  Row(
                                    children: [
                                      Expanded(child: buildPlanItem(plans[0])),
                                      const SizedBox(width: 12),
                                      Expanded(child: buildPlanItem(plans[1])),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Row 2: Elite (Centered)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width:
                                            150, // Fixed width for the last one to stay centered
                                        child: buildPlanItem(plans[2]),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            else
                              // Fallback for fewer plans
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 12,
                                runSpacing: 12,
                                children: plans
                                    .map((p) => SizedBox(
                                        width: 150, child: buildPlanItem(p)))
                                    .toList(),
                              ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 32),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancelar',
                              style: TextStyle(
                                  color: Colors.white54,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: selectedPlanId == null
                              ? null
                              : () {
                                  Navigator.pop(
                                      ctx); // Close dialog immediately
                                  _initiatePayment(
                                      walletContext, selectedPlanId!);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentGold,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text('Pagar',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  /// Shows a plan selector for Stripe (credit/debit card) payments.
  void _showStripePlanSelectorDialog() {
    String? selectedPlanId;

    // Get the player's existing stripe_customer_id to determine if they have a saved card
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final existingCustomerId = playerProvider.currentPlayer?.stripeCustomerId;
    final hasSavedCard = existingCustomerId != null && existingCustomerId.isNotEmpty;

    // Default: save card if they don't have one yet, or if they already do (keep it)
    // Users can toggle this off to pay without saving
    bool saveCard = true;

    final combinedFuture = Future.wait([
      CloverPlanService(supabaseClient: Supabase.instance.client)
          .fetchActivePlans(),
      Future.value(
          0.0), // No gateway fee for Stripe (fee is built into Stripe's pricing)
    ]);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: const Color(0xFF635BFF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: const Color(0xFF635BFF).withOpacity(0.3), width: 1),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF151517),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF635BFF).withOpacity(0.5),
                      width: 1.5),
                ),
                constraints: const BoxConstraints(maxWidth: 400),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Title
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF635BFF).withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.credit_card_rounded,
                                color: Color(0xFF635BFF), size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Pagar con Tarjeta',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                fontFamily: 'Orbitron',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Visa, Mastercard, Amex',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        'Selecciona un plan de tréboles:',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 16),

                      FutureBuilder<List<dynamic>>(
                        future: combinedFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const SizedBox(
                              height: 150,
                              child: LoadingIndicator(),
                            );
                          }

                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'Error: ${snapshot.error}',
                                style: const TextStyle(
                                    color: Colors.redAccent, fontSize: 12),
                              ),
                            );
                          }

                          final plans =
                              (snapshot.data?[0] as List<CloverPlan>?) ?? [];
                          plans.sort((a, b) =>
                              a.cloversQuantity.compareTo(b.cloversQuantity));

                          Widget buildPlanItem(CloverPlan plan) {
                            return CloverPlanCard(
                              plan: plan,
                              isSelected: selectedPlanId == plan.id,
                              feePercentage:
                                  0.0, // No extra fee shown for Stripe
                              onTap: () {
                                setDialogState(() => selectedPlanId = plan.id);
                              },
                            );
                          }

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (plans.length >= 3)
                                Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                            child: buildPlanItem(plans[0])),
                                        const SizedBox(width: 12),
                                        Expanded(
                                            child: buildPlanItem(plans[1])),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 150,
                                          child: buildPlanItem(plans[2]),
                                        ),
                                      ],
                                    ),
                                  ],
                                )
                              else
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: plans
                                      .map((p) => SizedBox(
                                          width: 150, child: buildPlanItem(p)))
                                      .toList(),
                                ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // ── CARD SAVING SECTION ──────────────────────────────
                      if (hasSavedCard)
                        // User already has a saved card — show info banner
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF10B981).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.credit_card_rounded,
                                  color: Color(0xFF10B981), size: 18),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Se usará tu tarjeta guardada',
                                  style: TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setDialogState(() => saveCard = !saveCard);
                                },
                                child: Text(
                                  saveCard ? 'Usar otra' : 'Usar guardada',
                                  style: TextStyle(
                                    color: saveCard
                                        ? Colors.white54
                                        : const Color(0xFF10B981),
                                    fontSize: 11,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        // First time — let user choose to save card
                        InkWell(
                          onTap: () => setDialogState(() => saveCard = !saveCard),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Transform.scale(
                                  scale: 0.9,
                                  child: Checkbox(
                                    value: saveCard,
                                    onChanged: (val) =>
                                        setDialogState(() => saveCard = val ?? true),
                                    activeColor: const Color(0xFF635BFF),
                                    side: const BorderSide(color: Colors.white38),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Guardar tarjeta para futuros pagos',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        'Tu próxima recarga será más rápida',
                                        style: TextStyle(
                                          color: Colors.white38,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // ─────────────────────────────────────────────────────

                      const SizedBox(height: 20),

                      // Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed:
                                _isLoading ? null : () => Navigator.pop(ctx),
                            child: const Text('Cancelar',
                                style: TextStyle(
                                    color: Colors.white54,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: ElevatedButton.icon(
                              onPressed: (_isLoading || selectedPlanId == null)
                                  ? null
                                  : () async {
                                      Navigator.pop(ctx); // Close dialog first
                                      setState(() => _isLoading = true);
                                      try {
                                        final resultData = await StripeService
                                            .initiateStripePurchase(
                                          planId: selectedPlanId!,
                                          context: context,
                                          saveCard: saveCard,
                                          stripeCustomerId: hasSavedCard && saveCard
                                              ? existingCustomerId
                                              : null,
                                        );

                                        if (!mounted) return;

                                        if (resultData.result ==
                                            StripePaymentResult.success) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  '¡Pago exitoso! Tus tréboles serán acreditados en instantes.'),
                                              backgroundColor:
                                                  Color(0xFF10B981),
                                            ),
                                          );

                                          // Save new customer ID if returned and different
                                          if (resultData.stripeCustomerId != null && 
                                              resultData.stripeCustomerId != existingCustomerId) {
                                            final userId = Supabase.instance.client.auth.currentUser?.id;
                                            if (userId != null) {
                                              await Supabase.instance.client
                                                .from('profiles')
                                                .update({'stripe_customer_id': resultData.stripeCustomerId})
                                                .eq('id', userId);
                                              
                                              // Update local player state if possible
                                              if (mounted) {
                                                Provider.of<PlayerProvider>(context, listen: false).refreshProfile();
                                              }
                                            }
                                          }
                                          await Future.delayed(
                                              const Duration(seconds: 3));
                                          if (mounted) {
                                            await Provider.of<PlayerProvider>(
                                                    context,
                                                    listen: false)
                                                .refreshProfile();
                                            await _loadRecentTransactions();
                                          }
                                        } else if (resultData.result ==
                                            StripePaymentResult.cancelled) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content:
                                                    Text('Pago cancelado.')),
                                          );
                                        }
                                        // StripePaymentResult.failed already shows its own SnackBar inside StripeService
                                      } finally {
                                        if (mounted)
                                          setState(() => _isLoading = false);
                                        _loadRecentTransactions();
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF635BFF),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.lock_rounded, size: 16),
                              label: const Text(
                                'Pagar',
                                style: TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
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
        },
      ),
    );
  }


  /// Initiates payment with selected plan ID.
  ///
  /// The Edge Function validates the plan and retrieves the true price from the database.
  Future<void> _initiatePayment(BuildContext context, String planId) async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final user = playerProvider.currentPlayer;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No hay usuario autenticado.')),
      );
      return;
    }

    try {
      debugPrint('[WalletScreen] Initiating payment for plan: $planId');

      // Show loading overlay while edge function runs
      LoadingOverlay.show(context);

      // Call Edge Function directly with plan_id only (security: price validated server-side)
      final response = await Supabase.instance.client.functions.invoke(
        'api_pay_orders',
        body: {
          'plan_id': planId,
        },
      );

      if (!mounted) return;
      LoadingOverlay.hide(context);

      if (response.status != 200) {
        throw Exception(
            'Error en servicio de pagos (${response.status}): ${response.data}');
      }

      final responseData = response.data;
      debugPrint('[WalletScreen] RAW RESPONSE: $responseData');

      if (responseData == null) {
        throw Exception('Respuesta vacía del servicio de pagos');
      }

      if (responseData['success'] == false) {
        throw Exception(
            'API Error: ${responseData['message'] ?? responseData['error'] ?? "Unknown error"}');
      }

      // Parse response
      final Map<String, dynamic> dataObj =
          responseData['data'] ?? responseData['result'] ?? responseData;
      final String? dbOrderId = dataObj['db_order_id']?.toString();
      final double? amountVes = (dataObj['amount_ves'] is num)
          ? (dataObj['amount_ves'] as num).toDouble()
          : double.tryParse(dataObj['amount_ves']?.toString() ?? '');

      if (dbOrderId == null || dbOrderId.isEmpty) {
        throw Exception('Datos de validación no recibidos');
      }

      if (!mounted) return;

      // Show Pago Móvil Validation Modal
      final bool? result = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: PaymentValidationWidget(
              orderId: dbOrderId,
              amountVes: amountVes,
            ),
          ),
        ),
      );

      if (result == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Pago verificado! Actualizando saldo...'),
            backgroundColor: AppTheme.successGreen,
          ),
        );

        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          await Provider.of<PlayerProvider>(context, listen: false)
              .refreshProfile();
          await _loadRecentTransactions();
        }
      } else {
        if (!mounted) return;
        // Refresh anyway to show the pending order if it was created
        _loadRecentTransactions();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Operación cancelada o pendiente.')),
        );
      }
    } catch (e) {
      debugPrint('[WalletScreen] Payment error: $e');
      if (mounted) {
        LoadingOverlay.hide(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.dangerRed,
        ));
      }
    }
  }

  void _showWithdrawDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => WithdrawalMethodSelector(
        onMethodSelected: (method) {
          Navigator.pop(ctx);
          // Allow bottom sheet animation to finish
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) _showWithdrawPlanDialog(method);
          });
        },
      ),
    );
  }

  void _showWithdrawPlanDialog(Map<String, dynamic> method) {
    String? selectedPlanId;
    final type = method['type'];
    final isStripe = type == 'stripe';
    final isAutomatedStripe = method['is_automated'] == true;
    final bankCode = method['bank_code'] ?? '???';
    final phone = method['phone_number'] ?? '???';
    final email = method['identifier'] ?? '???';

    // Combined future: check rate validity AND load plans in parallel
    // Only check BCV rate for Pago Movil
    final configService =
        AppConfigService(supabaseClient: Supabase.instance.client);
    final combinedFuture = Future.wait([
      WithdrawalPlanService(supabaseClient: Supabase.instance.client)
          .fetchActivePlans(),
      isStripe ? Future.value(true) : configService.isBcvRateValid(),
    ]);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A1D),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                  color: isStripe
                      ? const Color(0xFF635BFF)
                      : AppTheme.secondaryPink,
                  width: 1),
            ),
            title: Row(
              children: [
                Icon(
                    isStripe
                        ? Icons.credit_card_rounded
                        : Icons.publish_rounded,
                    color: isStripe
                        ? const Color(0xFF635BFF)
                        : AppTheme.secondaryPink,
                    size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Retirar Tréboles',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            fontFamily: 'Orbitron'),
                      ),
                      Text(
                        isAutomatedStripe
                            ? 'A: Tu cuenta Stripe vinculada'
                            : (isStripe
                                ? 'A: Stripe ($email)'
                                : 'A: $bankCode - $phone'),
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: FutureBuilder<List<dynamic>>(
                future: combinedFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return SizedBox(
                      height: 200,
                      child: LoadingIndicator(
                          color: isStripe
                              ? const Color(0xFF635BFF)
                              : AppTheme.secondaryPink),
                    );
                  }

                  if (snapshot.hasError) {
                    return SizedBox(
                      height: 100,
                      child: Center(
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    );
                  }

                  final plans =
                      (snapshot.data?[0] as List<WithdrawalPlan>?) ?? [];
                  final isRateValid = (snapshot.data?[1] as bool?) ?? false;

                  if (plans.isEmpty) {
                    return const SizedBox(
                      height: 100,
                      child: Center(
                        child: Text(
                          'No hay planes de retiro disponibles',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    );
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── INFO: Automated Stripe Banner ──
                      if (isAutomatedStripe) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF635BFF).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFF635BFF).withOpacity(0.5)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.verified_user_rounded,
                                  color: Color(0xFF635BFF), size: 22),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Tu cuenta está vinculada. El dinero se enviará automáticamente a tu balance de Stripe.',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      // ── FAIL-SAFE: Maintenance Banner ──
                      if (!isRateValid) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.redAccent.withOpacity(0.5)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: Colors.redAccent, size: 22),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'El sistema de cambio está en mantenimiento temporal. Los retiros no están disponibles en este momento.',
                                  style: TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      const Text(
                        'Selecciona cuántos tréboles quieres retirar:',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      // Plan Cards
                      ...plans.map((plan) {
                        final isSelected = selectedPlanId == plan.id;
                        return GestureDetector(
                          onTap: isRateValid
                              ? () => setState(() => selectedPlanId = plan.id)
                              : null, // Disable selection when rate is stale
                          child: Opacity(
                            opacity: isRateValid ? 1.0 : 0.5,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isStripe
                                        ? const Color(0xFF635BFF)
                                            .withOpacity(0.2)
                                        : AppTheme.secondaryPink
                                            .withOpacity(0.2))
                                    : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? (isStripe
                                          ? const Color(0xFF635BFF)
                                          : AppTheme.secondaryPink)
                                      : Colors.white.withOpacity(0.1),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Icon
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: (isStripe
                                              ? const Color(0xFF635BFF)
                                              : AppTheme.secondaryPink)
                                          .withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Text(
                                        isStripe ? '💳' : (plan.icon ?? '💸'),
                                        style: const TextStyle(fontSize: 24),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          plan.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              'Costo: ${plan.cloversCost} ',
                                              style: const TextStyle(
                                                color: Colors.white60,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const CoinImage(size: 14),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Amount
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        plan.formattedAmountUsd,
                                        style: TextStyle(
                                          color: isSelected
                                              ? (isStripe
                                                  ? const Color(0xFF635BFF)
                                                  : AppTheme.secondaryPink)
                                              : Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      const Text(
                                        'USD',
                                        style: TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  // Check
                                  if (isSelected) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.check_circle,
                                        color: AppTheme.secondaryPink),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                      if (_isLoading)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: LoadingIndicator(
                              color: isStripe
                                  ? const Color(0xFF635BFF)
                                  : AppTheme.secondaryPink,
                              fontSize: 14),
                        ),
                    ],
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isLoading ? null : () => Navigator.pop(ctx),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(
                    color: Colors.white54,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              FutureBuilder<List<dynamic>>(
                future: combinedFuture,
                builder: (context, snapshot) {
                  final isRateValid = (snapshot.data?[1] as bool?) ?? false;
                  return ElevatedButton(
                    onPressed:
                        (_isLoading || selectedPlanId == null || !isRateValid)
                            ? null
                            : () async {
                                setState(() => _isLoading = true);
                                await _processWithdrawalWithPlan(
                                    context, selectedPlanId!, method);
                                if (mounted) {
                                  setState(() => _isLoading = false);
                                  Navigator.pop(ctx);
                                }
                              },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isStripe
                          ? const Color(0xFF635BFF)
                          : AppTheme.secondaryPink,
                      disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                    ),
                    child: Text(
                      isRateValid ? 'Confirmar Retiro' : 'En Mantenimiento',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  /// Process withdrawal using a withdrawal plan ID.
  ///
  /// Sends plan_id to api_withdraw_funds Edge Function which handles:
  /// - Fetching plan details from withdrawal_plans table
  /// - Converting USD to VES using exchange rate from app_config
  /// - Validating clover balance
  /// - Processing the payment
  Future<void> _processWithdrawalWithPlan(
      BuildContext context, String planId, Map<String, dynamic> method) async {
    try {
      debugPrint('[WalletScreen] Processing withdrawal with plan: $planId');

      final response = await Supabase.instance.client.functions.invoke(
        'api_withdraw_funds',
        body: {
          'plan_id': planId,
          'payment_method_id': method['id'],
          // Legacy support or fallback (optional since we've updated it)
          'bank': method['bank_code'],
          'dni': method['dni'],
          'phone': method['phone_number'],
        },
      );

      if (!mounted) return;

      if (response.status != 200) {
        final errorData = response.data;
        throw Exception(
            errorData?['error'] ?? 'Error en el servidor (${response.status})');
      }

      final data = response.data;
      if (data?['success'] == true) {
        final isPending = data?['pending'] == true;
        final message = data?['message'] ?? (isPending
              ? 'Retiro en proceso. Se confirmara pronto.'
              : '¡Retiro procesado exitosamente!');
              
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
          backgroundColor:
              isPending ? AppTheme.accentGold : AppTheme.successGreen,
        ));
        // Refresh balance and history
        await Provider.of<PlayerProvider>(context, listen: false)
            .refreshProfile();
        _loadRecentTransactions();
      } else {
        throw Exception(data?['error'] ?? 'Error desconocido');
      }
    } catch (e) {
      debugPrint('[WalletScreen] Withdrawal error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.dangerRed,
        ));
      }
    }
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
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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

  Widget _buildStripeConnectSection(bool isDarkMode) {
    if (_stripeStatus == 'completed') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.1),
            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Cuenta de Stripe Verificada',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _CyberRingButton(
                size: 32,
                icon: Icons.open_in_new_rounded,
                onPressed: _handleStripeSetup,
                color: const Color(0xFFFECB00),
              ),
            ],
          ),
        ),
      );
    }

    if (_stripeStatus == 'loading') {
      return const Center(child: LoadingIndicator(fontSize: 12));
    }

    final String title = _stripeStatus == 'pending' 
        ? 'COMPLETAR REGISTRO STRIPE' 
        : 'RECIBIR PAGOS POR STRIPE';
    
    final String subtitle = _stripeStatus == 'pending'
        ? 'Faltan datos para habilitar tus cobros automáticamente.'
        : 'Vincula tu cuenta para retirar tus premios de forma instantánea.';

    final Color statusColor = _stripeStatus == 'pending' ? Colors.orange : const Color(0xFFFECB00);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: statusColor.withOpacity(0.3), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                   Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _stripeStatus == 'pending' ? Icons.warning_amber_rounded : Icons.account_balance_rounded, 
                      color: statusColor, 
                      size: 20
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Orbitron',
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: _isStripeLoading 
                  ? const Center(child: LoadingIndicator(fontSize: 12))
                  : ElevatedButton(
                      onPressed: _handleStripeSetup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: statusColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(
                        _stripeStatus == 'pending' ? 'CONTINUAR' : 'VINCULAR AHORA',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          fontFamily: 'Orbitron',
                        ),
                      ),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CyberRingButton extends StatelessWidget {
  final double size;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;

  const _CyberRingButton({
    required this.size,
    required this.icon,
    this.onPressed,
    this.color = const Color(0xFFFECB00),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1.0,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(0.4),
            border: Border.all(
              color: color.withOpacity(0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 8,
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: size * 0.5,
          ),
        ),
      ),
    );
  }
}
