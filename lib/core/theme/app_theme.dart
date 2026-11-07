import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A purchasable/ unlockable colour theme.
class AppThemeData {
  final String id;
  final String name;
  final int coinCost; // 0 = free/default
  final Color background;
  final Color arrowColor;
  final Color arrowBlocked;
  final Color arrowHint;
  final Color surface;
  final Color textColor;

  const AppThemeData({
    required this.id,
    required this.name,
    required this.coinCost,
    required this.background,
    required this.arrowColor,
    required this.arrowBlocked,
    required this.arrowHint,
    required this.surface,
    required this.textColor,
  });
}

const List<AppThemeData> kAppThemes = [
  AppThemeData(
    id: 'classic',
    name: 'Classic Cream',
    coinCost: 0,
    background: Color(0xFFF3EAD9),
    arrowColor: Color(0xFF6B4A3A),
    arrowBlocked: Color(0xFFE53935),
    arrowHint: Color(0xFF2D9CFF),
    surface: Color(0xFFFFFFFF),
    textColor: Color(0xFF3E2B22),
  ),
  AppThemeData(
    id: 'dark',
    name: 'Midnight Cocoa',
    coinCost: 0,
    background: Color(0xFF2A1E18),
    arrowColor: Color(0xFFF3EAD9),
    arrowBlocked: Color(0xFFFF6F60),
    arrowHint: Color(0xFF64B5FF),
    surface: Color(0xFF3E2B22),
    textColor: Color(0xFFF3EAD9),
  ),
  AppThemeData(
    id: 'forest',
    name: 'Forest',
    coinCost: 150,
    background: Color(0xFFE8F0E4),
    arrowColor: Color(0xFF2E5B3E),
    arrowBlocked: Color(0xFFD84343),
    arrowHint: Color(0xFF2D9CFF),
    surface: Color(0xFFFFFFFF),
    textColor: Color(0xFF1E3A28),
  ),
  AppThemeData(
    id: 'ocean',
    name: 'Ocean Breeze',
    coinCost: 150,
    background: Color(0xFFE4EEF6),
    arrowColor: Color(0xFF1C4E73),
    arrowBlocked: Color(0xFFE53935),
    arrowHint: Color(0xFF00A6C0),
    surface: Color(0xFFFFFFFF),
    textColor: Color(0xFF123348),
  ),
  AppThemeData(
    id: 'rose',
    name: 'Rosewood',
    coinCost: 250,
    background: Color(0xFFF7E8E6),
    arrowColor: Color(0xFF7A3B47),
    arrowBlocked: Color(0xFFC62828),
    arrowHint: Color(0xFF2D9CFF),
    surface: Color(0xFFFFFFFF),
    textColor: Color(0xFF4A1F28),
  ),
];

AppThemeData themeById(String id) =>
    kAppThemes.firstWhere((t) => t.id == id, orElse: () => kAppThemes.first);

abstract final class AppTheme {
  static ThemeData build(AppThemeData t) {
    final scheme = ColorScheme.fromSeed(
      seedColor: t.arrowColor,
      brightness:
          t.background.computeLuminance() > 0.5 ? Brightness.light : Brightness.dark,
      surface: t.surface,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: t.background,
      splashFactory: InkSparkle.splashFactory,
    );
    final textTheme = GoogleFonts.nunitoTextTheme(base.textTheme).apply(
      bodyColor: t.textColor,
      displayColor: t.textColor,
    );
    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: t.textColor,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: t.arrowColor,
          foregroundColor: t.background,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

/// Colour-blind-safe highlight palette alternative.
abstract final class ColorblindHighlights {
  static const hint = Color(0xFF0072B2);
  static const blocked = Color(0xFFD55E00);
}
