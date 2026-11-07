import 'package:arrow_puzzle/features/game/presentation/board_painter.dart';
import 'package:flutter/material.dart';

class ArrowGalleryScreen extends StatelessWidget {
  const ArrowGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Arrow Gallery (Debug)')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Straight Arrows (Up, Down, Left, Right)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _ArrowGalleryWidget(bent: false),
            const SizedBox(height: 24),
            Text(
              'Bent Arrows (Up, Down, Left, Right)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _ArrowGalleryWidget(bent: true),
          ],
        ),
      ),
    );
  }
}

class _ArrowGalleryWidget extends StatelessWidget {
  final bool bent;

  const _ArrowGalleryWidget({required this.bent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: Colors.brown.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.brown.shade200),
      ),
      child: CustomPaint(
        painter: _GalleryPainter(bent: bent),
      ),
    );
  }
}

class _GalleryPainter extends CustomPainter {
  final bool bent;

  _GalleryPainter({required this.bent});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeW = 4.0;
    final paint = Paint()
      ..color = Colors.brown.shade800
      ..strokeWidth = strokeW
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = Colors.brown.shade800
      ..style = PaintingStyle.fill;

    final step = size.width / 4;
    final centerY = size.height / 2;

    // 4 directions: Up, Down, Left, Right
    // 0: Up
    final x0 = step * 0.5;
    if (!bent) {
      final p1 = Offset(x0, centerY + 30);
      final p2 = Offset(x0, centerY - 30);
      _drawArrowWithHead(canvas, [p1, p2], paint, fillPaint, strokeW);
    } else {
      final p1 = Offset(x0 - 25, centerY + 20);
      final p2 = Offset(x0, centerY + 20);
      final p3 = Offset(x0, centerY - 30);
      _drawArrowWithHead(canvas, [p1, p2, p3], paint, fillPaint, strokeW);
    }

    // 1: Down
    final x1 = step * 1.5;
    if (!bent) {
      final p1 = Offset(x1, centerY - 30);
      final p2 = Offset(x1, centerY + 30);
      _drawArrowWithHead(canvas, [p1, p2], paint, fillPaint, strokeW);
    } else {
      final p1 = Offset(x1 - 25, centerY - 20);
      final p2 = Offset(x1, centerY - 20);
      final p3 = Offset(x1, centerY + 30);
      _drawArrowWithHead(canvas, [p1, p2, p3], paint, fillPaint, strokeW);
    }

    // 2: Left
    final x2 = step * 2.5;
    if (!bent) {
      final p1 = Offset(x2 + 30, centerY);
      final p2 = Offset(x2 - 30, centerY);
      _drawArrowWithHead(canvas, [p1, p2], paint, fillPaint, strokeW);
    } else {
      final p1 = Offset(x2 + 20, centerY + 25);
      final p2 = Offset(x2 + 20, centerY);
      final p3 = Offset(x2 - 30, centerY);
      _drawArrowWithHead(canvas, [p1, p2, p3], paint, fillPaint, strokeW);
    }

    // 3: Right
    final x3 = step * 3.5;
    if (!bent) {
      final p1 = Offset(x3 - 30, centerY);
      final p2 = Offset(x3 + 30, centerY);
      _drawArrowWithHead(canvas, [p1, p2], paint, fillPaint, strokeW);
    } else {
      final p1 = Offset(x3 - 20, centerY + 25);
      final p2 = Offset(x3 - 20, centerY);
      final p3 = Offset(x3 + 30, centerY);
      _drawArrowWithHead(canvas, [p1, p2, p3], paint, fillPaint, strokeW);
    }
  }

  void _drawArrowWithHead(
    Canvas canvas,
    List<Offset> points,
    Paint strokePaint,
    Paint fillPaint,
    double strokeW,
  ) {
    final tip = points.last;
    final prev = points[points.length - 2];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, strokePaint);
    BoardPainter.drawArrowHead(canvas, tip, prev, fillPaint, strokeW);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

