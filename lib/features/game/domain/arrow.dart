import 'package:equatable/equatable.dart';

import 'direction.dart';
import 'grid_cell.dart';

/// A snake-like polyline of orthogonal segments living on grid cells, with a
/// triangular arrowhead at one end. [path] runs from tail to head and
/// [dir] is the exit direction the head points at (last segment direction).
class Arrow extends Equatable {
  final String id;
  final List<GridCell> path;
  final Direction dir;

  const Arrow({required this.id, required this.path, required this.dir});

  GridCell get head => path.last;
  GridCell get tail => path.first;
  int get length => path.length;

  Set<GridCell> get cells => path.toSet();

  /// Manhattan distance covered by the polyline (number of steps).
  int get segmentCount => path.length - 1;

  String encodePath() =>
      '${dir.code}:${path.map((c) => c.encode()).join(';')}';

  static Arrow decode({required String id, required String encoded}) {
    final sep = encoded.indexOf(':');
    final dir = DirectionX.fromCode(encoded.substring(0, sep));
    final cells = encoded
        .substring(sep + 1)
        .split(';')
        .map(GridCell.decode)
        .toList(growable: false);
    return Arrow(id: id, path: cells, dir: dir);
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
    final dir = DirectionX.fromCode(json['dir'] as String);

    if (path.length >= 2) {
      final prev = path[path.length - 2];
      final head = path.last;
      final dr = head.row - prev.row;
      final dc = head.col - prev.col;
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
        expectedDir = dir;
      }
      assert(
        dir == expectedDir,
        'Arrow ${json['id']} dir $dir does not match path segment from $prev to $head ($expectedDir)',
      );
    }

    return Arrow(
      id: json['id'] as String,
      path: path,
      dir: dir,
    );
  }

  @override
  List<Object?> get props => [id, path, dir];
}
