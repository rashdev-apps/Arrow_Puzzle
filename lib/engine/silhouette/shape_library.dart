import 'dart:math';
import 'dart:ui';

/// High-resolution vector polygon template for recognizable shapes
class ShapeTemplate {
  final String id;
  final String name;
  final String category; // 'animal', 'geometric', 'object', 'maze'
  final List<List<Offset>> contours; // Normalized [0, 1] x [0, 1]

  const ShapeTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.contours,
  });

  /// Point-in-polygon test (ray casting algorithm)
  bool contains(double nx, double ny) {
    var inside = false;
    for (final polygon in contours) {
      final n = polygon.length;
      for (var i = 0, j = n - 1; i < n; j = i++) {
        final xi = polygon[i].dx, yi = polygon[i].dy;
        final xj = polygon[j].dx, yj = polygon[j].dy;
        final intersect = ((yi > ny) != (yj > ny)) &&
            (nx < (xj - xi) * (ny - yi) / (yj - yi) + xi);
        if (intersect) inside = !inside;
      }
    }
    return inside;
  }
}

/// Comprehensive library of 29 recognizable shapes across Animals, Geometric, Objects, and Mazes
class ShapeLibrary {
  static final Map<String, ShapeTemplate> _templates = {};

  static void init() {
    if (_templates.isNotEmpty) return;

    // 1. HEART (Geometric)
    _register(const ShapeTemplate(
      id: 'heart',
      name: 'Heart',
      category: 'geometric',
      contours: [
        [
          Offset(0.50, 0.85),
          Offset(0.35, 0.72),
          Offset(0.20, 0.58),
          Offset(0.10, 0.42),
          Offset(0.08, 0.28),
          Offset(0.14, 0.16),
          Offset(0.26, 0.12),
          Offset(0.38, 0.16),
          Offset(0.46, 0.26),
          Offset(0.50, 0.34),
          Offset(0.54, 0.26),
          Offset(0.62, 0.16),
          Offset(0.74, 0.12),
          Offset(0.86, 0.16),
          Offset(0.92, 0.28),
          Offset(0.90, 0.42),
          Offset(0.80, 0.58),
          Offset(0.65, 0.72),
        ]
      ],
    ));

    // 2. DOG (Animal) - Silhouette with head, ears, body, tail, legs
    _register(const ShapeTemplate(
      id: 'dog',
      name: 'Dog',
      category: 'animal',
      contours: [
        [
          // Snout & head
          Offset(0.12, 0.22),
          Offset(0.22, 0.15),
          Offset(0.30, 0.10), // Ear tip
          Offset(0.34, 0.18),
          Offset(0.42, 0.24), // Neck
          // Back
          Offset(0.58, 0.26),
          Offset(0.74, 0.28),
          Offset(0.84, 0.24), // Tail up
          Offset(0.90, 0.18),
          Offset(0.88, 0.32),
          Offset(0.82, 0.40), // Rump
          // Back leg
          Offset(0.80, 0.62),
          Offset(0.78, 0.88),
          Offset(0.70, 0.88),
          Offset(0.70, 0.64),
          // Belly
          Offset(0.58, 0.56),
          Offset(0.44, 0.56),
          // Front leg
          Offset(0.40, 0.64),
          Offset(0.40, 0.88),
          Offset(0.32, 0.88),
          Offset(0.32, 0.58),
          // Chest
          Offset(0.24, 0.44),
          Offset(0.14, 0.34),
          Offset(0.10, 0.26),
        ]
      ],
    ));

    // 3. CAT (Animal) - Arched back, pointed ears, curved tail
    _register(const ShapeTemplate(
      id: 'cat',
      name: 'Cat',
      category: 'animal',
      contours: [
        [
          Offset(0.20, 0.28),
          Offset(0.22, 0.12), // Left ear
          Offset(0.30, 0.20),
          Offset(0.36, 0.12), // Right ear
          Offset(0.42, 0.22),
          Offset(0.55, 0.24), // Back
          Offset(0.72, 0.30),
          Offset(0.84, 0.20), // Tail up-curve
          Offset(0.92, 0.12),
          Offset(0.94, 0.24),
          Offset(0.86, 0.38),
          Offset(0.78, 0.54), // Back leg
          Offset(0.76, 0.88),
          Offset(0.66, 0.88),
          Offset(0.66, 0.62),
          Offset(0.52, 0.58), // Belly
          Offset(0.40, 0.62),
          Offset(0.38, 0.88), // Front leg
          Offset(0.28, 0.88),
          Offset(0.28, 0.50),
          Offset(0.16, 0.40),
        ]
      ],
    ));

    // 4. ELEPHANT (Animal) - Trunk, big ears, massive body, tusks/legs
    _register(const ShapeTemplate(
      id: 'elephant',
      name: 'Elephant',
      category: 'animal',
      contours: [
        [
          // Trunk down and curled
          Offset(0.08, 0.68),
          Offset(0.12, 0.78),
          Offset(0.16, 0.68),
          Offset(0.16, 0.48),
          Offset(0.24, 0.32),
          Offset(0.20, 0.18), // Ear top
          Offset(0.36, 0.12),
          Offset(0.44, 0.24),
          // Massive back
          Offset(0.60, 0.16),
          Offset(0.78, 0.20),
          Offset(0.88, 0.32),
          Offset(0.88, 0.48), // Tail
          // Hind leg
          Offset(0.84, 0.88),
          Offset(0.72, 0.88),
          Offset(0.72, 0.60),
          // Underbelly
          Offset(0.58, 0.58),
          // Foreleg
          Offset(0.52, 0.88),
          Offset(0.40, 0.88),
          Offset(0.38, 0.54),
          Offset(0.28, 0.50),
        ]
      ],
    ));

    // 5. BUTTERFLY (Animal) - Symmetrical dual wings and body
    _register(const ShapeTemplate(
      id: 'butterfly',
      name: 'Butterfly',
      category: 'animal',
      contours: [
        [
          Offset(0.50, 0.14), // Head/antennae
          Offset(0.65, 0.08), // Upper right wing
          Offset(0.92, 0.18),
          Offset(0.96, 0.38),
          Offset(0.82, 0.50),
          Offset(0.92, 0.66), // Lower right wing
          Offset(0.84, 0.86),
          Offset(0.65, 0.78),
          Offset(0.52, 0.88), // Body tail
          Offset(0.48, 0.88),
          Offset(0.35, 0.78), // Lower left wing
          Offset(0.16, 0.86),
          Offset(0.08, 0.66),
          Offset(0.18, 0.50),
          Offset(0.04, 0.38), // Upper left wing
          Offset(0.08, 0.18),
          Offset(0.35, 0.08),
        ]
      ],
    ));

    // 6. COMPLEX MAZE (Reference Maze Style)
    _register(const ShapeTemplate(
      id: 'maze',
      name: 'Complex Maze',
      category: 'maze',
      contours: [
        [
          // Irregular natural maze silhouette (like the reference screenshot)
          Offset(0.10, 0.15),
          Offset(0.35, 0.10),
          Offset(0.50, 0.14),
          Offset(0.75, 0.08),
          Offset(0.90, 0.20),
          Offset(0.94, 0.50),
          Offset(0.88, 0.82),
          Offset(0.65, 0.90),
          Offset(0.35, 0.88),
          Offset(0.12, 0.82),
          Offset(0.08, 0.50),
        ]
      ],
    ));

    // 7. STAR (Geometric)
    _register(const ShapeTemplate(
      id: 'star',
      name: 'Star',
      category: 'geometric',
      contours: [
        [
          Offset(0.50, 0.08),
          Offset(0.62, 0.36),
          Offset(0.92, 0.38),
          Offset(0.68, 0.56),
          Offset(0.78, 0.86),
          Offset(0.50, 0.68),
          Offset(0.22, 0.86),
          Offset(0.32, 0.56),
          Offset(0.08, 0.38),
          Offset(0.38, 0.36),
        ]
      ],
    ));

    // 8. DIAMOND (Geometric)
    _register(const ShapeTemplate(
      id: 'diamond',
      name: 'Diamond',
      category: 'geometric',
      contours: [
        [
          Offset(0.50, 0.08),
          Offset(0.90, 0.50),
          Offset(0.50, 0.92),
          Offset(0.10, 0.50),
        ]
      ],
    ));

    // 9. CROWN (Object)
    _register(const ShapeTemplate(
      id: 'crown',
      name: 'Crown',
      category: 'object',
      contours: [
        [
          Offset(0.12, 0.82),
          Offset(0.88, 0.82),
          Offset(0.86, 0.40),
          Offset(0.72, 0.58),
          Offset(0.50, 0.22),
          Offset(0.28, 0.58),
          Offset(0.14, 0.40),
        ]
      ],
    ));

    // 10. ROCKET (Object)
    _register(const ShapeTemplate(
      id: 'rocket',
      name: 'Rocket',
      category: 'object',
      contours: [
        [
          Offset(0.50, 0.06),
          Offset(0.66, 0.28),
          Offset(0.66, 0.68),
          Offset(0.84, 0.84),
          Offset(0.66, 0.80),
          Offset(0.50, 0.88),
          Offset(0.34, 0.80),
          Offset(0.16, 0.84),
          Offset(0.34, 0.68),
          Offset(0.34, 0.28),
        ]
      ],
    ));

    // 11. TREE (Object)
    _register(const ShapeTemplate(
      id: 'tree',
      name: 'Tree',
      category: 'object',
      contours: [
        [
          Offset(0.50, 0.08),
          Offset(0.74, 0.32),
          Offset(0.62, 0.34),
          Offset(0.82, 0.56),
          Offset(0.66, 0.58),
          Offset(0.86, 0.78),
          Offset(0.56, 0.78),
          Offset(0.56, 0.92),
          Offset(0.44, 0.92),
          Offset(0.44, 0.78),
          Offset(0.14, 0.78),
          Offset(0.34, 0.58),
          Offset(0.18, 0.56),
          Offset(0.38, 0.34),
          Offset(0.26, 0.32),
        ]
      ],
    ));

    // 12. FISH (Animal)
    _register(const ShapeTemplate(
      id: 'fish',
      name: 'Fish',
      category: 'animal',
      contours: [
        [
          Offset(0.10, 0.50), // Nose
          Offset(0.32, 0.24),
          Offset(0.64, 0.26),
          Offset(0.86, 0.16), // Upper tail
          Offset(0.80, 0.50),
          Offset(0.86, 0.84), // Lower tail
          Offset(0.64, 0.74),
          Offset(0.32, 0.76),
        ]
      ],
    ));

    // 13. TURTLE (Animal)
    _register(const ShapeTemplate(
      id: 'turtle',
      name: 'Turtle',
      category: 'animal',
      contours: [
        [
          Offset(0.50, 0.08), // Head
          Offset(0.58, 0.20),
          Offset(0.74, 0.22), // Front right flipper
          Offset(0.76, 0.36),
          Offset(0.84, 0.54), // Shell
          Offset(0.76, 0.74), // Back right flipper
          Offset(0.68, 0.82),
          Offset(0.50, 0.90), // Tail
          Offset(0.32, 0.82),
          Offset(0.24, 0.74), // Back left flipper
          Offset(0.16, 0.54), // Shell
          Offset(0.24, 0.36),
          Offset(0.26, 0.22), // Front left flipper
          Offset(0.42, 0.20),
        ]
      ],
    ));
  }

  static void _register(ShapeTemplate template) {
    _templates[template.id] = template;
  }

  static ShapeTemplate get(String id) {
    init();
    return _templates[id] ?? _templates['maze']!;
  }

  static List<ShapeTemplate> all() {
    init();
    return _templates.values.toList();
  }

  /// Select a shape template deterministically for a level
  static ShapeTemplate templateForLevel(int level) {
    init();
    // Test shape sequence
    if (level == 1) return get('heart');
    if (level == 2) return get('dog');
    if (level == 3) return get('cat');
    if (level == 4) return get('elephant');
    if (level == 5) return get('butterfly');
    if (level == 6) return get('maze');

    final list = _templates.values.toList();
    return list[(level - 1) % list.length];
  }
}
