import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../wallet/models/clover_plan.dart';
import '../../wallet/services/clover_plan_service.dart';
import '../../../shared/widgets/coin_image.dart';

class CloverPlansManagementScreen extends StatefulWidget {
  const CloverPlansManagementScreen({super.key});

  @override
  State<CloverPlansManagementScreen> createState() =>
      _CloverPlansManagementScreenState();
}

class _CloverPlansManagementScreenState
    extends State<CloverPlansManagementScreen> {
  late CloverPlanService _planService;
  List<CloverPlan> _plans = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _planService = CloverPlanService(supabaseClient: Supabase.instance.client);
    _loadPlans();
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

  Future<void> _updatePlan(CloverPlan plan,
      {double? priceUsd, int? cloversQuantity, bool? isActive}) async {
    try {
      await _planService.updatePlan(
        plan.id,
        priceUsd: priceUsd,
        cloversQuantity: cloversQuantity,
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

  void _showEditDialog(CloverPlan plan) {
    final priceController =
        TextEditingController(text: plan.priceUsd.toStringAsFixed(2));
    final cloversController =
        TextEditingController(text: plan.cloversQuantity.toString());
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
                  child: const CoinImage(size: 22),
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
                  Text('Precio (USD)',
                      style: TextStyle(color: textColor?.withOpacity(0.7))),
                  const SizedBox(height: 8),
                  TextField(
                    controller: priceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.attach_money, color: AppTheme.lGoldAction, size: 20),
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
                  Text('Cantidad de Tréboles',
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
                  final newPrice = double.tryParse(priceController.text);
                  final newClovers = int.tryParse(cloversController.text);

                  if (newPrice == null || newPrice <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Precio inválido')),
                    );
                    return;
                  }

                  if (newClovers == null || newClovers <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cantidad inválida')),
                    );
                    return;
                  }

                  Navigator.pop(ctx);
                  _updatePlan(
                    plan,
                    priceUsd: newPrice,
                    cloversQuantity: newClovers,
                    isActive: isActive,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.lGoldAction,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
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
          'Gestión de Planes',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.lGoldAction),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.lGoldAction),
            onPressed: _loadPlans,
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
                          onPressed: _loadPlans,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Planes de Tréboles',
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

  Widget _buildPlanCard(CloverPlan plan) {
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
          final bool isNarrow = cardConstraints.maxWidth < 360;
          return Row(
            children: [
              Container(
                width: isNarrow ? 48 : 60,
                height: isNarrow ? 48 : 60,
                decoration: BoxDecoration(
                  color: plan.isActive
                      ? AppTheme.lGoldAction.withOpacity(0.12)
                      : Theme.of(context).dividerColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: CoinImage(size: isNarrow ? 22 : 28),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          plan.name,
                          style: TextStyle(
                            color: plan.isActive ? textColor : Colors.grey,
                            fontSize: isNarrow ? 15 : 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (!plan.isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).dividerColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'INACTIVO',
                              style: TextStyle(color: textColor?.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${plan.cloversQuantity} Tréboles',
                      style: TextStyle(
                        color: plan.isActive ? textColor?.withOpacity(0.5) : Colors.grey.withOpacity(0.5),
                        fontSize: isNarrow ? 12 : 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        plan.formattedPrice,
                        style: TextStyle(
                          color:
                              plan.isActive ? AppTheme.lGoldAction : Colors.grey,
                          fontSize: isNarrow ? 16 : 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      'USD',
                      style: TextStyle(
                          color: plan.isActive ? AppTheme.lGoldAction.withOpacity(0.5) : Colors.grey, 
                          fontSize: isNarrow ? 8 : 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.edit_rounded,
                    color: AppTheme.lGoldAction.withOpacity(0.7), size: isNarrow ? 18 : 24),
                onPressed: () => _showEditDialog(plan),
                tooltip: 'Editar',
              ),
            ],
          );
        },
      ),
    );
  }
}
