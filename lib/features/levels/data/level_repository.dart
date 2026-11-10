import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../../engine/generator/level_generator.dart';
import '../../../engine/models/level.dart';

/// Loads pre-generated level JSON from assets, falling back to deterministic
/// runtime generation (via compute/Isolate for 301+ or missing files).
class LevelRepository {
  final Map<int, Level> _cache = {};

  static String _pathFor(int id) =>
      'assets/levels/level_${id.toString().padLeft(3, '0')}.json';

  Future<Level> load(int levelId) async {
    final cached = _cache[levelId];
    if (cached != null) return cached;

    Level level;
    try {
      final raw = await rootBundle.loadString(_pathFor(levelId));
      level = Level.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
    } catch (_) {
      level = await compute(_generateLevelInBackground, levelId);
    }
    _cache[levelId] = level;
    return level;
  }

  /// Daily challenge: selects a daily puzzle deterministically
  Future<Level> loadDaily(DateTime date) async {
    final key = dailyKey(date);
    final cached = _cache[key];
    if (cached != null) return cached;

    // Daily levels generated deterministically using daily date seed
    final level = LevelGenerator().generate(key, salt: 'arrowescape-daily');
    _cache[key] = level;
    return level;
  }

  static int dailyKey(DateTime date) =>
      date.year * 10000 + date.month * 100 + date.day;

  static String dailyKeyString(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

Level _generateLevelInBackground(int levelId) {
  return LevelGenerator().generate(levelId);
}
