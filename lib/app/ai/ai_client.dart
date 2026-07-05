// AI 聊天补全客户端的条件导入门面：真实平台用 `dart:io HttpClient`，
// 测试宿主用抛错 stub（与 WebDAV 客户端同款平台适配约定）。
export 'ai_client_stub.dart' if (dart.library.io) 'ai_client_io.dart';
