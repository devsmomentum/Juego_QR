import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/country_code.dart';

/// Provider para gestionar el estado del campo de teléfono en el registro.
///
/// Maneja: código de país, número local, sanitización E.164,
/// y actualización directa en la tabla `profiles` de Supabase.
class ProfileRegistrationProvider extends ChangeNotifier {
  CountryCode _selectedCountryCode = CountryCode.defaultVE;
  String _phoneNumber = '';
  bool _isLoading = false;
  String? _error;

  // --- Getters ---
  CountryCode get selectedCountryCode => _selectedCountryCode;
  String get phoneNumber => _phoneNumber;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // --- Setters con notificación ---

  void setCountryCode(CountryCode code) {
    _selectedCountryCode = code;
    _error = null;
    notifyListeners();
  }

  void setPhoneNumber(String number) {
    _phoneNumber = number;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Resetea el estado completo del provider.
  void reset() {
    _selectedCountryCode = CountryCode.defaultVE;
    _phoneNumber = '';
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  /// Carga un número E.164 existente (ej: "+584121234567") y separa
  /// el código de país del número local para pre-poblar el formulario.
  void loadFromE164(String? e164) {
    if (e164 == null || e164.isEmpty) {
      reset();
      return;
    }
    final parsed = CountryCode.parseE164(e164);
    if (parsed != null) {
      _selectedCountryCode = parsed.$1;
      _phoneNumber = parsed.$2;
    } else {
      // Fallback: poner todo como número con código por defecto
      _selectedCountryCode = CountryCode.defaultVE;
      _phoneNumber = e164.replaceAll(RegExp(r'[^0-9]'), '');
    }
    _error = null;
    notifyListeners();
  }

  // --- Sanitización E.164 ---

  /// Elimina todo lo que NO sea un dígito: espacios, guiones, letras, etc.
  static String sanitizeNumber(String raw) {
    return raw.replaceAll(RegExp(r'[^0-9]'), '');
  }

  /// Devuelve el teléfono completo en formato E.164: +[código][número].
  /// Elimina el "0" inicial del número local si existe (convención venezolana).
  /// Retorna `null` si el número está vacío tras sanitizar.
  String? get formattedPhone {
    final localNumber = sanitizeNumber(_phoneNumber);
    if (localNumber.isEmpty) return null;

    // dialCode ya incluye "+" (ej: "+58")
    // Para códigos tipo "+1-809", limpiamos el guión para E.164
    final cleanDialCode =
        _selectedCountryCode.dialCode.replaceAll(RegExp(r'[^+0-9]'), '');

    return '$cleanDialCode$localNumber';
  }

  /// Valida que el número tenga al menos `minDigits` dígitos.
  String? validatePhone(String? value, {int minDigits = 7}) {
    if (value == null || value.isEmpty) {
      return 'Ingresa tu número de teléfono';
    }
    final digits = sanitizeNumber(value);
    if (digits.isEmpty) {
      return 'El número debe contener dígitos';
    }
    if (digits.startsWith('0')) {
      return 'No incluyas el cero inicial';
    }
    if (digits.length < minDigits) {
      return 'Mínimo $minDigits dígitos';
    }
    if (digits.length > _selectedCountryCode.maxLength) {
      return 'Máximo ${_selectedCountryCode.maxLength} dígitos';
    }
    return null;
  }

  // --- Supabase Update ---

  /// Actualiza el campo `phone` en la tabla `profiles` con formato E.164.
  /// Requiere que el usuario esté autenticado (RLS: update own profile).
  Future<bool> updatePhoneInProfile(String userId) async {
    final phone = formattedPhone;
    if (phone == null) {
      _error = 'Número de teléfono inválido';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'phone': phone}).eq('id', userId);

      _isLoading = false;
      notifyListeners();
      return true;
    } on PostgrestException catch (e) {
      _isLoading = false;
      if (e.code == '23505') {
        // UNIQUE violation — el teléfono ya está registrado
        _error = 'Este número ya está registrado';
      } else {
        _error = 'Error al guardar el teléfono: ${e.message}';
      }
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _error = 'Error inesperado: $e';
      notifyListeners();
      return false;
    }
  }
}
