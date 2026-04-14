import 'package:flutter/material.dart';

class AppTheme {
  // --- DARK PALETTE (The Void) ---
  static const Color dGoldMain = Color(0xFFFECB00);
  static const Color dGoldLight = Color(0xFFFFF176);
  static const Color dGoldDark = Color(0xFFFBC02D);
  static const Color dGoldMuted = Color(0xFFB8860B);

  static const Color dBrandMain = Color(0xFF7B2CBF);
  static const Color dBrandLight = Color(0xFFA29BFE);
  static const Color dBrandDark = Color(0xFF4834D4);
  static const Color dBrandDeep = Color(0xFF150826);

  static const Color dSurface0 = Color(0xFF0D0D0F); // Background absolute
  static const Color dSurface1 = Color(0xFF1A1A1D); // Cards
  static const Color dSurface2 = Color(0xFF2D3436); // Modals/Overlays
  static const Color dBorder = Color(0xFF3D3D4D);

  // --- LIGHT PALETTE (Premium White & Gold) ---
  static const Color lGoldAction = Color(0xFFD4AF37); // Metallic Gold
  static const Color lGoldText = Color(0xFF9C7A14); // Darker Gold for text contrast
  static const Color lGoldSurface = Color(0xFFFFFDF0);

  static const Color lBrandMain = Color(0xFFC5BA30); // Lighter brand gold
  static const Color lBrandSurface = Color(0xFFFDFCF2);
  static const Color lBrandDeep = Color(0xFF8E7D14);

  static const Color lSurface0 = Color(0xFFF8F9FA); // Background absolute
  static const Color lSurface1 = Color(0xFFFFFFFF); // Cards
  static const Color lSurfaceAlt = Color(0xFFF1F1F7); // Secondary fields
  static const Color lBorder = Color(0xFFE0E0E0);

  // legacy aliases for backward compatibility
  static const Color accentGold = dGoldMain;
  static const Color darkBg = dSurface0;
  static const Color cardBg = dSurface1;
  static const Color dangerRed = Color(0xFFFF4757);
  static const Color successGreen = Color(0xFF00D9A3);
  static const Color primaryPurple = Color(0xFF7B2CBF);
  static const Color secondaryPink = Color(0xFFD42AB3);
  static const Color warningOrange = Color(0xFFFF9F43);
  static const Color neonGreen = Color(0xFF00D9A3);

  // Aliases for compatibility
  static const Color surfaceDark = dSurface1;
  static const Color accentGreen = neonGreen;

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryPurple, secondaryPink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [dSurface0, Color(0xFF1A1A1D)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [dGoldMain, dGoldDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient mainGradient(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const LinearGradient(
        colors: [dSurface0, dSurface1],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    }
    return const LinearGradient(
      colors: [lSurface0, lSurface1],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
  }

  static ThemeData get darkTheme => _buildTheme(Brightness.dark);
  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  static ThemeData _buildTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    final Color bg = isDark ? dSurface0 : lSurface0;
    final Color surface = isDark ? dSurface1 : lSurface1;
    final Color primary = isDark ? dBrandMain : lBrandMain;
    final Color textColor = isDark ? Colors.white : Colors.black;
    final Color textSec = isDark ? Colors.white70 : Colors.black87;
    final Color borderColor = isDark ? dBorder : lBorder;

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      primaryColor: primary,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        secondary: isDark ? dGoldMain : lGoldAction,
        surface: surface,
        error: dangerRed,
        onPrimary: isDark ? Colors.white : Colors.black,
        onSecondary: Colors.black, // Gold backgrounds need black text
        onSurface: textColor,
        onError: Colors.white,
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
            fontSize: 32, fontWeight: FontWeight.bold, color: textColor),
        displayMedium: TextStyle(
            fontSize: 28, fontWeight: FontWeight.bold, color: textColor),
        bodyLarge: TextStyle(fontSize: 16, color: textColor),
        bodyMedium: TextStyle(fontSize: 14, color: textSec),
        labelLarge: TextStyle(fontWeight: FontWeight.bold, color: textColor),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: isDark ? 0 : 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: isDark ? Colors.white : Colors.black,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(color: textColor.withOpacity(0.4), fontSize: 14),
        labelStyle: TextStyle(color: textColor.withOpacity(0.7), fontSize: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                isDark ? BorderSide.none : BorderSide(color: borderColor)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderColor)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primary, width: 2)),
      ),
    );
  }

  static InputDecoration inputDecoration({
    required BuildContext context,
    String? label,
    String? hint,
    IconData? icon,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black;
    final Color borderColor = isDark ? dBorder : lBorder;
    final Color primary = isDark ? dBrandMain : lBrandMain;

    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null
          ? Icon(icon, color: isDark ? dGoldMain : lGoldAction)
          : null,
      labelStyle: TextStyle(color: textColor.withOpacity(0.6), fontSize: 14),
      hintStyle: TextStyle(color: textColor.withOpacity(0.3), fontSize: 14),
      filled: true,
      fillColor: Theme.of(context).cardTheme.color,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor.withOpacity(0.5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primary, width: 2),
      ),
    );
  }
}
