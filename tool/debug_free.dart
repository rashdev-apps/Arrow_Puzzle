import 'dart:convert';
import 'dart:io';

import 'package:arrow_puzzle/features/game/domain/arrow.dart';
import 'package:arrow_puzzle/features/game/domain/board.dart';

void main() {
  final file = File('assets/levels/level_001.json');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final rows = json['rows'] as int;
  final cols = json['cols'] as int;
  final mask = (json['mask'] as List).cast<int>().map((m) => m == 1).toList();
  final arrows = (json['arrows'] as List).cast<Map<String, dynamic>>().map(Arrow.fromJson).toList();
  final board = Board(rows: rows, cols: cols, mask: mask, arrows: arrows);
  final free = board.freeArrows(arrows.map((a) => a.id).toSet());
  print('Total arrows: ${arrows.length}');
  print('Free at start: ${free.length}');
  for (final fa in free) {
    print('Arrow ${fa.id}: head=${fa.head}, dir=${fa.dir}, pathLen=${fa.length}, exitRay=${board.exitRay(fa)}');
  }
}

