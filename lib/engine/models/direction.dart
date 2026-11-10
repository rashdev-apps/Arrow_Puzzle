enum Direction {
  up(-1, 0, 'U'),
  down(1, 0, 'D'),
  left(0, -1, 'L'),
  right(0, 1, 'R');

  final int dr;
  final int dc;
  final String code;

  const Direction(this.dr, this.dc, this.code);

  Direction get opposite => switch (this) {
        Direction.up => Direction.down,
        Direction.down => Direction.up,
        Direction.left => Direction.right,
        Direction.right => Direction.left,
      };

  bool get isVertical => this == Direction.up || this == Direction.down;
  bool get isHorizontal => this == Direction.left || this == Direction.right;

  static Direction fromCode(String code) => switch (code.toUpperCase()) {
        'U' => Direction.up,
        'D' => Direction.down,
        'L' => Direction.left,
        'R' => Direction.right,
        _ => throw ArgumentError('Unknown direction code: $code'),
      };

  static Direction? fromDelta(int dr, int dc) {
    if (dr == -1 && dc == 0) return Direction.up;
    if (dr == 1 && dc == 0) return Direction.down;
    if (dc == -1 && dr == 0) return Direction.left;
    if (dc == 1 && dr == 0) return Direction.right;
    return null;
  }

  static const List<Direction> orthogonal = [
    Direction.up,
    Direction.down,
    Direction.left,
    Direction.right,
  ];
}
