import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

/// Servicio para manejar la política de un solo dispositivo (Single Device Policy).
/// Se encarga de generar, almacenar y validar el token de sesión.
class SessionService {
  static const String _sessionTokenKey = 'current_session_token';
  
  final FlutterSecureStorage _storage;
  final Uuid _uuid;

  // Singleton pattern for easy global access, or can be injected
  static final SessionService _instance = SessionService._internal();
  
  factory SessionService() {
    return _instance;
  }

  SessionService._internal()
      : _storage = const FlutterSecureStorage(),
        _uuid = const Uuid();

  /// Genera un nuevo UUID v4 y lo guarda localmente de forma segura.
  Future<String> generateAndSaveSessionToken() async {
    final token = _uuid.v4();
    try {
      await _storage.write(key: _sessionTokenKey, value: token);
      debugPrint('SessionService: Generated and saved new session token.');
    } catch (e) {
      debugPrint('SessionService Error: Failed to save session token - $e');
    }
    return token;
  }

  /// Recupera el token de sesión guardado.
  Future<String?> getSessionToken() async {
    try {
      return await _storage.read(key: _sessionTokenKey);
    } catch (e) {
      debugPrint('SessionService Error: Failed to read session token - $e');
      return null;
    }
  }

  /// Limpia el token actual de forma local (al cerrar sesión).
  Future<void> clearSessionToken() async {
    try {
      await _storage.delete(key: _sessionTokenKey);
      debugPrint('SessionService: Session token cleared.');
    } catch (e) {
      debugPrint('SessionService Error: Failed to clear session token - $e');
    }
  }

  /// Compara el token remoto (de la DB) con el token local.
  /// Retorna false si existe un mismatch explícito (sesión iniciada en otro dispositivo).
  Future<bool> isSessionValid(String? remoteToken) async {
    // Si la DB todavía no tiene un token (o es nulo), permitimos la continuación
    if (remoteToken == null) return true;

    final localToken = await getSessionToken();
    
    // Si no tenemos token local pero el remoto existe, significa que quizás limpiamos localmente
    // o hubo un error. En caso de auth_provider, podríamos desloguear.
    if (localToken == null) {
       debugPrint('SessionService: Local token missing, but remote exists.');
       return false; 
    }

    return localToken == remoteToken;
  }
}
