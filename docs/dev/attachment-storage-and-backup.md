# 附件存储与备份

本文描述 Veri Fin 当前的图片附件存储、备份、恢复和旧数据兼容契约。权威实现以
`lib/app/attachments/`、`lib/app/backup/`、`lib/data/` 与对应测试为准。

## 核心约束

- 权威账目与附件元数据只存 SQLite；附件图片字节只存应用私有目录下的独立文件。
- `AttachmentStore` 是附件字节的唯一读写入口。页面不得自行拼路径或直接操作附件文件。
- 冷启动只读取附件元数据列，不读取旧版 `data_url` 大字段。
- 备份、恢复、加密、WebDAV 与安装包文件复制都保持流式；峰值内存与附件总量、备份总体积无关。
- 恢复和导入只有在结构校验完成且整账本数据库事务成功后才提交内存状态。
- 用户相册原图、分享来源文件不属于应用，不得删除；应用只清理由 `image_picker` 或备份流程创建的缓存副本。

## 目录布局

```text
<appSupport>/
├── attachments/
│   └── <attachment-id>               # 单张图片原始字节，文件名即附件 id
├── attachments/.staging/<token>/     # 导入/恢复暂存
└── backup_cache/                     # 打包、解密、WebDAV 下载等临时文件
```

附件 id 只允许 `[A-Za-z0-9][A-Za-z0-9._-]{0,127}`，并拒绝 `.`、`..`、路径分隔符和绝对路径。
该校验同时位于备份解码层与 `FileAttachmentStore` 文件入口，外部备份不能借附件 id 写出附件目录。

## SQLite 与模型

当前 schema 为 **v19**。`attachments` 表包含：

```sql
CREATE TABLE attachments (
  id TEXT PRIMARY KEY,
  entry_id TEXT NOT NULL,
  sort_order INTEGER NOT NULL,
  mime_type TEXT NOT NULL,
  byte_size INTEGER NOT NULL,
  data_url TEXT
);
```

`data_url` 只用于承接尚未迁移的旧版内嵌图片，是历史兼容列，不是新写入路径。当前附件模型为：

```dart
class Attachment {
  final String id;
  final String entryId;
  final String mimeType;
  final int byteSize;
}
```

数据库的 `sort_order` 由附件在集合中的位置映射，不进入模型 JSON。`Attachment.toJson/fromJson`
与仓储的 `_attachmentToRow/_attachmentFromRow` 必须保持字段一致。附件按 `entryId` 关联交易，
删除交易时同步清理元数据与文件。

## 附件生命周期

### 新增与编辑

- `stageNewAttachment` 先生成唯一 id 并写入附件文件，返回尚未落库的 `Attachment` 元数据。
- 编辑页把最终 `List<Attachment>` 交给 `saveEntryAggregateDraftResult`；Controller 将交易、退款、附件元数据以及可选的“记住汇率”放在同一 repository 事务中保存。
- 数据库提交成功后才更新 Controller 内存。
- 被移除附件的文件在事务成功后删除；事务失败时旧文件保留，由下一次孤儿回收兜底。

### 批量添加

- 记账页「附件」chip 与交易详情附件卡的相册入口统一走 `pickAndAddAttachments`：
  相册一次可多选，拍照仍为单张；取消选择不产生任何改动。
- 图片按用户选择顺序逐张读取、压缩（最长边 1600、JPEG 80）并 `stageNewAttachment`；
  同一时刻只解码一张，峰值内存与单张原图有关，不随批量张数增长。
- 添加期间用 `runWithLoadingDialog` 显示不可关闭的进度对话框（动态文案
  `attachAddingProgress`），阻止用户在批量写入中途重复操作页面；页面离开时停止
  处理剩余图片，已暂存但未落库的文件由启动孤儿回收清理。
- 单张读取/解码失败会跳过并在 `AttachmentPickOutcome.failed` 里计数，结束后用
  轻提示告知已添加与跳过数量；全部失败或选择器打开失败给错误提示，失败详情只写
  本地日志，不记录图片内容、路径或 data URL。
- 批量添加不改变保存语义：快速记账仍在保存时提交附件元数据，交易详情仍走聚合
  草稿自动保存；备份、恢复和旧库 `data_url` 迁移路径均不受影响。

### 读取与展示

- `loadAttachments()` 只查询
  `id / entry_id / sort_order / mime_type / byte_size`，不读取 `data_url`。
- `attachmentsForEntry(entryId)` 返回按 `sortOrder` 排序的元数据。
- 图片通过 `AttachmentStore.imageProviderFor(id, cacheWidth: ...)` 渲染；列表缩小解码尺寸，全屏查看使用原图。
- `readBytes` / `openRead` 发现文件不存在且旧 `data_url` 仍存在时，先物化文件再读取。

### 删除与孤儿回收

- 删除附件元数据成功后才删除对应文件。
- 启动维护会清理不在当前元数据集合中的文件和遗留 `.part` 临时文件，并清理中断的暂存目录。
- 清理失败只记录日志，不影响账目读写。

## `AttachmentStore` 契约

`AttachmentStore` 的当前公共能力：

- 就绪与查询：`ensureReady`、`existsSync`、`exists`、`sizeOf`
- 读取：`readBytes`、`openRead`
- 写入：`writeBytes`、`writeStream`。写入使用同目录临时文件并原子改名。
- 删除与维护：`delete`、`deleteMany`、`collectOrphans`
- 导入暂存：`createStagingStore`、`discardStagingStore`、`purgeStaging`
- 渲染：`imageProviderFor`
- 旧数据物化：`setMaterializer`
- 临时目录：`ensureCacheDirectory`

生产实现是 `FileAttachmentStore`，测试使用 `InMemoryAttachmentStore`。测试实现不得被生产入口使用。

## 旧版 `data_url` 迁移

旧库可能仍把 base64 图片存在 `attachments.data_url`。迁移规则如下：

1. `loadAttachments()` 始终只取元数据，避免冷启动把几十到上百 MB base64 读入内存。
2. `loadAttachmentDataUrl(id)` 只在单条附件需要物化时读取旧字段。
3. `migrateLegacyAttachments()` 逐条把旧字节写成文件，写文件成功后才清空该行的 `data_url`。
4. 单条失败会记录日志并继续；只要 `data_url` 还在，数据就没有丢。
5. 全部转换完成后，`dropLegacyAttachmentData()` 重建表去掉旧列并执行 `VACUUM`；只要仍有非空 `data_url` 就拒绝回收。
6. 所有整账本整替路径都必须保留未迁移行的 `data_url`，包括导入、恢复、重置、删账本和启动自愈。

迁移没有单独的磁盘预检：写文件失败会保留 `data_url`，下次启动继续尝试。恢复备份前的解包在 Android
上会检查可用空间；桌面端没有统一 API，因此跳过硬预检，失败同样在数据库提交前中止。

## 备份容器

### 未加密备份

未加密备份是 zip：

- `backup.json`：JSON payload 当前为 **v4**，分类与标签带 `bookId`。
- `attachments/<id>`：附件文件，使用 store 模式，不重复压缩已压缩图片。
- `backup.json` 中的附件项包含 `byteSize`；每条附件另有 ZIP CRC-32。
- 整个产物写盘后计算 SHA-256；原生流式写入目标位置时再次计算并与打包结果比对。
- 附件条目与索引条目每次解压上限为 **64 MiB**；归档文件数量和附件数量上限各为 **200000**。

### 加密备份

新版加密备份为 `.verifin` 流式容器：

```text
VERIFIN-ENC2\n
{"kdf":"pbkdf2-sha256","iter":...,"salt":"...","nonce":"..."}\n
<AES-GCM ciphertext>
<16-byte MAC>
```

- 密文内容就是未加密备份中的 zip。
- 使用 AES-256-GCM 与 PBKDF2-SHA256；迭代次数有上下限，salt、nonce 与 MAC 长度全部校验。
- 解密写同目录 `.partial` 文件；GCM 认证成功后才原子改名为最终 zip，失败或取消会清理临时输出。
- 旧版 JSON 加密信封继续支持导入，但该历史格式需要整份读入内存，见
  [known-limitations.md](known-limitations.md) L8。

## 打包与解包

### 打包

`packBackupArchiveToFile` 使用 `OutputFileStream` + `ZipEncoder` 增量写盘：

1. 从导出 JSON 读取附件元数据。
2. 逐张通过 `AttachmentStore.readBytes` 读取，写入 `attachments/<id>`。
3. 附件只保留当前正在处理的这一张在内存中。
4. 最后写入 `backup.json`。

任一张附件缺失或为空时整次备份失败，不生成缺附件的备份。

### 解包

`unpackBackupArchiveFile` 使用 `InputFileStream` + `ZipDecoder.decodeStream`：

- 只接受 `backup.json` 与 `attachments/<单段合法 id>`。
- 每个条目先检查声明尺寸，再通过限流输出流限制实际解压大小。
- 附件写入暂存 `AttachmentStore`，并校验 CRC-32。
- 实际解出字节数必须与 `byteSize` 一致。
- Android 在写入附件前通过 `StatFs` 检查缓存目录可用空间。
- 解包失败、取消或索引缺失时不会修改现有账目。

## 恢复与提交顺序

```text
选择 SAF 文件
  → 流式复制到应用缓存
  → 识别 zip / 明文 JSON / 旧加密信封 / .verifin
  → 解密、解包或旧 JSON 流式重写
  → 附件写入暂存 AttachmentStore
  → Controller 校验账目引用与金额
  → 附件并入主存储
  → replaceAllLedgerData 单事务落库
  → 成功后替换 Controller 内存与设备偏好
```

- 附件 id 与现有文件碰撞但字节不同时，导入会为备份附件分配新 id，不覆盖现有文件。
- 数据库提交失败时，本次新写入的附件文件会被删除，旧文件与旧账目保持可用。
- `replaceAllLedgerData` 是导入、恢复、重置、删账本及跨表删除的统一原子写入入口。

## 平台文件通道

恢复入口使用应用自己的 SAF 选择器，不支持把整份备份经 `file_selector` 读成字节。

| 通道 | 行为 |
| --- | --- |
| `pickBackupFile` | 返回 SAF `content://` URI、文件名与可选大小，不读取正文 |
| `stageBackupFile` | 流式复制到应用缓存；本地普通文件返回 `owned=false` |
| `writeBackupFromCache` | 流式写入备份目录，同时计算 SHA-256 与字节数 |
| `saveCacheFileToDownloads` | 流式写入系统 Downloads |
| `deleteCacheFile` | 只允许删除应用缓存目录树内的文件 |
| `availableBytes` | Android `StatFs` 返回目标目录可用字节数 |

账单等小文件仍可使用 `file_selector`，但读取完成后必须删除插件生成的缓存副本。

## WebDAV

- 上传从缓存文件分块读取并流式写入 PUT 请求体；下载从响应流分块写入缓存文件。
- 手动上传/下载接受取消回调；取消时抛出 `BackupCancelledException`，关闭客户端并删除下载残片。
- 上传等待响应、下载空闲读取使用超时；自动备份协调器另有整体超时兜底。
- WebDAV 不设固定下载总大小上限，最终由文件系统、结构校验与单条解压限制保护。

## 进度与反馈

`BackupPhase` 当前阶段：

```text
preparing, packing, writing, verifying, reading, decrypting,
encrypting, unpacking, importing, cleaning
```

进度通过 `BackupProgress{phase, fraction, detail}` 上报。恢复、备份和导出在阻塞进度对话框中显示阶段与百分比；
用户取消统一提示“已取消”。成功、校验失败、格式错误、空间不足分别使用本地化反馈。

## 当前限制

- 单个 zip 条目（索引或附件）上限为 64 MiB；合法备份总量不设固定上限。
- 旧版 JSON 加密信封解密仍需整份信封进入内存。
- Android 10 以下向下载目录导出时没有 MediaStore 流式通道，只能回退到系统“保存到”选择器。

## 自动化验收

- `test/backup_archive_test.dart`：zip 往返、垃圾 id、重复 id、CRC、尺寸上限、空间预检。
- `test/backup_security_test.dart`：附件路径穿越、超大条目、旧格式非法 id。
- `test/backup_test.dart`：明文、加密、旧格式、取消、缓存清理与完整导入。
- `test/backup_crypto_test.dart`：AES-GCM 往返、错误口令、篡改与 `.partial` 清理。
- `test/attachment_legacy_data_test.dart`：旧 `data_url` 物化、幂等、列回收和整替保留。
- `test/attachment*_test.dart` / `test/attachments_test.dart`：附件元数据、批量保存、删除与渲染。
- `test/webdav_client_test.dart`：本机 HTTP 服务器下的取消、超时与失败清理。

真机或模拟器还应覆盖：

- 带大量图片的冷启动、备份、恢复与 WebDAV 往返。
- 迁移中杀进程、恢复中杀进程后重启的数据完整性。
- 磁盘空间不足、SAF 授权失效、错误备份密码和取消下载。
