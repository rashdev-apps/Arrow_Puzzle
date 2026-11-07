import 'package:flutter/material.dart';

abstract final class AppConstants {
  static const String appName = 'Arrow Escape';

  static const int heartsPerLevel = 3;
  static const int maxLevel = 200;
  static const int chapterSize = 20;

  static const int hintCost = 30;
  static const int undoCost = 15;
  static const int reviveCost = 50;
  static const int undoChargesPerLevel = 3;

  static const int coinsPerLevel = 10;
  static const int starBonus2 = 5;
  static const int starBonus3 = 10;

  static const double minCellSize = 10;
  static const double hitTolerance = 14;

  // Palette
  static const Color cream = Color(0xFFF3EAD9);
  static const Color brown = Color(0xFF6B4A3A);
  static const Color brownDark = Color(0xFF3E2B22);
  static const Color blue = Color(0xFF2D9CFF);
  static const Color red = Color(0xFFE53935);
  static const Color gold = Color(0xFFF4B942);
}
