# Arrow Escape (arrow_puzzle)

A polished mobile puzzle game built with Flutter. Boards are silhouettes
(trophy, anchor, dog, heart, rocket, …) filled with tangled snake-like
**arrows**. Tap an arrow to slide it out along the direction its head
points — but only if nothing blocks its exit path. Clear every arrow to win.

## Features

- **200 hand-tuned generated levels** across 10 shape-themed chapters
- **Guaranteed solvable & unique levels** via reverse-order generation
  (removal order = reverse placement order) with canonical layout hashing
- Hearts (3 per level), mistakes-based star rating (3 / 2 / 1)
- Hints, undo (animated reverse), restart, revive
- Coins economy + unlockable colour themes + daily challenge with streaks
- Onboarding tutorial with animated tap demo (levels 1–3)
- Pinch-to-zoom + pan on large boards, tolerant arrow hit-testing
- Sound effects (synthesised, no binary blobs), haptics, confetti
- Light + dark themes, colorblind-safe highlight option
- Offline-first; ads/IAP behind clean stub interfaces
- Local persistence via Hive (progress, stars, coins, settings, streaks,
  resume-in-progress level state)

## Getting started

```bash
flutter pub get

# One-time: synthesise sound effects into assets/sounds/
dart run tool/generate_sounds.dart

# One-time: pre-generate the 200 level JSON files into assets/levels/
# (pass a number to generate fewer, e.g. `dart run tool/generate_levels.dart 20`)
dart run tool/generate_levels.dart

flutter run
```

> Levels and sounds are generated artifacts. The app still runs without
> them — levels fall back to deterministic runtime generation using the
> same seeds — but shipping the pre-generated JSON keeps startup fast.

## Tests

```bash
flutter test
```

Covers move validation, the solver/dependency graph, hit-testing,
generator determinism, solvability & uniqueness across all shapes, plus
widget tests for the game screen (tap validation, hearts, win/fail
overlays, persistence).

## Project layout

```
lib/
  main.dart, app.dart          Entry point, go_router, theming
  core/                        Theme, constants, storage (Hive), audio,
                               haptics, Ad/IAP stubs, Riverpod providers
  features/
    game/
      domain/                  Arrow, Board, GridCell, Direction, Level
      logic/                   MoveValidator, Solver, HitTester,
                               GameNotifier (state machine)
      logic/generator/         Shapes, LevelGenerator, layout hashing
      presentation/            BoardPainter (single canvas), BoardView
                               (gestures/zoom/animations), GameScreen
    levels/                    Level repository (assets + fallback),
                               level select with chapters
    settings/                  Settings + stats
    shop/                      Themes & coins
    onboarding/                First-run tutorial pages
tool/
  generate_levels.dart         Pre-generates assets/levels/*.json
  generate_sounds.dart         Synthesises assets/sounds/*.wav
assets/
  levels/  shapes/  sounds/  images/
test/                        Unit + widget tests
```

## Adding a new shape

1. Add ASCII art to `kBuiltinShapes` in
   `lib/features/game/logic/generator/shapes.dart` (`#` = playable cell),
   **or** drop a JSON file into `assets/shapes/`:
   ```json
   { "name": "myshape", "rows": ["..#..", "#####", ".###."] }
   ```
2. Regenerate levels: `dart run tool/generate_levels.dart`

Shapes are automatically aspect-resampled to each tier's grid size, so one
silhouette definition serves tutorials (5×5) through hard boards (22×22).

## Adding / regenerating levels

Levels are deterministic: level *N* always uses seed
`fnv1a64("arrowpuzzle:N")`. The generator tool walks levels 1–200, bumps
the salt on the rare layout-hash collision, and writes
`assets/levels/level_NNN.json` plus a `manifest.json`.

Difficulty tiers: 1–10 tutorial (5–7 grid), 11–50 medium (8–12),
51–120 large shaped (14–17), 121–200 hard (18–22, deeper chains).

## Architecture notes

- Game logic is pure Dart with no Flutter imports (except `hit_test.dart`,
  which only needs `Offset`); everything is unit-testable.
- `BoardPainter` draws the whole board on one canvas; static arrow paths
  are cached `Path` objects and only the animating arrow recomputes per
  frame. Animations drive repaints through `AnimationController`s.
- `GameNotifier` is the single source of truth for a level; the widget
  layer animates, then commits results (`completeSlide`,
  `registerMistake`, …).
- Ads/IAP: implement `AdService` / `IapService` in `lib/core/ads/` and
  override `adServiceProvider` / `iapServiceProvider` in `main.dart`.

## Building for release

### Android (APK / AAB)

```bash
flutter build apk --release          # app-release.apk
flutter build appbundle --release    # app-release.aab (Play Store)
```

Requires the Android SDK + Android Studio toolchain
(`flutter doctor` to verify). App signing: create
`android/key.properties` and reference it in
`android/app/build.gradle.kts` per the
[official docs](https://docs.flutter.dev/deployment/android).

### iOS

```bash
flutter build ipa --release
```

Requires macOS with Xcode. Update `ios/Runner/Info.plist` display name and
signing team; see the
[official docs](https://docs.flutter.dev/deployment/ios).

### App icon & splash

Configured in `pubspec.yaml` via `flutter_launcher_icons` and
`flutter_native_splash`; regenerate after changing
`assets/images/app_icon.png`:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## Google AdMob Integration

The game integrates Google Mobile Ads (Banner and Rewarded) using [`google_mobile_ads`](https://pub.dev/packages/google_mobile_ads) and Google UMP consent for GDPR/EEA.

### Switching to Production AdMob IDs
All ad unit IDs are configured in [`lib/core/ads/ad_config.dart`](file:///c:/Users/shakthi/Documents/Qoder/2026-11-07/15c9f198/arrow_puzzle/lib/core/ads/ad_config.dart).

1. In [`ad_config.dart`](file:///c:/Users/shakthi/Documents/Qoder/2026-11-07/15c9f198/arrow_puzzle/lib/core/ads/ad_config.dart), replace the placeholder IDs under `Production IDs`:
   - `androidAppIdProd`, `androidBannerIdProd`, `androidRewardedIdProd`
   - `iosAppIdProd`, `iosBannerIdProd`, `iosRewardedIdProd`
2. Update the App IDs in native configs:
   - **Android**: Replace the `com.google.android.gms.ads.APPLICATION_ID` meta-data value in [`android/app/src/main/AndroidManifest.xml`](file:///c:/Users/shakthi/Documents/Qoder/2026-11-07/15c9f198/arrow_puzzle/android/app/src/main/AndroidManifest.xml).
   - **iOS**: Replace `GADApplicationIdentifier` in [`ios/Runner/Info.plist`](file:///c:/Users/shakthi/Documents/Qoder/2026-11-07/15c9f198/arrow_puzzle/ios/Runner/Info.plist).
3. To build with production IDs, build in release mode:
   ```bash
   flutter build apk --release --dart-define=USE_TEST_ADS=false
   ```

### Pre-release Ad Checklist
- [ ] **Test Devices**: Register your physical device test IDs via `MobileAds.instance.updateRequestConfiguration(RequestConfiguration(testDeviceIds: [...]))` to avoid accidental policy violations during internal QA.
- [ ] **Consent Flow (UMP)**: Verify that EU/EEA user consent form displays on cold launch before loading live ads.
- [ ] **Rewarded Revive**: Verify that "Watch ad to continue" restores exactly 2 hearts, resumes timer & board state without reloading the board, and cannot be watched more than once per attempt.
- [ ] **Rewarded Hints**: Verify that the Hint button is badged `AD`, limits to 2 hints per level attempt, and only reveals a hint arrow when the user completes watching the full ad (no reward if dismissed early).
- [ ] **Banner Placement**: Verify that adaptive banners automatically collapse when loading fails, appear only at the bottom of Level Select and Settings, and never overlap the game board or interaction buttons.
- [ ] **Timer & Lifecycle**: Verify that the game timer and audio pause while a full-screen ad is active and seamlessly resume after dismissal.
