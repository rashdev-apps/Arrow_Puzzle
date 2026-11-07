import 'package:arrow_puzzle/features/levels/data/level_repository.dart';

void main() async {
  final repo = LevelRepository();
  final sw = Stopwatch()..start();
  print('Generating daily level...');
  final level = await repo.loadDaily(DateTime.now());
  print('Generated daily in ${sw.elapsedMilliseconds}ms: ${level.board.arrows.length} arrows, solvable!');
}

