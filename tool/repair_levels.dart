import 'dart:convert';
import 'dart:io';

import 'package:arrow_puzzle/features/game/domain/arrow.dart';
import 'package:arrow_puzzle/features/game/domain/direction.dart';
import 'package:arrow_puzzle/features/game/domain/grid_cell.dart';

void main() {
  final dir = Directory('assets/levels');
  if (!dir.existsSync()) {
    print('assets/levels not found');
    return;
  }

  var fixedLevels = 0;
  var fixedArrows = 0;

  for (var id = 1; id <= 200; id++) {
    final file = File('${dir.path}/level_${id.toString().padLeft(3, '0')}.json');
    if (!file.existsSync()) continue;
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final rawArrows = (json['arrows'] as List).cast<Map<String, dynamic>>();
    var modified = false;

    for (var i = 0; i < rawArrows.length; i++) {
      final raw = rawArrows[i];
      final pathList = (raw['path'] as List).cast<List>();
      final path = pathList.map((p) => GridCell(p[0] as int, p[1] as int)).toList();
      final currentDir = DirectionX.fromCode(raw['dir'] as String);

      if (path.length >= 2) {
        final prev = path[path.length - 2];
        final head = path.last;
        final dr = head.row - prev.row;
        final dc = head.col - prev.col;
        Direction trueDir;
        if (dr == -1 && dc == 0) {
          trueDir = Direction.up;
        } else if (dr == 1 && dc == 0) {
          trueDir = Direction.down;
        } else if (dc == -1 && dr == 0) {
          trueDir = Direction.left;
        } else if (dc == 1 && dr == 0) {
          trueDir = Direction.right;
        } else {
          trueDir = currentDir;
        }

        if (currentDir != trueDir) {
          raw['dir'] = trueDir.code;
          fixedArrows++;
          modified = true;
        }
      }
    }

    if (modified) {
      fixedLevels++;
      file.writeAsStringSync(const JsonEncoder.withIndent(' ').convert(json));
    }
  }

  print('Repaired $fixedArrows mismatched arrows across $fixedLevels levels in assets/levels.');
}

