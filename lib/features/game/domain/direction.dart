import 'dart:math' as math;

/// Orthogonal grid direction. `up` decreases row, `right` increases col.
enum Direction { up, down, left, right }

extension DirectionX on Direction {
  int get dr => switch (this) {
        Direction.up => -1,
        Direction.down => 1,
        Direction.left => 0,
        Direction.right => 0,
      };

  int get dc => switch (this) {
        Direction.up => 0,
        Direction.down => 0,
        Direction.left => -1,
        Direction.right => 1,
      };

  Direction get opposite => switch (this) {
        Direction.up => Direction.down,
        Direction.down => Direction.up,
        Direction.left => Direction.right,
        Direction.right => Direction.left,
      };

  /// Angle in radians used to rotate an arrowhead that points [Direction.right]
  /// by default. Screen coords: x right, y down.
  double get angleRadians => switch (this) {
        Direction.right => 0.0,
        Direction.down => math.pi / 2,
        Direction.left => math.pi,
        Direction.up => -math.pi / 2,
      };

  String get code => switch (this) {
        Direction.up => 'U',
        Direction.down => 'D',
        Direction.left => 'L',
        Direction.right => 'R',
      };

  static Direction fromCode(String code) => switch (code) {
        'U' => Direction.up,
        'D' => Direction.down,
        'L' => Direction.left,
        _ => Direction.right,
      };

  static const List<Direction> orthogonal = [
    Direction.up,
    Direction.down,
    Direction.left,
    Direction.right,
  ];
}
