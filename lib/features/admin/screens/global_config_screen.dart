import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/app_config_service.dart';
import '../../../core/models/payment_methods_config.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/payment_methods_config_provider.dart';
import '../../mall/models/power_item.dart';

/// Data class for each collapsible config section.
class _ConfigSection {
  final String id;
  final String title;
  final IconData icon;
  final GlobalKey sectionKey;
  bool isExpanded;

  _ConfigSection({
    required this.id,
    required this.title,
    required this.icon,
    this.isExpanded = false,
  }) : sectionKey = GlobalKey();
}

class GlobalConfigScreen extends StatefulWidget {
  const GlobalConfigScreen({super.key});

  @override
  State<GlobalConfigScreen> createState() => _GlobalConfigScreenState();
}

class _GlobalConfigScreenState extends State<GlobalConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  final _exchangeRateController = TextEditingController();
  final _gatewayFeeController = TextEditingController();
  final _minigameEasyController = TextEditingController();
  final _minigameMediumController = TextEditingController();
  final _minigameHardController = TextEditingController();

  Map<String, int> _powerDefaultCosts = {};

  final _pmBancoController = TextEditingController();
  final _pmCedulaController = TextEditingController();
  final _pmTelefonoController = TextEditingController();

  final _latestVersionController = TextEditingController();
  final _minVersionController = TextEditingController();
  final _apkUrlController = TextEditingController();
  final _androidStoreUrlController = TextEditingController();
  final _iosStoreUrlController = TextEditingController();
  bool _maintenanceMode = false;
  bool _isSavingVersion = false;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _rechargeEnabled = true;
  bool _isTogglingRecharge = false;
  bool _isSavingPaymentMethods = false;
  bool _minigameMinDurationEnabled = true;
  bool _merchandiseStoreEnabled = false;
  bool _isTogglingMerchandiseStore = false;

  PaymentMethodsConfig _paymentMethodsConfig =
      PaymentMethodsConfig.fallbackAllDisabled();

  late final AppConfigService _configService;

  late final List<_ConfigSection> _sections;

  @override
  void initState() {
    super.initState();
    _configService = AppConfigService(supabaseClient: Supabase.instance.client);

    _sections = [
      _ConfigSection(id: 'exchange', title: 'Tasa de Cambio BCV', icon: Icons.currency_exchange),
      _ConfigSection(id: 'fee', title: 'Comisión de Pasarela', icon: Icons.percent),
      _ConfigSection(id: 'recharge', title: 'Botón de Recarga', icon: Icons.add_card),
      _ConfigSection(id: 'merchandise_store', title: 'Tienda de Mercancía', icon: Icons.storefront),
      _ConfigSection(id: 'payment_methods', title: 'Métodos de Pago', icon: Icons.tune),
      _ConfigSection(id: 'pago_movil', title: 'Pago Móvil Destinatario', icon: Icons.phone_android),
      _ConfigSection(id: 'version', title: 'Control de Versiones', icon: Icons.system_update_alt),
      _ConfigSection(id: 'powers', title: 'Precios Base de Poderes', icon: Icons.bolt),
      _ConfigSection(id: 'minigame', title: 'Tiempos de Minijuegos', icon: Icons.timer),
    ];

    _loadConfig();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _exchangeRateController.dispose();
    _gatewayFeeController.dispose();
    _minigameEasyController.dispose();
    _minigameMediumController.dispose();
    _minigameHardController.dispose();
    _pmBancoController.dispose();
    _pmCedulaController.dispose();
    _pmTelefonoController.dispose();
    _latestVersionController.dispose();
    _minVersionController.dispose();
    _apkUrlController.dispose();
    _androidStoreUrlController.dispose();
    _iosStoreUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _configService.getExchangeRate(),
        _configService.getGatewayFeePercentage(),
        _configService.isRechargeEnabled(),
        _configService.getVersionConfig(),
        _configService.getPowerDefaultCosts(),
        _configService.getMinigameMinDurationEnabled(),
        _configService.getMinigameMinDurationsByDifficulty(),
        _configService.getPagoMovilRecipient(),
        _configService.getPaymentMethodsStatus(),
        _configService.isMerchandiseStoreEnabled(),
      ]);
      _exchangeRateController.text = (results[0] as double).toStringAsFixed(2);
      _gatewayFeeController.text = (results[1] as double).toStringAsFixed(2);
      _rechargeEnabled = results[2] as bool;

      final versionCfg = results[3] as Map<String, dynamic>;

      final dbPowerCosts = results[4] as Map<String, int>;
      _powerDefaultCosts = {};
      for (var item in PowerItem.getShopItems()) {
        _powerDefaultCosts[item.id] = dbPowerCosts[item.id] ?? item.cost;
      }

      _minigameMinDurationEnabled = results[5] as bool;
      final minigameDurations = results[6] as Map<String, int>;
        _minigameEasyController.text =
          (minigameDurations['easy'] ?? 4).toString();
        _minigameMediumController.text =
          (minigameDurations['medium'] ?? 8).toString();
        _minigameHardController.text =
          (minigameDurations['hard'] ?? 12).toString();

      _latestVersionController.text =
          versionCfg['latest_version'] as String? ?? '1.0.0';
      _minVersionController.text =
          versionCfg['min_supported_version'] as String? ?? '1.0.0';
      _apkUrlController.text = versionCfg['apk_download_url'] as String? ?? '';
      _androidStoreUrlController.text =
          versionCfg['android_store_url'] as String? ?? '';
      _iosStoreUrlController.text =
          versionCfg['ios_store_url'] as String? ?? '';
      _maintenanceMode = versionCfg['maintenance_mode'] as bool? ?? false;

      final pmRecipient = results[7] as Map<String, String>;
      _pmBancoController.text = pmRecipient['banco'] ?? '';
      _pmCedulaController.text = pmRecipient['cedula'] ?? '';
      _pmTelefonoController.text = pmRecipient['telefono'] ?? '';

      _paymentMethodsConfig = results[8] as PaymentMethodsConfig;
      _merchandiseStoreEnabled = results[9] as bool;
    } catch (e) {
      debugPrint('[GlobalConfigScreen] Error loading config: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToSection(_ConfigSection section) {
    // Expand the section first
    setState(() {
      section.isExpanded = true;
    });

    // Wait for the widget tree to rebuild, then scroll
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = section.sectionKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          alignment: 0.0,
        );
      }
    });
  }

  bool _sectionMatchesSearch(_ConfigSection section) {
    if (_searchQuery.isEmpty) return true;
    return section.title.toLowerCase().contains(_searchQuery);
  }

  Future<void> _togglePaymentMethod(
    String flow,
    String methodId,
    bool value,
  ) async {
    if (_isSavingPaymentMethods) return;
    setState(() => _isSavingPaymentMethods = true);

    final updated = flow == 'withdrawal'
        ? _paymentMethodsConfig.copyWith(
            withdrawal: {
              ..._paymentMethodsConfig.withdrawal,
              methodId: value,
            },
          )
        : _paymentMethodsConfig.copyWith(
            purchase: {
              ..._paymentMethodsConfig.purchase,
              methodId: value,
            },
          );

    final success = await _configService.updatePaymentMethodsStatus(updated);

    if (mounted) {
      setState(() {
        if (success) {
          _paymentMethodsConfig = updated;
        }
        _isSavingPaymentMethods = false;
      });
      if (success) {
        final provider =
            Provider.of<PaymentMethodsConfigProvider>(context, listen: false);
        provider.update(updated);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Metodos de pago actualizados'
                : 'Error al actualizar metodos de pago',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _saveVersionConfig() async {
    final semverRegex = RegExp(r'^\d+\.\d+\.\d+$');
    if (!semverRegex.hasMatch(_latestVersionController.text.trim()) ||
        !semverRegex.hasMatch(_minVersionController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Formato inválido. Usa x.y.z (ej: 1.0.1)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSavingVersion = true);
    final success = await _configService.updateVersionConfig({
      'latest_version': _latestVersionController.text.trim(),
      'min_supported_version': _minVersionController.text.trim(),
      'apk_download_url': _apkUrlController.text.trim(),
      'android_store_url': _androidStoreUrlController.text.trim(),
      'ios_store_url': _iosStoreUrlController.text.trim(),
      'maintenance_mode': _maintenanceMode,
    });
    if (mounted) {
      setState(() => _isSavingVersion = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Versión actualizada correctamente'
              : 'Error al guardar la versión'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleRecharge(bool value) async {
    setState(() => _isTogglingRecharge = true);
    final success = await _configService.setRechargeEnabled(value);
    if (mounted) {
      setState(() {
        if (success) _rechargeEnabled = value;
        _isTogglingRecharge = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? (value ? 'Recarga habilitada' : 'Recarga en mantenimiento')
              : 'Error al cambiar estado de recarga'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleMerchandiseStore(bool value) async {
    setState(() => _isTogglingMerchandiseStore = true);
    final success = await _configService.setMerchandiseStoreEnabled(value);
    if (mounted) {
      setState(() {
        if (success) _merchandiseStoreEnabled = value;
        _isTogglingMerchandiseStore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? (value ? 'Tienda habilitada' : 'Tienda deshabilitada')
              : 'Error al cambiar estado de la tienda'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final exchangeRate = double.parse(_exchangeRateController.text);
      final gatewayFee = double.parse(_gatewayFeeController.text);
      final minigameEasy = int.tryParse(_minigameEasyController.text);
      final minigameMedium = int.tryParse(_minigameMediumController.text);
      final minigameHard = int.tryParse(_minigameHardController.text);

      if (_minigameMinDurationEnabled &&
          (minigameEasy == null ||
              minigameMedium == null ||
              minigameHard == null)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Minimo de tiempo de minijuegos inválido'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isSaving = false);
        return;
      }

      final rateSuccess = await _configService.updateExchangeRate(exchangeRate);
      final feeSuccess =
          await _configService.updateGatewayFeePercentage(gatewayFee);
      final powerSuccess = await _configService
          .updatePowerDefaultCosts(_powerDefaultCosts);
      final minigameEnabledSuccess =
          await _configService.updateMinigameMinDurationEnabled(
        _minigameMinDurationEnabled,
      );
      final minigameSuccess =
          await _configService.updateMinigameMinDurationsByDifficulty({
        'easy': minigameEasy ?? 4,
        'medium': minigameMedium ?? 8,
        'hard': minigameHard ?? 12,
      });
      final pmSuccess = await _configService.updatePagoMovilRecipient({
        'banco': _pmBancoController.text.trim(),
        'cedula': _pmCedulaController.text.trim(),
        'telefono': _pmTelefonoController.text.trim(),
      });

      PowerItem.updateGlobalCosts(_powerDefaultCosts);

      if (mounted) {
        if (rateSuccess &&
            feeSuccess &&
            powerSuccess &&
            minigameEnabledSuccess &&
            minigameSuccess &&
            pmSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Configuración guardada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al guardar configuración'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.lGoldAction),
      );
    }

    final textColor = Theme.of(context).textTheme.displayLarge?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;

    final filteredSections = _sections.where(_sectionMatchesSearch).toList();

    return Column(
      children: [
        // ── Sticky header: title + search + nav chips ──
        Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Configuración Global',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Configuraciones que afectan el funcionamiento de la app.',
                          style: TextStyle(
                            color: secondaryTextColor?.withOpacity(0.6),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Expand / collapse all
                  IconButton(
                    tooltip: 'Expandir todas',
                    icon: Icon(Icons.unfold_more, color: secondaryTextColor?.withOpacity(0.5)),
                    onPressed: () {
                      setState(() {
                        for (final s in _sections) {
                          s.isExpanded = true;
                        }
                      });
                    },
                  ),
                  IconButton(
                    tooltip: 'Colapsar todas',
                    icon: Icon(Icons.unfold_less, color: secondaryTextColor?.withOpacity(0.5)),
                    onPressed: () {
                      setState(() {
                        for (final s in _sections) {
                          s.isExpanded = false;
                        }
                      });
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Search bar ──
              TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                style: TextStyle(color: textColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Buscar sección...',
                  hintStyle: TextStyle(color: secondaryTextColor?.withOpacity(0.35)),
                  prefixIcon: Icon(Icons.search, color: secondaryTextColor?.withOpacity(0.4), size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: secondaryTextColor?.withOpacity(0.4), size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Theme.of(context).dividerColor.withOpacity(0.05),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.lGoldAction, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Quick-access nav chips ──
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: filteredSections.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final section = filteredSections[i];
                    return ActionChip(
                      avatar: Icon(section.icon, size: 16, color: AppTheme.lGoldAction),
                      label: Text(
                        section.title,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      backgroundColor: Theme.of(context).cardTheme.color,
                      side: BorderSide(color: AppTheme.lGoldAction.withOpacity(0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      onPressed: () => _scrollToSection(section),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),

        // ── Scrollable content ──
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  if (_sectionMatchesSearch(_sections[0]))
                    _buildCollapsibleSection(_sections[0], _buildExchangeRateContent()),
                  if (_sectionMatchesSearch(_sections[1]))
                    _buildCollapsibleSection(_sections[1], _buildGatewayFeeContent()),
                  if (_sectionMatchesSearch(_sections[2]))
                    _buildCollapsibleSection(_sections[2], _buildRechargeContent()),
                  if (_sectionMatchesSearch(_sections[3]))
                    _buildCollapsibleSection(_sections[3], _buildMerchandiseStoreContent()),
                  if (_sectionMatchesSearch(_sections[4]))
                    _buildCollapsibleSection(_sections[4], _buildPaymentMethodsContent()),
                  if (_sectionMatchesSearch(_sections[5]))
                    _buildCollapsibleSection(_sections[5], _buildPagoMovilContent()),
                  if (_sectionMatchesSearch(_sections[6]))
                    _buildCollapsibleSection(_sections[6], _buildVersionContent()),
                  if (_sectionMatchesSearch(_sections[7]))
                    _buildCollapsibleSection(_sections[7], _buildPowerCostsContent()),
                  if (_sectionMatchesSearch(_sections[8]))
                    _buildCollapsibleSection(_sections[8], _buildMinigameTimingContent()),

                  const SizedBox(height: 24),

                  // ── Global save button ──
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveConfig,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.lGoldAction,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Theme.of(context).dividerColor.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 5,
                        shadowColor: AppTheme.lGoldAction.withOpacity(0.2),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'GUARDAR CONFIGURACIÓN',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COLLAPSIBLE SECTION WRAPPER
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCollapsibleSection(_ConfigSection section, Widget content) {
    final textColor = Theme.of(context).textTheme.displayLarge?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;

    return Padding(
      key: section.sectionKey,
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: section.isExpanded
                ? AppTheme.lGoldAction.withOpacity(0.25)
                : Theme.of(context).dividerColor.withOpacity(0.1),
          ),
          boxShadow: [
            if (section.isExpanded)
              BoxShadow(
                color: AppTheme.lGoldAction.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          children: [
            // ── Header (always visible) ──
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => setState(() => section.isExpanded = !section.isExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.lGoldAction.withOpacity(section.isExpanded ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        section.icon,
                        color: AppTheme.lGoldAction,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        section.title,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: section.isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: secondaryTextColor?.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Content (collapsible) ──
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: content,
              ),
              crossFadeState: section.isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
              sizeCurve: Curves.easeInOut,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION CONTENT BUILDERS
  // ═══════════════════════════════════════════════════════════════════════════

  InputDecoration _inputDecoration({String? hint, String? prefix, String? suffix}) {
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    return InputDecoration(
      filled: true,
      fillColor: Theme.of(context).dividerColor.withOpacity(0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.lGoldAction, width: 2),
      ),
      hintText: hint,
      hintStyle: TextStyle(color: secondaryTextColor?.withOpacity(0.3)),
      prefixText: prefix,
      prefixStyle: const TextStyle(color: AppTheme.lGoldAction),
      suffixText: suffix,
      suffixStyle: TextStyle(color: secondaryTextColor?.withOpacity(0.5)),
    );
  }

  Widget _buildExchangeRateContent() {
    final textColor = Theme.of(context).textTheme.displayLarge?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tasa USD → VES para cálculo de retiros',
          style: TextStyle(color: secondaryTextColor?.withOpacity(0.5), fontSize: 12),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _exchangeRateController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: textColor, fontSize: 18),
          decoration: _inputDecoration(hint: 'Ej: 56.50', prefix: 'Bs. ', suffix: 'por 1 USD').copyWith(
            fillColor: Theme.of(context).cardTheme.color,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Requerido';
            final parsed = double.tryParse(value);
            if (parsed == null || parsed <= 0) return 'Ingrese un valor válido';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildGatewayFeeContent() {
    final textColor = Theme.of(context).textTheme.displayLarge?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Porcentaje de comisión de Pago a Pago',
          style: TextStyle(color: secondaryTextColor?.withOpacity(0.5), fontSize: 12),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.amber, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Este valor debe coincidir con la comisión configurada en Pago a Pago '
                  'para mostrar el estimado correcto al usuario.',
                  style: TextStyle(color: Colors.amber.withOpacity(0.9), fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _gatewayFeeController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: textColor, fontSize: 18),
          decoration: _inputDecoration(hint: 'Ej: 3.0', suffix: '%').copyWith(
            fillColor: Theme.of(context).cardTheme.color,
            suffixStyle: const TextStyle(color: AppTheme.lGoldAction, fontSize: 18),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Requerido';
            final parsed = double.tryParse(value);
            if (parsed == null || parsed < 0) return 'Ingrese un valor válido (0 o más)';
            if (parsed > 100) return 'El porcentaje no puede ser mayor a 100';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildRechargeContent() {
    final textColor = Theme.of(context).textTheme.displayLarge?.color;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _rechargeEnabled
                    ? 'Disponible — los usuarios pueden recargar'
                    : 'En mantenimiento — botón deshabilitado',
                style: TextStyle(
                  color: _rechargeEnabled
                      ? AppTheme.lGoldText
                      : Colors.orange.shade700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _isTogglingRecharge
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.lGoldAction,
                ),
              )
            : Switch(
                value: _rechargeEnabled,
                onChanged: _toggleRecharge,
                activeColor: AppTheme.lGoldAction,
                inactiveThumbColor: Colors.orange,
                inactiveTrackColor: Colors.orange.withOpacity(0.3),
              ),
      ],
    );
  }

  Widget _buildMerchandiseStoreContent() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _merchandiseStoreEnabled
                    ? 'Visible — los usuarios ven la Tienda'
                    : 'Oculta — la Tienda no aparece en el menú',
                style: TextStyle(
                  color: _merchandiseStoreEnabled
                      ? AppTheme.lGoldText
                      : Colors.orange.shade700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Controla la visibilidad del tab "Tienda" en la pantalla principal.',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _isTogglingMerchandiseStore
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.lGoldAction,
                ),
              )
            : Switch(
                value: _merchandiseStoreEnabled,
                onChanged: _toggleMerchandiseStore,
                activeColor: AppTheme.lGoldAction,
                inactiveThumbColor: Colors.orange,
                inactiveTrackColor: Colors.orange.withOpacity(0.3),
              ),
      ],
    );
  }

  Widget _buildPaymentMethodsContent() {
    final textColor = Theme.of(context).textTheme.displayLarge?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final primaryColor = AppTheme.lGoldAction;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Habilita o deshabilita metodos por flujo',
              style: TextStyle(color: secondaryTextColor?.withOpacity(0.5), fontSize: 12),
            ),
            const Spacer(),
            if (_isSavingPaymentMethods)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: primaryColor,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Compra',
          style: TextStyle(color: secondaryTextColor?.withOpacity(0.7), fontSize: 12),
        ),
        const SizedBox(height: 6),
        ...PaymentMethodsCatalog.purchase.map((method) {
          final enabled = _paymentMethodsConfig.isEnabled(
            flow: 'purchase',
            methodId: method.id,
          );
          return SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(method.label,
                style: TextStyle(color: textColor)),
            subtitle: Text(
              method.description,
              style: TextStyle(color: secondaryTextColor?.withOpacity(0.4), fontSize: 11),
            ),
            value: enabled,
            activeColor: primaryColor,
            onChanged: _isSavingPaymentMethods
                ? null
                : (value) =>
                     _togglePaymentMethod('purchase', method.id, value),
          );
        }),
        const SizedBox(height: 12),
        Text(
          'Retiro',
          style: TextStyle(color: secondaryTextColor?.withOpacity(0.7), fontSize: 12),
        ),
        const SizedBox(height: 6),
        ...PaymentMethodsCatalog.withdrawal.map((method) {
          final enabled = _paymentMethodsConfig.isEnabled(
            flow: 'withdrawal',
            methodId: method.id,
          );
          return SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(method.label,
                style: TextStyle(color: textColor)),
            subtitle: Text(
              method.description,
              style: TextStyle(color: secondaryTextColor?.withOpacity(0.4), fontSize: 11),
            ),
            value: enabled,
            activeColor: primaryColor,
            onChanged: _isSavingPaymentMethods
                ? null
                : (value) =>
                     _togglePaymentMethod('withdrawal', method.id, value),
          );
        }),
      ],
    );
  }

  Widget _buildPagoMovilContent() {
    final textColor = Theme.of(context).textTheme.displayLarge?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final primaryColor = AppTheme.lGoldAction;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Datos que verá el usuario al hacer Pago Móvil',
          style: TextStyle(color: secondaryTextColor?.withOpacity(0.5), fontSize: 12),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _pmBancoController,
          keyboardType: TextInputType.number,
          style: TextStyle(color: textColor, fontSize: 16),
          decoration: InputDecoration(
            labelText: 'Código de Banco',
            labelStyle: TextStyle(color: secondaryTextColor?.withOpacity(0.6)),
            hintText: 'Ej: 0134',
            hintStyle: TextStyle(color: secondaryTextColor?.withOpacity(0.25)),
            prefixIcon: Icon(Icons.account_balance, color: primaryColor.withOpacity(0.7), size: 20),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.lGoldAction),
            ),
            filled: true,
            fillColor: Theme.of(context).dividerColor.withOpacity(0.05),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _pmCedulaController,
          keyboardType: TextInputType.number,
          style: TextStyle(color: textColor, fontSize: 16),
          decoration: InputDecoration(
            labelText: 'Cédula (sin la V)',
            labelStyle: TextStyle(color: secondaryTextColor?.withOpacity(0.6)),
            hintText: 'Ej: 12345678',
            hintStyle: TextStyle(color: secondaryTextColor?.withOpacity(0.25)),
            prefixIcon: Icon(Icons.badge_outlined, color: primaryColor.withOpacity(0.7), size: 20),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.lGoldAction),
            ),
            filled: true,
            fillColor: Theme.of(context).dividerColor.withOpacity(0.05),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _pmTelefonoController,
          keyboardType: TextInputType.phone,
          style: TextStyle(color: textColor, fontSize: 16),
          decoration: InputDecoration(
            labelText: 'Teléfono',
            labelStyle: TextStyle(color: secondaryTextColor?.withOpacity(0.6)),
            hintText: 'Ej: 04121234567',
            hintStyle: TextStyle(color: secondaryTextColor?.withOpacity(0.25)),
            prefixIcon: Icon(Icons.phone_rounded, color: primaryColor.withOpacity(0.7), size: 20),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.lGoldAction),
            ),
            filled: true,
            fillColor: Theme.of(context).dividerColor.withOpacity(0.05),
          ),
        ),
      ],
    );
  }

  Widget _buildVersionContent() {
    final textColor = Theme.of(context).textTheme.displayLarge?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: Colors.blueAccent, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'La "Versión mínima" es la que bloquea usuarios con APK antigua. '
                  '"Versión publicada" es solo informativa. '
                  'Ambas usan formato x.y.z (ej: 1.0.1).',
                  style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildVersionField(
          controller: _latestVersionController,
          label: 'Versión publicada',
          hint: '1.0.0',
          helper: 'Versión del APK que subiste al servidor',
        ),
        const SizedBox(height: 16),
        _buildVersionField(
          controller: _minVersionController,
          label: 'Versión mínima requerida',
          hint: '1.0.0',
          helper: 'Los APKs más antiguos quedarán bloqueados',
          accentColor: Theme.of(context).colorScheme.secondary,
        ),
        const SizedBox(height: 16),
        _buildUrlField(
          controller: _apkUrlController,
          label: 'URL descarga APK (Android sin Store)',
          hint: 'https://tudominio.com/download/app.apk',
          icon: Icons.android_rounded,
          iconColor: Colors.green,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).dividerColor.withOpacity(0.03),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.store_rounded, color: textColor?.withOpacity(0.38), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'URLs de tiendas oficiales (opcional)',
                    style: TextStyle(
                      color: textColor?.withOpacity(0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Déjalas vacías hasta que la app esté publicada en cada tienda. '
                'Cuando tengan valor, tienen prioridad sobre la URL del APK.',
                style: TextStyle(color: textColor?.withOpacity(0.3), fontSize: 11),
              ),
              const SizedBox(height: 14),
              _buildUrlField(
                controller: _androidStoreUrlController,
                label: 'Play Store URL (Android)',
                hint: 'https://play.google.com/store/apps/details?id=com.map.hunter',
                icon: Icons.shop_rounded,
                iconColor: Colors.green.shade700,
              ),
              const SizedBox(height: 12),
              _buildUrlField(
                controller: _iosStoreUrlController,
                label: 'App Store URL (iOS)',
                hint: 'https://apps.apple.com/app/idXXXXXXXXX',
                icon: Icons.apple_rounded,
                iconColor: textColor?.withOpacity(0.7) ?? Colors.grey,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Maintenance mode
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _maintenanceMode
                ? Colors.orange.withOpacity(0.08)
                : Theme.of(context).dividerColor.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _maintenanceMode
                  ? Colors.orange.withOpacity(0.4)
                  : Theme.of(context).dividerColor.withOpacity(0.1),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.construction_rounded,
                color: _maintenanceMode ? Colors.orange : secondaryTextColor?.withOpacity(0.38),
                size: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Modo Mantenimiento',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _maintenanceMode
                          ? 'Activo — todos los usuarios ven pantalla de mantenimiento'
                          : 'Inactivo — la app funciona normalmente',
                      style: TextStyle(
                        color: _maintenanceMode
                            ? Colors.orange.shade700
                            : secondaryTextColor?.withOpacity(0.38),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _maintenanceMode,
                onChanged: (v) => setState(() => _maintenanceMode = v),
                activeColor: AppTheme.lGoldAction,
                inactiveThumbColor: secondaryTextColor?.withOpacity(0.38),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Save version button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isSavingVersion ? null : _saveVersionConfig,
            icon: _isSavingVersion
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save_rounded, size: 20),
            label: const Text('GUARDAR VERSIÓN',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.lGoldAction,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Theme.of(context).dividerColor.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPowerCostsContent() {
    final textColor = Theme.of(context).textTheme.displayLarge?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Costo por defecto al crear nuevos eventos (online y presenciales)',
          style: TextStyle(color: secondaryTextColor?.withOpacity(0.5), fontSize: 12),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: constraints.maxWidth < 600 ? 1 : 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: constraints.maxWidth < 600 ? 5 : 3,
            ),
            itemCount: PowerItem.getShopItems().length,
            itemBuilder: (context, index) {
              final power = PowerItem.getShopItems()[index];
              final currentValue = _powerDefaultCosts[power.id] ?? power.cost;

              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.08)),
                ),
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Text(power.icon, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        power.name,
                        style: TextStyle(
                            color: textColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      child: TextFormField(
                        initialValue: currentValue.toString(),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppTheme.lGoldText,
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 4),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color: Theme.of(context).dividerColor.withOpacity(0.2)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                 const BorderSide(color: AppTheme.lGoldAction),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).dividerColor.withOpacity(0.05),
                        ),
                        onChanged: (val) {
                          final parsed = int.tryParse(val);
                          if (parsed != null && parsed >= 0) {
                            _powerDefaultCosts[power.id] = parsed;
                          }
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        }),
      ],
    );
  }

  Widget _buildMinigameTimingContent() {
    final textColor = Theme.of(context).textTheme.displayLarge?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;

    Widget buildDurationField({
      required TextEditingController controller,
      required String label,
    }) {
      return TextFormField(
        controller: controller,
        enabled: _minigameMinDurationEnabled,
        keyboardType: TextInputType.number,
        style: TextStyle(color: textColor, fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: secondaryTextColor?.withOpacity(0.6)),
          hintText: 'Segundos',
          hintStyle: TextStyle(color: secondaryTextColor?.withOpacity(0.25)),
          suffixText: 's',
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.2),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.lGoldAction),
          ),
          filled: true,
          fillColor: Theme.of(context).dividerColor.withOpacity(0.05),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return 'Requerido';
          final parsed = int.tryParse(value);
          if (parsed == null || parsed < 0) return 'Valor invalido';
          return null;
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Segundos mínimos para validar resultados por dificultad',
          style: TextStyle(color: secondaryTextColor?.withOpacity(0.5), fontSize: 12),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).dividerColor.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.1),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Habilitar tiempos minimos',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _minigameMinDurationEnabled
                          ? 'Validacion activa'
                          : 'Validacion desactivada',
                      style: TextStyle(
                        color: secondaryTextColor?.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _minigameMinDurationEnabled,
                onChanged: (value) {
                  setState(() => _minigameMinDurationEnabled = value);
                },
                activeColor: AppTheme.lGoldAction,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 520;
            if (isNarrow) {
              return Column(
                children: [
                  buildDurationField(controller: _minigameEasyController, label: 'Facil'),
                  const SizedBox(height: 12),
                  buildDurationField(controller: _minigameMediumController, label: 'Medio'),
                  const SizedBox(height: 12),
                  buildDurationField(controller: _minigameHardController, label: 'Dificil'),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: buildDurationField(controller: _minigameEasyController, label: 'Facil')),
                const SizedBox(width: 12),
                Expanded(child: buildDurationField(controller: _minigameMediumController, label: 'Medio')),
                const SizedBox(width: 12),
                Expanded(child: buildDurationField(controller: _minigameHardController, label: 'Dificil')),
              ],
            );
          },
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHARED FIELD WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildUrlField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    Color? iconColor,
  }) {
    final textColor = Theme.of(context).textTheme.displayLarge?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;

    return TextFormField(
      controller: controller,
      style: TextStyle(color: textColor, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: secondaryTextColor?.withOpacity(0.6)),
        hintText: hint,
        hintStyle:
            TextStyle(color: secondaryTextColor?.withOpacity(0.2), fontSize: 12),
        prefixIcon: Icon(icon, color: iconColor ?? secondaryTextColor?.withOpacity(0.38), size: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.lGoldAction),
        ),
        filled: true,
        fillColor: Theme.of(context).dividerColor.withOpacity(0.04),
      ),
    );
  }

  Widget _buildVersionField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String helper,
    Color? accentColor,
  }) {
    final textColor = Theme.of(context).textTheme.displayLarge?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final color = accentColor ?? AppTheme.lGoldAction;

    return TextFormField(
      controller: controller,
      style: TextStyle(color: textColor, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: secondaryTextColor?.withOpacity(0.6)),
        hintText: hint,
        hintStyle: TextStyle(color: secondaryTextColor?.withOpacity(0.25)),
        helperText: helper,
        helperStyle:
            TextStyle(color: secondaryTextColor?.withOpacity(0.4), fontSize: 11),
        prefixIcon:
            Icon(Icons.tag_rounded, color: color.withOpacity(0.7), size: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color),
        ),
        filled: true,
        fillColor: Theme.of(context).dividerColor.withOpacity(0.05),
      ),
    );
  }
}
