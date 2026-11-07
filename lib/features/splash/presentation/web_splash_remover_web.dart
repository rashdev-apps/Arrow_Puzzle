import 'dart:js_interop';

@JS('removeSplashFromWeb')
external void _removeSplashFromWeb();

void removeWebSplash() {
  try {
    _removeSplashFromWeb();
  } catch (_) {}
}

