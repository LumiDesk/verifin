export 'webdav_client_stub.dart'
    if (dart.library.html) 'webdav_client_web.dart'
    if (dart.library.io) 'webdav_client_io.dart';
