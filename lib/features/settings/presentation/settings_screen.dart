import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/storage/storage_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const String privacyPolicyUrl = 'https://example.com/privacy';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final storage = ref.watch(storageProvider);
    final profile = ref.watch(profileProvider);
    final audio = ref.read(audioProvider);
    final haptics = ref.read(hapticsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SwitchTile(
                  title: 'Sound effects',
                  subtitle: 'Whooshes, buzzes and jingles',
                  value: settings.soundOn,
                  icon: Icons.volume_up_rounded,
                  onChanged: (_) {
                    notifier.toggleSound();
                    audio.enabled = !settings.soundOn;
                    audio.click();
                  },
                ),
                _SwitchTile(
                  title: 'Music',
                  subtitle: 'Background music (coming soon)',
                  value: settings.musicOn,
                  icon: Icons.music_note_rounded,
                  onChanged: (_) => notifier.toggleMusic(),
                ),
                _SwitchTile(
                  title: 'Haptics',
                  subtitle: 'Vibration feedback on taps',
                  value: settings.hapticsOn,
                  icon: Icons.vibration_rounded,
                  onChanged: (_) {
                    notifier.toggleHaptics();
                    haptics.enabled = !settings.hapticsOn;
                  },
                ),
                _SwitchTile(
                  title: 'Colorblind-safe highlights',
                  subtitle: 'Blue / orange instead of blue / red',
                  value: settings.colorblindMode,
                  icon: Icons.visibility_rounded,
                  onChanged: (_) => notifier.toggleColorblind(),
                ),
                _SwitchTile(
                  title: 'Relaxed mode',
                  subtitle: 'Disable countdown timer (stars capped at 2)',
                  value: settings.relaxedMode,
                  icon: Icons.hourglass_disabled_rounded,
                  onChanged: (_) => notifier.toggleRelaxedMode(),
                ),
                const SizedBox(height: 16),
                Text(
                  'Statistics',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                _StatsCard(
                  levelsCompleted: profile.levelsCompleted,
                  totalStars: _totalStars(storage),
                  arrowsRemoved: profile.totalArrowsRemoved,
                  bestStreak: profile.bestStreak,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => context.push('/debug/arrow_gallery'),
                  icon: const Icon(Icons.navigation_rounded),
                  label: const Text('Arrow Gallery (Debug)'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => context.push('/shop'),
                  icon: const Icon(Icons.palette_rounded),
                  label: const Text('Themes & Coins'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Remove Ads (\$1.99) · Placeholder')),
                    );
                  },
                  icon: const Icon(Icons.block_rounded),
                  label: const Text('Remove Ads (IAP Placeholder)'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Privacy policy: $privacyPolicyUrl')),
                    );
                  },
                  icon: const Icon(Icons.privacy_tip_outlined),
                  label: const Text('Privacy policy'),
                ),
                const SizedBox(height: 24),
                Center(
                  child: TextButton(
                    onPressed: () => _confirmReset(context, ref),
                    child: const Text(
                      'Reset all progress',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Adaptive Banner at bottom of Settings
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

  int _totalStars(StorageService storage) {
    var sum = 0;
    for (var i = 1; i <= 200; i++) {
      sum += storage.starsForLevel(i);
    }
    return sum;
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset progress?'),
        content: const Text(
          'This erases stars, coins and unlocked themes. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(storageProvider).resetProgress();
      ref.read(profileProvider.notifier).refresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Progress reset.')),
        );
      }
    }
  }
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final IconData icon;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SwitchListTile(
        secondary: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final int levelsCompleted;
  final int totalStars;
  final int arrowsRemoved;
  final int bestStreak;

  const _StatsCard({
    required this.levelsCompleted,
    required this.totalStars,
    required this.arrowsRemoved,
    required this.bestStreak,
  });

  @override
  Widget build(BuildContext context) {
    Widget stat(String label, String value, IconData icon) => Column(
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        );

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            stat('Levels', '$levelsCompleted', Icons.flag_rounded),
            stat('Stars', '$totalStars', Icons.star_rounded),
            stat('Arrows', '$arrowsRemoved', Icons.alt_route_rounded),
            stat('Streak', '$bestStreak', Icons.local_fire_department_rounded),
          ],
        ),
      ),
    );
  }
}
