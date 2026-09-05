export 'data_file_port_stub.dart'
    if (dart.library.io) 'data_file_port_io.dart'
    if (dart.library.js_interop) 'data_file_port_web.dart';
