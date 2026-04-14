/// Modelo de código de país para el selector de teléfono.
class CountryCode {
  final String dialCode; // e.g. "+58"
  final String iso;      // e.g. "VE"
  final String name;     // e.g. "Venezuela"
  final String flag;     // e.g. "🇻🇪"
  final int maxLength;   // Max dígitos del número local (sin código de país)

  const CountryCode({
    required this.dialCode,
    required this.iso,
    required this.name,
    required this.flag,
    this.maxLength = 10,
  });

  /// Venezuela como código por defecto
  static const CountryCode defaultVE = CountryCode(
    dialCode: '+58',
    iso: 'VE',
    name: 'Venezuela',
    flag: '🇻🇪',
    maxLength: 10,
  );

  /// Texto para mostrar en el selector: "🇻🇪 +58"
  String get displayShort => '$flag $dialCode';

  /// Texto completo: "🇻🇪 Venezuela (+58)"
  String get displayFull => '$flag $name ($dialCode)';

  /// Formatea un número E.164 para visualización humana.
  /// Ejemplo: "+584121234567" → "🇻🇪 +58 412 123 4567"
  ///          "+14125256398"  → "🇺🇸 +1 412 525 6398"
  /// Si no se puede parsear, retorna el string original.
  static String formatForDisplay(String? e164) {
    if (e164 == null || e164.isEmpty) return 'No definido';
    final parsed = parseE164(e164);
    if (parsed == null) return e164;
    final (code, local) = parsed;
    // Agrupar el número local en bloques de 3-4 dígitos
    final spaced = _groupDigits(local);
    return '${code.flag} ${code.dialCode} $spaced';
  }

  /// Agrupa dígitos para legibilidad: "4121234567" → "412 123 4567"
  static String _groupDigits(String digits) {
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 3 == 0 && i < digits.length) buf.write(' ');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  /// Intenta encontrar el CountryCode que coincide con un número E.164.
  /// Retorna un record (CountryCode, String localNumber) o null si no matchea.
  static (CountryCode, String)? parseE164(String e164) {
    if (!e164.startsWith('+')) return null;
    // Intentar matchear del dialCode más largo al más corto
    final sorted = List<CountryCode>.from(all)
      ..sort((a, b) => b.dialCode.replaceAll(RegExp(r'[^0-9]'), '').length
          .compareTo(a.dialCode.replaceAll(RegExp(r'[^0-9]'), '').length));
    for (final code in sorted) {
      final cleanDial = code.dialCode.replaceAll(RegExp(r'[^+0-9]'), '');
      if (e164.startsWith(cleanDial)) {
        final local = e164.substring(cleanDial.length);
        if (local.isNotEmpty) return (code, local);
      }
    }
    return null;
  }

  /// Lista de códigos de país — Latinoamérica + principales internacionales
  static const List<CountryCode> all = [
    // -- Latinoamérica --
    CountryCode(dialCode: '+58', iso: 'VE', name: 'Venezuela', flag: '🇻🇪', maxLength: 10),
    CountryCode(dialCode: '+57', iso: 'CO', name: 'Colombia', flag: '🇨🇴', maxLength: 10),
    CountryCode(dialCode: '+52', iso: 'MX', name: 'México', flag: '🇲🇽', maxLength: 10),
    CountryCode(dialCode: '+54', iso: 'AR', name: 'Argentina', flag: '🇦🇷', maxLength: 10),
    CountryCode(dialCode: '+55', iso: 'BR', name: 'Brasil', flag: '🇧🇷', maxLength: 11),
    CountryCode(dialCode: '+56', iso: 'CL', name: 'Chile', flag: '🇨🇱', maxLength: 9),
    CountryCode(dialCode: '+51', iso: 'PE', name: 'Perú', flag: '🇵🇪', maxLength: 9),
    CountryCode(dialCode: '+591', iso: 'BO', name: 'Bolivia', flag: '🇧🇴', maxLength: 8),
    CountryCode(dialCode: '+593', iso: 'EC', name: 'Ecuador', flag: '🇪🇨', maxLength: 9),
    CountryCode(dialCode: '+595', iso: 'PY', name: 'Paraguay', flag: '🇵🇾', maxLength: 9),
    CountryCode(dialCode: '+598', iso: 'UY', name: 'Uruguay', flag: '🇺🇾', maxLength: 8),
    CountryCode(dialCode: '+507', iso: 'PA', name: 'Panamá', flag: '🇵🇦', maxLength: 8),
    CountryCode(dialCode: '+506', iso: 'CR', name: 'Costa Rica', flag: '🇨🇷', maxLength: 8),
    CountryCode(dialCode: '+503', iso: 'SV', name: 'El Salvador', flag: '🇸🇻', maxLength: 8),
    CountryCode(dialCode: '+502', iso: 'GT', name: 'Guatemala', flag: '🇬🇹', maxLength: 8),
    CountryCode(dialCode: '+504', iso: 'HN', name: 'Honduras', flag: '🇭🇳', maxLength: 8),
    CountryCode(dialCode: '+505', iso: 'NI', name: 'Nicaragua', flag: '🇳🇮', maxLength: 8),
    CountryCode(dialCode: '+53', iso: 'CU', name: 'Cuba', flag: '🇨🇺', maxLength: 8),
    CountryCode(dialCode: '+1-809', iso: 'DO', name: 'Rep. Dominicana', flag: '🇩🇴', maxLength: 7),
    CountryCode(dialCode: '+1-787', iso: 'PR', name: 'Puerto Rico', flag: '🇵🇷', maxLength: 7),
    // -- Norteamérica y Europa --
    CountryCode(dialCode: '+1', iso: 'US', name: 'Estados Unidos', flag: '🇺🇸', maxLength: 10),
    CountryCode(dialCode: '+34', iso: 'ES', name: 'España', flag: '🇪🇸', maxLength: 9),
    CountryCode(dialCode: '+39', iso: 'IT', name: 'Italia', flag: '🇮🇹', maxLength: 10),
    CountryCode(dialCode: '+33', iso: 'FR', name: 'Francia', flag: '🇫🇷', maxLength: 9),
    CountryCode(dialCode: '+44', iso: 'GB', name: 'Reino Unido', flag: '🇬🇧', maxLength: 10),
    CountryCode(dialCode: '+49', iso: 'DE', name: 'Alemania', flag: '🇩🇪', maxLength: 11),
    CountryCode(dialCode: '+351', iso: 'PT', name: 'Portugal', flag: '🇵🇹', maxLength: 9),
  ];
}
