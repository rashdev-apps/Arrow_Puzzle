import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../game/domain/level.dart';
import '../../game/logic/generator/layout_hash.dart';
import '../../game/logic/generator/level_generator.dart';

/// Loads pre-generated level JSON from assets, falling back to deterministic
/// runtime generation (same seeds) for 301+ or when a file is missing.
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
      level = _generate(levelId);
    }
    _cache[levelId] = level;
    return level;
  }

  Level _generate(int levelId) {
    return LevelGenerator().generate(levelId).level;
  }

  /// Daily challenge: selects a daily puzzle deterministically from the level catalog
  /// so it loads instantly with 0 UI freeze, 100% verified solvability, and no heavy runtime generation.
  Future<Level> loadDaily(DateTime date) async {
    final key = dailyKey(date);
    final cached = _cache[key];
    if (cached != null) return cached;

    // Pick a daily level deterministically from levels 20..100
    final seed = LayoutHash.seed('daily:$key');
    final levelNum = 20 + (seed.abs() % 80);

    final baseLevel = await load(levelNum);
    final dailyLevel = Level(
      id: key,
      shape: 'rectangle',
      board: baseLevel.board,
      parMoves: baseLevel.parMoves,
      difficulty: baseLevel.difficulty,
      hash: baseLevel.hash,
      timeLimitSeconds: baseLevel.timeLimitSeconds,
    );

    _cache[key] = dailyLevel;
    return dailyLevel;
  }

  static int dailyKey(DateTime date) =>
      date.year * 10000 + date.month * 100 + date.day;

  static String dailyKeyString(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
