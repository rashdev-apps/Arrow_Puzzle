import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ads/ad_service.dart';
import '../../../core/constants.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final profile = ref.watch(profileProvider);
    final audio = ref.read(audioProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Themes & Coins')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.monetization_on_rounded,
                  color: AppConstants.gold, size: 28),
              const SizedBox(width: 6),
              Text(
                '${profile.coins}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () async {
                final granted =
                    await ref.read(adServiceProvider).showRewarded(purpose: AdPurpose.hint);
                if (!context.mounted) return;
                if (granted) {
                  ref.read(profileProvider.notifier).addCoins(30);
                  audio.coin();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Rewarded ads are not available in this build.'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.ondemand_video_rounded),
              label: const Text('Watch ad for +30 coins (placeholder)'),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Board themes',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          for (final theme in kAppThemes)
            _ThemeCard(
              theme: theme,
              owned: profile.ownedThemes.contains(theme.id),
              selected: settings.themeId == theme.id,
              onTap: () {
                if (profile.ownedThemes.contains(theme.id)) {
                  ref.read(settingsProvider.notifier).setTheme(theme.id);
                  audio.click();
                  return;
                }
                final ok = ref
                    .read(profileProvider.notifier)
                    .unlockTheme(theme.id, theme.coinCost);
                if (!context.mounted) return;
                if (ok) {
                  ref.read(settingsProvider.notifier).setTheme(theme.id);
                  audio.coin();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${theme.name} unlocked!')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Not enough coins yet.')),
                  );
                }
              },
            ),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final AppThemeData theme;
  final bool owned;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.theme,
    required this.owned,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: selected
            ? const BorderSide(color: AppConstants.gold, width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: theme.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.arrowColor, width: 2),
          ),
          child: Icon(Icons.north_east_rounded, color: theme.arrowColor),
        ),
        title: Text(theme.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: owned
            ? (selected ? const Text('In use') : const Text('Owned'))
            : Text('${theme.coinCost} coins'),
        trailing: owned
            ? (selected ? const Icon(Icons.check_circle_rounded) : null)
            : const Icon(Icons.lock_outline_rounded),
        onTap: onTap,
      ),
    );
  }
}
