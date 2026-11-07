import 'dart:convert';
import 'dart:io';

import 'package:arrow_puzzle/features/game/domain/arrow.dart';
import 'package:arrow_puzzle/features/game/domain/direction.dart';

void main() {
  for (var id = 1; id <= 5; id++) {
    final file = File('assets/levels/level_${id.toString().padLeft(3, '0')}.json');
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final rawArrows = (json['arrows'] as List).cast<Map<String, dynamic>>();
    var mismatches = 0;
    for (final raw in rawArrows) {
      final a = Arrow.fromJson(raw);
      final prev = a.path[a.path.length - 2];
      final head = a.path.last;
      final dr = head.row - prev.row;
      final dc = head.col - prev.col;
      Direction expected;
      if (dr == -1) expected = Direction.up;
      else if (dr == 1) expected = Direction.down;
      else if (dc == -1) expected = Direction.left;
      else expected = Direction.right;
      if (a.dir != expected) mismatches++;
    }
    print('Level $id mismatches: $mismatches / ${rawArrows.length}');
  }
}

