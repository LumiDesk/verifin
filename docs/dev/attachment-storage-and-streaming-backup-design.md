# 附件文件化与流式备份

本文件记录「图片附件从库内 base64 改为文件存储」与「备份/恢复全链路流式化」的设计依据、
数据安全边界与验收标准。撰写动机见 Issue 45：用户数据量增长到数十~上百 MB 后，导入/恢复
与冷启动自动备份触发原生 `java.lang.OutOfMemoryError`，应用直接闪退。

## 背景与问题

崩溃堆栈为：

```
java.lang.OutOfMemoryError: Failed to allocate a 189350928 byte allocation
with 60855440 free bytes and 58MB until OOM,
target footprint 268435456, growth limit 268435456
  at java.util.Arrays.copyOf(Arrays.java:3578)
  at java.io.ByteArrayOutputStream.grow(ByteArrayOutputStream.java:120)
  at java.io.ByteArrayOutputStream.ensureCapacity(ByteArrayOutputStream.java:95)
```

`growth limit 268435456` 是设备给普通应用的 Java 堆上限（256 MiB）。失败点是一次约
180 MiB 的整块分配，即某处正在把整份数据（或其翻倍副本）放进 `ByteArrayOutputStream`。
这不是输入文件格式错误导致的，任何合法但足够大的备份都会触发。

改造前，所有涉及附件的环节都要求「整份进内存」，没有任何流式路径：

| 环节 | 现状 | 后果 |
| --- | --- | --- |
| 冷启动装载 | `SqliteLedgerRepository.loadAttachments()` 全表读取，Controller 的 `_attachments` 常驻全部 base64 | 内存与附件总量线性相关，冷启动随时可能崩 |
| 新增/删除图片 | `saveAttachments` 走 `_replaceAll` 整表覆盖 | 加一张图重写整张附件表 |
| 导出 | `exportDataJson` 生成内嵌 base64 的巨型 JSON 字符串，`packBackupArchive` 再 `jsonDecode`、逐张 `base64Decode`、`ZipEncoder().encode(archive)`、`Uint8List.fromList` | 同一时刻存在数份整卷拷贝 |
| 写备份 | `writeBackupBytesFile` 把整份 zip 当 `Uint8List` 过 MethodChannel | 即崩溃堆栈中的 `ByteArrayOutputStream` |
| 写后校验 | `BackupService._writeVerified` 把文件整份读回来逐字节比对 | 峰值内存再翻一倍 |
| 恢复读取 | `readBackupBytes`（原生 `readLimitedBytes`）与 `pickBackupBytes`（`XFile.readAsBytes`）整份读入 | 选完文件立刻崩 |
| 解包导入 | `unpackBackupArchive` 用 `ZipDecoder().decodeBytes` 全量解码，再拼回内嵌 base64 的巨型 JSON 字符串，`importDataJson` 再 `jsonDecode` | 又一份整卷 |
| 加密备份 | `encryptBackup` 对整份 JSON 字符串做 AES-GCM | 整卷 + 密文 |
| WebDAV | 上传 `request.add(整份 bytes)`，下载 `BytesBuilder` 累积 | 整卷 |

改造前的大小保护也拦不住：原生 `MAX_BACKUP_BYTES = 256 MiB`、Dart `maxBackupArchiveBytes =
256 MiB` 都等于或高于设备堆上限，还没读到阈值就 OOM；`maxBackupAttachmentCount = 2000`、
`maxBackupArchiveFileCount = 2048`、`_maxWebdavDownloadBytes = 256 MiB` 则会在数据正常增长后
直接拒绝合法备份。

**结论：问题不是「包太大」，而是「处理方式只会整包进内存」。** 用户每天记账、每笔附 3–5 张图，
备份达到 GB 级是正常状态，不能用大小上限规避。

## 目标与硬性要求

1. **内存有界**：任意链路的峰值内存只与「单张附件」和「固定分块」有关，与附件总量、备份体积无关。
   1 GB、10 GB 备份都能备份、恢复、上传、下载。
2. **不设大小上限**：删除 `MAX_BACKUP_BYTES`、`maxBackupArchive*`、`_maxWebdavDownloadBytes`
   等固定阈值；反向保护改为流式结构校验 + 可用磁盘空间检查，而非拒绝大数据。
3. **不丢数据**：存量库内 base64 附件必须完整迁移到文件；迁移可中断、可重试、幂等。
4. **可观测**：备份、导出、恢复、迁移都有百分比进度，可取消；成功、失败、文件损坏分别有明确提示。
5. **可校验**：写入后校验完整性，恢复时校验结构，损坏必须在落库前被拦下并报错。
6. **向后兼容**：仍能导入旧版明文 JSON（内嵌 base64）、旧版加密信封与 v3 zip 备份。

## 方案总览

1. 附件改为**文件存储**，SQLite 只保存元数据；读取/写入/删除都按单条进行。
2. 备份与恢复改为**暂存目录 + 流式 zip**，平台通道只传路径，不传字节数组。
3. 加密备份改为**流式容器**（加密 zip），旧信封仍可解密导入。
4. 进度、取消、完整性校验作为一等能力贯穿全链路。
5. 存量数据迁移是独立的、可中断的后台任务，与最小化的 schema 迁移分开。

## 一、附件文件化存储

### 目录布局

```
<appSupport>/                         # path_provider getApplicationSupportDirectory()
├── attachments/
│   └── <id>                          # 单张图片原始字节（JPEG），文件名即附件 id，无扩展名
├── attachments/.staging/<token>/     # 导入/恢复暂存，成功后并入主目录
└── backup_cache/                     # 备份/恢复的临时 zip、解密产物（用完即删）
```

文件不带扩展名，与 v3 zip 内 `attachments/<id>` 的条目名保持一致，迁移与备份都是直接搬运字节。
`id` 由现有 `_generateId` 生成，全局唯一，不会碰撞。

### 表结构（schema v17 → v18）

```sql
ALTER TABLE attachments ADD COLUMN mime_type TEXT NOT NULL DEFAULT 'image/jpeg';
ALTER TABLE attachments ADD COLUMN byte_size INTEGER NOT NULL DEFAULT 0;
```

`data_url` 列在迁移期保留（既是读取兜底，也是转换的输入）。全部转换完成后再重建表去掉该列并
`VACUUM` 回收空间：

```sql
CREATE TABLE attachments_new (
  id TEXT PRIMARY KEY, entry_id TEXT NOT NULL, sort_order INTEGER NOT NULL,
  mime_type TEXT NOT NULL, byte_size INTEGER NOT NULL);
INSERT INTO attachments_new SELECT id, entry_id, sort_order, mime_type, byte_size FROM attachments;
DROP TABLE attachments;
ALTER TABLE attachments_new RENAME TO attachments;
CREATE INDEX idx_attachments_entry ON attachments (entry_id);
VACUUM;
```

### 模型与映射

`Attachment` 去掉内联 `dataUrl`，改为 `id / entryId / mimeType / byteSize`；同步
`toJson`、`fromJson`、`toRow`、`fromRow` 四向映射与 `test/model_roundtrip_test.dart`。

编辑期需要携带「还没落库的新图片字节」，用独立的草稿类型表达（现有/新建二选一），不把大字段
塞回领域模型：

```dart
sealed class AttachmentDraft {
  const AttachmentDraft({required this.entryId});
  final String entryId;
}
class ExistingAttachmentDraft extends AttachmentDraft { final String id; /* 已落库，文件即数据 */ }
class NewAttachmentDraft extends AttachmentDraft { final String id; final Uint8List bytes; }
```

`saveEntryAggregate` 接收 `List<AttachmentDraft>`：新建草稿先写文件，再与交易、退款一并在事务内
写元数据；被移除的附件在提交成功后才删除文件（失败时旧文件仍在）。

### 共享入口

新增 `AttachmentStore`（`lib/app/attachments/attachment_store.dart`），是附件字节的唯一读写入口：

- `pathFor(id)` / `exists(id)` / `readBytes(id)` / `openRead(id)`
- `writeBytes(id, bytes)` / `writeFrom(InputStream)` / `delete(id)`
- 暂存：`beginStaging()` / `commitStaging()` / `discardStaging()`
- 维护：`collectOrphans(Set<String> aliveIds)`、`purgeStaleStaging()`

绘制层禁止各页自行拼路径或调用 `File`；这与其他共享件（`CategoryIconBox` 等）同一约束。

### 读取路径

- `attachmentsForEntry(entryId)` 继续返回按 `sortOrder` 排序的元数据列表。
- 缩略图用 `Image.file`，并传 `cacheWidth`（列表/网格）限制解码内存；全屏查看读原图。
- 需要字节本身时（导出、重新编码等）走 `AttachmentStore.readBytes`。
- 头像与资产封面仍存在 KV 里的小 data URL，继续用 `imageForSource`，不受本次改动影响。

### 自愈

- **孤儿文件**（有文件无行）：启动时清理，只保留 `.staging` 之外、被 DB 引用的 id。
- **缺失文件**（有行无文件）：该附件标记为不可用，界面显示占位，不再静默崩溃；日志记录。
- 清理与自愈都只删「确认无引用」的文件，任何判断不确定时保留文件。

## 二、存量迁移（不丢数据）

分两阶段，避免把重活塞进 `onUpgrade`：

1. **schema 迁移（`onUpgrade` 内，秒级）**：只加 `mime_type` / `byte_size` 两列。
2. **数据转换任务（应用启动后，后台，可中断）**：逐条把 `data_url` 解成文件并回写元数据。

转换任务规则：

- **混合读取兜底**：`AttachmentStore.readBytes` 发现文件不存在但 `data_url` 非空时，当场解码
  写文件并清空该行的 `data_url`。因此迁移期间应用功能完全正常，中断也不影响使用。
- **幂等**：目标文件已存在或 `data_url` 已清空即跳过；重复运行不产生副作用。
- **可中断**：每 N 条提交一次；被系统杀死后下次启动从剩余行继续。
- **进度可见**：通过 `ValueNotifier<MigrationProgress>` 上报；界面显示「正在整理图片附件 x%」
  的非阻塞提示，不阻塞记账。
- **失败可见**：单条失败记录日志并继续；整体失败给出可重试提示，绝不删除原始 `data_url`。
- **完成后回收**：全部转换成功后重建表去掉 `data_url` 并 `VACUUM`，同样带进度与失败提示。
- **空间检查**：转换前检查可用磁盘空间是否足以容纳「新增文件 + 临时重建表」，不足则暂停并提示，
  不半途而废。

**安全底线：只要 `data_url` 还在，数据就没丢。任何路径都不会在校验通过前删除它。**

## 三、备份与恢复全链路流式

### 暂存目录模型

恢复统一先落到暂存目录：`staging/backup.json` + `staging/attachments/<id>`。
所有格式（v3 zip、旧明文 JSON、旧加密信封、新加密容器）都归一到这个形态后再交给 Controller
导入。落库前若任一步失败，删除暂存目录即可，用户现有数据零影响。

### 打包（导出/备份）

保持 **v3 zip 容器形状不变**（`backup.json` + `attachments/<id>`），另外附加校验字段：

- `backup.json` 的附件项新增 `size` 与 `sha256`；旧版本读取时会忽略未知字段，仍可导入。
- 附件条目用 **store**（不压缩，JPEG 已压缩），`backup.json` 用 deflate。

实现走 `archive` 的磁盘流式编码器：`ZipFileEncoder` + `InputFileStream` +
`ArchiveFile.stream`，配置为 `CompressionType.none`；CRC 与写入均按 1 MB 分块。
`archive` 的 `ZipEncoder` 对 deflate 条目会在内存里缓冲该条目的压缩结果，因此**只对附件用
store、只对体积可控的 `backup.json` 用 deflate**。

打包产物先写 `<appSupport>/backup_cache/*.zip`，再交原生流式复制到目标位置，避免边打包边写
外部存储导致失败后留下半个文件。

### 平台通道（不再传 byte[]）

新增原生方法，只传路径：

- `stageBackupFile(fileUri) -> cachePath`：SAF 文件流式复制到应用缓存，返回本地路径。
- `writeBackupFromCache(directoryUri, filename, cachePath) -> {uri, sha256, bytes}`：
  流式复制缓存文件到备份目录，**复制过程中同步计算 SHA-256 与字节数并回传**。
- `saveCacheFileToDownloads(filename, cachePath, mimeType) -> {sha256, bytes}`：下载目录导出同理。

Android 侧用 `ContentResolver.openInputStream/openOutputStream` 边读边写，固定缓冲区，逐步
把 `MainActivity` 里整包缓冲的 `readLimitedBytes` / `writeBackupBytes` 替换掉。

### 完整性校验

- 打包时流式计算产物 SHA-256；原生写入时再次流式计算；两侧不一致即判定写坏，报「备份校验失败」。
- 恢复时校验每个附件的 `size` 与 `sha256`（若备份提供），以及结构完整性（存在 `backup.json`、
  版本可识别、附件引用可解析）。
- `archive` 4.x 的 `ZipDecoder(verify: ...)` 校验分支已被注释掉，**不能依赖它做 CRC 校验**，
  完整性以备份内 `sha256` 为准。
- zip 炸弹防护改为：逐条目声明尺寸合理性检查 + 可用磁盘空间检查；不再用固定总量上限拒绝合法备份。

### 恢复（导入）流程

1. `stageBackupFile` 把外部文件流式复制到缓存，读首部判容器类型。
2. 按类型解到暂存目录（zip 流式解包 / 流式解密后解包 / 旧明文 JSON 流式转换）。
3. 校验完成后交给 Controller：解析 `backup.json`、重建账目数据、写附件文件、在事务内落库。
4. 提交成功后再清理暂存与被替换的旧附件文件（孤儿回收兜底）。
5. 全流程带进度；失败/取消时删除暂存与缓存，用户数据保持不变。

### 加密

- **新格式（已落地）**：`.verifin` 流式加密容器，布局为
  `VERIFIN-ENC2\n` + 一行 JSON 参数（`kdf` / `iter` / `salt` / `nonce`）+ `\n`
  + AES-GCM 密文 + 16 字节 MAC；密文里就是上面那个 zip。加解密走
  `cryptography` 的 `encryptStream` / `decryptStream`，按分块处理，不整卷进内存。
  口令错误或篡改由 GCM 认证失败捕获，映射为可读错误并允许重试。
- **旧格式**：现有 JSON 信封继续可解密导入（口令仍在设备 KV）；该路径仍需整份读入
  内存，作为历史格式记入 [已知限制 L8](known-limitations.md)。
- 文件名后缀用 `.verifin`：备份目录列表、文件选择器与 WebDAV 列表的过滤规则同步包含它。

### WebDAV

上传改为把缓存 zip 文件流式写入请求体；下载改为流式写入缓存文件。移除
`_maxWebdavDownloadBytes` 的固定上限，改由磁盘空间与结构校验保护。

### 旧格式兼容

| 来源 | 处理方式 |
| --- | --- |
| v3 zip（当前主线） | 流式解包到暂存目录 |
| 旧明文 JSON（v1/v2，内嵌 base64） | 流式解析，把每张 `dataUrl` 解码写文件，产出暂存目录 |
| 旧加密信封 | 流式解密得到旧明文 JSON，再按上一行处理 |

旧明文 JSON 是「单个大字符串里内嵌 base64」，`dart:convert` 无法流式解析。为此引入前向遍历的
流式 JSON 解析库（候选 `json_events`），以事件流重写文档：附件 `dataUrl` 边解析边落文件，
其余字段原样转发。这样旧格式同样不受体积限制。

## 四、进度与反馈

统一进度模型，由备份服务上报、界面订阅：

```dart
enum BackupPhase { preparing, packing, writing, verifying, reading, decrypting, unpacking, importing, cleaning }
class BackupProgress { final BackupPhase phase; final int done; final int total; final String? label; }
```

- 备份、导出、恢复、迁移共用同一个进度对话框组件（替换现有仅「转圈」的 `_BackupProgressDialog`），
  显示阶段文案、进度条、百分比与「取消」。
- 取消通过 cancel token 在条目/分块之间检查；取消后清理临时文件并提示「已取消」。
- 结果反馈：成功、失败、校验失败、文件损坏、格式不支持、空间不足分别有明确文案，全部走
  `VeriFeedbackHost`（阻塞式过程除外，见 `feedback-system.md`）。

## 五、依赖与选型

| 依赖 | 现状 | 计划 | 理由 |
| --- | --- | --- | --- |
| `archive` | `^4.0.9` | 锁定 `4.3.0` | 4.1.0 起修复了大文件相关的 `file_buffer`、路径分隔符问题；不跟随当天发布的 4.4.0。流式写用 `ZipEncoder.startEncode/add/endEncode` + `ArchiveFile.stream`，读用 `ZipDecoder.decodeStream(InputFileStream)` |
| `path_provider` | 未显式声明 | 新增 `^2.1.6` | 官方插件，解析应用支持目录；不自行拼接数据库目录 |
| `json_events` | 无 | 新增 `^1.2.2` | 仅用于旧明文 JSON 的流式解析；JSON 规范稳定，风险可控 |
| `cryptography` | `^2.7.0` | 不变 | 已有 `encryptStream` / `decryptStream` |
| `crypto` | `^3.0.6` | 不变 | 已用于应用锁，可直接算 SHA-256 |

不引入原生 zip/加密库：现有纯 Dart 依赖已能满足流式需求，避免增加 ABI、体积与 R8 风险。

## 六、测试与验收

自动化：

- 迁移矩阵 `test/migration_matrix_test.dart` 覆盖 v17 → v18；转换任务单独覆盖幂等、可中断、
  文件缺失兜底、孤儿清理。
- 附件往返：`toJson/fromJson/toRow/fromRow` 与 `test/model_roundtrip_test.dart`。
- 流式打包/解包往返，数据集显著超过旧上限（附件数量 > 2000、总量远超旧 256 MB 阈值）。
- 兼容导入：v1/v2 明文 JSON、旧加密信封、v3 zip 各留 fixture。
- 损坏用例：截断 zip、篡改附件字节、缺 `backup.json`、声明尺寸不符，均须在落库前报错且不改动现有数据。
- UI：进度对话框、取消、成功/失败/损坏文案。
- 评估内存上界：用一个远大于旧上限的数据集跑通全链路而不触发 OOM。

真机（GitHub CI release APK，`--flavor github`）：

- 大量图片附件下冷启动、备份、恢复、WebDAV 上传下载。
- 迁移过程中杀进程，重启后继续且数据完整。
- 恢复过程中杀进程，重启后现有数据完整。
- 磁盘空间不足、SAF 授权失效时的报错与恢复。

## 七、文档同步清单

- `docs/dev/tech-decisions.md`：更新「图片附件存储」「备份格式」「备份目录」「WebDAV」等条目，
  以及备份数据范围表中附件的表述。
- `docs/dev/architecture.md`、`docs/dev/components.md`：新增 `AttachmentStore`、进度组件与共享件。
- `docs/dev/known-limitations.md`：移除被本设计解决的大小限制条目；保留旧加密信封等仍需说明的边界。
- `README.md`、`docs/product.md`、`docs/acceptance-checklist.md`：附件与备份说明。
- `CHANGELOG.md`：用户可见的存储格式、迁移、进度与损坏提示变化。

## 已确认的取舍

1. **备份容器保持 v3 形状**（附件条目名、`dataUrl: ''` 与 `_archiveMime` 都不变，只新增
   `byteSize` 字段），保证「新版本导出的备份旧版本仍能导入」，也就是双向兼容。
2. **新加密备份改为流式加密容器**（`.verifin`），旧 JSON 信封只保留读取兼容。
3. **存量迁移走后台转换 + 非阻塞提示 + 混合读取兜底**，不做首启动阻塞式全量转换。

## 落地状态

| 部分 | 状态 |
| --- | --- |
| 附件文件化（`AttachmentStore`、schema v18、迁移任务、孤儿回收） | 已实现 |
| 备份/恢复流式（增量 zip 写盘、流式解包、原生流式复制、SHA-256 校验） | 已实现 |
| 加密备份流式容器 + 旧信封读取兼容 | 已实现 |
| 旧版明文 JSON 流式重写（`json_events`） | 已实现 |
| 进度条、取消、成功/失败/损坏提示 | 已实现 |
| WebDAV 流式上传/下载 | 已实现 |
| Android 真机与 CI release APK 验收 | 待 CI 与真机执行（本机无 Android SDK） |
