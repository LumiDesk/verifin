import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// SQLite WASM 的虚拟文件系统持久化到同源 IndexedDB；继续使用正式 schema
/// 和 SqliteLedgerRepository，不把浏览器账目降级为内存或 KV 快照。
Future<DatabaseFactory> resolveDatabaseFactory() async => databaseFactoryFfiWeb;

Future<String> resolveDatabasePath(String name) async => name;
