import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// Controla la frecuencia de actualización del leaderboard.
///
/// Problema que resuelve:
/// Con 50 jugadores, cada pista completada o vida perdida dispara un Postgres
/// Change que llama `notifyListeners()` directamente. En ráfagas de actividad,
/// esto causa 50+ reconstrucciones/segundo del widget del podio.
/// Además, para evitar el problema de "Thundering Herd" (todos los clientes consultando
/// al mismo milisegundo al recibir el socket de actualización), añade un JITTER aleatorio.
///
/// Solución:
/// Acumula cambios durante [interval] y emite solo una actualización al final
/// del período de silencio (trailing debounce) más un [jitter] aleatorio. Si la ráfaga
/// dura más de [maxWait], fuerza una actualización para no parecer congelado.
class LeaderboardDebouncer {
  final Duration interval;
  final Duration maxWait;
  final Duration jitter;

  Timer? _debounceTimer;
  Timer? _maxWaitTimer;
  VoidCallback? _pendingCallback;
  bool _hasPendingUpdate = false;
  final Random _random = Random();

  LeaderboardDebouncer({
    this.interval = const Duration(milliseconds: 2000),
    this.maxWait = const Duration(milliseconds: 5000),
    this.jitter = const Duration(milliseconds: 1500), // Rango de Jitter
  });

  /// Registra que hay un cambio pendiente en el leaderboard.
  ///
  /// [callback] será llamado después de [interval] + un retraso aleatorio de inactividad,
  /// o después de [maxWait] si hay actualizaciones continuas.
  void schedule(VoidCallback callback) {
    _pendingCallback = callback;
    _hasPendingUpdate = true;

    // Reiniciar el timer de debounce con un jitter para prevenir Thundering Herd
    _debounceTimer?.cancel();
    final randomizedInterval = interval + Duration(milliseconds: _random.nextInt(jitter.inMilliseconds + 1));
    _debounceTimer = Timer(randomizedInterval, _flush);

    // Iniciar timer de maxWait solo si no está corriendo (con jitter también)
    if (_maxWaitTimer == null) {
      final randomizedMaxWait = maxWait + Duration(milliseconds: _random.nextInt(jitter.inMilliseconds + 1));
      _maxWaitTimer = Timer(randomizedMaxWait, () {
        _maxWaitTimer = null;
        if (_hasPendingUpdate) {
          _flush();
        }
      });
    }
  }

  void _flush() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _maxWaitTimer?.cancel();
    _maxWaitTimer = null;

    if (_hasPendingUpdate && _pendingCallback != null) {
      _hasPendingUpdate = false;
      _pendingCallback!();
    }
  }

  /// Fuerza ejecución inmediata (e.g., al inicializar la pantalla del podio).
  void flush() => _flush();

  void dispose() {
    _debounceTimer?.cancel();
    _maxWaitTimer?.cancel();
  }
}
