import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common/sqlite_api.dart';

/// Android/iOS 使用 sqflite 原生实现。
Future<DatabaseFactory> resolveDatabaseFactory() async =>
    sqflite.databaseFactory;

/// 数据库落地到平台默认的 databases 目录。
Future<String> resolveDatabasePath(String name) async {
  final dir = await sqflite.getDatabasesPath();
  return dir.endsWith('/') ? '$dir$name' : '$dir/$name';
}
