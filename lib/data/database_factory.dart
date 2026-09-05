// 平台专属的 sqflite DatabaseFactory 与数据库路径解析。
//
// - io（Android/iOS）：使用 sqflite 原生实现，落地到应用数据库目录。
// - web：SQLite WASM 文件系统写入同源 IndexedDB。
// - stub / 测试：不提供实现，测试用例自行注入 ffi factory。
export 'database_factory_stub.dart'
    if (dart.library.io) 'database_factory_io.dart'
    if (dart.library.js_interop) 'database_factory_web.dart';
