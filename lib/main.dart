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
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final storage = await HiveStorageService.init();

  final audio = AudioService();
  audio.enabled = storage.soundOn;
  await audio.preload();

  final adService = AdMobService();
  await adService.initialize();

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
