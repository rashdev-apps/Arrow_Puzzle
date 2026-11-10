import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../../core/providers.dart';
import 'onboarding_graphic.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const _pages = [
    (
      'Arrow Escape',
      'Untangle the labyrinth',
      'Every board is a dense maze of snake arrows. Find the path, unlock them in sequence, and clear the board.',
    ),
    (
      'Tap to Slide',
      'Free path only',
      'Tap an arrow to slide it out in the direction its head points. Make sure its path out of the maze is completely clear.',
    ),
    (
      'Mind Your Lives & Time',
      'Escape before time runs out',
      'Hitting a blocking arrow costs a heart! Think ahead, spot free outer arrows, and clear the board before the clock ticks down.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    ref.read(storageProvider).onboardingDone = true;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = settings.theme;

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar with Skip and step badge
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.arrowColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'HOW TO PLAY',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800,
                        color: theme.arrowColor,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _finish,
                    style: TextButton.styleFrom(
                      foregroundColor: theme.textColor.withValues(alpha: 0.7),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
            const Spacer(flex: 1),
            // Illustration & Page Content
            Expanded(
              flex: 12,
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final (superTitle, title, body) = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Custom polished graphic badge
                        OnboardingGraphic(
                          pageIndex: i,
                          primaryColor: theme.arrowColor,
                          accentColor: AppConstants.blue,
                          surfaceColor: theme.surface,
                        )
                            .animate(key: ValueKey('graphic_$i'))
                            .scale(duration: 500.ms, curve: Curves.easeOutBack)
                            .fadeIn(duration: 400.ms),
                        const SizedBox(height: 36),
                        // Mini category kicker
                        Text(
                          superTitle.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 2.0,
                            fontWeight: FontWeight.w800,
                            color: AppConstants.blue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: theme.textColor,
                                letterSpacing: -0.5,
                              ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          body,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: theme.textColor.withValues(alpha: 0.75),
                                height: 1.45,
                                fontSize: 15,
                              ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Spacer(flex: 1),
            // Modern Dot Indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: i == _page
                          ? theme.arrowColor
                          : theme.arrowColor.withValues(alpha: 0.2),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            // High-impact CTA Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.arrowColor,
                    foregroundColor: theme.background,
                    elevation: 4,
                    shadowColor: theme.arrowColor.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: () {
                    if (_page < _pages.length - 1) {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutQuad,
                      );
                    } else {
                      _finish();
                    }
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _page < _pages.length - 1 ? 'Continue' : 'Start Playing',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _page < _pages.length - 1
                            ? Icons.arrow_forward_rounded
                            : Icons.play_arrow_rounded,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
