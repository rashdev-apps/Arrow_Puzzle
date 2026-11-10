import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ads/ad_service.dart';
import '../../../core/constants.dart';
import '../../../core/providers.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/theme/ui_components.dart';
import '../../game/logic/difficulty_config.dart';

/// Professional home screen with hero branding, current level quick-play,
/// daily challenge card with streak, coins pill, and level progression navigation.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageProvider);
    final profile = ref.watch(profileProvider);
    final adService = ref.watch(adServiceProvider);

    final currentLevel = storage.maxUnlockedLevel;
    final isBoss = DifficultyConfig.isBossLevel(currentLevel);

    return Scaffold(
      backgroundColor: DesignTokens.creamBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Coins Pill & Settings
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.s20,
                vertical: DesignTokens.s12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StatChip(
                    icon: Icons.monetization_on_rounded,
                    iconColor: DesignTokens.accentGold,
                    text: '${profile.coins}',
                    onTap: () => context.push('/shop'),
                  ),
                  Row(
                    children: [
                      StatChip(
                        icon: Icons.star_rounded,
                        iconColor: DesignTokens.accentAmber,
                        text: '${profile.levelsCompleted}',
                      ),
                      const SizedBox(width: DesignTokens.s8),
                      IconButton(
                        icon: const Icon(
                          Icons.settings_rounded,
                          color: DesignTokens.brownPrimary,
                          size: 28,
                        ),
                        onPressed: () => context.push('/settings'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Content Area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: DesignTokens.s24),
                child: Column(
                  children: [
                    const SizedBox(height: DesignTokens.s24),

                    // Game Logo / Title
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: DesignTokens.brownPrimary,
                        borderRadius: DesignTokens.br24,
                        boxShadow: DesignTokens.shadowElevated,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.navigation_rounded,
                          size: 52,
                          color: DesignTokens.creamBg,
                        ),
                      ),
                    ),
                    const SizedBox(height: DesignTokens.s16),

                    const Text(
                      'ARROW ESCAPE',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: DesignTokens.brownDark,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: DesignTokens.s4),
                    const Text(
                      'Unravel the labyrinth, slide to escape',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: DesignTokens.brownMuted,
                      ),
                    ),

                    const SizedBox(height: DesignTokens.s40),

                    // Big Primary "Play Level N" Button
                    PrimaryButton(
                      height: 64,
                      onPressed: () => context.push('/game/$currentLevel'),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isBoss ? Icons.military_tech_rounded : Icons.play_arrow_rounded,
                            size: 32,
                            color: DesignTokens.creamBg,
                          ),
                          const SizedBox(width: DesignTokens.s12),
                          Text(
                            isBoss ? 'BOSS LEVEL $currentLevel' : 'PLAY LEVEL $currentLevel',
                            style: const TextStyle(
                              color: DesignTokens.creamBg,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: DesignTokens.s16),

                    // Level Map Button
                    SecondaryButton(
                      width: double.infinity,
                      height: 52,
                      label: 'Level Map',
                      icon: Icons.map_rounded,
                      onPressed: () => context.push('/levels'),
                    ),

                    const SizedBox(height: DesignTokens.s32),

                    // Daily Challenge Card
                    _DailyChallengeCard(
                      streak: storage.dailyStreak,
                      onTap: () => context.push('/daily'),
                    ),

                    const SizedBox(height: DesignTokens.s24),
                  ],
                ),
              ),
            ),

            // Banner Ad at Bottom
            adService.buildBannerWidget(),
          ],
        ),
      ),
    );
  }
}

class _DailyChallengeCard extends StatelessWidget {
  final int streak;
  final VoidCallback onTap;

  const _DailyChallengeCard({
    required this.streak,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(DesignTokens.s20),
        decoration: BoxDecoration(
          color: DesignTokens.creamSurface,
          borderRadius: DesignTokens.br20,
          border: Border.all(
            color: DesignTokens.accentAmber.withAlpha(100),
            width: 1.5,
          ),
          boxShadow: DesignTokens.shadowSoft,
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: DesignTokens.accentAmber.withAlpha(40),
                borderRadius: DesignTokens.br16,
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: DesignTokens.accentAmber,
                size: 28,
              ),
            ),
            const SizedBox(width: DesignTokens.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Daily Challenge',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: DesignTokens.brownDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    streak > 0 ? '$streak-day streak 🔥' : 'Play today’s puzzle',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: DesignTokens.brownMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: DesignTokens.brownMuted,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}

