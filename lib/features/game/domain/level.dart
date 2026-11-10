import 'package:equatable/equatable.dart';

import '../logic/difficulty_config.dart';
import 'arrow.dart';
import 'board.dart';

/// A playable level: a shaped board plus precomputed metadata.
class Level extends Equatable {
  final int id;
  final String shape;
  final Board board;

  /// Canonical solution length (= number of arrows).
  final int parMoves;

  /// Generator-computed difficulty score (higher = harder).
  final double difficulty;

  /// Canonical layout hash used for the uniqueness guarantee.
  final String hash;

  /// Time limit in seconds for countdown timer.
  final int? timeLimitSeconds;

  const Level({
    required this.id,
    this.shape = 'rectangle',
    required this.board,
    required this.parMoves,
    required this.difficulty,
    required this.hash,
    this.timeLimitSeconds,
  });

  int get rows => board.rows;
  int get cols => board.cols;
  int get arrowCount => board.arrows.length;

  int get effectiveTimeLimitSeconds =>
      timeLimitSeconds ??
      (DifficultyConfig.computeTimeLimitSeconds(arrowCount, id) ?? 0);

  Map<String, dynamic> toJson() => {
        'id': id,
        'shape': shape,
        'rows': board.rows,
        'cols': board.cols,
        'mask': board.mask.map((m) => m ? 1 : 0).toList(),
        'arrows': board.arrows.map((a) => a.toJson()).toList(),
        'par_moves': parMoves,
        'difficulty': difficulty,
        'hash': hash,
        'time_limit_seconds': effectiveTimeLimitSeconds,
      };

  factory Level.fromJson(Map<String, dynamic> json) {
    final rows = json['rows'] as int;
    final cols = json['cols'] as int;
    final mask = (json['mask'] as List)
        .map((m) => (m as int) == 1)
        .toList(growable: false);
    final arrows = (json['arrows'] as List)
        .map((a) => Arrow.fromJson((a as Map).cast<String, dynamic>()))
        .toList(growable: false);
    return Level(
      id: json['id'] as int,
      shape: (json['shape'] as String?) ?? 'rectangle',
      board: Board(rows: rows, cols: cols, mask: mask, arrows: arrows),
      parMoves: json['par_moves'] as int,
      difficulty: (json['difficulty'] as num).toDouble(),
      hash: json['hash'] as String,
      timeLimitSeconds: json['time_limit_seconds'] as int?,
    );
  }

  @override
  List<Object?> get props =>
      [id, shape, board, parMoves, difficulty, hash, timeLimitSeconds];
}
