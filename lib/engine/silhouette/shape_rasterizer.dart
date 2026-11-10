import 'dart:math';
import 'shape_library.dart';
import 'silhouette_mask.dart';

class ShapeRasterizer {
  const ShapeRasterizer();

  /// Converts a [ShapeTemplate] vector polygon into a 2D occupancy grid
  SilhouetteMask rasterize({
    required ShapeTemplate shape,
    required int rows,
    required int cols,
  }) {
    final mask = List<bool>.filled(rows * cols, false);

    for (var r = 0; r < rows; r++) {
      final ny = (r + 0.5) / rows;
      for (var c = 0; c < cols; c++) {
        final nx = (c + 0.5) / cols;
        if (shape.contains(nx, ny)) {
          mask[r * cols + c] = true;
        }
      }
    }

    // Clean up isolated 1-cell noise and ensure connectivity
    final clean = _ensureConnectedComponent(mask, rows, cols);

    return SilhouetteMask(
      rows: rows,
      cols: cols,
      mask: clean,
      family: SilhouetteFamily.organicBlob,
    );
  }

  List<bool> _ensureConnectedComponent(List<bool> mask, int rows, int cols) {
    final visited = List<bool>.filled(rows * cols, false);
    var largestComponent = <int>[];

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final idx = r * cols + c;
        if (mask[idx] && !visited[idx]) {
          final comp = <int>[];
          final q = [idx];
          visited[idx] = true;
          while (q.isNotEmpty) {
            final curr = q.removeLast();
            comp.add(curr);
            final cr = curr ~/ cols;
            final cc = curr % cols;

            for (final (dr, dc) in [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
              final nr = cr + dr;
              final nc = cc + dc;
              if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
                final nIdx = nr * cols + nc;
                if (mask[nIdx] && !visited[nIdx]) {
                  visited[nIdx] = true;
                  q.add(nIdx);
                }
              }
            }
          }
          if (comp.length > largestComponent.length) {
            largestComponent = comp;
          }
        }
      }
    }

    final clean = List<bool>.filled(rows * cols, false);
    for (final idx in largestComponent) {
      clean[idx] = true;
    }
    return clean;
  }
}
