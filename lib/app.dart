import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers.dart';
import 'core/theme/app_theme.dart';
import 'features/game/presentation/game_screen.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/levels/presentation/level_map_screen.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/settings/presentation/arrow_gallery_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/shop/presentation/shop_screen.dart';
import 'features/splash/presentation/splash_screen.dart';

GoRouter createRouter({String initialLocation = '/splash'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/levels',
      builder: (context, state) => const LevelMapScreen(),
    ),
    GoRoute(
      path: '/game/:id',
      builder: (context, state) =>
          GameScreen(levelId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/daily',
      builder: (context, state) =>
          const GameScreen(levelId: 0, daily: true),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/debug/arrow_gallery',
      builder: (context, state) => const ArrowGalleryScreen(),
    ),
    GoRoute(
      path: '/shop',
      builder: (context, state) => const ShopScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
  ],
  redirect: (context, state) {
    // Let splash screen complete its animation before routing
    if (state.matchedLocation == '/splash') {
      return null;
    }
    final container = ProviderScope.containerOf(context, listen: false);
    final onboardingDone =
        container.read(storageProvider).onboardingDone;
    final onOnboarding = state.matchedLocation == '/onboarding';
    if (!onboardingDone && !onOnboarding) return '/onboarding';
    if (onboardingDone && onOnboarding) return '/home';
    return null;
  },
);

final _defaultRouter = createRouter();

class ArrowPuzzleApp extends ConsumerWidget {
  final GoRouter? router;

  const ArrowPuzzleApp({super.key, this.router});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(settingsProvider).theme;
    return MaterialApp.router(
      title: 'Arrow Escape',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(theme),
      routerConfig: router ?? _defaultRouter,
    );
  }
}
