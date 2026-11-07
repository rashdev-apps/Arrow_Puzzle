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
  final mask = (json['mask'] as List).cast<int>().map((m) => m == 1).toList();
  final rawArrows = (json['arrows'] as List).cast<Map<String, dynamic>>();
  final arrows = rawArrows.map(Arrow.fromJson).toList();
  final board = Board(rows: json['rows'], cols: json['cols'], mask: mask, arrows: arrows);

  // In level 1: arrows a15, a16, a18, a19, a20, a21, a22, a23, a24 are free!
  // Suppose we want ONLY ONE arrow to be free (say a24).
  // Then a15, a16, a18, a19, a20, a21, a22, a23 MUST BE BLOCKED!
  // If their exit ray goes off the board, why did it go off the board?
  // Because when they were placed, no arrow was placed in front of their heads!
}

