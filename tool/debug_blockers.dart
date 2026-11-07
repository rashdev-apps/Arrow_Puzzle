import 'dart:convert';
import 'dart:io';
import 'package:arrow_puzzle/features/game/domain/arrow.dart';
import 'package:arrow_puzzle/features/game/domain/board.dart';
import 'package:arrow_puzzle/features/game/logic/difficulty_config.dart';

void main() {
  final file = File('assets/levels/level_001.json');
  final json = jsonDecode(file.readAsStringSync());
  final mask = (json['mask'] as List).cast<int>().map((m) => m == 1).toList();
  final rawArrows = (json['arrows'] as List).cast<Map<String, dynamic>>();
  final arrows = rawArrows.map(Arrow.fromJson).toList();
  final board = Board(rows: json['rows'], cols: json['cols'], mask: mask, arrows: arrows);

  // Print arrows in placement order (which was reverse removal order)
  for (var i = 0; i < arrows.length; i++) {
    final a = arrows[i];
    final ray = board.exitRay(a);
    // Find who blocks a
    final blockers = <String>[];
    for (final c in ray) {
      final occArrow = board.occupancy[c];
      if (occArrow != null) blockers.add(occArrow.id);
    }
    print('$i: ${a.id} (dir ${a.dir}) blocked by: $blockers');
  }
}
