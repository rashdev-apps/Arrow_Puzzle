import '../../domain/grid_cell.dart';

/// A silhouette shape: playable cells drawn as ASCII art where `#` is a
/// playable cell and anything else is empty. Shapes can also be loaded from
/// JSON asset files (see [ShapeMask.fromRows]); the built-ins below ship at
/// launch and new ones can be added without code changes.
class ShapeMask {
  final String name;
  final List<String> art;

  const ShapeMask(this.name, this.art);

  factory ShapeMask.fromRows(String name, List<List<int>> rows) => ShapeMask(
        name,
        rows.map((r) => r.map((v) => v == 1 ? '#' : '.').join()).toList(),
      );

  int get baseRows => art.length;

  int get baseCols {
    var max = 0;
    for (final row in art) {
      if (row.length > max) max = row.length;
    }
    return max;
  }

  /// Build a rows x cols boolean mask at the shape's native resolution.
  List<bool> toMask() {
    final cols = baseCols;
    final mask = List<bool>.filled(art.length * cols, false);
    for (var r = 0; r < art.length; r++) {
      final row = art[r].padRight(cols, '.');
      for (var c = 0; c < cols; c++) {
        mask[r * cols + c] = row[c] == '#';
      }
    }
    return mask;
  }

  List<GridCell> get cells {
    final cols = baseCols;
    final result = <GridCell>[];
    for (var r = 0; r < art.length; r++) {
      final row = art[r].padRight(cols, '.');
      for (var c = 0; c < cols; c++) {
        if (row[c] == '#') result.add(GridCell(r, c));
      }
    }
    return result;
  }

  /// Nearest-neighbour resample to [targetRows] x [targetCols], preserving
  /// the silhouette at a different grid resolution.
  ShapeMask resized(int targetRows, int targetCols) {
    final srcCols = baseCols;
    final rows = List<String>.generate(targetRows, (r) {
      final srcR = (r * baseRows / targetRows).floor();
      final srcRow = art[srcR].padRight(srcCols, '.');
      return List<String>.generate(targetCols, (c) {
        final srcC = (c * srcCols / targetCols).floor();
        return srcRow[srcC];
      }).join();
    });
    return ShapeMask(name, rows);
  }
}

/// Built-in silhouette library. Order matters: chapters cycle through it.
const List<ShapeMask> kBuiltinShapes = [
  ShapeMask('square', [
    '#######',
    '#######',
    '#######',
    '#######',
    '#######',
    '#######',
    '#######',
  ]),
  ShapeMask('trophy', [
    '.##...##.',
    '#########',
    '#########',
    '.#######.',
    '..#####..',
    '...###...',
    '...###...',
    '...###...',
    '...##....',
    '..####...',
    '.######..',
  ]),
  ShapeMask('anchor', [
    '...###...',
    '...###...',
    '.########',
    '.########',
    '...###...',
    '...###...',
    '...###...',
    '...###...',
    '#..###..#',
    '##.###.##',
    '.#######.',
    '..#####..',
    '...###...',
  ]),
  ShapeMask('dog', [
    '.##.....###.',
    '############',
    '############',
    '.##########.',
    '..###..###..',
    '..########..',
    '.##########.',
    '.####..####.',
    '##........##',
  ]),
  ShapeMask('heart', [
    '.###.###.',
    '#########',
    '#########',
    '#########',
    '.#######.',
    '..#####..',
    '...###...',
    '....#....',
  ]),
  ShapeMask('star', [
    '.....#.....',
    '....###....',
    '###########',
    '.#########.',
    '..#######..',
    '..#######..',
    '.#########.',
    '...#####...',
    '..#######..',
    '.#########.',
  ]),
  ShapeMask('house', [
    '....#....',
    '...###...',
    '..#####..',
    '.#######.',
    '#########',
    '#########',
    '.##...##.',
    '.##...##.',
    '.##...##.',
    '.#######.',
  ]),
  ShapeMask('tree', [
    '....#....',
    '..#####..',
    '.#######.',
    '#########',
    '..#####..',
    '.#######.',
    '#########',
    '.#######.',
    '...###...',
    '...###...',
    '..#####..',
  ]),
  ShapeMask('fish', [
    '.......##..',
    '...########',
    '###########',
    '###########',
    '...########',
    '.......##..',
  ]),
  ShapeMask('key', [
    '.#######...',
    '#########..',
    '#########..',
    '.#######...',
    '....##.....',
    '....##.....',
    '....########',
    '....##.....',
    '...###.....',
  ]),
  ShapeMask('cat', [
    '##.....##',
    '###...###',
    '#########',
    '#########',
    '.#######.',
    '#########',
    '.#######.',
    '..#####..',
    '.##...##.',
  ]),
  ShapeMask('rocket', [
    '...#...',
    '..###..',
    '.#####.',
    '.#####.',
    '#######',
    '#######',
    '#######',
    '#######',
    '.#####.',
    '.#####.',
    '..###..',
    '.##.##.',
    '##...##',
  ]),
  ShapeMask('crown', [
    '#...#...#...#',
    '##..#..#..##',
    '#############',
    '#############',
    '.###########.',
    '.###########.',
  ]),
  ShapeMask('flower', [
    '..#####..',
    '.#######.',
    '..#####..',
    '#########',
    '#########',
    '..#####..',
    '.#######.',
    '..#####..',
    '...###...',
    '...###...',
    '..#####..',
  ]),
  ShapeMask('butterfly', [
    '.##.....##.',
    '####...####',
    '###########',
    '.#########.',
    '..#######..',
    '..#######..',
    '.#########.',
    '####...####',
  ]),
  ShapeMask('moon', [
    '...####',
    '..#####',
    '.######',
    '.######',
    '#######',
    '#######',
    '#######',
    '.######',
    '.######',
    '..#####',
    '...####',
  ]),
  ShapeMask('duck', [
    '......###..',
    '......####.',
    '.#########.',
    '###########',
    '.#########.',
    '..#######..',
    '..##..##...',
  ]),
  ShapeMask('castle', [
    '#...#...#..#',
    '##..#...#..#',
    '############',
    '############',
    '#.###.###..#',
    '#.###.###..#',
    '############',
  ]),
];

ShapeMask shapeByName(String name) =>
    kBuiltinShapes.firstWhere((s) => s.name == name,
        orElse: () => kBuiltinShapes.first);
