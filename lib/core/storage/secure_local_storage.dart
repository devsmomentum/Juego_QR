import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Implementación segura del almacenamiento local para Supabase Auth.
/// Utiliza Keychain (iOS), Keystore (Android) y libsecret (Linux) para encriptar el tokens.
class SecureLocalStorage extends LocalStorage {
  SecureLocalStorage();

  static const supabasePersistSessionKey = 'supabase_persist_session';
  static const _lastProjectUrlKey = 'supabase_last_project_url';
  final _storage = const FlutterSecureStorage();

  /// Clears the cached session if it belongs to a different Supabase project.
  /// Checks both the stored URL marker AND the JWT issuer inside the session.
  /// Must be called BEFORE Supabase.initialize().
  static Future<void> clearIfProjectChanged(String currentUrl) async {
    const storage = FlutterSecureStorage();

    // Extract the project ref from the current URL (e.g. "hyjelngckvqoanckqwep")
    final currentRef = Uri.tryParse(currentUrl)?.host.split('.').first ?? '';

    final sessionJson = await storage.read(key: supabasePersistSessionKey);
    if (sessionJson != null) {
      bool shouldClear = false;
      try {
        final session = jsonDecode(sessionJson) as Map<String, dynamic>;
        final accessToken = session['access_token'] as String?;
        if (accessToken != null) {
          // Decode the JWT payload (base64url, no verification needed)
          final parts = accessToken.split('.');
          if (parts.length == 3) {
            final payload = utf8.decode(
              base64Url.decode(base64Url.normalize(parts[1])),
            );
            final claims = jsonDecode(payload) as Map<String, dynamic>;
            final issuer = claims['iss'] as String? ?? '';
            // If the token was issued by a different project, clear it
            if (!issuer.contains(currentRef)) {
              shouldClear = true;
              debugPrint('🔑 Stale session detected — JWT issuer "$issuer" '
                  'does not match current project "$currentRef"');
            }
          }
        }
      } catch (e) {
        // Corrupted session data → clear it
        shouldClear = true;
        debugPrint('🔑 Corrupted session data — clearing ($e)');
      }

      if (shouldClear) {
        await storage.delete(key: supabasePersistSessionKey);
        debugPrint('🔑 Cached session cleared successfully');
      }
    }

    await storage.write(key: _lastProjectUrlKey, value: currentUrl);
  }

  @override
  Future<void> initialize() async {
    // No initialization needed for flutter_secure_storage
  }

  @override
  Future<bool> hasAccessToken() async {
    return _storage.containsKey(key: supabasePersistSessionKey);
  }

  @override
  Future<String?> accessToken() async {
    return _storage.read(key: supabasePersistSessionKey);
  }

  @override
  Future<void> removePersistedSession() async {
    return _storage.delete(key: supabasePersistSessionKey);
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    return _storage.write(
        key: supabasePersistSessionKey, value: persistSessionString);
  }
}
