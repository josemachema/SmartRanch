import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Theme for Smart Ranch (Supports Light and Dark Mode, Light by default)
class AppTheme {
  // --- Global Theme State ---
  /// Global notifier for theme mode — defaults to Light Mode
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  /// Current ThemeMode
  static ThemeMode get currentThemeMode => themeModeNotifier.value;

  /// Check whether current effective theme is dark
  static bool get isDark {
    if (themeModeNotifier.value == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return themeModeNotifier.value == ThemeMode.dark;
  }

  /// Setter for backwards-compatibility
  static set isDark(bool value) {
    setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
  }

  /// Change theme mode explicitly
  static void setThemeMode(ThemeMode mode) {
    if (themeModeNotifier.value != mode) {
      themeModeNotifier.value = mode;
    }
  }

  /// Quick toggle between light and dark mode
  static void toggleTheme() {
    setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }

  // --- Brand Colors ---
  static const Color primary = Color(0xFF619F49); // rgba(97, 159, 73)
  static const Color primaryDark = Color(0xFF4A7D37);
  static const Color secondary = Color(0xFFFF6D00); // Warm orange (alerts)

  static Color get surface => isDark ? const Color(0xFF101010) : const Color(0xFFFFFFFF);
  static Color get surfaceVariant => isDark ? const Color(0xFF181818) : const Color(0xFFF1F5F9);
  static Color get card => isDark ? const Color(0xFF141414) : const Color(0xFFFFFFFF);
  static Color get cardBright => isDark ? const Color(0xFF222222) : const Color(0xFFF0FDF4);
  static Color get background => isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC);
  
  static Color get textPrimary => isDark ? const Color(0xFFF0F0F5) : const Color(0xFF0F172A);
  static Color get textSecondary => isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
  static Color get divider => isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0);

  // --- THI Level Colors ---
  static const Color thiNormal = Color(0xFF00C853);
  static const Color thiAlert = Color(0xFFFFD600);
  static const Color thiDanger = Color(0xFFFF6D00);
  static const Color thiEmergency = Color(0xFFFF1744);

  static Color thiColor(String level) => switch (level) {
    'normal' => thiNormal,
    'alert' => thiAlert,
    'danger' => thiDanger,
    'emergency' => thiEmergency,
    _ => textSecondary,
  };

  static String thiLabel(String level) => switch (level) {
    'normal' => 'Normal',
    'alert' => 'Alerta',
    'danger' => 'Peligro',
    'emergency' => 'Emergencia',
    _ => 'Desconocido',
  };

  static IconData thiIcon(String level) => switch (level) {
    'normal' => Icons.check_circle_rounded,
    'alert' => Icons.warning_amber_rounded,
    'danger' => Icons.local_fire_department_rounded,
    'emergency' => Icons.crisis_alert_rounded,
    _ => Icons.help_outline_rounded,
  };

  // --- Theme Data ---
  static ThemeData get darkTheme {
    return _buildTheme(Brightness.dark);
  }
  
  static ThemeData get lightTheme {
    return _buildTheme(Brightness.light);
  }

  static ThemeData _buildTheme(Brightness brightness) {
    final bool isDarkTheme = brightness == Brightness.dark;
    final bg = isDarkTheme ? const Color(0xFF000000) : const Color(0xFFF8FAFC);
    final surf = isDarkTheme ? const Color(0xFF121212) : const Color(0xFFFFFFFF);
    final txt = isDarkTheme ? const Color(0xFFF0F0F5) : const Color(0xFF0F172A);
    final txtSec = isDarkTheme ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    final cardCol = isDarkTheme ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF);
    final divCol = isDarkTheme ? const Color(0xFF333333) : const Color(0xFFE2E8F0);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
        primary: primary,
        secondary: secondary,
        surface: surf,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: txt,
        outline: divCol,
      ),
      textTheme: GoogleFonts.interTextTheme(
        isDarkTheme ? ThemeData.dark().textTheme : ThemeData.light().textTheme
      ).copyWith(
            headlineLarge: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: txt,
            ),
            headlineMedium: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: txt,
            ),
            titleLarge: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: txt,
            ),
            titleMedium: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: txtSec,
            ),
            bodyLarge: GoogleFonts.inter(fontSize: 16, color: txt),
            bodyMedium: GoogleFonts.inter(fontSize: 14, color: txtSec),
            labelLarge: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: txt,
            ),
          ),
      cardTheme: CardThemeData(
        color: cardCol,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: divCol),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: divCol,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDarkTheme ? const Color(0xFF181818) : const Color(0xFFFFFFFF),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: divCol),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: divCol),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        labelStyle: TextStyle(color: txtSec, fontSize: 13),
        hintStyle: TextStyle(color: txtSec.withAlpha(120), fontSize: 13),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surf,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: txt),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: txt,
        ),
      ),
    );
  }
}
