import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

/// 某附件字节在文件缺失时的物化回调。
///
/// 迁移期专用：库里仍有旧版 base64（`attachments.data_url`）而文件尚未生成时，
/// 由控制器实现本回调把 base64 解成文件。回调必须幂等，且只有在写入成功后才允许
/// 清空该行的 `data_url`。
typedef AttachmentMaterializer = Future<void> Function(String id);

/// 附件（票据图片）字节的唯一读写入口。
///
/// 设计见 `docs/dev/attachment-storage-and-streaming-backup-design.md`：一张附件一个
/// 文件，SQLite 只保存元数据，因此启动只读元数据、备份与恢复可逐张流式处理，内存
/// 不再随附件总量增长。绘制层禁止自行拼路径或直接使用 `File`，一律经本入口。
abstract interface class AttachmentStore {
  /// 确保根目录就绪。
  Future<void> ensureReady();

  /// 该附件当前是否已有文件。
  bool existsSync(String id);

  Future<bool> exists(String id);

  /// 单张附件的字节数；文件缺失返回 0。
  Future<int> sizeOf(String id);

  /// 读取整张附件（会触发按需物化）。
  Future<Uint8List> readBytes(String id);

  /// 分块读取，供流式备份使用。
  Stream<List<int>> openRead(String id);

  /// 写入整张附件（临时文件 + 原子改名，避免中断留下半张图片）。
  Future<int> writeBytes(String id, List<int> bytes);

  /// 从任意字节流写入整张附件。
  Future<int> writeStream(String id, Stream<List<int>> chunks);

  Future<void> delete(String id);

  Future<void> deleteMany(Iterable<String> ids);

  /// 删除不再被任何元数据引用的附件文件，返回删除数量。用于导入/恢复/删除后回收。
  Future<int> collectOrphans(Set<String> aliveIds);

  /// 创建一个独立的暂存存储：导入/恢复期间先把附件字节落在这里，全部校验通过后再
  /// 逐条并入主存储；任何一步失败直接丢弃暂存即可，现有数据零改动。
  Future<AttachmentStore> createStagingStore();

  /// 丢弃某个暂存存储（删除其目录 / 内存内容）。
  Future<void> discardStagingStore(AttachmentStore store);

  /// 清理遗留的暂存目录（冷启动回收中断的导入）。
  Future<void> purgeStaging();

  /// 供图片渲染使用的 provider。
  ImageProvider imageProviderFor(String id, {int? cacheWidth});

  /// 注册迁移期物化回调（控制器在创建后注入；幂等，可覆盖）。
  void setMaterializer(AttachmentMaterializer? materializer);
}

/// 生产实现：附件字节落在应用私有支持目录下的普通文件。
class FileAttachmentStore implements AttachmentStore {
  FileAttachmentStore({
    required Directory root,
    AttachmentMaterializer? materializer,
    // ignore: prefer_initializing_formals
  }) : _root = root,
       // ignore: prefer_initializing_formals
       _materializer = materializer;

  /// 暂存子目录名（以点开头，不参与 [collectOrphans] 的存活判定）。
  static const String stagingDirectoryName = '.staging';

  final Directory _root;
  AttachmentMaterializer? _materializer;

  @override
  void setMaterializer(AttachmentMaterializer? materializer) {
    _materializer = materializer;
  }

  Directory get directory => _root;

  Directory get stagingRoot =>
      Directory(p.join(_root.path, stagingDirectoryName));

  @override
  Future<void> ensureReady() => _root.create(recursive: true);

  @override
  bool existsSync(String id) => File(_pathFor(id)).existsSync();

  @override
  Future<bool> exists(String id) async {
    if (await File(_pathFor(id)).exists()) {
      return true;
    }
    await _materialize(id);
    return File(_pathFor(id)).exists();
  }

  @override
  Future<int> sizeOf(String id) async {
    final file = File(_pathFor(id));
    if (!await file.exists()) {
      await _materialize(id);
    }
    return (await file.exists()) ? file.length() : 0;
  }

  @override
  Future<Uint8List> readBytes(String id) async {
    await _ensureFile(id);
    return File(_pathFor(id)).readAsBytes();
  }

  @override
  Stream<List<int>> openRead(String id) async* {
    await _ensureFile(id);
    yield* File(_pathFor(id)).openRead();
  }

  @override
  Future<int> writeBytes(String id, List<int> bytes) async {
    await ensureReady();
    final target = File(_pathFor(id));
    final temp = File('${target.path}.part');
    if (await temp.exists()) {
      await temp.delete();
    }
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(target.path);
    return bytes.length;
  }

  @override
  Future<int> writeStream(String id, Stream<List<int>> chunks) async {
    await ensureReady();
    final target = File(_pathFor(id));
    final temp = File('${target.path}.part');
    if (await temp.exists()) {
      await temp.delete();
    }
    final sink = temp.openWrite();
    var total = 0;
    try {
      await for (final chunk in chunks) {
        sink.add(chunk);
        total += chunk.length;
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    await temp.rename(target.path);
    return total;
  }

  @override
  Future<void> delete(String id) async {
    final file = File(_pathFor(id));
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<void> deleteMany(Iterable<String> ids) async {
    for (final id in ids) {
      await delete(id);
    }
  }

  @override
  Future<int> collectOrphans(Set<String> aliveIds) async {
    if (!await _root.exists()) {
      return 0;
    }
    var removed = 0;
    await for (final entity in _root.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final name = p.basename(entity.path);
      if (name.endsWith('.part')) {
        await entity.delete();
        removed++;
        continue;
      }
      if (aliveIds.contains(name)) {
        continue;
      }
      await entity.delete();
      removed++;
    }
    return removed;
  }

  @override
  Future<AttachmentStore> createStagingStore() async {
    await ensureReady();
    final token = '${DateTime.now().microsecondsSinceEpoch}_${_stagingSeq++}';
    final dir = Directory(p.join(stagingRoot.path, token));
    await dir.create(recursive: true);
    return FileAttachmentStore(root: dir);
  }

  @override
  Future<void> discardStagingStore(AttachmentStore store) async {
    final dir = (store as FileAttachmentStore).directory;
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  @override
  Future<void> purgeStaging() async {
    final dir = stagingRoot;
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  @override
  ImageProvider imageProviderFor(String id, {int? cacheWidth}) {
    return FileImage(File(_pathFor(id)));
  }

  String _pathFor(String id) => p.join(_root.path, id);

  Future<void> _ensureFile(String id) async {
    if (existsSync(id)) {
      return;
    }
    await _materialize(id);
  }

  Future<void> _materialize(String id) async {
    final materializer = _materializer;
    if (materializer == null) {
      return;
    }
    await materializer(id);
  }

  static int _stagingSeq = 0;
}

/// 测试实现：附件字节留在内存，避免 widget 测试的 fake-async 与真实文件 I/O 冲突。
class InMemoryAttachmentStore implements AttachmentStore {
  final Map<String, Uint8List> _files = <String, Uint8List>{};
  final Set<AttachmentStore> _stagingStores = <AttachmentStore>{};

  AttachmentMaterializer? materializer;

  @override
  void setMaterializer(AttachmentMaterializer? materializer) {
    this.materializer = materializer;
  }

  @override
  Future<void> ensureReady() async {}

  @override
  bool existsSync(String id) => _files.containsKey(id);

  @override
  Future<bool> exists(String id) async {
    if (_files.containsKey(id)) {
      return true;
    }
    await materializer?.call(id);
    return _files.containsKey(id);
  }

  @override
  Future<int> sizeOf(String id) async {
    if (!_files.containsKey(id)) {
      await materializer?.call(id);
    }
    return _files[id]?.length ?? 0;
  }

  @override
  Future<Uint8List> readBytes(String id) async {
    if (!_files.containsKey(id)) {
      await materializer?.call(id);
    }
    final bytes = _files[id];
    if (bytes == null) {
      throw StateError('附件不存在：$id');
    }
    return bytes;
  }

  @override
  Stream<List<int>> openRead(String id) async* {
    yield await readBytes(id);
  }

  @override
  Future<int> writeBytes(String id, List<int> bytes) async {
    _files[id] = Uint8List.fromList(bytes);
    return bytes.length;
  }

  @override
  Future<int> writeStream(String id, Stream<List<int>> chunks) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in chunks) {
      builder.add(chunk);
    }
    final bytes = builder.takeBytes();
    _files[id] = bytes;
    return bytes.length;
  }

  @override
  Future<void> delete(String id) async {
    _files.remove(id);
  }

  @override
  Future<void> deleteMany(Iterable<String> ids) async {
    for (final id in ids) {
      _files.remove(id);
    }
  }

  @override
  Future<int> collectOrphans(Set<String> aliveIds) async {
    final orphans = _files.keys
        .where((id) => !aliveIds.contains(id))
        .toList(growable: false);
    for (final id in orphans) {
      _files.remove(id);
    }
    return orphans.length;
  }

  @override
  Future<AttachmentStore> createStagingStore() async {
    final store = InMemoryAttachmentStore();
    _stagingStores.add(store);
    return store;
  }

  @override
  Future<void> discardStagingStore(AttachmentStore store) async {
    _stagingStores.remove(store);
    if (store is InMemoryAttachmentStore) {
      store._files.clear();
    }
  }

  @override
  Future<void> purgeStaging() async {
    for (final store in _stagingStores) {
      if (store is InMemoryAttachmentStore) {
        store._files.clear();
      }
    }
    _stagingStores.clear();
  }

  @override
  ImageProvider imageProviderFor(String id, {int? cacheWidth}) {
    return MemoryImage(_files[id] ?? Uint8List(0));
  }
}
