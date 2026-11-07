import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../../core/providers.dart';
import '../../../core/storage/storage_service.dart';
import '../../game/logic/generator/shapes.dart';
import '../data/level_repository.dart';

class ChapterInfo {
  final int index;
  final String name;
  final String shape;
  final int firstLevel;

  const ChapterInfo({
    required this.index,
    required this.name,
    required this.shape,
    required this.firstLevel,
  });
}

List<ChapterInfo> buildChapters(int count) {
  final chapters = <ChapterInfo>[];
  for (var c = 0; c * AppConstants.chapterSize < count; c++) {
    final shape = kBuiltinShapes[c % kBuiltinShapes.length];
    final name = '${shape.name[0].toUpperCase()}${shape.name.substring(1)}';
    chapters.add(ChapterInfo(
      index: c,
      name: '$name Shapes',
      shape: shape.name,
      firstLevel: c * AppConstants.chapterSize + 1,
    ));
  }
  return chapters;
}

class LevelSelectScreen extends ConsumerWidget {
  const LevelSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageProvider);
    final profile = ref.watch(profileProvider);
    final theme = ref.watch(settingsProvider).theme;
    final chapters = buildChapters(AppConstants.maxLevel);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppConstants.gold.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.monetization_on_rounded,
                      size: 16, color: AppConstants.gold),
                  const SizedBox(width: 3),
                  Text('${profile.coins}',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _DailyCard(streak: profile.dailyStreak),
                for (final chapter in chapters)
                  _ChapterSection(
                    chapter: chapter,
                    storage: storage,
                    textColor: theme.textColor,
                  ),
              ],
            ),
          ),
          // Adaptive Banner at the bottom of Level Select
          Consumer(
            builder: (context, ref, _) {
              final adService = ref.watch(adServiceProvider);
              return adService.buildBannerWidget();
            },
          ),
        ],
      ),
    );
  }
}

class _DailyCard extends ConsumerWidget {
  final int streak;

  const _DailyCard({required this.streak});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(settingsProvider).theme;
    final storage = ref.watch(storageProvider);
    final today = LevelRepository.dailyKeyString(DateTime.now());
    final done = storage.starsForDaily(today) > 0;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        color: theme.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppConstants.gold.withValues(alpha: 0.3),
            child: const Icon(Icons.calendar_month_rounded,
                color: AppConstants.gold),
          ),
          title: const Text('Daily Challenge',
              style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(
            done
                ? 'Completed today! Streak: $streak'
                : 'New puzzle every day · Streak: $streak',
          ),
          trailing: Icon(
            done ? Icons.check_circle_rounded : Icons.play_circle_fill_rounded,
            color: done ? Colors.green : theme.arrowColor,
            size: 32,
          ),
          onTap: () => context.push('/daily'),
        ),
      ),
    );
  }
}

class _ChapterSection extends StatelessWidget {
  final ChapterInfo chapter;
  final StorageService storage;
  final Color textColor;

  const _ChapterSection({
    required this.chapter,
    required this.storage,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final levels = List.generate(
      AppConstants.chapterSize,
      (i) => chapter.firstLevel + i,
    ).where((id) => id <= AppConstants.maxLevel).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              _ShapePreview(shapeName: chapter.shape, size: 28),
              const SizedBox(width: 10),
              Text(
                chapter.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
              ),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.85,
          ),
          itemCount: levels.length,
          itemBuilder: (context, i) =>
              _LevelTile(levelId: levels[i], storage: storage),
        ),
      ],
    );
  }
}

class _ShapePreview extends StatelessWidget {
  final String shapeName;
  final double size;

  const _ShapePreview({required this.shapeName, required this.size});

  @override
  Widget build(BuildContext context) {
    final shape = shapeByName(shapeName);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ShapePreviewPainter(shape),
      ),
    );
  }
}

class _ShapePreviewPainter extends CustomPainter {
  final ShapeMask shape;

  _ShapePreviewPainter(this.shape);

  @override
  void paint(Canvas canvas, Size size) {
    final rows = shape.baseRows;
    final cols = shape.baseCols;
    final cell = size.shortestSide / (rows > cols ? rows : cols);
    final paint = Paint()..color = AppConstants.brown.withValues(alpha: 0.7);
    final art = shape.art;
    for (var r = 0; r < rows; r++) {
      final row = art[r].padRight(cols, '.');
      for (var c = 0; c < cols; c++) {
        if (row[c] == '#') {
          canvas.drawCircle(
            Offset(c * cell + cell / 2, r * cell + cell / 2),
            cell * 0.42,
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ShapePreviewPainter old) => old.shape != shape;
}

class _LevelTile extends StatelessWidget {
  final int levelId;
  final StorageService storage;

  const _LevelTile({required this.levelId, required this.storage});

  @override
  Widget build(BuildContext context) {
    final stars = storage.starsForLevel(levelId);
    final unlocked = storage.isLevelUnlocked(levelId);

    return GestureDetector(
      onTap: unlocked ? () => context.push('/game/$levelId') : null,
      child: Opacity(
        opacity: unlocked ? 1 : 0.45,
        child: Container(
          decoration: BoxDecoration(
            color: unlocked
                ? AppConstants.brown.withValues(alpha: 0.08)
                : Colors.grey.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppConstants.brown.withValues(alpha: unlocked ? 0.25 : 0.1),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (unlocked)
                Text(
                  '$levelId',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                )
              else
                const Icon(Icons.lock_rounded, size: 18),
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    Icon(
                      Icons.star_rounded,
                      size: 10,
                      color: i < stars
                          ? AppConstants.gold
                          : Colors.grey.withValues(alpha: 0.4),
                    ),
                ],
              ),
              if (storage.bestTimeForLevel(levelId) != null) ...[
                const SizedBox(height: 1),
                Text(
                  '${storage.bestTimeForLevel(levelId)! ~/ 60}:${(storage.bestTimeForLevel(levelId)! % 60).toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppConstants.brown.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
