import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PowerEffectProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  StreamSubscription? _subscription;
  Timer? _expiryTimer;
  Timer? _defenseFeedbackTimer;
  bool _shieldActive = false;
  String? _listeningForId;
  bool _returnArmed = false;
  Future<bool> Function(String powerSlug, String targetGamePlayerId)? _returnHandler;
  DefenseAction? _lastDefenseAction;
  DateTime? _lastDefenseActionAt;
  
  // Guardamos el slug del poder activo (ej: 'black_screen', 'freeze')
  String? _activePowerSlug;
  String? get activePowerSlug => _activePowerSlug;
  DefenseAction? get lastDefenseAction => _lastDefenseAction;

  void setShielded(bool value, {String? sourceSlug}) {
    final shouldEnable = value || _isShieldSlug(sourceSlug);
    _shieldActive = shouldEnable;

    // Si activamos el escudo, limpiamos cualquier efecto activo.
    if (_shieldActive) {
      _clearEffect();
    } else {
      notifyListeners();
    }
  }

  void armReturn() {
    _returnArmed = true;
  }

  void configureReturnHandler(
      Future<bool> Function(String powerSlug, String targetGamePlayerId) handler) {
    _returnHandler = handler;
  }

  // Iniciar la escucha de ataques dirigidos a este jugador específico
  void startListening(String? myGamePlayerId) {
    if (myGamePlayerId == null || myGamePlayerId.isEmpty) {
      _clearEffect();
      _subscription?.cancel();
      return;
    }

    _subscription?.cancel();
    _expiryTimer?.cancel();
    _listeningForId = myGamePlayerId;

    _subscription = _supabase
        .from('active_powers')
        .stream(primaryKey: ['id'])
        .eq('target_id', myGamePlayerId)
        .listen((List<Map<String, dynamic>> data) {
          _processEffects(data);
        }, onError: (e) {
          debugPrint('PowerEffectProvider stream error: $e');
        });
  }

  void _processEffects(List<Map<String, dynamic>> data) {
    _expiryTimer?.cancel(); // Limpiar temporizadores previos

    if (data.isEmpty) {
      _clearEffect();
      return;
    }

    // Filtro adicional por target para evitar overlays en el atacante u oyentes stale
    final filtered = data.where((effect) {
      final targetId = effect['target_id'];
      return _listeningForId != null && targetId == _listeningForId;
    }).toList();

    if (filtered.isEmpty) {
      _clearEffect();
      return;
    }

    // Buscamos el efecto más reciente que aún no haya expirado
    final now = DateTime.now().toUtc();
    final validEffects = filtered.where((effect) {
      final expiresAt = DateTime.parse(effect['expires_at']);
      return expiresAt.isAfter(now);
    }).toList();

    if (validEffects.isEmpty) {
      _clearEffect();
      return;
    }

    // Tomamos el efecto más reciente
    final latestEffect = validEffects.last;
    final latestSlug = latestEffect['power_slug'];

    if (_shieldActive) {
      _activePowerSlug = null;
      _registerDefenseAction(DefenseAction.shieldBlocked);
      debugPrint('PowerEffectProvider: Ataque interceptado por escudo, ignorando.');
      return;
    }

    _activePowerSlug = latestSlug;

    // Manejo de devolución reactiva
    if (_returnArmed && _returnHandler != null) {
      final casterId = latestEffect['caster_id'];
      final slugToReturn = latestSlug;
      if (casterId != null && slugToReturn != null) {
        _returnArmed = false;
        _returnHandler!(slugToReturn, casterId);
        _registerDefenseAction(DefenseAction.returned);
        debugPrint('PowerEffectProvider: Devolución activada contra $casterId');
      }
    }
    
    // Programamos la limpieza automática para el momento exacto de la expiración
    final expiresAt = DateTime.parse(latestEffect['expires_at']);
    final durationRemaining = expiresAt.difference(now);
    
    _expiryTimer = Timer(durationRemaining, () {
      _activePowerSlug = null;
      notifyListeners();
    });

    notifyListeners();
  }

  void _clearEffect() {
    _expiryTimer?.cancel();
    _activePowerSlug = null;
    notifyListeners();
  }

  void clearActiveEffect() {
    _clearEffect();
  }

  void _registerDefenseAction(DefenseAction action) {
    _defenseFeedbackTimer?.cancel();
    _lastDefenseAction = action;
    _lastDefenseActionAt = DateTime.now();
    notifyListeners();

    _defenseFeedbackTimer = Timer(const Duration(seconds: 2), () {
      // Evitamos borrar si se registró un nuevo evento dentro de la ventana.
      final elapsed = DateTime.now().difference(_lastDefenseActionAt ?? DateTime.now());
      if (elapsed.inSeconds >= 2) {
        _lastDefenseAction = null;
        notifyListeners();
      }
    });
  }

  bool _isShieldSlug(String? slug) {
    if (slug == null) return false;
    return slug == 'shield' || slug == 'shield_pro';
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _expiryTimer?.cancel();
    _defenseFeedbackTimer?.cancel();
    super.dispose();
  }
}

enum DefenseAction { shieldBlocked, returned }