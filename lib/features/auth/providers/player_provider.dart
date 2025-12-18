import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/player.dart';

class PlayerProvider extends ChangeNotifier {
  Player? _currentPlayer;
  List<Player> _allPlayers = [];
  final _supabase = Supabase.instance.client;

  Player? get currentPlayer => _currentPlayer;
  List<Player> get allPlayers => _allPlayers;

  bool get isLoggedIn => _currentPlayer != null;

  // --- AUTHENTICATION ---

  Future<void> login(String email, String password) async {
    try {
      final response = await _supabase.functions.invoke(
        'auth-service/login',
        body: {'email': email, 'password': password},
        method: HttpMethod.post,
      );

      if (response.status != 200) {
        final error = response.data['error'] ?? 'Error desconocido';
        throw error; // Lanzar el string directamente para procesarlo
      }

      final data = response.data;
      
      if (data['session'] != null) {
        await _supabase.auth.setSession(data['session']['refresh_token']);
        
        if (data['user'] != null) {
          await _fetchProfile(data['user']['id']);
        }
      } else {
         throw 'No se recibió sesión válida';
      }
    } catch (e) {
      debugPrint('Error logging in: $e');
      throw _handleAuthError(e);
    }
  }

  Future<void> register(String name, String email, String password) async {
    try {
      final response = await _supabase.functions.invoke(
        'auth-service/register',
        body: {'email': email, 'password': password, 'name': name},
        method: HttpMethod.post,
      );

      if (response.status != 200) {
        final error = response.data['error'] ?? 'Error desconocido';
        throw error;
      }

      final data = response.data;

      if (data['session'] != null) {
        await _supabase.auth.setSession(data['session']['refresh_token']);
        
        if (data['user'] != null) {
          await Future.delayed(const Duration(seconds: 1));
          await _fetchProfile(data['user']['id']);
        }
      }
    } catch (e) {
      debugPrint('Error registering: $e');
      throw _handleAuthError(e);
    }
  }

  String _handleAuthError(dynamic e) {
    String errorMsg = e.toString().toLowerCase();

    if (errorMsg.contains('invalid login credentials') || 
        errorMsg.contains('invalid credentials')) {
      return 'Email o contraseña incorrectos. Verifica tus datos e intenta de nuevo.';
    }
    if (errorMsg.contains('user already registered') || 
        errorMsg.contains('already exists')) {
      return 'Este correo ya está registrado. Intenta iniciar sesión.';
    }
    if (errorMsg.contains('password should be at least 6 characters')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    if (errorMsg.contains('network') || errorMsg.contains('connection')) {
      return 'Error de conexión. Revisa tu internet e intenta de nuevo.';
    }
    if (errorMsg.contains('email not confirmed')) {
      return 'Debes confirmar tu correo electrónico antes de entrar.';
    }
    if (errorMsg.contains('too many requests')) {
      return 'Demasiados intentos. Por favor espera un momento.';
    }
    
    // Limpiar el prefijo 'Exception: ' si existe
    return e.toString().replaceAll('Exception: ', '').replaceAll('exception: ', '');
  }

  Future<void> logout() async {
    _pollingTimer?.cancel();
    await _profileSubscription?.cancel();
    await _supabase.auth.signOut();
    _currentPlayer = null;
    notifyListeners();
  }

  // --- PROFILE MANAGEMENT ---

  StreamSubscription<List<Map<String, dynamic>>>? _profileSubscription;

  Future<void> refreshProfile() async {
    if (_currentPlayer != null) {
      await _fetchProfile(_currentPlayer!.id);
    }
  }

  Future<void> _fetchProfile(String userId) async {
    try {
      // 1. Obtener perfil básico
      final profileData = await _supabase.from('profiles').select().eq('id', userId).single();
      
      // 2. Obtener GamePlayer y Vidas
      final gpData = await _supabase
          .from('game_players')
          .select('id, lives')
          .eq('user_id', userId)
          .order('joined_at', ascending: false)
          .limit(1)
          .maybeSingle();

      List<String> realInventory = [];
      int actualLives = 3;

      if (gpData != null) {
        actualLives = gpData['lives'] ?? 3;
        final String gpId = gpData['id'];

        // 3. Obtener Inventario real de player_powers
        final List<dynamic> powersData = await _supabase
            .from('player_powers')
            .select('quantity, powers!inner(slug)')
            .eq('game_player_id', gpId)
            .gt('quantity', 0);

        for (var item in powersData) {
          final powerDetails = item['powers'];
          if (powerDetails != null && powerDetails['slug'] != null) {
            final String slug = powerDetails['slug'];
            final int qty = item['quantity'];
            for (var i = 0; i < qty; i++) {
              realInventory.add(slug);
            }
          }
        }
      }

      // 4. Construir jugador de forma atómica
      final newPlayer = Player.fromJson(profileData);
      newPlayer.lives = actualLives;
      newPlayer.inventory = realInventory;

      _currentPlayer = newPlayer;
      notifyListeners();

      // ASEGURAR que los listeners estén corriendo pero SOLAMENTE UNA VEZ
      _startListeners(userId);
      
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }
  }

  Timer? _pollingTimer;

  void _startListeners(String userId) {
    if (_pollingTimer == null) _startPolling(userId);
    if (_profileSubscription == null) _subscribeToProfile(userId);
  }

  void _startPolling(String userId) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
       if (_currentPlayer != null) {
         try {
           await refreshProfile();
         } catch (e) {
           // Si falla por internet (No host), ignoramos y reintentamos en 2s
           debugPrint("Polling silenciado por error de red: $e");
         }
       } else {
         timer.cancel();
         _pollingTimer = null;
       }
    });
  }

  void _subscribeToProfile(String userId) {
    if (_profileSubscription != null) return; // Ya suscrito

    _profileSubscription = _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .listen((data) {
          if (data.isNotEmpty) {
            _fetchProfile(userId);
          }
        }, onError: (e) {
          debugPrint('Profile stream error: $e');
          _profileSubscription = null;
        });
  }

  // syncRealInventory ya no es necesario como método separado si todo está en _fetchProfile
  Future<void> syncRealInventory() async {
     if (_currentPlayer != null) await _fetchProfile(_currentPlayer!.id);
  }

  // --- LOGICA DE PODERES E INVENTARIO (BACKEND INTEGRATION) ---

  Future<bool> usePower({
    required String powerId, 
    required String targetUserId 
  }) async {
    if (_currentPlayer == null) throw "No hay sesión activa.";
    if (targetUserId.isEmpty) throw "Debes seleccionar un objetivo.";

    try {
      debugPrint("--- [SABOTAJE] INICIO: $powerId de ${_currentPlayer!.name} a $targetUserId ---");

      // 1. Obtener mi GamePlayer ID actual
      final myGP = await _supabase
          .from('game_players')
          .select('id')
          .eq('user_id', _currentPlayer!.id)
          .order('joined_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (myGP == null) {
        throw "No estás unido a ningún juego activo.";
      }
      final myGPId = myGP['id'];

      // 2. Buscar la UUID real del poder por su slug
      final powerRes = await _supabase
          .from('powers')
          .select('id')
          .eq('slug', powerId)
          .limit(1)
          .maybeSingle();

      if (powerRes == null) {
        throw "Error interno: El poder '$powerId' no existe en la base de datos.";
      }
      final String realPowerUuid = powerRes['id'];

      // 3. Verificar inventario real
      final currentPowerRecord = await _supabase
          .from('player_powers')
          .select('id, quantity')
          .eq('game_player_id', myGPId)
          .eq('power_id', realPowerUuid)
          .maybeSingle();

      if (currentPowerRecord == null || (currentPowerRecord['quantity'] ?? 0) <= 0) {
        // Doble verificación: Forzar refresh local para ver si fue un des-sync
        await _fetchProfile(_currentPlayer!.id);
        throw "No tienes este objeto en el inventario. (Cantidad: 0)";
      }

      // 4. VERIFICACIÓN DE ESCUDO EN EL OBJETIVO
      final targetProfile = await _supabase
          .from('profiles')
          .select('status, name')
          .eq('id', targetUserId)
          .maybeSingle();

      if (targetProfile != null && targetProfile['status'] == 'shielded' && powerId != 'shield') {
        debugPrint("ATAQUE REBOTADO: ${targetProfile['name']} tiene un ESCUDO activo.");
        
        // Consumimos el poder de todas formas (regla de balance)
        await _supabase
            .from('player_powers')
            .update({'quantity': (currentPowerRecord['quantity'] ?? 1) - 1})
            .eq('id', currentPowerRecord['id']);
        
        await syncRealInventory();
        
        // Lanzamos error amigable para avisar al usuario
        throw "¡Ataque fallido! ${targetProfile['name']} tenía un ESCUDO activo.";
      }

      // 5. Descontar del inventario
      final int newQty = currentPowerRecord['quantity'] - 1;
      await _supabase
          .from('player_powers')
          .update({'quantity': newQty})
          .eq('id', currentPowerRecord['id']);

      debugPrint("Cantidad actualizada: $newQty");

      // 6. Aplicar efecto
      String newStatus = 'active';
      if (powerId == 'freeze' || powerId == 'time_penalty') {
        newStatus = 'frozen';
      } else if (powerId == 'black_screen' || powerId == 'blind') {
        newStatus = 'blinded';
      } else if (powerId == 'slow_motion') {
        newStatus = 'slowed';
      } else if (powerId == 'shield') {
        newStatus = 'shielded';
      }

      if (newStatus != 'active') {
        final expiration = DateTime.now().toUtc().add(const Duration(seconds: 60)); // Duración estándar
        debugPrint("Aplicando $newStatus a $targetUserId hasta ${expiration.toIso8601String()}");

        await _supabase
            .from('profiles')
            .update({
              'status': newStatus,
              'frozen_until': expiration.toIso8601String(),
            })
            .eq('id', targetUserId);

        // Limpieza automática local (backend debería tener su propio cron, esto es backup)
        Future.delayed(const Duration(seconds: 60), () async {
          try {
            await _supabase.from('profiles').update({
              'status': 'active',
              'frozen_until': null,
            }).eq('id', targetUserId);
          } catch (e) {
            debugPrint("Error limpiando efecto: $e");
          }
        });
      }

      await Future.delayed(const Duration(milliseconds: 500));
      await syncRealInventory();
      
      debugPrint("--- [SABOTAJE] COMPLETADO CON ÉXITO ---");
      return true;

    } catch (e) {
      debugPrint('Error en usePower: $e');
      rethrow; // Re-lanzar para que pantalla de inventario lo muestre
    }
  }

  // --- LÓGICA DE TIENDA ---

 // player_provider.dart

  Future<bool> purchaseItem(String itemId, String eventId, int cost, {bool isPower = true}) async {
    if (currentPlayer == null) return false;

    try {
      // Llamada a la función SQL
      final response = await Supabase.instance.client.rpc('buy_item', params: {
        'p_user_id': currentPlayer!.id,
        'p_event_id': eventId,
        'p_item_id': itemId,
        'p_cost': cost,
        'p_is_power': isPower,
      });

      // Manejar respuesta flexible (Map o List)
      Map<String, dynamic> data;
      if (response is List) {
        if (response.isEmpty) throw "Respuesta vacía del servidor";
        data = response.first as Map<String, dynamic>;
      } else if (response is Map) {
         data = response as Map<String, dynamic>;
      } else {
        throw "Formato de respuesta desconocido: $response";
      }

      final success = data['success'] as bool? ?? false;
      final message = data['message'] as String? ?? 'Error desconocido';

      if (success) {
        // Actualizar monedas localmente y perfil
        currentPlayer!.coins -= cost; // Optimistic update
        await refreshProfile(); // Refresh completo para asegurar
        notifyListeners();
        return true;
      } else {
        // Si falló (ej: Max vidas alcanzado), lanzamos el mensaje que vino de SQL
        throw message; 
      }
    } catch (e) {
      debugPrint("Error transacción: $e");
      rethrow; 
    }
  }
  // --- MINIGAME LIFE MANAGEMENT (OPTIMIZED RPC) ---

  Future<void> loseLife() async {
    if (_currentPlayer == null) return;
    
    // Evitamos llamada si ya está en 0 localmente para ahorrar red, 
    // aunque el backend es la fuente de verdad.
    if (_currentPlayer!.lives <= 0) return;

    try {
      // Llamada RPC atómica: la base de datos resta y nos devuelve el valor final
      final int newLives = await _supabase.rpc('lose_life', params: {
        'p_user_id': _currentPlayer!.id,
      });

      // Actualizamos estado local inmediatamente con la respuesta real del servidor
      _currentPlayer!.lives = newLives;
      notifyListeners();
      
    } catch (e) {
      debugPrint("Error perdiendo vida: $e");
      // Opcional: Revertir UI o mostrar error
    }
  }

  Future<void> resetLives() async {
    if (_currentPlayer == null) return;

    try {
      final int newLives = await _supabase.rpc('reset_lives', params: {
        'p_user_id': _currentPlayer!.id,
      });

      _currentPlayer!.lives = newLives;
      notifyListeners();

    } catch (e) {
      debugPrint("Error reseteando vidas: $e");
    }
  }

  // --- SOCIAL & ADMIN ---

  Future<void> fetchAllPlayers() async {
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .order('name', ascending: true);

      _allPlayers = (data as List).map((json) => Player.fromJson(json)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching all players: $e');
    }
  }

  Future<void> toggleBanUser(String userId, bool ban) async {
    try {
      await _supabase.rpc('toggle_ban',
          params: {'user_id': userId, 'new_status': ban ? 'banned' : 'active'});

      final index = _allPlayers.indexWhere((p) => p.id == userId);
      if (index != -1) {
        _allPlayers[index].status = ban ? PlayerStatus.banned : PlayerStatus.active;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error toggling ban: $e');
      rethrow;
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      await _supabase.rpc('delete_user', params: {'user_id': userId});
      _allPlayers.removeWhere((p) => p.id == userId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting user: $e');
      rethrow;
    }
  }

  // --- DEBUG ONLY ---
  Future<void> debugAddPower(String powerSlug) async {
    if (_currentPlayer == null) return;
    try {
      final gp = await _supabase.from('game_players').select('id').eq('user_id', _currentPlayer!.id).order('joined_at', ascending: false).limit(1).maybeSingle();
      if (gp == null) return;
      final String gpId = gp['id'];
      final power = await _supabase.from('powers').select('id').eq('slug', powerSlug).single();
      final String powerUuid = power['id'];
      final existing = await _supabase.from('player_powers').select('id, quantity').eq('game_player_id', gpId).eq('power_id', powerUuid).maybeSingle();
      if (existing != null) {
        await _supabase.from('player_powers').update({'quantity': (existing['quantity'] ?? 0) + 1}).eq('id', existing['id']);
      } else {
        await _supabase.from('player_powers').insert({'game_player_id': gpId, 'power_id': powerUuid, 'quantity': 1});
      }
      await refreshProfile();
      debugPrint("DEBUG: Poder $powerSlug añadido.");
    } catch (e) {
      debugPrint("Error en debugAddPower: $e");
    }
  }

  Future<void> debugToggleStatus(String status) async {
    if (_currentPlayer == null) return;
    try {
      final expiration = DateTime.now().toUtc().add(const Duration(seconds: 15));
      final newStatus = _currentPlayer!.status.name == status ? 'active' : status;
      
      await _supabase.from('profiles').update({
        'status': newStatus,
        'frozen_until': newStatus == 'active' ? null : expiration.toIso8601String(),
      }).eq('id', _currentPlayer!.id);
      
      await refreshProfile();
      debugPrint("DEBUG: Status cambiado a $newStatus");
    } catch (e) {
      debugPrint("Error en debugToggleStatus: $e");
    }
  }

  Future<void> debugAddAllPowers() async {
    final slugs = ['freeze', 'black_screen', 'slow_motion', 'shield', 'hint', 'extra_life'];
    for (var slug in slugs) {
      await debugAddPower(slug);
    }
  }
}
