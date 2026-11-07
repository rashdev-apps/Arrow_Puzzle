import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/providers.dart';
import '../logic/level_timer_notifier.dart';

/// Highly efficient timer pill displaying mm:ss.
/// Isolated repaint: only rebuilds when remainingSeconds changes.
class LevelTimerPill extends ConsumerWidget {
  final int levelId;

  const LevelTimerPill({super.key, required this.levelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(levelTimerProvider(levelId));
    if (timerState.isHidden) return const SizedBox.shrink();

    final settings = ref.watch(settingsProvider);
    final theme = settings.theme;

    final remaining = timerState.remainingSeconds;
    final mins = remaining ~/ 60;
    final secs = remaining % 60;
    final timeStr = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    // Timer color: brown normally, turns amber under 30%, red + subtle pulse under 15%
    Color textColor = theme.textColor;
    Color bgColor = theme.arrowColor.withValues(alpha: 0.1);
    Color borderColor = theme.arrowColor.withValues(alpha: 0.2);

    if (timerState.isFrozen) {
      textColor = AppConstants.blue;
      bgColor = AppConstants.blue.withValues(alpha: 0.15);
      borderColor = AppConstants.blue.withValues(alpha: 0.4);
    } else if (timerState.isCritical) {
      textColor = AppConstants.red;
      bgColor = AppConstants.red.withValues(alpha: 0.15);
      borderColor = AppConstants.red.withValues(alpha: 0.4);
    } else if (timerState.isWarning) {
      textColor = AppConstants.gold;
      bgColor = AppConstants.gold.withValues(alpha: 0.2);
      borderColor = AppConstants.gold.withValues(alpha: 0.45);
    }

    Widget pillContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: textColor.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            timerState.isFrozen ? Icons.ac_unit_rounded : Icons.timer_outlined,
            size: 17,
            color: textColor,
          ),
          const SizedBox(width: 6),
          Text(
            timeStr,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: textColor,
              letterSpacing: 0.8,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );

    if (timerState.isCritical && timerState.isRunning && !timerState.isFrozen) {
      pillContent = pillContent
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(begin: 1.0, end: 1.08, duration: 400.ms, curve: Curves.easeInOut);
    }

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        pillContent,
        if (timerState.mistakePenaltyAlert > 0)
          Positioned(
            top: 24,
            child: Text(
              '-3s',
              style: const TextStyle(
                color: AppConstants.red,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            )
                .animate(key: ValueKey(timerState.mistakePenaltyAlert))
                .moveY(begin: 0, end: 16, duration: 600.ms, curve: Curves.easeOut)
                .fadeOut(duration: 600.ms),
          ),
      ],
    );
  }
}

