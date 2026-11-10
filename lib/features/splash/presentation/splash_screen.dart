import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import 'web_splash_remover.dart';

/// Professional game splash screen with animated branding, smooth progress bar,
/// and warm studio gaming aesthetic.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  String _loadingStatus = 'Preparing arrows...';
  Timer? _statusTimer;

  final List<String> _statusMessages = [
    'Preparing arrows...',
    'Unraveling mazes...',
    'Calibrating puzzles...',
    'Ready to escape!',
  ];

  @override
  void initState() {
    super.initState();

    // Dismiss the browser HTML preloader as soon as Flutter renders the splash
    if (kIsWeb) {
      removeWebSplash();
    }
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _progressController.addListener(() {
      setState(() {});
    });

    int index = 0;
    _statusTimer = Timer.periodic(const Duration(milliseconds: 350), (timer) {
      if (mounted && index < _statusMessages.length - 1) {
        index++;
        setState(() {
          _loadingStatus = _statusMessages[index];
        });
      }
    });

    _startLoading();
  }

  Future<void> _startLoading() async {
    await _progressController.forward();
    if (!mounted) return;

    // Small cinematic beat
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    final storage = ref.read(storageProvider);
    if (!storage.onboardingDone) {
      context.go('/onboarding');
    } else {
      context.go('/home');
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(settingsProvider).theme;

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),
              // App Icon / Logo with gentle breathing pulse & entrance
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: theme.arrowColor.withValues(alpha: 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Image.asset(
                    'assets/images/app_icon.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.alt_route_rounded,
                        size: 56,
                        color: theme.arrowColor,
                      );
                    },
                  ),
                ),
              )
                  .animate()
                  .scale(
                    begin: const Offset(0.7, 0.7),
                    end: const Offset(1.0, 1.0),
                    duration: 600.ms,
                    curve: Curves.easeOutBack,
                  )
                  .fadeIn(duration: 400.ms),

              const SizedBox(height: 24),

              // Game Title
              Text(
                'ARROW ESCAPE',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3.0,
                      color: theme.arrowColor,
                    ),
              )
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 400.ms)
                  .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),

              const SizedBox(height: 6),

              Text(
                'TANGLE PUZZLE QUEST',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.5,
                  color: theme.textColor.withValues(alpha: 0.55),
                ),
              ).animate().fadeIn(delay: 350.ms, duration: 400.ms),

              const Spacer(flex: 3),

              // Progress bar container
              SizedBox(
                width: 200,
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _progressController.value,
                        minHeight: 6,
                        backgroundColor: theme.surface,
                        valueColor: AlwaysStoppedAnimation<Color>(theme.arrowColor),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _loadingStatus,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.textColor.withValues(alpha: 0.7),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 450.ms, duration: 400.ms),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}
