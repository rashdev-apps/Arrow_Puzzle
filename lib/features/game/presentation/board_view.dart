import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/providers.dart';
import '../domain/arrow.dart';
import '../domain/grid_cell.dart';
import '../domain/level.dart';
import '../logic/game_notifier.dart';
import '../logic/hit_test.dart';
import 'board_painter.dart';

/// The interactive board: pinch-zoom + pan via [InteractiveViewer], tolerant
/// arrow hit-testing, and slide / bump / undo animations driven by
/// [AnimationController]s that repaint only this subtree.
class BoardView extends ConsumerStatefulWidget {
  final Level level;
  final VoidCallback? onFirstInteraction;

  const BoardView({
    super.key,
    required this.level,
    this.onFirstInteraction,
  });

  @override
  ConsumerState<BoardView> createState() => BoardViewState();
}

class BoardViewState extends ConsumerState<BoardView>
    with SingleTickerProviderStateMixin {
  final TransformationController _transform = TransformationController();
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  ArrowAnimation? _active;
  Listenable? _merged;

  double _cellSize = 24;

  @override
  void initState() {
    super.initState();
    _merged = Listenable.merge([_anim]);
  }

  @override
  void dispose() {
    _anim.dispose();
    _transform.dispose();
    super.dispose();
  }

  double get _scale => _transform.value.getMaxScaleOnAxis();

  void _onTapDown(TapDownDetails details) {
    widget.onFirstInteraction?.call();
    final game = ref.read(gameProvider(widget.level.id));
    final notifier = ref.read(gameProvider(widget.level.id).notifier);
    final point = details.localPosition;
    final hit = HitTester(tolerance: AppConstants.hitTolerance / _scale).hit(
      game.remainingArrows,
      point,
      _cellSize,
    );
    if (hit == null) return;

    switch (notifier.evaluateTap(hit)) {
      case TapIgnored():
        break;
      case TapValid(arrow: final arrow):
        _slideOut(arrow);
      case TapBlocked(arrow: final arrow, blockedRay: final ray):
        _bump(arrow, ray);
    }
  }

  void _slideOut(Arrow arrow) {
    final notifier = ref.read(gameProvider(widget.level.id).notifier);
    final board = widget.level.board;
    ref.read(audioProvider).whoosh();
    ref.read(hapticsProvider).light();
    notifier.beginSlide(arrow);
    _setAnim(arrow, ArrowAnimationType.slideOut);
    _anim
        .animateTo(1,
            duration: Duration(
              milliseconds: (300 + board.cellsToExit(arrow) * 18).clamp(300, 450),
            ),
            curve: Curves.easeIn)
        .whenComplete(() {
      notifier.completeSlide(arrow);
      _clearAnim();
      _markTutorialSeen();
    });
  }

  void _markTutorialSeen() {
    final id = widget.level.id;
    if (id <= 3 && !ref.read(storageProvider).tutorialSeenFor(id)) {
      ref.read(storageProvider).markTutorialSeen(id);
      setState(() {});
    }
  }

  void _bump(Arrow arrow, List<GridCell> ray) {
    final notifier = ref.read(gameProvider(widget.level.id).notifier);
    ref.read(audioProvider).buzz();
    ref.read(hapticsProvider).error();
    notifier.registerMistake(arrow, ray);
    _setAnim(arrow, ArrowAnimationType.bump);
    _anim
        .animateTo(1,
            duration: const Duration(milliseconds: 420),
            curve: Curves.linear)
        .whenComplete(() {
      notifier.clearBlocked();
      _clearAnim();
    });
  }

  /// Undo with animated reverse slide. Called by the parent screen after
  /// [GameNotifier.undo] returns the restored arrow.
  void playUndoSlide(Arrow arrow) {
    _setAnim(arrow, ArrowAnimationType.slideIn);
    _anim
        .animateTo(1,
            duration: const Duration(milliseconds: 350), curve: Curves.easeOut)
        .whenComplete(_clearAnim);
  }

  void _setAnim(Arrow arrow, ArrowAnimationType type) {
    _active = ArrowAnimation(
      arrow: arrow,
      dir: arrow.dir,
      exitCells: widget.level.board.cellsToExit(arrow),
      progress: 0,
      type: type,
    );
    _anim.value = 0;
  }

  void _clearAnim() {
    if (mounted) {
      setState(() => _active = null);
    } else {
      _active = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final board = widget.level.board;
        final cellSize = (constraints.maxWidth / board.cols)
            .clamp(AppConstants.minCellSize, 56.0);
        _cellSize = cellSize.toDouble();
        final boardSize = Size(
          board.cols * _cellSize,
          board.rows * _cellSize,
        );

        return Stack(
          children: [
            InteractiveViewer(
              transformationController: _transform,
              minScale: 1,
              maxScale: 6,
              boundaryMargin: const EdgeInsets.all(120),
              onInteractionStart: (_) => widget.onFirstInteraction?.call(),
              child: Center(
            child: SizedBox(
              width: boardSize.width,
              height: boardSize.height,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: _onTapDown,
                child: AnimatedBuilder(
                  animation: _merged!,
                  builder: (context, _) {
                    final game = ref.watch(
                      gameProvider(widget.level.id),
                    );
                    final settings = ref.watch(settingsProvider);
                    return CustomPaint(
                      size: boardSize,
                      painter: BoardPainter(
                        board: board,
                        remainingIds: game.remaining,
                        cellSize: _cellSize,
                        theme: settings.theme,
                        colorblind: settings.colorblindMode,
                        hintArrowId: game.hintArrowId,
                        blockedArrowId: game.blockedArrowId,
                        blockedRay: game.blockedRay,
                        animation: _active == null
                            ? null
                            : ArrowAnimation(
                                arrow: _active!.arrow,
                                dir: _active!.dir,
                                exitCells: _active!.exitCells,
                                progress: _anim.value,
                                type: _active!.type,
                              ),
                        repaint: _merged!,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          ),
          if (_tutorialDue && _tutorialTarget != null)
            _buildTutorial(constraints, boardSize),
        ],
        );
      },
    );
  }

  bool get _tutorialDue {
    final id = widget.level.id;
    if (id > 3) return false;
    return !ref.read(storageProvider).tutorialSeenFor(id);
  }

  GridCell? get _tutorialTarget {
    final game = ref.read(gameProvider(widget.level.id));
    final free = game.level.board.freeArrows(game.remaining);
    return free.isEmpty ? null : free.first.head;
  }

  static const _tutorialTexts = {
    1: 'Tap an arrow — it slides out along the direction its head points!',
    2: 'Arrows only slide when nothing blocks their exit path.',
    3: 'Careful: blocked taps cost hearts. Use Hint if you get stuck!',
  };

  Widget _buildTutorial(BoxConstraints constraints, Size boardSize) {
    final target = _tutorialTarget;
    if (target == null) return const SizedBox.shrink();
    final origin = Offset(
      (constraints.maxWidth - boardSize.width) / 2,
      (constraints.maxHeight - boardSize.height) / 2,
    );
    final pos = origin +
        Offset((target.col + 0.5) * _cellSize, (target.row + 0.5) * _cellSize);

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: pos.dx - 34,
            top: pos.dy - 34,
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppConstants.blue, width: 3),
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 0.7, end: 1.15, duration: 700.ms),
          ),
          Positioned(
            // Position the finger so its pointing tip (top-left of touch_app icon)
            // targets directly into the center of the pulsing circle / arrow head.
            // Icons.touch_app_rounded fingertip is located near (dx: +11, dy: +4) within a 40x40 icon box.
            left: pos.dx - 11,
            top: pos.dy - 4,
            child: const Icon(
              Icons.touch_app_rounded,
              size: 40,
              color: AppConstants.blue,
            )
                .animate(onPlay: (c) => c.repeat())
                .move(
                  begin: const Offset(8, -8),
                  end: const Offset(0, 0),
                  duration: 800.ms,
                  curve: Curves.easeOutQuad,
                )
                .then()
                .scaleXY(begin: 1, end: 0.85, duration: 150.ms)
                .then()
                .scaleXY(begin: 0.85, end: 1, duration: 150.ms),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: AppConstants.brown,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _tutorialTexts[widget.level.id] ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppConstants.cream,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.3, end: 0),
          ),
        ],
      ),
    );
  }
}
