import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'board.dart';
import 'grid_cell.dart';

enum SilhouetteFamily {
  organicBlob(1, 'Organic Blob'),
  mirrorSymmetric(2, 'Mirror Symmetric'),
  ringDonut(3, 'Ring Donut'),
  tetrominoGiant(4, 'Polyomino Structure'),
  geometricPoly(5, 'Geometric Polygon'),
  staircasePyramid(6, 'Staircase Pyramid'),
  connectedIslands(7, 'Connected Islands'),
  notchedRectangle(8, 'Notched Rectangle'),
  flowingCurves(9, 'Flowing Curves');

  final int id;
  final String label;
  const SilhouetteFamily(this.id, this.label);
}

class SilhouetteMask {
  final int rows;
  final int cols;
  final List<bool> mask; // row-major
  final SilhouetteFamily family;

  const SilhouetteMask({
    required this.rows,
    required this.cols,
    required this.mask,
    required this.family,
  });

  int get cellCount => mask.where((m) => m).length;
  bool isInside(int r, int c) => r >= 0 && r < rows && c >= 0 && c < cols && mask[r * cols + c];

  String get hash {
    final str = '$rows:$cols:${mask.map((m) => m ? '1' : '0').join()}';
    return md5.convert(utf8.encode(str)).toString().substring(0, 12);
  }

  /// Run-length encoding for compact JSON storage
  List<int> encodeRLE() {
    final rle = <int>[];
    if (mask.isEmpty) return rle;
    var current = mask.first;
    var count = 0;
    // first value indicates starting bit (0 or 1)
    rle.add(current ? 1 : 0);
    for (final bit in mask) {
      if (bit == current) {
        count++;
      } else {
        rle.add(count);
        current = bit;
        count = 1;
      }
    }
    rle.add(count);
    return rle;
  }

  static List<bool> decodeRLE(int rows, int cols, List<int> rle) {
    final mask = <bool>[];
    if (rle.isEmpty) return List<bool>.filled(rows * cols, false);
    var bit = rle[0] == 1;
    for (var i = 1; i < rle.length; i++) {
      final run = rle[i];
      for (var k = 0; k < run; k++) {
        mask.add(bit);
      }
      bit = !bit;
    }
    return mask;
  }
}

