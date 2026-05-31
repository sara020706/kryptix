import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// VaultX Design System
/// Based on the Modern-Industrial Glassmorphism reference
/// Primary palette: Deep blacks (#131313) + Electric Blue-Lilac (#adc7ff)
class VaultXColors {
  // Core background
  static const Color background = Color(0xFF131313);
  static const Color backgroundLowest = Color(0xFF0E0E0E);
  static const Color surface = Color(0xFF131313);
  static const Color surfaceDim = Color(0xFF131313);
  static const Color surfaceBright = Color(0xFF3a3939);

  // Surface containers (glassmorphic layers)
  static const Color surfaceContainerLowest = Color(0xFF0e0e0e);
  static const Color surfaceContainerLow = Color(0xFF1c1b1b);
  static const Color surfaceContainer = Color(0xFF201f1f);
  static const Color surfaceContainerHigh = Color(0xFF2a2a2a);
  static const Color surfaceContainerHighest = Color(0xFF353534);
  static const Color surfaceVariant = Color(0xFF353534);

  // On-surface
  static const Color onSurface = Color(0xFFe5e2e1);
  static const Color onSurfaceVariant = Color(0xFFc1c6d7);
  static const Color onBackground = Color(0xFFe5e2e1);

  // Primary (Electric Blue-Lilac)
  static const Color primary = Color(0xFFadc7ff);
  static const Color onPrimary = Color(0xFF002e68);
  static const Color primaryContainer = Color(0xFF4a8eff);
  static const Color onPrimaryContainer = Color(0xFF00285b);
  static const Color primaryFixed = Color(0xFFd8e2ff);
  static const Color primaryFixedDim = Color(0xFFadc7ff);
  static const Color inversePrimary = Color(0xFF005bc0);

  // Outline
  static const Color outline = Color(0xFF8b90a0);
  static const Color outlineVariant = Color(0xFF414754);

  // Error
  static const Color error = Color(0xFFffb4ab);
  static const Color onError = Color(0xFF690005);
  static const Color errorContainer = Color(0xFF93000a);
  static const Color onErrorContainer = Color(0xFFffdad6);

  // Inverse
  static const Color inverseSurface = Color(0xFFe5e2e1);
  static const Color inverseOnSurface = Color(0xFF313030);

  // Glassmorphic constants
  static Color glassBackground = Colors.white.withOpacity(0.03);
  static Color glassBorder = Colors.white.withOpacity(0.08);
  static Color glassBorderHover = Colors.white.withOpacity(0.15);
  static Color primaryGlow = const Color(0xFFadc7ff).withOpacity(0.25);
}

class VaultXTheme {
  static TextTheme _buildTextTheme() {
    return TextTheme(
      // headline-lg: 28px, Inter 700, -0.02em
      displayLarge: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.56,
        height: 34 / 28,
        color: VaultXColors.onSurface,
      ),
      // headline-md: 20px, Inter 600, -0.01em
      headlineMedium: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 28 / 20,
        color: VaultXColors.onSurface,
      ),
      // body-lg: 16px, Inter 400
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        color: VaultXColors.onSurface,
      ),
      // body-md: 14px, Inter 400
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: VaultXColors.onSurface,
      ),
      // label-sm: 12px, Inter 600, 0.05em
      labelSmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        height: 16 / 12,
        color: VaultXColors.onSurfaceVariant,
      ),
      // password-display: 18px, JetBrains Mono 500, 0.05em
      titleMedium: GoogleFonts.jetBrainsMono(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.9,
        height: 24 / 18,
        color: VaultXColors.onSurface,
      ),
    );
  }

  static ThemeData getTheme() {
    final textTheme = _buildTextTheme();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: VaultXColors.background,
      colorScheme: const ColorScheme.dark(
        primary: VaultXColors.primary,
        onPrimary: VaultXColors.onPrimary,
        primaryContainer: VaultXColors.primaryContainer,
        onPrimaryContainer: VaultXColors.onPrimaryContainer,
        error: VaultXColors.error,
        onError: VaultXColors.onError,
        errorContainer: VaultXColors.errorContainer,
        onErrorContainer: VaultXColors.onErrorContainer,
        surface: VaultXColors.surface,
        onSurface: VaultXColors.onSurface,
        surfaceContainerHighest: VaultXColors.surfaceContainerHighest,
        outline: VaultXColors.outline,
        outlineVariant: VaultXColors.outlineVariant,
        inverseSurface: VaultXColors.inverseSurface,
        onInverseSurface: VaultXColors.inverseOnSurface,
        inversePrimary: VaultXColors.inversePrimary,
      ),
      textTheme: textTheme,
      // No AppBar in the new design — we use custom headers
      appBarTheme: AppBarTheme(
        backgroundColor: VaultXColors.background.withOpacity(0.8),
        foregroundColor: VaultXColors.primary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: VaultXColors.primary,
          letterSpacing: -0.4,
        ),
      ),
      // Bottom nav styling
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: VaultXColors.surfaceContainerLowest,
        selectedItemColor: VaultXColors.primary,
        unselectedItemColor: VaultXColors.onSurfaceVariant,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      // Elevated buttons: primary filled with glow
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: VaultXColors.primary,
          foregroundColor: VaultXColors.onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: VaultXColors.primary,
          textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.6),
          minimumSize: const Size(0, 40),
        ),
      ),
      // Inputs: bottom-border only, animated focus
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1), width: 2),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1), width: 2),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: VaultXColors.primary, width: 2),
        ),
        errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: VaultXColors.error, width: 2),
        ),
        focusedErrorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: VaultXColors.error, width: 2),
        ),
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: VaultXColors.primary,
        ),
        hintStyle: GoogleFonts.inter(
          color: VaultXColors.onSurfaceVariant.withOpacity(0.3),
        ),
        prefixIconColor: VaultXColors.outline,
        suffixIconColor: VaultXColors.onSurfaceVariant,
      ),
      // Slider
      sliderTheme: SliderThemeData(
        activeTrackColor: VaultXColors.primary,
        inactiveTrackColor: Colors.white.withOpacity(0.1),
        thumbColor: VaultXColors.primary,
        overlayColor: VaultXColors.primary.withOpacity(0.12),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
        trackHeight: 4,
      ),
      // Switch (for toggles)
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return VaultXColors.onPrimary;
          }
          return VaultXColors.onSurfaceVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return VaultXColors.primary;
          }
          return VaultXColors.surfaceContainerHighest;
        }),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: VaultXColors.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: VaultXColors.onSurface,
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: VaultXColors.onSurfaceVariant,
          height: 1.5,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withOpacity(0.05),
        thickness: 1,
        space: 0,
      ),
      iconTheme: const IconThemeData(color: VaultXColors.onSurfaceVariant, size: 24),
    );
  }

  // Keep old methods for backwards compatibility
  static ThemeData getLightTheme() => getTheme();
  static ThemeData getDarkTheme() => getTheme();
}

extension PasswordStrengthColor on String {
  Color toColor() {
    switch (this) {
      case 'red':
        return const Color(0xFFffb4ab);
      case 'orange':
        return const Color(0xFFFFB74D);
      case 'yellow':
        return const Color(0xFFFFEE58);
      case 'lightGreen':
        return const Color(0xFF81C784);
      case 'green':
        return const Color(0xFF4CAF50);
      case 'darkGreen':
        return const Color(0xFF43A047);
      default:
        return VaultXColors.outline;
    }
  }
}
