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
  
  // --- LIGHT PALETTE (Crystal Clarity) ---
  static const Color lGoldAction = Color(0xFFFFD700);
  static const Color lGoldText = Color(0xFFB8860B);
  static const Color lGoldSurface = Color(0xFFFFFDE7);
  
  static const Color lBrandMain = Color(0xFF5A189A);
  static const Color lBrandSurface = Color(0xFFE9D5FF);
  static const Color lBrandDeep = Color(0xFF3C096C);
  
  static const Color lSurface0 = Color(0xFFF2F2F7); // Background absolute
  static const Color lSurface1 = Color(0xFFFFFFFF); // Cards
  static const Color lSurfaceAlt = Color(0xFFD1D1DB); // Secondary fields
  static const Color lBorder = Color(0xFFD1D1DB);
  
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
  
  // UI Specific colors for visibility
  static const Color adminCardBorder = Color(0x33FECB00); // 20% Gold
  static const Color adminTabUnselected = Colors.white38;
  static const Color adminTabSelected = dGoldMain;

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

  static ThemeData get darkTheme => _buildTheme();
  static ThemeData get lightTheme => _buildTheme(); // Fallback to dark if requested

  static ThemeData _buildTheme() {
    const Brightness brightness = Brightness.dark;
    const Color bg = dSurface0;
    const Color surface = dSurface1;
    const Color primary = dBrandMain;
    const Color textColor = Colors.white;
    const Color textSec = Colors.white70;
    const Color borderColor = dBorder;

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      primaryColor: primary,
      colorScheme: const ColorScheme(
        brightness: brightness,
        primary: primary,
        secondary: dGoldMain,
        surface: surface,
        background: bg,
        error: dangerRed,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: textColor,
        onBackground: textColor,
        onError: Colors.white,
      ),
      textTheme: const TextTheme(
        displayLarge:
            TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textColor),
        displayMedium:
            TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor),
        bodyLarge: TextStyle(fontSize: 16, color: textSec),
        bodyMedium: TextStyle(fontSize: 14, color: textSec),
        labelLarge: TextStyle(fontWeight: FontWeight.bold),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(color: textColor.withOpacity(0.4), fontSize: 14),
        labelStyle: const TextStyle(color: textSec),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: dGoldMain, width: 2)),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: dGoldMain,
        unselectedLabelColor: Colors.white38,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: dGoldMain, width: 3),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textColor),
        titleTextStyle: TextStyle(
          color: textColor,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
