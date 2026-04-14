import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/app_config_service.dart';
import '../../wallet/models/withdrawal_plan.dart';
import '../../wallet/services/withdrawal_plan_service.dart';
import '../../../shared/widgets/coin_image.dart';

class WithdrawalPlansManagementScreen extends StatefulWidget {
  const WithdrawalPlansManagementScreen({super.key});

  @override
  State<WithdrawalPlansManagementScreen> createState() =>
      _WithdrawalPlansManagementScreenState();
}

class _WithdrawalPlansManagementScreenState
    extends State<WithdrawalPlansManagementScreen> {
  late WithdrawalPlanService _planService;
  late AppConfigService _configService;
  List<WithdrawalPlan> _plans = [];
  bool _isLoading = true;
  String? _error;

  double _exchangeRate = 0.0;
  bool _isLoadingRate = true;
  bool _isUpdatingRate = false;
  bool _isBcvRateValid = true;
  final _rateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _planService =
        WithdrawalPlanService(supabaseClient: Supabase.instance.client);
    _configService = AppConfigService(supabaseClient: Supabase.instance.client);
    _loadData();
  }

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadPlans(),
      _loadExchangeRate(),
    ]);
  }

  Future<void> _loadExchangeRate() async {
    setState(() => _isLoadingRate = true);
    try {
      final results = await Future.wait([
        _configService.getExchangeRate(),
        _configService.isBcvRateValid(),
      ]);
      setState(() {
        _exchangeRate = results[0] as double;
        _isBcvRateValid = results[1] as bool;
        _rateController.text = _exchangeRate.toStringAsFixed(2);
        _isLoadingRate = false;
      });
    } catch (e) {
      setState(() => _isLoadingRate = false);
    }
  }

  Future<void> _updateExchangeRate() async {
    final newRate = double.tryParse(_rateController.text);
    if (newRate == null || newRate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa una tasa válida'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    setState(() => _isUpdatingRate = true);
    final success = await _configService.updateExchangeRate(newRate);
    setState(() => _isUpdatingRate = false);

    if (mounted) {
      if (success) {
        setState(() => _exchangeRate = newRate);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tasa actualizada a $newRate Bs/USD'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al actualizar la tasa'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      }
    }
  }

  Future<void> _loadPlans() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final plans = await _planService.fetchAllPlans();
      setState(() {
        _plans = plans;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _updatePlan(WithdrawalPlan plan,
      {int? cloversCost, double? amountUsd, bool? isActive}) async {
    try {
      await _planService.updatePlan(
        plan.id,
        cloversCost: cloversCost,
        amountUsd: amountUsd,
        isActive: isActive,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Plan "${plan.name}" actualizado'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        _loadPlans();
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
    }
  }

  void _showEditDialog(WithdrawalPlan plan) {
    final cloversController =
        TextEditingController(text: plan.cloversCost.toString());
    final amountController =
        TextEditingController(text: plan.amountUsd.toStringAsFixed(2));
    bool isActive = plan.isActive;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final textColor = Theme.of(context).textTheme.bodyLarge?.color;
          return AlertDialog(
            backgroundColor: Theme.of(context).cardTheme.color,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: AppTheme.lGoldAction.withOpacity(0.1)),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.lGoldAction.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(plan.icon ?? '💸', style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Editar ${plan.name}',
                    style: TextStyle(
                        color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Costo en Tréboles',
                      style: TextStyle(color: textColor?.withOpacity(0.7))),
                  const SizedBox(height: 8),
                  TextField(
                    controller: cloversController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      suffixIcon: const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: CoinImage(size: 20),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).dividerColor.withOpacity(0.05),
                      enabledBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide:
                             const BorderSide(color: AppTheme.lGoldAction, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Monto a Recibir (USD)',
                      style: TextStyle(color: textColor?.withOpacity(0.7))),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.attach_money, color: AppTheme.lGoldAction),
                      filled: true,
                      fillColor: Theme.of(context).dividerColor.withOpacity(0.05),
                      enabledBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide:
                             const BorderSide(color: AppTheme.lGoldAction, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_exchangeRate > 0)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.lGoldAction.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.lGoldAction.withOpacity(0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline, color: AppTheme.lGoldAction, size: 16),
                              const SizedBox(width: 8),
                              Text('Simulación de Recepción:',
                                  style: TextStyle(
                                      color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildSourceRow(Icons.credit_card, 'Stripe (USD):', 
                              '\$${(double.tryParse(amountController.text) ?? 0).toStringAsFixed(2)}', textColor),
                          const SizedBox(height: 4),
                          _buildSourceRow(Icons.phone_android, 'Pago Móvil (VES):', 
                              '${((double.tryParse(amountController.text) ?? 0) * _exchangeRate).toStringAsFixed(2)} Bs.', textColor),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text('Plan Activo',
                        style: TextStyle(color: textColor)),
                    subtitle: Text(
                      isActive
                          ? 'Visible para usuarios'
                          : 'Oculto para usuarios',
                      style:
                           TextStyle(color: textColor?.withOpacity(0.6), fontSize: 12),
                    ),
                    value: isActive,
                    activeColor: Theme.of(context).primaryColor,
                    onChanged: (value) => setState(() => isActive = value),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancelar',
                    style: TextStyle(color: textColor?.withOpacity(0.6))),
              ),
              ElevatedButton(
                onPressed: () {
                  final newClovers = int.tryParse(cloversController.text);
                  final newAmount = double.tryParse(amountController.text);

                  if (newClovers == null || newClovers <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Costo en tréboles inválido')),
                    );
                    return;
                  }

                  if (newAmount == null || newAmount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Monto USD inválido')),
                    );
                    return;
                  }

                  Navigator.pop(ctx);
                  _updatePlan(
                    plan,
                    cloversCost: newClovers,
                    amountUsd: newAmount,
                    isActive: isActive,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.lGoldAction,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Planes de Retiro',
           style: TextStyle(color: textColor, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.lGoldAction),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.lGoldAction),
            onPressed: _loadData,
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: primaryColor))
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!,
                            style: const TextStyle(color: Colors.redAccent)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadData,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildExchangeRateCard(),
                      const SizedBox(height: 24),
                      Text(
                        'Planes Disponibles',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._plans.map((plan) => _buildPlanCard(plan)),
                    ],
                  ),
      ),
    );
  }

  Widget _buildExchangeRateCard() {
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.lGoldAction.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.lGoldAction.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.lGoldAction.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.currency_exchange,
                    color: AppTheme.lGoldAction, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tasa de Cambio BCV',
                        style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('USD → VES para retiros oficiales',
                        style: TextStyle(color: textColor?.withOpacity(0.5), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingRate)
            Center(
                child: CircularProgressIndicator(color: primaryColor))
          else ...[
            if (!_isBcvRateValid)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.redAccent, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '⚠️ TASA DESACTUALIZADA — Los retiros están bloqueados. Actualiza la tasa para reactivar.',
                        style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_exchangeRate.toStringAsFixed(2)} Bs.',
                    style: const TextStyle(
                        color: AppTheme.lGoldAction,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1),
                  ),
                ),
                Text('/ USD', 
                    style: TextStyle(color: textColor?.withOpacity(0.3), fontWeight: FontWeight.bold)),
              ],
            ),
          ],
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 400) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _rateController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Nueva Tasa',
                        labelStyle: TextStyle(color: textColor?.withOpacity(0.5)),
                        prefixIcon: const Icon(Icons.edit_note, color: AppTheme.lGoldAction),
                        filled: true,
                        fillColor: Theme.of(context).dividerColor.withOpacity(0.05),
                        enabledBorder: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide:
                               const BorderSide(color: AppTheme.lGoldAction, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _isUpdatingRate ? null : _updateExchangeRate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.lGoldAction,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isUpdatingRate
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('ACTUALIZAR TASA', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _rateController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Nueva Tasa BCV',
                        labelStyle: TextStyle(color: textColor?.withOpacity(0.5)),
                        prefixIcon: const Icon(Icons.edit_note, color: AppTheme.lGoldAction),
                        filled: true,
                        fillColor: Theme.of(context).dividerColor.withOpacity(0.05),
                        enabledBorder: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide:
                               const BorderSide(color: AppTheme.lGoldAction, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isUpdatingRate ? null : _updateExchangeRate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.lGoldAction,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      elevation: 0,
                    ),
                    child: _isUpdatingRate
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('ACTUALIZAR', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(WithdrawalPlan plan) {
    final vesAmount = plan.amountUsd * _exchangeRate;
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: plan.isActive
              ? AppTheme.lGoldAction.withOpacity(0.15)
              : Theme.of(context).dividerColor.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, cardConstraints) {
          final bool isNarrow = cardConstraints.maxWidth < 350;
          return Row(
            children: [
              Container(
                width: isNarrow ? 40 : 48,
                height: isNarrow ? 40 : 48,
                decoration: BoxDecoration(
                  color: plan.isActive
                      ? AppTheme.lGoldAction.withOpacity(0.12)
                      : Theme.of(context).dividerColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(plan.icon ?? '💸',
                      style: TextStyle(fontSize: isNarrow ? 18 : 20)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            plan.name,
                            style: TextStyle(
                              color: plan.isActive ? textColor : Colors.grey,
                              fontSize: isNarrow ? 14 : 15,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!plan.isActive) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).dividerColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('OFF',
                                style:
                                    TextStyle(color: textColor?.withOpacity(0.4), fontSize: 8, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${plan.cloversCost} ',
                          style: TextStyle(
                            color: plan.isActive ? textColor?.withOpacity(0.7) : Colors.grey,
                            fontSize: isNarrow ? 10 : 11,
                          ),
                        ),
                        CoinImage(size: isNarrow ? 10 : 11),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.credit_card, color: Colors.blueAccent, size: 10),
                        const SizedBox(width: 4),
                        Text(
                          '${plan.amountUsd.toStringAsFixed(2)} USD',
                          style: TextStyle(
                            color: plan.isActive ? textColor?.withOpacity(0.5) : Colors.grey.withOpacity(0.5),
                            fontSize: isNarrow ? 9 : 11,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.phone_android, color: AppTheme.secondaryPink, size: 10),
                        const SizedBox(width: 4),
                        Text(
                          '${vesAmount.toStringAsFixed(2)} VES',
                          style: TextStyle(
                            color: plan.isActive ? textColor?.withOpacity(0.4) : Colors.grey.withOpacity(0.5),
                            fontSize: isNarrow ? 9 : 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      plan.formattedAmountUsd,
                      style: TextStyle(
                        color:
                            plan.isActive ? AppTheme.lGoldAction : Colors.grey,
                        fontSize: isNarrow ? 14 : 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text('USD',
                      style: TextStyle(
                          color: plan.isActive ? AppTheme.lGoldAction.withOpacity(0.5) : Colors.grey, 
                          fontSize: isNarrow ? 8 : 10,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.edit_rounded,
                    color: AppTheme.lGoldAction.withOpacity(0.7), size: isNarrow ? 18 : 22),
                onPressed: () => _showEditDialog(plan),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Editar',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSourceRow(IconData icon, String label, String value, Color? textColor) {
    return Row(
      children: [
        Icon(icon, size: 14, color: textColor?.withOpacity(0.5)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: textColor?.withOpacity(0.6), fontSize: 12)),
        const Spacer(),
        Text(value, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }
}
