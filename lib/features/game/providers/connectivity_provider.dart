import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/connectivity_service.dart';

/// Provider que expone el estado de conectividad y controla
/// el contexto de minijuego para la pérdida de vida.
class ConnectivityProvider extends ChangeNotifier {
  late final StreamSubscription<ConnectivityStatus> _subscription;
  
  ConnectivityStatus _status = ConnectivityStatus.online;
  bool _isInMinigame = false;
  String? _currentEventId;
  bool _isMonitoring = false;

  ConnectivityProvider() {
    _subscription = ConnectivityService.instance.statusStream.listen(_onStatusChanged);
  }

  // --- Getters ---
  
  ConnectivityStatus get status => _status;
  bool get isOnline => _status == ConnectivityStatus.online;
  bool get isLowSignal => _status == ConnectivityStatus.lowSignal;
  bool get isOffline => _status == ConnectivityStatus.offline;
  bool get isInMinigame => _isInMinigame;
  String? get currentEventId => _currentEventId;
  bool get isMonitoring => _isMonitoring;

  // --- Control de Monitoreo ---
  
  /// Inicia el monitoreo de conectividad (llamar después del login)
  void startMonitoring() {
    if (_isMonitoring) return;
    _isMonitoring = true;
    ConnectivityService.instance.startMonitoring();
    debugPrint('ConnectivityProvider: Monitoreo iniciado');
  }

  /// Detiene el monitoreo (llamar antes del logout)
  void stopMonitoring() {
    _isMonitoring = false;
    ConnectivityService.instance.stopMonitoring();
    _status = ConnectivityStatus.online;
    _isInMinigame = false;
    _currentEventId = null;
    debugPrint('ConnectivityProvider: Monitoreo detenido');
    notifyListeners();
  }

  // --- Control de Minijuego ---
  
  /// Marca que el usuario entró a un minijuego
  void enterMinigame(String eventId) {
    _isInMinigame = true;
    _currentEventId = eventId;
    debugPrint('ConnectivityProvider: Entró a minijuego (eventId: $eventId)');
    notifyListeners();
  }

  /// Marca que el usuario salió del minijuego
  void exitMinigame() {
    _isInMinigame = false;
    debugPrint('ConnectivityProvider: Salió del minijuego');
    notifyListeners();
  }

  // --- Manejo de Estado ---
  
  void _onStatusChanged(ConnectivityStatus newStatus) {
    if (_status != newStatus) {
      debugPrint('ConnectivityProvider: Estado de conexión: $newStatus');
      _status = newStatus;
      notifyListeners();
    }
  }

  /// Fuerza una actualización inmediata del estado
  void forceUpdate() {
    _status = ConnectivityService.instance.currentStatus;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
