import 'package:equatable/equatable.dart';

import 'direction.dart';

/// A cell on the board grid. `row` grows downward, `col` grows rightward.
class GridCell extends Equatable implements Comparable<GridCell> {
  final int row;
  final int col;

  const GridCell(this.row, this.col);

  GridCell shift(Direction d) => GridCell(row + d.dr, col + d.dc);

  bool inside(int rows, int cols) =>
      row >= 0 && row < rows && col >= 0 && col < cols;

  String encode() => '$row,$col';

  static GridCell decode(String s) {
    final parts = s.split(',');
    return GridCell(int.parse(parts[0]), int.parse(parts[1]));
  }

  @override
  List<Object?> get props => [row, col];

  @override
  int compareTo(GridCell other) =>
      row != other.row ? row.compareTo(other.row) : col.compareTo(other.col);

  @override
  String toString() => '($row,$col)';
}
