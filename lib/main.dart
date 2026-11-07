import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/ads/ad_service.dart';
import 'core/audio/audio_service.dart';
import 'core/providers.dart';
import 'core/storage/hive_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait only.
  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } catch (e) {
    debugPrint('Orientation setup error: $e');
  }

  // Safe storage initialization
  late final HiveStorageService storage;
  try {
    storage = await HiveStorageService.init();
  } catch (e) {
    debugPrint('Storage init error: $e');
    storage = await HiveStorageService.init();
  }

  // Safe audio initialization
  final audio = AudioService();
  try {
    audio.enabled = storage.soundOn;
    await audio.preload();
  } catch (e) {
    debugPrint('Audio preload error: $e');
  }

  // AdMob initialized in background with error handling so it cannot crash startup
  final adService = AdMobService();
  unawaited(
    adService.initialize().catchError((e) {
      debugPrint('AdMob init error: $e');
    }),
  );

  runApp(
    ProviderScope(
      overrides: [
        storageProvider.overrideWithValue(storage),
        audioProvider.overrideWithValue(audio),
        adServiceProvider.overrideWithValue(adService),
      ],
      child: const ArrowPuzzleApp(),
    ),
  );
}
