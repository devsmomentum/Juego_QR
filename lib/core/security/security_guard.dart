import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomSecurityException implements Exception {
  final String message;
  final String referenceCode;
  CustomSecurityException(this.message, this.referenceCode);
  
  @override
  String toString() => message;
}

class SecurityGuard {
  static final _supabase = Supabase.instance.client;

  /// Detecta si el dispositivo del cliente ha sido vulnerado.
  static Future<void> assertDeviceIntegrity() async {
    try {
      // FIX: kIsWeb must be checked before Platform to avoid "Unsupported operation" in browsers.
      if (kIsWeb) return;

      if (!Platform.isAndroid && !Platform.isIOS) {
        return; // Omitir chequeos nativos en Windows/Mac locales
      }

      final isJailbroken = await FlutterJailbreakDetection.jailbroken;
      final isDeveloperMode = await FlutterJailbreakDetection.developerMode;

      if (isJailbroken) { 
        debugPrint('⚠️ SECURITY EVENT: Device tampering detected (Root/Jailbreak)');
        throw CustomSecurityException('Dispositivo no seguro para operar.', '0xERR-DEVICE-TAMPER');
      }
      if (isDeveloperMode) {
        debugPrint('⚠️ Warning: Developer mode active.');
      }
    } on PlatformException catch (e) {
      if (e.code == 'UNAVAILABLE') return; // Plugin no soportado temporalmente
      throw CustomSecurityException('Protección de memoria inyectada.', '0xERR-MEM-INJECT');
    } catch (e) {
      // Ignorar de forma segura si el plugin nativo no ha sido compilado en Windows
      // (Ocurre si el usuario hizo Hot Restart en lugar de cerrar el proceso y volver a compilar).
      if (e is MissingPluginException) return; 
      rethrow;
    }
  }

  /// Método universal y opaco para enrutar cualquier pago o minijuego.
  static Future<Map<String, dynamic>?> invokeSecureAction({
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    try {
      await assertDeviceIntegrity();

      final secureRandom = Random.secure();
      final nonceBytes = List<int>.generate(16, (_) => secureRandom.nextInt(256));
      final nonce = nonceBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final session = _supabase.auth.currentSession;
      
      final response = await _supabase.functions.invoke(
        'minigame-handshake',
        headers: {
          if (session != null) 'Authorization': 'Bearer ${session.accessToken}',
          'X-Client-Nonce': nonce,
        },
        body: { 'action': action, ...payload },
      );

      if (response.status != 200 || response.data == null) {
        final dataMap = (response.data is Map) ? response.data as Map : {};
        if (dataMap['error'] == 'BLOCKED') {
          throw CustomSecurityException('Cuenta bloqueada.', 'BLOCKED');
        }
        
        final refCode = dataMap['reference'] ?? '0xERR-UNKNOWN';
        throw CustomSecurityException('Fallo al validar entorno remoto.', refCode);
      }

      final responseMap = Map<String, dynamic>.from(response.data);
      
      if (responseMap.containsKey('success') && responseMap['success'] == false) {
        final errorField = responseMap['error']?.toString();
        if (errorField?.startsWith('TOO_FAST') == true) {
          return responseMap;
        }
        if (errorField == 'BLOCKED') {
          throw CustomSecurityException('Cuenta bloqueada.', 'BLOCKED');
        }
        final refCode = responseMap['reference_code'] ?? '0xERR-GENERIC';
        throw CustomSecurityException('Validación matemática rechazada.', refCode);
      }

      return responseMap;
    } on CustomSecurityException catch (e) {
      debugPrint('[SECURITY_GUARD] Banned Call: ${e.referenceCode}');
      rethrow; 
    } catch (e, stack) {
      debugPrint('[SECURITY_GUARD] CRITICAL NET ERROR: $e');
      debugPrint('[SECURITY_GUARD] Stacktrace: $stack');
      throw CustomSecurityException(e.toString(), '0xERR-NET-PKT');
    }
  }
}
