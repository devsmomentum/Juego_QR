import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/interfaces/i_resettable.dart';

/// Estados del flujo de progresión del juego.
///
/// Modela la máquina de estado para el avance entre pistas,
/// soportando interrupciones por poderes asíncronos.
///
/// Diagrama de transiciones:
/// ```
/// idle ──[completa pista]──> pendingCelebration ──[sin poder]──> showingCelebration ──[cierra diálogo]──> idle
///                                    │                                                                    ▲
///                                    └──[poder activo]──> (espera) ──[poder termina]──────────────────────┘
/// ```
enum GameFlowState {
  /// Sin acción en curso.
  idle,

  /// Pista completada exitosamente, celebración pendiente de mostrarse.
  /// Si un poder está bloqueando, se mantiene en este estado hasta que termine.
  pendingCelebration,

  /// El diálogo de celebración se está mostrando al jugador.
  showingCelebration,
}

/// Datos de una celebración pendiente de mostrarse al jugador.
///
/// Serializable a JSON para persistencia en SharedPreferences,
/// permitiendo recuperar el estado si la app se cierra durante un poder.
class PendingCelebration {
  final String clueId;
  final int clueSequenceIndex;
  final int coinsEarned;

  const PendingCelebration({
    required this.clueId,
    required this.clueSequenceIndex,
    this.coinsEarned = 0,
  });

  Map<String, dynamic> toJson() => {
        'clueId': clueId,
        'clueSequenceIndex': clueSequenceIndex,
        'coinsEarned': coinsEarned,
      };

  factory PendingCelebration.fromJson(Map<String, dynamic> json) =>
      PendingCelebration(
        clueId: json['clueId'] as String,
        clueSequenceIndex: json['clueSequenceIndex'] as int,
        coinsEarned: json['coinsEarned'] as int? ?? 0,
      );
}

/// Provider que gestiona la persistencia de intención de flujo del juego.
///
/// Resuelve la race condition donde un "poder" asíncrono (via Supabase Realtime)
/// interrumpe la transición entre pistas, causando que el sistema "olvide"
/// la celebración pendiente y el desbloqueo de la siguiente pista.
///
/// Patron: **Action Queue con State Machine**
/// - Cuando el jugador completa una pista, se registra la intención via [recordClueCompletion].
/// - Si un poder bloqueante (freeze/black_screen) está activo, la celebración queda encolada.
/// - Cuando el poder termina ([onPowerBlockingEnded]), los listeners son notificados
///   para mostrar la celebración diferida.
/// - Si la app se cierra, el estado se persiste en SharedPreferences y se restaura
///   en la próxima sesión via [restorePendingAction].
class GameFlowProvider extends ChangeNotifier implements IResettable {
  GameFlowState _state = GameFlowState.idle;
  PendingCelebration? _pendingCelebration;
  bool _isPowerBlocking = false;

  static const String _persistKey = 'pending_celebration_v1';

  // --- Getters ---

  GameFlowState get state => _state;
  PendingCelebration? get pendingCelebration => _pendingCelebration;
  bool get isPowerBlocking => _isPowerBlocking;

  /// True cuando hay una celebración lista para mostrarse
  /// (existe celebración pendiente Y no hay poder bloqueante activo).
  bool get hasCelebrationReady =>
      _pendingCelebration != null &&
      _state == GameFlowState.pendingCelebration &&
      !_isPowerBlocking;

  /// True cuando hay una celebración pendiente (sin importar poder bloqueante).
  bool get hasPendingCelebration =>
      _pendingCelebration != null &&
      _state == GameFlowState.pendingCelebration;

  // --- State Transitions ---

  /// Registra que una pista fue completada y la celebración debe mostrarse.
  ///
  /// Si un poder está activo, la celebración queda encolada automáticamente.
  /// Persiste el estado a SharedPreferences para resiliencia ante crashes.
  void recordClueCompletion(PendingCelebration celebration) {
    _pendingCelebration = celebration;
    _state = GameFlowState.pendingCelebration;
    _persist();
    debugPrint(
        '🎯 [GameFlow] Celebración registrada: ${celebration.clueId} '
        '(powerBlocking: $_isPowerBlocking)');
    notifyListeners();
  }

  /// Notifica que un poder bloqueante (freeze/black_screen) se activó.
  ///
  /// La celebración pendiente NO se pierde, solo se difiere.
  void onPowerBlockingStarted() {
    if (!_isPowerBlocking) {
      _isPowerBlocking = true;
      debugPrint('🎯 [GameFlow] Power blocking STARTED '
          '(pending: ${_pendingCelebration != null})');
    }
  }

  /// Notifica que el poder bloqueante se desactivó.
  ///
  /// Si hay celebración pendiente, [hasCelebrationReady] será true
  /// y los listeners serán notificados para mostrarla.
  void onPowerBlockingEnded() {
    if (_isPowerBlocking) {
      _isPowerBlocking = false;
      debugPrint(
          '🎯 [GameFlow] Power blocking ENDED → celebration ready: '
          '${_pendingCelebration != null}');
      notifyListeners();
    }
  }

  /// Marca que la celebración se está mostrando actualmente.
  ///
  /// Previene que se vuelva a mostrar mientras está visible.
  void markCelebrationShowing() {
    if (_state == GameFlowState.pendingCelebration) {
      _state = GameFlowState.showingCelebration;
      debugPrint('🎯 [GameFlow] Celebración → SHOWING');
      notifyListeners();
    }
  }

  /// Consume y retorna la celebración pendiente, reseteando el estado a idle.
  ///
  /// Llamar cuando el diálogo de celebración se cierra.
  /// Retorna null si no hay celebración pendiente.
  PendingCelebration? consumePendingCelebration() {
    final pending = _pendingCelebration;
    _pendingCelebration = null;
    _state = GameFlowState.idle;
    _clearPersisted();
    debugPrint('🎯 [GameFlow] Celebración CONSUMED → idle');
    notifyListeners();
    return pending;
  }

  /// Restaura estado persistido desde SharedPreferences.
  ///
  /// Llamar durante la inicialización de la app. Si la app se cerró
  /// durante un poder, el estado de celebración pendiente se recupera.
  Future<void> restorePendingAction() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_persistKey);
      if (json != null) {
        _pendingCelebration = PendingCelebration.fromJson(
            jsonDecode(json) as Map<String, dynamic>);
        _state = GameFlowState.pendingCelebration;
        debugPrint(
            '🎯 [GameFlow] Restored pending: ${_pendingCelebration!.clueId}');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('🎯 [GameFlow] Failed to restore: $e');
      _clearPersisted();
    }
  }

  // --- Persistence ---

  void _persist() {
    if (_pendingCelebration == null) return;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_persistKey, jsonEncode(_pendingCelebration!.toJson()));
    });
  }

  void _clearPersisted() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(_persistKey);
    });
  }

  @override
  void resetState() {
    _state = GameFlowState.idle;
    _pendingCelebration = null;
    _isPowerBlocking = false;
    _clearPersisted();
    notifyListeners();
  }
}
