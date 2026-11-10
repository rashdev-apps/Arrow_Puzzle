import 'package:equatable/equatable.dart';

import 'direction.dart';

class GridCell extends Equatable {
  final int row;
  final int col;

  const GridCell(this.row, this.col);

  GridCell shift(Direction dir) => GridCell(row + dir.dr, col + dir.dc);

  bool inside(int rows, int cols) =>
      row >= 0 && row < rows && col >= 0 && col < cols;

  int manhattan(GridCell other) =>
      (row - other.row).abs() + (col - other.col).abs();

  String encode() => '$row,$col';

  static GridCell decode(String s) {
    final idx = s.indexOf(',');
    return GridCell(
      int.parse(s.substring(0, idx)),
      int.parse(s.substring(idx + 1)),
    );
  }

  @override
  List<Object?> get props => [row, col];

  @override
  String toString() => '($row,$col)';
}
