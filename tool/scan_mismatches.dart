import 'dart:convert';
import 'dart:io';

import 'package:arrow_puzzle/features/game/domain/arrow.dart';
import 'package:arrow_puzzle/features/game/domain/direction.dart';

void main() {
  final dir = Directory('assets/levels');
  if (!dir.existsSync()) {
    print('assets/levels not found');
    return;
  }

  var totalLevels = 0;
  var totalArrows = 0;
  var mismatchedArrows = 0;
  final mismatchedLevels = <int>[];

  for (var id = 1; id <= 200; id++) {
    final file = File('${dir.path}/level_${id.toString().padLeft(3, '0')}.json');
    if (!file.existsSync()) continue;
    totalLevels++;
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final rawArrows = (json['arrows'] as List).cast<Map<String, dynamic>>();
    var levelHasMismatch = false;

    for (final raw in rawArrows) {
      final arrow = Arrow.fromJson(raw);
      totalArrows++;
      if (arrow.path.length < 2) continue;
      final prev = arrow.path[arrow.path.length - 2];
      final last = arrow.path.last;
      final dr = last.row - prev.row;
      final dc = last.col - prev.col;
      Direction expectedDir;
      if (dr == -1 && dc == 0) {
        expectedDir = Direction.up;
      } else if (dr == 1 && dc == 0) {
        expectedDir = Direction.down;
      } else if (dc == -1 && dr == 0) {
        expectedDir = Direction.left;
      } else if (dc == 1 && dr == 0) {
        expectedDir = Direction.right;
      } else {
        expectedDir = arrow.dir; // non-orthogonal?
      }

      if (arrow.dir != expectedDir) {
        mismatchedArrows++;
        levelHasMismatch = true;
      }
    }
    if (levelHasMismatch) mismatchedLevels.add(id);
  }

  print('Checked $totalLevels levels, $totalArrows arrows.');
  print('Mismatched arrows: $mismatchedArrows in ${mismatchedLevels.length} levels.');
  if (mismatchedLevels.isNotEmpty) {
    print('First 10 mismatched levels: ${mismatchedLevels.take(10).toList()}');
  }
}

