import 'dart:convert';
import 'dart:io';
import 'package:arrow_puzzle/features/game/domain/arrow.dart';
import 'package:arrow_puzzle/features/game/domain/board.dart';
import 'package:arrow_puzzle/features/game/logic/solver.dart';

void main() {
  const solver = Solver();
  for (var id = 6; id <= 15; id++) {
    final file = File('assets/levels/level_${id.toString().padLeft(3, '0')}.json');
    final json = jsonDecode(file.readAsStringSync());
    final mask = (json['mask'] as List).cast<int>().map((m) => m == 1).toList();
    final rawArrows = (json['arrows'] as List).cast<Map<String, dynamic>>();
    final arrows = rawArrows.map(Arrow.fromJson).toList();
    final board = Board(rows: json['rows'], cols: json['cols'], mask: mask, arrows: arrows);
    final solvable = solver.solvableByGreedy(board);
    print('Level $id solvable: $solvable');
  }
}

