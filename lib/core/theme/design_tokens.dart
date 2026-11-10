import 'package:flutter/material.dart';

/// Design tokens for Arrow Escape.
/// Professional, warm gaming aesthetic with accessible contrast and cohesive spacing.
abstract final class DesignTokens {
  // ---- Spacing scale --------------------------------------------------------
  static const double s4 = 4.0;
  static const double s8 = 8.0;
  static const double s12 = 12.0;
  static const double s16 = 16.0;
  static const double s20 = 20.0;
  static const double s24 = 24.0;
  static const double s32 = 32.0;
  static const double s40 = 40.0;
  static const double s48 = 48.0;

  // ---- Border Radii ---------------------------------------------------------
  static const double r8 = 8.0;
  static const double r12 = 12.0;
  static const double r16 = 16.0;
  static const double r20 = 20.0;
  static const double r24 = 24.0;
  static const double r32 = 32.0;
  static const double rPill = 999.0;

  static final BorderRadius br12 = BorderRadius.circular(r12);
  static final BorderRadius br16 = BorderRadius.circular(r16);
  static final BorderRadius br20 = BorderRadius.circular(r20);
  static final BorderRadius br24 = BorderRadius.circular(r24);
  static final BorderRadius brPill = BorderRadius.circular(rPill);

  // ---- Palette (Light / Modern Clean) --------------------------------------
  static const Color creamBg = Color(0xFFFFFFFF); // Pure clean white as in reference
  static const Color creamSurface = Color(0xFFF8FAFC);
  static const Color creamCard = Color(0xFFFFFFFF);

  static const Color brownPrimary = Color(0xFF0F172A); // Deep navy/slate arrow stroke
  static const Color brownDark = Color(0xFF020617);
  static const Color brownMuted = Color(0xFF64748B);
  static const Color brownLight = Color(0xFFE2E8F0);

  static const Color accentAmber = Color(0xFFE8A33D);
  static const Color accentGold = Color(0xFFF4B942);
  static const Color successGreen = Color(0xFF4CAF7A);
  static const Color errorRed = Color(0xFFE53935);
  static const Color hintBlue = Color(0xFF2D9CFF);

  // ---- Dark Palette ---------------------------------------------------------
  static const Color darkBg = Color(0xFF241913);
  static const Color darkSurface = Color(0xFF32231A);
  static const Color darkCard = Color(0xFF3E2B22);
  static const Color darkText = Color(0xFFF3EAD9);
  static const Color darkMuted = Color(0xFFA69082);

  // ---- Shadows --------------------------------------------------------------
  static const List<BoxShadow> shadowSoft = [
    BoxShadow(
      color: Color(0x143B2A22),
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> shadowElevated = [
    BoxShadow(
      color: Color(0x223B2A22),
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
  ];

  static const List<BoxShadow> shadowPill = [
    BoxShadow(
      color: Color(0x1F3B2A22),
      blurRadius: 8,
      offset: Offset(0, 3),
    ),
  ];
}

