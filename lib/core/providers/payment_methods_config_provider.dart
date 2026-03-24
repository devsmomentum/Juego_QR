import 'package:flutter/foundation.dart';
import '../models/payment_methods_config.dart';
import '../services/app_config_service.dart';

class PaymentMethodsConfigProvider extends ChangeNotifier {
  final AppConfigService _configService;

  PaymentMethodsConfig _config = PaymentMethodsConfig.fallbackAllDisabled();
  bool _isLoading = false;
  String? _error;

  PaymentMethodsConfigProvider({required AppConfigService configService})
      : _configService = configService;

  PaymentMethodsConfig get config => _config;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _config = await _configService.getPaymentMethodsStatus();
    } catch (e) {
      _config = PaymentMethodsConfig.fallbackAllDisabled();
      _error = 'Error cargando metodos de pago: $e';
      debugPrint('[PaymentMethodsConfigProvider] $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool isMethodEnabled(String flow, String methodId) {
    return _config.isEnabled(flow: flow, methodId: methodId);
  }

  Future<bool> update(PaymentMethodsConfig updated) async {
    _config = updated;
    notifyListeners();

    final success = await _configService.updatePaymentMethodsStatus(updated);
    if (!success) {
      _error = 'Error guardando metodos de pago';
      notifyListeners();
    }
    return success;
  }
}
