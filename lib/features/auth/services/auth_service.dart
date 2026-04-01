import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/player.dart';
import '../../../core/storage/secure_local_storage.dart';
import '../../../core/services/session_service.dart';

/// Excepción personalizada para errores de autenticación con metadatos.
class AuthUserException implements Exception {
  final String message;
  final bool isUnverified;

  AuthUserException(this.message, {this.isUnverified = false});

  @override
  String toString() => message;
}

/// Servicio de autenticación que encapsula la lógica de login, registro y logout.
///
/// Implementa DIP al recibir [SupabaseClient] por constructor en lugar
/// de depender de variables globales.
class AuthService {
  final SupabaseClient _supabase;
  final List<Future<void> Function()> _logoutCallbacks = [];

  AuthService({required SupabaseClient supabaseClient})
      : _supabase = supabaseClient;

  /// Registra un callback que se ejecutará al cerrar sesión.
  void onLogout(Future<void> Function() callback) {
    _logoutCallbacks.add(callback);
  }

  /// Inicia sesión con email y password.
  ///
  /// Retorna el ID del usuario autenticado en caso de éxito.
  /// Lanza una excepción con mensaje legible si falla.
  Future<String> login(String email, String password) async {
    try {
      debugPrint('AuthService: Iniciando login para $email');
      
      final response = await _supabase.functions.invoke(
        'auth-service/login',
        body: {'email': email, 'password': password},
        method: HttpMethod.post,
      );

      final dynamic data = response.data;

      if (response.status != 200) {
        final error = (data is Map) ? (data['error'] ?? 'Error desconocido') : 'Error del servidor (${response.status})';
        final bool isUnverified = (data is Map) && data['unverified'] == true;

        if (response.status == 403) {
          try {
            await _supabase.auth.signOut();
          } catch (_) {}
        }
        
        if (isUnverified) {
          throw AuthUserException(_handleAuthError(error), isUnverified: true);
        }
        throw _handleAuthError(error);
      }

      if (data == null) throw 'No se recibió respuesta del servidor';

      // Manejar el caso donde la respuesta no sea un Map directo (ej. si el SDK no decodifica automáticamente)
      final Map<String, dynamic> payload;
      if (data is Map) {
        payload = Map<String, dynamic>.from(data);
      } else {
        throw 'Respuesta del servidor inválida: Se esperaba JSON';
      }

      if (payload['session'] != null) {
        final sessionData = payload['session'];
        
        // En Supabase 2.x, setSession requiere el refresh_token string
        final String? refreshToken = sessionData['refresh_token'];
        if (refreshToken == null) throw 'La sesión no contiene un token de refresco válido';
        
        await _supabase.auth.setSession(refreshToken);
        
        if (payload['user'] != null) {
          final user = payload['user'];

          if (user['email_confirmed_at'] == null) {
            await logout(); 
            throw AuthUserException('Tu cuenta aún no está activa. Por favor, verifica tu correo electrónico.', isUnverified: true);
          }

          final userId = user['id'] as String;
          
          // SINGLE DEVICE POLICY: Generate session token and update profile BEFORE granting access
          try {
            final sessionService = SessionService();
            final sessionToken = await sessionService.generateAndSaveSessionToken();
            await _supabase.rpc('set_current_session_id', params: {
              'p_session_id': sessionToken,
            });
          } catch (e) {
            debugPrint('AuthService: Failed to set current_session_id during login: $e');
            // Allow login to proceed even if token update fails, or you could throw. Throwing is safer for strict policy.
            // But we will just log it here for minimum disruption.
          }

          return userId;
        }
        throw 'No se recibió información del usuario';
      } else {
        throw 'No se recibió una sesión válida';
      }
    } catch (e) {
      if (e is AuthUserException) rethrow;
      
      debugPrint('AuthService: Error logging in: $e');

      // Detect unverified status inside FunctionException details
      if (e is FunctionException) {
        final details = e.details;
        if (details is Map && details['unverified'] == true) {
          throw AuthUserException(
            _handleAuthError(details['error'] ?? 'Debes confirmar tu correo para entrar.'),
            isUnverified: true,
          );
        }
      }

      throw _handleAuthError(e);
    }
  }

  /// Inicia sesión como ADMINISTRADOR.
  ///
  /// Verificas credenciales y ADEMÁS verifica que el usuario tenga rol 'admin'.
  /// Si no es admin, cierra sesión automáticamente y lanza excepción.
  Future<String> loginAdmin(String email, String password) async {
    try {
      // 1. Login normal
      final userId = await login(email, password);

      // 2. Verificar rol
      final profile = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single();

      final role = profile['role'] as String?;

      if (role != 'admin') {
        debugPrint('AuthService: Access denied for $email (Role: $role)');
        await logout(); // Limpiar sesión inmediatamente
        throw 'Acceso denegado: No tienes permisos de administrador.';
      }

      return userId;
    } catch (e) {
      // Re-lanzar errores ya procesados o procesar nuevos
      debugPrint('AuthService: Error logging in as admin: $e');
      if (e is String) rethrow;
      throw _handleAuthError(e);
    }
  }

  /// Registra un nuevo usuario con nombre, email y password.
  ///
  /// El registro es ATÓMICO: la Edge Function llama a signUp() y el trigger
  /// `handle_new_user` crea el perfil completo dentro de la misma transacción.
  /// Si algo falla, se hace rollback automático — nunca quedan usuarios huérfanos.
  ///
  /// Retorna el ID del usuario creado en caso de éxito.
  /// Lanza una excepción con mensaje legible si falla.
  Future<String> register(String name, String email, String password,
      {String? cedula, String? phone}) async {
    try {
      final response = await _supabase.functions.invoke(
        'auth-service/register',
        body: {
          'email': email,
          'password': password,
          'name': name,
          'cedula': cedula,
          'phone': phone,
        },
        method: HttpMethod.post,
      );

      if (response.status != 200) {
        final data = response.data;
        final error = (data is Map) ? (data['error'] ?? 'Error desconocido') : 'Error del servidor (${response.status})';
        throw error;
      }

      final data = response.data;

      if (data['user'] != null) {
        // Si hay sesión, la guardamos (auto-login).
        // Si no hay sesión (requiere confirmación de email), continuamos igual.
        if (data['session'] != null) {
          await _supabase.auth.setSession(data['session']['refresh_token']);
          
          // SINGLE DEVICE POLICY: Create new session token for the newly registered user
          final userId = data['user']['id'] as String;
          try {
            final sessionService = SessionService();
            final sessionToken = await sessionService.generateAndSaveSessionToken();
            await _supabase.rpc('set_current_session_id', params: {
              'p_session_id': sessionToken,
            });
          } catch(e) {
            debugPrint('AuthService: Failed to set current_session_id during register: $e');
          }
        }

        return data['user']['id'] as String;
      }
      throw 'No se recibió información del usuario';
    } catch (e) {
      debugPrint('AuthService: Error registering: $e');
      throw _handleAuthError(e);
    }
  }

  /// Cierra la sesión del usuario actual y ejecuta los callbacks de limpieza.
  Future<void> logout() async {
    debugPrint('AuthService: Executing Global Logout...');

    // 1. Ejecutar limpieza de providers
    for (final callback in _logoutCallbacks) {
      try {
        await callback();
      } catch (e) {
        debugPrint('AuthService: Error in logout callback: $e');
      }
    }

    // 2. Limpiar token local PRIMERO — garantiza que el storage quede limpio
    //    incluso si signOut() falla por red, sesión expirada, etc.
    try {
      await SecureLocalStorage().removePersistedSession();
      await SessionService().clearSessionToken();
      debugPrint('AuthService: Local tokens cleared.');
    } catch (e) {
      debugPrint('AuthService: Error clearing local token: $e');
    }

    // 3. Cerrar sesión local (no revoca tokens del servidor para evitar
    //    invalidar sesiones de otros dispositivos que acaban de loguearse).
    try {
      await _supabase.auth.signOut(scope: SignOutScope.local);
    } catch (e) {
      debugPrint('AuthService: Error closing local session: $e');
      // No re-lanzamos — el token local ya fue borrado, la App puede continuar
    }
  }

  /// Reenvía el correo de verificación.
  Future<void> resendVerification(String email) async {
    try {
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: email.trim(),
      );
    } catch (e) {
      debugPrint('AuthService: Error resending verification: $e');
      throw _handleAuthError(e);
    }
  }

  /// Envía un correo de recuperación de contraseña.
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: kIsWeb ? null : 'io.supabase.maphunter://reset-password',
      );
    } catch (e) {
      debugPrint('AuthService: Error resetting password: $e');
      throw _handleAuthError(e);
    }
  }

  /// Actualiza la contraseña del usuario actual.
  Future<void> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } catch (e) {
      debugPrint('AuthService: Error updating password: $e');
      throw _handleAuthError(e);
    }
  }

  /// Actualiza el avatar del usuario en su perfil.
  Future<void> updateAvatar(String userId, String avatarId) async {
    debugPrint('AuthService: Updating avatar for $userId to $avatarId');
    try {
      await _supabase.from('profiles').update({
        'avatar_id': avatarId,
      }).eq('id', userId);
      debugPrint('AuthService: Avatar updated successfully in profiles table');
    } catch (e) {
      debugPrint('AuthService: Error updating avatar: $e');
      throw _handleAuthError(e);
    }
  }

  /// Actualiza la información del perfil del usuario.
  /// Returns true if email was changed (requires verification).
  Future<bool> updateProfile(String userId,
      {String? name, String? email, String? phone, String? cedula}) async {
    try {
      // Route ALL fields through the edge function (including email)
      final body = <String, dynamic>{};
      
      if (name != null) body['name'] = name.trim();
      if (email != null) body['email'] = email.trim();
      if (phone != null) body['phone'] = phone.trim();
      if (cedula != null) body['cedula'] = cedula.trim();

      if (body.isEmpty) return false;

      final response = await _supabase.functions.invoke(
        'auth-service/update-profile',
        body: body,
        method: HttpMethod.post,
      );

      if (response.status != 200) {
        final error = response.data['error'] ??
            'Error desconocido al actualizar perfil';
        throw error;
      }

      final bool emailChanged = response.data['emailChanged'] == true;
      return emailChanged;
    } catch (e) {
      debugPrint('AuthService: Error updating profile: $e');
      throw _handleAuthError(e);
    }
  }

  /// Convierte errores de autenticación en mensajes legibles para el usuario.
  String _handleAuthError(dynamic e) {
    if (e is FormatException) {
      return 'Error de comunicación: El servidor envió una respuesta con formato inválido. (${e.message})';
    }
    
    String errorMsg = e.toString().toLowerCase();

    if (errorMsg.contains('invalid login credentials') ||
        errorMsg.contains('invalid credentials')) {
      return 'Email o contraseña incorrectos. Verifica tus datos e intenta de nuevo.';
    }
    if (errorMsg.contains('contraseña incorrecta')) {
      return 'Contraseña incorrecta. Por favor, verifica e intenta de nuevo.';
    }
    if (errorMsg.contains('cédula ya está registrada')) {
      return 'Esta cédula ya está registrada. Intenta con otra.';
    }
    if (errorMsg.contains('teléfono ya está registrado')) {
      return 'Este teléfono ya está registrado. Intenta con otro.';
    }
    if (errorMsg.contains('formato de cédula')) {
      return 'Formato de cédula inválido. Usa V12345678 o E12345678.';
    }
    if (errorMsg.contains('formato de teléfono')) {
      return 'Formato de teléfono inválido. Usa formato internacional (+584121234567) o local (04121234567).';
    }
    if (errorMsg.contains('user already registered') ||
        errorMsg.contains('already exists')) {
      return 'Este correo ya está registrado. Intenta iniciar sesión.';
    }
    if (errorMsg.contains('profiles_id_fkey') ||
        errorMsg.contains('foreign key constraint')) {
      return 'Este correo ya está registrado. Intenta iniciar sesión.';
    }
    if (errorMsg.contains('database error saving new user')) {
      return 'No se pudo completar el registro. La cédula o el teléfono ya están en uso por otra cuenta.';
    }
    if (errorMsg.contains('is invalid') && errorMsg.contains('email')) {
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
    if (errorMsg.contains('aún no está activa')) {
      return 'Tu cuenta aún no está activa. Por favor, verifica tu correo electrónico.';
    }
    if (errorMsg.contains('rate limit') ||
        errorMsg.contains('too many requests')) {
      return 'Demasiados intentos. Por favor espera unos minutos antes de intentar de nuevo.';
    }
    if (errorMsg.contains('422') ||
        errorMsg.contains('different from the old password')) {
      return 'La nueva contraseña debe ser diferente a la anterior.';
    }
    if (errorMsg.contains('suspendida') || errorMsg.contains('banned')) {
      return 'Tu cuenta ha sido suspendida permanentemente.';
    }

    // Limpiar el prefijo 'Exception: ' si existe
    return e
        .toString()
        .replaceAll('Exception: ', '')
        .replaceAll('exception: ', '');
  }

  /// Agrega un método de pago vinculado al usuario.
  Future<void> addPaymentMethod({required String bankCode}) async {
    try {
      final response = await _supabase.functions.invoke(
        'auth-service/add-payment-method',
        body: {
          'bank_code': bankCode,
        },
        method: HttpMethod.post,
      );

      if (response.status != 200) {
        final error = response.data['error'] ??
            'Error desconocido al guardar método de pago';
        throw error;
      }
    } catch (e) {
      debugPrint('AuthService: Error adding payment method: $e');
      throw _handleAuthError(e);
    }
  }

  /// Obtiene el perfil del usuario.
  Future<Player?> getProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;
      return Player.fromJson(response);
    } catch (e) {
      debugPrint('AuthService: Error fetching profile: $e');
      return null;
    }
  }

  /// Elimina la cuenta del usuario actual.
  ///
  /// Invoca a la Edge Function 'auth-service/delete-account'.
  /// Si tiene éxito, el usuario es eliminado de la base de datos.
  Future<void> deleteAccount(String password) async {
    try {
      final response = await _supabase.functions.invoke(
        'auth-service/delete-account',
        body: {'password': password},
        method: HttpMethod.delete,
      );

      if (response.status != 200) {
        final error =
            response.data['error'] ?? 'Error desconocido al eliminar cuenta';
        throw error;
      }

      // La sesión se cierra automáticamente o debemos forzarlo
      await logout();
    } catch (e) {
      debugPrint('AuthService: Error deleting account: $e');
      throw _handleAuthError(e);
    }
  }

  /// Elimina un usuario siendo administrador.
  ///
  /// Invoca a la Edge Function 'auth-service/delete-user-admin'.
  Future<void> adminDeleteUser(String userId) async {
    try {
      final response = await _supabase.functions.invoke(
        'auth-service/delete-user-admin',
        body: {'user_id': userId},
        method: HttpMethod.delete,
      );

      if (response.status != 200) {
        final error = response.data['error'] ??
            'Error desconocido al eliminar usuario como admin';
        throw error;
      }
    } catch (e) {
      debugPrint('AuthService: Error in adminDeleteUser: $e');
      throw _handleAuthError(e);
    }
  }
}
