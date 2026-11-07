import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:arrow_puzzle/features/game/domain/arrow.dart';
import 'package:arrow_puzzle/features/game/domain/board.dart';
import 'package:arrow_puzzle/features/game/logic/difficulty_config.dart';
import 'package:arrow_puzzle/features/game/logic/solver.dart';
import 'package:arrow_puzzle/features/game/domain/grid_cell.dart';
import 'package:arrow_puzzle/features/game/domain/direction.dart';

void main() {
  const solver = Solver();
  final file = File('assets/levels/level_001.json');
  final json = jsonDecode(file.readAsStringSync());
  final rows = json['rows'] as int;
  final cols = json['cols'] as int;
  final mask = (json['mask'] as List).cast<int>().map((m) => m == 1).toList();
  final rawArrows = (json['arrows'] as List).cast<Map<String, dynamic>>();
  final arrows = rawArrows.map(Arrow.fromJson).toList();
  final board = Board(rows: rows, cols: cols, mask: mask, arrows: arrows);

  // In level 1: 9 arrows are free at start!
  final initialFree = board.freeArrows(arrows.map((a) => a.id).toSet());
  print('Initial free (${initialFree.length}): ${initialFree.map((a) => a.id).toList()}');

  // If only 1 or 2 arrows are free at the start, that means the other 7 or 8 arrows must be BLOCKED!
  // Why were they not blocked?
  // Because their exit ray went straight off the board without hitting any other arrow!
  for (final fa in initialFree) {
    final ray = board.exitRay(fa);
    print('  ${fa.id} head: ${fa.head}, dir: ${fa.dir}, exitRay length: ${ray.length}');
  }
}

