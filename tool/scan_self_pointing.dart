import 'dart:convert';
import 'dart:io';

import 'package:arrow_puzzle/features/game/domain/arrow.dart';
import 'package:arrow_puzzle/features/game/domain/grid_cell.dart';

void main() {
  final dir = Directory('assets/levels');
  var totalSelfBlocked = 0;
  final affectedLevels = <int>[];

  for (var id = 1; id <= 200; id++) {
    final file = File('${dir.path}/level_${id.toString().padLeft(3, '0')}.json');
    if (!file.existsSync()) continue;
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final rawArrows = (json['arrows'] as List).cast<Map<String, dynamic>>();
    final rows = json['rows'] as int;
    final cols = json['cols'] as int;

    var levelCount = 0;
    for (final raw in rawArrows) {
      final a = Arrow.fromJson(raw);
      final ownBody = a.path.sublist(0, a.path.length - 1).toSet();
      var c = a.head.shift(a.dir);
      var pointsToTail = false;
      while (c.inside(rows, cols)) {
        if (ownBody.contains(c)) {
          pointsToTail = true;
          break;
        }
        c = c.shift(a.dir);
      }
      if (pointsToTail) {
        levelCount++;
        totalSelfBlocked++;
      }
    }
    if (levelCount > 0) {
      affectedLevels.add(id);
    }
  }

  print('Total self-pointing arrows: $totalSelfBlocked across ${affectedLevels.length} levels');
}
