import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/ads/ad_service.dart';
import 'core/audio/audio_service.dart';
import 'core/providers.dart';
import 'core/storage/hive_storage_service.dart';
import 'core/storage/memory_storage_service.dart';
import 'core/storage/storage_service.dart';

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

  // Safe storage initialization with foolproof fallback
  StorageService storage;
  try {
    storage = await HiveStorageService.init();
  } catch (e) {
    debugPrint('Storage init error, using MemoryStorage: $e');
    storage = MemoryStorageService();
  }

  // Safe audio initialization (lazy preload)
  final audio = AudioService();
  try {
    audio.enabled = storage.soundOn;
  } catch (e) {
    debugPrint('Audio setup error: $e');
  }

  // AdMob initialized in background with error handling so it cannot crash startup
  final adService = AdMobService();

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

  // Background initialization of audio & ads after first frame
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(audio.preload().catchError((e) => debugPrint('Audio preload error: $e')));
    unawaited(adService.initialize().catchError((e) => debugPrint('AdMob init error: $e')));
  });
}
