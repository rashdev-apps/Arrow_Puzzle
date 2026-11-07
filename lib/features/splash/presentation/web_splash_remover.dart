// Universal conditional export for removing HTML splash
export 'web_splash_remover_stub.dart'
    if (dart.library.js_interop) 'web_splash_remover_web.dart';

