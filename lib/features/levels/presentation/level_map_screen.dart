import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ads/ad_service.dart';
import '../../../core/constants.dart';
import '../../../core/providers.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/theme/ui_components.dart';
import '../../game/logic/difficulty_config.dart';

/// Single vertical winding path Level Map screen.
/// - Shows completed (stars), current (pulsing ring, "Play"), and locked nodes.
/// - Handles 1000+ levels lazily with auto-scroll to current unlocked level.
/// - Boss nodes (every 10th) are larger with crown icon.
class LevelMapScreen extends ConsumerStatefulWidget {
  const LevelMapScreen({super.key});

  @override
  ConsumerState<LevelMapScreen> createState() => _LevelMapScreenState();
}

class _LevelMapScreenState extends ConsumerState<LevelMapScreen> {
  late final ScrollController _scrollController;
  final int totalLevels = 100;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentLevel();
    });
  }

  void _scrollToCurrentLevel() {
    final storage = ref.read(storageProvider);
    final current = storage.maxUnlockedLevel.clamp(1, totalLevels);
    // Each level row is ~110dp high
    final targetOffset = (current - 1) * 110.0 - 150.0;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        math.max(0.0, targetOffset),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(storageProvider);
    final profile = ref.watch(profileProvider);
    final adService = ref.watch(adServiceProvider);
    final currentUnlocked = storage.maxUnlockedLevel;

    return Scaffold(
      backgroundColor: DesignTokens.creamBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: DesignTokens.brownPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Level Journey',
          style: TextStyle(
            color: DesignTokens.brownDark,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: StatChip(
                icon: Icons.monetization_on_rounded,
                iconColor: DesignTokens.accentGold,
                text: '${profile.coins}',
                onTap: () => context.push('/shop'),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              itemCount: totalLevels,
              itemBuilder: (context, index) {
                final levelId = index + 1;
                final isUnlocked = levelId <= currentUnlocked;
                final isCurrent = levelId == currentUnlocked;
                final isBoss = DifficultyConfig.isBossLevel(levelId);
                final stars = storage.starsForLevel(levelId);

                // Horizontal winding curve offset (-60 to +60)
                final waveX = math.sin(index * 0.55) * 65.0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Transform.translate(
                      offset: Offset(waveX, 0),
                      child: _LevelMapNode(
                        levelId: levelId,
                        isUnlocked: isUnlocked,
                        isCurrent: isCurrent,
                        isBoss: isBoss,
                        stars: stars,
                        onTap: () {
                          if (isUnlocked) {
                            context.push('/game/$levelId');
                          }
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          adService.buildBannerWidget(),
        ],
      ),
    );
  }
}

class _LevelMapNode extends StatelessWidget {
  final int levelId;
  final bool isUnlocked;
  final bool isCurrent;
  final bool isBoss;
  final int stars;
  final VoidCallback onTap;

  const _LevelMapNode({
    required this.levelId,
    required this.isUnlocked,
    required this.isCurrent,
    required this.isBoss,
    required this.stars,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = isBoss ? 76.0 : 64.0;
    final arrows = DifficultyConfig.arrowCount(levelId);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCurrent)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: isBoss ? DesignTokens.errorRed : DesignTokens.brownPrimary,
                borderRadius: DesignTokens.brPill,
                boxShadow: DesignTokens.shadowSoft,
              ),
              child: Text(
                isBoss ? 'BOSS • $arrows ➔' : 'PLAY • $arrows ➔',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          Stack(
            alignment: Alignment.center,
            children: [
              if (isCurrent)
                Container(
                  width: size + 16,
                  height: size + 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (isBoss ? DesignTokens.errorRed : DesignTokens.accentAmber).withAlpha(160),
                      width: 3,
                    ),
                  ),
                ),
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: !isUnlocked
                      ? Colors.grey.shade400
                      : (isBoss
                          ? DesignTokens.errorRed
                          : (isCurrent
                              ? DesignTokens.accentAmber
                              : DesignTokens.brownPrimary)),
                  boxShadow: isUnlocked ? DesignTokens.shadowSoft : null,
                ),
                child: Center(
                  child: !isUnlocked
                      ? const Icon(Icons.lock_rounded, color: Colors.white, size: 24)
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isBoss)
                              const Icon(Icons.military_tech_rounded, color: Colors.white, size: 20),
                            Text(
                              '$levelId',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isBoss ? 20 : 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
          if (isUnlocked && !isCurrent) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (starIdx) {
                final filled = starIdx < stars;
                return Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 16,
                  color: filled ? DesignTokens.accentAmber : DesignTokens.brownMuted,
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}

