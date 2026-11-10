import 'dart:math';

import '../models/grid_cell.dart';
import 'silhouette_mask.dart';

class SilhouetteGenerator {
  const SilhouetteGenerator();

  SilhouetteMask generate({
    required int level,
    required int targetCells,
    required Random rng,
    SilhouetteFamily? forceFamily,
  }) {
    // Pick family:
    // Early levels (<= 10) use simple compact silhouettes
    final family = forceFamily ?? _pickFamilyForLevel(level, rng);

    // Compute bounding box dimensions with portrait aspect ratio (w/h between 0.65 and 0.95)
    final (rows, cols) = _calculateDimensions(targetCells, family, rng);

    var mask = List<bool>.filled(rows * cols, false);

    switch (family) {
      case SilhouetteFamily.notchedRectangle:
        mask = _genNotchedRectangle(rows, cols, rng);
        break;
      case SilhouetteFamily.mirrorSymmetric:
        mask = _genMirrorSymmetric(rows, cols, rng);
        break;
      case SilhouetteFamily.ringDonut:
        mask = _genRingDonut(rows, cols, rng);
        break;
      case SilhouetteFamily.staircasePyramid:
        mask = _genStaircasePyramid(rows, cols, rng);
        break;
      case SilhouetteFamily.tetrominoGiant:
        mask = _genTetrominoGiant(rows, cols, rng);
        break;
      case SilhouetteFamily.geometricPoly:
        mask = _genGeometricPoly(rows, cols, rng);
        break;
      case SilhouetteFamily.connectedIslands:
        mask = _genConnectedIslands(rows, cols, rng);
        break;
      case SilhouetteFamily.flowingCurves:
        mask = _genFlowingCurves(rows, cols, rng);
        break;
      case SilhouetteFamily.organicBlob:
      default:
        mask = _genOrganicBlob(rows, cols, rng);
        break;
    }

    // Clean up: remove 1-cell spikes, ensure min corridor width >= 2, and guarantee single connected component
    mask = _cleanAndEnsureConnectivity(mask, rows, cols);

    return SilhouetteMask(
      rows: rows,
      cols: cols,
      mask: mask,
      family: family,
    );
  }

  SilhouetteFamily _pickFamilyForLevel(int level, Random rng) {
    if (level <= 5) {
      // Very simple, friendly compact shapes
      final choices = [
        SilhouetteFamily.notchedRectangle,
        SilhouetteFamily.mirrorSymmetric,
        SilhouetteFamily.geometricPoly,
      ];
      return choices[rng.nextInt(choices.length)];
    } else if (level <= 15) {
      final choices = [
        SilhouetteFamily.notchedRectangle,
        SilhouetteFamily.mirrorSymmetric,
        SilhouetteFamily.staircasePyramid,
        SilhouetteFamily.tetrominoGiant,
        SilhouetteFamily.organicBlob,
      ];
      return choices[rng.nextInt(choices.length)];
    } else {
      // All 9 families unlocked
      final all = SilhouetteFamily.values;
      return all[rng.nextInt(all.length)];
    }
  }

  (int, int) _calculateDimensions(int targetCells, SilhouetteFamily family, Random rng) {
    // Fill ratio varies per family:
    // notched rect is dense (~85%), donut is sparser (~60%), islands (~55%)
    final fillRatio = switch (family) {
      SilhouetteFamily.notchedRectangle => 0.85,
      SilhouetteFamily.mirrorSymmetric => 0.78,
      SilhouetteFamily.geometricPoly => 0.75,
      SilhouetteFamily.organicBlob => 0.70,
      SilhouetteFamily.flowingCurves => 0.65,
      SilhouetteFamily.staircasePyramid => 0.68,
      SilhouetteFamily.tetrominoGiant => 0.62,
      SilhouetteFamily.ringDonut => 0.58,
      SilhouetteFamily.connectedIslands => 0.55,
    };

    final neededBoxCells = (targetCells / fillRatio).ceil();
    // Portrait aspect ratio: rows >= cols, width/height ~ 0.7 to 0.85
    var cols = (sqrt(neededBoxCells) * 0.88).floor().clamp(6, 40);
    var rows = (neededBoxCells / cols).ceil().clamp(cols, 55);

    return (rows, cols);
  }

  List<bool> _genNotchedRectangle(int rows, int cols, Random rng) {
    final mask = List<bool>.filled(rows * cols, true);
    // Cut 2 to 4 small notches along corners or edges (at least 2 cells deep, but keeping >=2 corridor width)
    final notches = 2 + rng.nextInt(3);
    for (var n = 0; n < notches; n++) {
      final w = 2 + rng.nextInt(max(2, cols ~/ 4));
      final h = 2 + rng.nextInt(max(2, rows ~/ 4));
      final corner = rng.nextInt(4); // 0: TL, 1: TR, 2: BL, 3: BR
      final rStart = (corner == 2 || corner == 3) ? rows - h : 0;
      final cStart = (corner == 1 || corner == 3) ? cols - w : 0;
      for (var r = rStart; r < rStart + h; r++) {
        for (var c = cStart; c < cStart + w; c++) {
          if (r >= 0 && r < rows && c >= 0 && c < cols) {
            mask[r * cols + c] = false;
          }
        }
      }
    }
    return mask;
  }

  List<bool> _genMirrorSymmetric(int rows, int cols, Random rng) {
    final mask = List<bool>.filled(rows * cols, false);
    final halfCols = (cols + 1) ~/ 2;

    // Grow random connected cluster on left half
    for (var r = 1; r < rows - 1; r++) {
      final span = 2 + rng.nextInt(halfCols - 2);
      for (var c = 0; c < span; c++) {
        mask[r * cols + c] = true;
      }
    }
    // Mirror to right half
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols ~/ 2; c++) {
        if (mask[r * cols + c]) {
          mask[r * cols + (cols - 1 - c)] = true;
        }
      }
    }
    return mask;
  }

  List<bool> _genRingDonut(int rows, int cols, Random rng) {
    final mask = List<bool>.filled(rows * cols, false);
    final cr = rows / 2.0;
    final cc = cols / 2.0;
    final radOuterR = rows * 0.46;
    final radOuterC = cols * 0.46;
    final radInnerR = rows * 0.18;
    final radInnerC = cols * 0.18;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final distOuter = pow((r - cr) / radOuterR, 2) + pow((c - cc) / radOuterC, 2);
        final distInner = pow((r - cr) / radInnerR, 2) + pow((c - cc) / radInnerC, 2);
        if (distOuter <= 1.0 && distInner >= 1.0) {
          mask[r * cols + c] = true;
        }
      }
    }
    return mask;
  }

  List<bool> _genStaircasePyramid(int rows, int cols, Random rng) {
    final mask = List<bool>.filled(rows * cols, false);
    final cc = cols ~/ 2;
    for (var r = 0; r < rows; r++) {
      final span = ((r + 2) / rows * (cols ~/ 2 + 1)).ceil().clamp(2, cols ~/ 2);
      for (var c = cc - span; c <= cc + span; c++) {
        if (c >= 0 && c < cols) {
          mask[r * cols + c] = true;
        }
      }
    }
    return mask;
  }

  List<bool> _genTetrominoGiant(int rows, int cols, Random rng) {
    final mask = List<bool>.filled(rows * cols, false);
    // Create giant Plus / T / L shape with thick arms (thickness >= 3)
    final armThickness = max(3, cols ~/ 3);
    final cMid = cols ~/ 2;
    final rMid = rows ~/ 2;

    // Vertical stem
    for (var r = 1; r < rows - 1; r++) {
      for (var c = cMid - armThickness ~/ 2; c <= cMid + armThickness ~/ 2; c++) {
        if (c >= 0 && c < cols) mask[r * cols + c] = true;
      }
    }
    // Horizontal cross
    for (var r = rMid - armThickness ~/ 2; r <= rMid + armThickness ~/ 2; r++) {
      for (var c = 1; c < cols - 1; c++) {
        if (r >= 0 && r < rows) mask[r * cols + c] = true;
      }
    }
    return mask;
  }

  List<bool> _genGeometricPoly(int rows, int cols, Random rng) {
    final mask = List<bool>.filled(rows * cols, false);
    // Diamond or Hexagon
    final cr = rows / 2.0;
    final cc = cols / 2.0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final dist = ((r - cr).abs() / (rows * 0.48)) + ((c - cc).abs() / (cols * 0.48));
        if (dist <= 1.05) {
          mask[r * cols + c] = true;
        }
      }
    }
    return mask;
  }

  List<bool> _genConnectedIslands(int rows, int cols, Random rng) {
    final mask = List<bool>.filled(rows * cols, false);
    // Island 1 (top)
    final h1 = (rows * 0.4).floor();
    for (var r = 1; r < h1; r++) {
      for (var c = 1; c < cols - 1; c++) {
        mask[r * cols + c] = true;
      }
    }
    // Island 2 (bottom)
    final h2Start = (rows * 0.6).floor();
    for (var r = h2Start; r < rows - 1; r++) {
      for (var c = 1; c < cols - 1; c++) {
        mask[r * cols + c] = true;
      }
    }
    // Corridor connecting them (width 2 or 3)
    final corridorCol = cols ~/ 2;
    for (var r = h1 - 1; r <= h2Start; r++) {
      mask[r * cols + corridorCol] = true;
      mask[r * cols + corridorCol + 1] = true;
    }
    return mask;
  }

  List<bool> _genFlowingCurves(int rows, int cols, Random rng) {
    final mask = List<bool>.filled(rows * cols, false);
    final cr = rows / 2.0;
    final cc = cols / 2.0;
    // S-curve / Wave pattern
    for (var r = 1; r < rows - 1; r++) {
      final waveOffset = sin((r / rows) * pi * 2) * (cols * 0.25);
      final centerC = (cc + waveOffset).round();
      final width = max(3, (cols * 0.38).round());
      for (var c = centerC - width ~/ 2; c <= centerC + width ~/ 2; c++) {
        if (c >= 0 && c < cols) {
          mask[r * cols + c] = true;
        }
      }
    }
    return mask;
  }

  List<bool> _genOrganicBlob(int rows, int cols, Random rng) {
    // Cellular automata smoothing around center
    final mask = List<bool>.filled(rows * cols, false);
    final cr = rows / 2.0;
    final cc = cols / 2.0;
    final maxDist = pow(rows * 0.44, 2) + pow(cols * 0.44, 2);

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final d = pow(r - cr, 2) + pow(c - cc, 2);
        final prob = 1.0 - (d / maxDist);
        if (rng.nextDouble() < prob * 1.3) {
          mask[r * cols + c] = true;
        }
      }
    }

    // 2 passes of cellular automata
    var current = mask;
    for (var pass = 0; pass < 2; pass++) {
      final next = List<bool>.filled(rows * cols, false);
      for (var r = 1; r < rows - 1; r++) {
        for (var c = 1; c < cols - 1; c++) {
          var neighbors = 0;
          for (var dr = -1; dr <= 1; dr++) {
            for (var dc = -1; dc <= 1; dc++) {
              if (current[(r + dr) * cols + (c + dc)]) neighbors++;
            }
          }
          next[r * cols + c] = neighbors >= 5;
        }
      }
      current = next;
    }
    return current;
  }

  List<bool> _cleanAndEnsureConnectivity(List<bool> mask, int rows, int cols) {
    // Flood fill largest connected component
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

    // Keep only largest component
    final clean = List<bool>.filled(rows * cols, false);
    for (final idx in largestComponent) {
      clean[idx] = true;
    }

    // Eliminate 1-cell spikes (cells with only 1 neighbor)
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final idx = r * cols + c;
        if (clean[idx]) {
          var orthoNeighbors = 0;
          for (final (dr, dc) in [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
            final nr = r + dr;
            final nc = c + dc;
            if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && clean[nr * cols + nc]) {
              orthoNeighbors++;
            }
          }
          if (orthoNeighbors <= 1) {
            clean[idx] = false;
          }
        }
      }
    }

    return clean;
  }
}

