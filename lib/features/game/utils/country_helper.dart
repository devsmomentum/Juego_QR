class CountryHelper {
  static const Map<String, String> _nameToEmoji = {
    // --- LATINOAMÉRICA Y CARIBE ---
    'México': '🇲🇽',
    'Mexico': '🇲🇽',
    'Guatemala': '🇬🇹',
    'El Salvador': '🇸🇻',
    'Honduras': '🇭🇳',
    'Nicaragua': '🇳🇮',
    'Costa Rica': '🇨🇷',
    'Panamá': '🇵🇦',
    'Panama': '🇵🇦',
    'Cuba': '🇨🇺',
    'República Dominicana': '🇩🇴',
    'Dominicana': '🇩🇴',
    'Puerto Rico': '🇵🇷',
    'Jamaica': '🇯🇲',
    'Haití': '🇭🇹',
    'Haiti': '🇭🇹',
    'Bahamas': '🇧🇸',
    'Trinidad y Tobago': '🇹🇹',
    'Barbados': '🇧🇧',
    'Santa Lucía': '🇱🇨',
    'San Vicente y las Granadinas': '🇻🇨',
    'Granada': '🇬🇩',
    'Dominica': '🇩🇲',
    'Antigua y Barbuda': '🇦🇬',
    'San Cristóbal y Nieves': '🇰🇳',
    'Colombia': '🇨🇴',
    'Venezuela': '🇻🇪',
    'Ecuador': '🇪🇨',
    'Perú': '🇵🇪',
    'Peru': '🇵🇪',
    'Brasil': '🇧🇷',
    'Brazil': '🇧🇷',
    'Bolivia': '🇧🇴',
    'Paraguay': '🇵🇾',
    'Chile': '🇨🇱',
    'Argentina': '🇦🇷',
    'Uruguay': '🇺🇾',
    'Guyana': '🇬🇾',
    'Surinam': '🇸🇷',
    'Suriname': '🇸🇷',
    'Guayana Francesa': '🇬🇫',

    // --- NORTEAMÉRICA ---
    'Estados Unidos': '🇺🇸',
    'Estados Unidos de América': '🇺🇸',
    'EEUU': '🇺🇸',
    'USA': '🇺🇸',
    'EE.UU.': '🇺🇸',
    'Canadá': '🇨🇦',
    'Canada': '🇨🇦',

    // --- EUROPA ---
    'España': '🇪🇸',
    'España ': '🇪🇸',
    'Francia': '🇫🇷',
    'Italia': '🇮🇹',
    'Alemania': '🇩🇪',
    'Germany': '🇩🇪',
    'Reino Unido': '🇬🇧',
    'Inglaterra': '🇬🇧',
    'Escocia': '🏴󠁧󠁢󠁳󠁣󠁴󠁿',
    'Gales': '🏴󠁧󠁢󠁷󠁬󠁳󠁿',
    'Irlanda': '🇮🇪',
    'Irlanda del Norte': '🇬🇧',
    'Portugal': '🇵🇹',
    'Países Bajos': '🇳🇱',
    'Holanda': '🇳🇱',
    'Bélgica': '🇧🇪',
    'Belgica': '🇧🇪',
    'Suiza': '🇨🇭',
    'Austria': '🇦🇹',
    'Suecia': '🇸🇪',
    'Noruega': '🇳🇴',
    'Dinamarca': '🇩🇰',
    'Finlandia': '🇫🇮',
    'Islandia': '🇮🇸',
    'Polonia': '🇵🇱',
    'Hungría': '🇭🇺',
    'Hungria': '🇭🇺',
    'República Checa': '🇨🇿',
    'Chequia': '🇨🇿',
    'Eslovaquia': '🇸🇰',
    'Rumanía': '🇷🇴',
    'Rumania': '🇷🇴',
    'Bulgaria': '🇧🇬',
    'Grecia': '🇬🇷',
    'Turquía': '🇹🇷',
    'Turquia': '🇹🇷',
    'Ucrania': '🇺🇦',
    'Rusia': '🇷🇺',
    'Russia': '🇷🇺',
    'Federación Rusa': '🇷🇺',
    'Bielorrusia': '🇧🇾',
    'Estonia': '🇪🇪',
    'Letonia': '🇱🇻',
    'Lituania': '🇱🇹',
    'Croacia': '🇭🇷',
    'Serbia': '🇷🇸',
    'Eslovenia': '🇸🇮',
    'Bosnia y Herzegovina': '🇧🇦',
    'Montenegro': '🇲🇪',
    'Albania': '🇦🇱',
    'Macedonia del Norte': '🇲🇰',
    'Luxemburgo': '🇱🇺',
    'Mónaco': '🇲🇨',
    'Malta': '🇲🇹',
    'Andorra': '🇦🇩',
    'San Marino': '🇸🇲',
    'Vaticano': '🇻🇦',

    // --- ASIA ---
    'Japón': '🇯🇵',
    'Japon': '🇯🇵',
    'China': '🇨🇳',
    'Corea del Sur': '🇰🇷',
    'Corea del Norte': '🇰🇵',
    'India': '🇮🇳',
    'Indonesia': '🇮🇩',
    'Tailandia': '🇹🇭',
    'Vietnam': '🇻🇳',
    'Filipinas': '🇵🇭',
    'Malasia': '🇲🇾',
    'Singapur': '🇸🇬',
    'Pakistán': '🇵🇰',
    'Bangladesh': '🇧🇩',
    'Irán': '🇮🇷',
    'Iraq': '🇮🇶',
    'Arabia Saudita': '🇸🇦',
    'Israel': '🇮🇱',
    'Palestina': '🇵🇸',
    'Jordania': '🇯🇴',
    'Líbano': '🇱🇧',
    'Siria': '🇸🇾',
    'Emiratos Árabes Unidos': '🇦🇪',
    'EAU': '🇦🇪',
    'UAE': '🇦🇪',
    'Qatar': '🇶🇦',
    'Kuwait': '🇰🇼',
    'Omán': '🇴🇲',
    'Yemen': '🇾🇪',
    'Afganistán': '🇦🇫',
    'Kazajistán': '🇰🇿',
    'Uzbekistán': '🇺🇿',
    'Turkmenistán': '🇹🇲',
    'Kirguistán': '🇰🇬',
    'Tayikistán': '🇹🇯',
    'Nepal': '🇳🇵',
    'Sri Lanka': '🇱🇰',
    'Myanmar': '🇲🇲',
    'Birmania': '🇲🇲',
    'Camboya': '🇰🇭',
    'Laos': '🇱🇦',
    'Mongolia': '🇲🇳',
    'Taiwán': '🇹🇼',

    // --- ÁFRICA ---
    'Egipto': '🇪🇬',
    'Sudáfrica': '🇿🇦',
    'Nigeria': '🇳🇬',
    'Kenia': '🇰🇪',
    'Etiopía': '🇪🇹',
    'Ghana': '🇬🇭',
    'Marruecos': '🇲🇦',
    'Argelia': '🇩🇿',
    'Túnez': '🇹🇳',
    'Libia': '🇱🇾',
    'Sudán': '🇸🇩',
    'Senegal': '🇸🇳',
    'Tanzania': '🇹🇿',
    'Uganda': '🇺🇬',
    'Congo': '🇨🇬',
    'RD Congo': '🇨🇩',
    'Angola': '🇦🇴',
    'Mozambique': '🇲🇿',
    'Zimbabue': '🇿🇼',
    'Costa de Marfil': '🇨🇮',
    'Camerún': '🇨🇲',
    'Madagascar': '🇲🇬',

    // --- OCEANÍA ---
    'Australia': '🇦🇺',
    'Nueva Zelanda': '🇳🇿',
    'Fiyi': '🇫🇯',
    'Papúa Nueva Guinea': '🇵🇬',
  };

  /// Normaliza un nombre de país eliminando acentos, espacios y pasando a minúscula
  static String _normalize(String text) {
    const withAccents = 'áéíóúüñÁÉÍÓÚÜÑ';
    const withoutAccents = 'aeiouunAEIOUUN';
    
    String result = text.trim().toLowerCase();
    for (int i = 0; i < withAccents.length; i++) {
      result = result.replaceAll(withAccents[i], withoutAccents[i]);
    }
    // Eliminar puntos de siglas como EE.UU. para que coincida con EEUU
    result = result.replaceAll('.', '').replaceAll(' ', '');
    return result;
  }

  static String? getEmoji(String countryName) {
    if (countryName.isEmpty) return '🚩'; // Placeholder flag if empty
    
    // Si ya es un emoji (empieza por un código de región o tiene un símbolo de bandera)
    // Usamos una comprobación simple de rango Unicode para banderas
    if (countryName.length >= 2 && countryName.runes.first > 127) {
      return countryName;
    }

    final searchName = _normalize(countryName);
    
    // 1. Intento directo normalizado
    for (var entry in _nameToEmoji.entries) {
      if (_normalize(entry.key) == searchName) {
        return entry.value;
      }
    }
    
    // 2. Intento de sub-cadena (Contiene)
    // Útil para "Reino Unido de Gran Bretaña" -> "Reino Unido"
    for (var entry in _nameToEmoji.entries) {
      final keyNorm = _normalize(entry.key);
      if (searchName.contains(keyNorm) || keyNorm.contains(searchName)) {
        if (keyNorm.length > 3) { // Evitar falsos positivos con nombres muy cortos
           return entry.value;
        }
      }
    }
    
    return null; // Retornamos null para que el UI pueda decidir qué mostrar (ej. el Nombre)
  }
}
