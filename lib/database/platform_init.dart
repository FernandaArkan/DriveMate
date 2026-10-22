export 'platform_init_io.dart'
    if (dart.library.js_interop) 'platform_init_web.dart'
    if (dart.library.html) 'platform_init_web.dart';
