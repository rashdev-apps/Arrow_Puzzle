import 'package:equatable/equatable.dart';

import '../difficulty_config.dart';
import '../metrics/puzzle_metrics.dart';
import 'arrow.dart';
import 'board.dart';
import '../silhouette/silhouette_mask.dart';

class Level extends Equatable {
  final int id;
  final int seed;
  final Board board;
  final SilhouetteFamily silhouetteFamily;
  final List<String> solution;
  final double difficultyScore;
  final int? timeLimitSeconds;
  final int parMistakes;

  const Level({
    required this.id,
    required this.seed,
    required this.board,
    required this.silhouetteFamily,
    required this.solution,
    required this.difficultyScore,
    this.timeLimitSeconds,
    this.parMistakes = 0,
  });

  int get rows => board.rows;
  int get cols => board.cols;
  int get arrowCount => board.arrows.length;

  int get effectiveTimeLimitSeconds =>
      timeLimitSeconds ??
      (DifficultyConfig.computeTimeLimitSeconds(arrowCount, id) ?? 0);

  DifficultyTier get tier => DifficultyConfig.tierForLevel(id);

  Map<String, dynamic> toJson() {
    final maskRle = SilhouetteMask(
      rows: board.rows,
      cols: board.cols,
      mask: board.mask,
      family: silhouetteFamily,
    ).encodeRLE();

    return {
      'v': 2,
      'id': id,
      'seed': seed,
      'rows': board.rows,
      'cols': board.cols,
      'mask_rle': maskRle,
      'family': silhouetteFamily.name,
      'arrows': board.arrows.map((a) => a.toJson()).toList(),
      'solution': solution,
      'arrowCount': arrowCount,
      'tier': tier.label,
      'difficultyScore': difficultyScore,
      'timeLimit': timeLimitSeconds,
      'parMistakes': parMistakes,
    };
  }

  factory Level.fromJson(Map<String, dynamic> json) {
    final rows = json['rows'] as int;
    final cols = json['cols'] as int;
    final rawRle = (json['mask_rle'] as List).cast<int>();
    final mask = SilhouetteMask.decodeRLE(rows, cols, rawRle);

    final familyStr = json['family'] as String? ?? 'organicBlob';
    final family = SilhouetteFamily.values.firstWhere(
      (f) => f.name == familyStr,
      orElse: () => SilhouetteFamily.organicBlob,
    );

    final rawArrows = (json['arrows'] as List).cast<Map<String, dynamic>>();
    final arrows = rawArrows.map(Arrow.fromJson).toList();

    return Level(
      id: json['id'] as int,
      seed: json['seed'] as int? ?? json['id'] as int,
      board: Board(rows: rows, cols: cols, mask: mask, arrows: arrows),
      silhouetteFamily: family,
      solution: (json['solution'] as List).cast<String>(),
      difficultyScore: (json['difficultyScore'] as num).toDouble(),
      timeLimitSeconds: json['timeLimit'] as int?,
      parMistakes: json['parMistakes'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, seed, board, silhouetteFamily, solution];
}

