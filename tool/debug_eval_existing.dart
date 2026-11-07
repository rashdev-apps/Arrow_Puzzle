import 'dart:convert';
import 'dart:io';
import 'package:arrow_puzzle/features/game/domain/arrow.dart';
import 'package:arrow_puzzle/features/game/domain/board.dart';
import 'package:arrow_puzzle/features/game/logic/difficulty_config.dart';

void main() {
  for (var id = 1; id <= 10; id++) {
    final file = File('assets/levels/level_${id.toString().padLeft(3, '0')}.json');
    if (!file.existsSync()) continue;
    final json = jsonDecode(file.readAsStringSync());
    final mask = (json['mask'] as List).cast<int>().map((m) => m == 1).toList();
    final rawArrows = (json['arrows'] as List).cast<Map<String, dynamic>>();
    final arrows = rawArrows.map(Arrow.fromJson).toList();
    final board = Board(rows: json['rows'], cols: json['cols'], mask: mask, arrows: arrows);
    final m = DifficultyConfig.evaluate(board);
    print('L$id: N=${m.arrowCount}, maxFreeWave=${m.maxFreeWave}, free0=${m.free0}, avgFree=${m.avgFree}');
  }
}

