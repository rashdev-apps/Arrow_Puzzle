import 'package:equatable/equatable.dart';

import 'direction.dart';
import 'grid_cell.dart';

class Arrow extends Equatable {
  final String id;
  final List<GridCell> path; // from tail (index 0) to head (index last)
  final Direction dir; // direction of the last segment (head heading)

  const Arrow({
    required this.id,
    required this.path,
    required this.dir,
  });

  GridCell get head => path.last;
  GridCell get tail => path.first;
  int get length => path.length;
  Set<GridCell> get cells => path.toSet();

  /// Head run: number of consecutive straight cells leading into the head.
  int get headRun {
    if (path.length < 2) return path.length;
    var count = 1;
    final hDir = dir;
    for (var i = path.length - 2; i >= 0; i--) {
      final cur = path[i + 1];
      final prev = path[i];
      if (Direction.fromDelta(cur.row - prev.row, cur.col - prev.col) == hDir) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  /// Number of 90° bends in this arrow's polyline path.
  int get bendCount {
    if (path.length < 3) return 0;
    var turns = 0;
    for (var i = 0; i < path.length - 2; i++) {
      final d1 = Direction.fromDelta(
        path[i + 1].row - path[i].row,
        path[i + 1].col - path[i].col,
      );
      final d2 = Direction.fromDelta(
        path[i + 2].row - path[i + 1].row,
        path[i + 2].col - path[i + 1].col,
      );
      if (d1 != null && d2 != null && d1 != d2) {
        turns++;
      }
    }
    return turns;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path.map((c) => [c.row, c.col]).toList(),
        'dir': dir.code,
      };

  factory Arrow.fromJson(Map<String, dynamic> json) {
    final rawPath = (json['path'] as List).cast<List>();
    final path = rawPath
        .map((p) => GridCell(p[0] as int, p[1] as int))
        .toList(growable: false);

    Direction derivedDir;
    if (path.length >= 2) {
      final prev = path[path.length - 2];
      final head = path.last;
      derivedDir = Direction.fromDelta(head.row - prev.row, head.col - prev.col) ??
          (json['dir'] != null ? Direction.fromCode(json['dir'] as String) : Direction.up);
    } else {
      derivedDir = json['dir'] != null
          ? Direction.fromCode(json['dir'] as String)
          : Direction.up;
    }

    return Arrow(
      id: json['id'] as String,
      path: path,
      dir: derivedDir,
    );
  }

  @override
  List<Object?> get props => [id, path, dir];
}
