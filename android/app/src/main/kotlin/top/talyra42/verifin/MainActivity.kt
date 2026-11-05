package top.talyra42.verifin

import android.Manifest
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.StatFs
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.security.MessageDigest

// local_auth 需要宿主是 FragmentActivity，故继承 FlutterFragmentActivity。
class MainActivity : FlutterFragmentActivity() {
    private var channel: MethodChannel? = null
    private var widgetPreview: WidgetPreviewBridge? = null
    private var pendingQuickEntryIntent = false
    private var pendingWidgetRoute: Map<String, String>? = null
    private var pendingCaptureImageUri: Uri? = null
    private var pendingCaptureText: String? = null
    private var pendingDownloadsWrite: PendingDownloadsWrite? = null
    private var pendingDirectoryPick: MethodChannel.Result? = null
    private var pendingBackupFilePick: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // 进程/Activity 恢复时 getIntent() 仍是「最后一次启动意图」，可能正是用户
        // 已经消费过的组件快捷记账或分享采集。再次登记会把入口重放一遍（从图标
        // 或最近任务回到应用时凭空弹出记账键盘、或重跑一次 OCR）。只有真正的新
        // 启动才登记这些一次性入口。
        if (savedInstanceState == null) {
            rememberQuickEntryIntent(intent)
            rememberWidgetRouteIntent(intent)
            rememberCaptureIntent(intent)
        }
        super.onCreate(savedInstanceState)
        if (AppLockPreferences.isEnabled(this)) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        widgetPreview = WidgetPreviewBridge(this)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "renderWidgetPreview" -> widgetPreview!!.handle(call, result)
                "widgetInstanceCounts" -> widgetPreview!!.handle(call, result)
                "openApp" -> widgetPreview!!.handle(call, result)
                "consumeQuickEntryIntent" -> {
                    val shouldOpen = pendingQuickEntryIntent
                    pendingQuickEntryIntent = false
                    result.success(shouldOpen)
                }
                "consumeWidgetRoute" -> {
                    val route = pendingWidgetRoute
                    pendingWidgetRoute = null
                    result.success(route)
                }
                "consumeCaptureImage" -> consumeCaptureImage(result)
                "consumeCaptureText" -> {
                    val text = pendingCaptureText
                    pendingCaptureText = null
                    result.success(text)
                }
                "setSecureFlag" -> {
                    setSecureFlag(call.argument<Boolean>("secure") ?: false)
                    result.success(true)
                }
                "saveTextToDownloads" -> saveTextToDownloads(
                    call.argument<String>("filename") ?: "verifin-backup.json",
                    call.argument<String>("content") ?: "",
                    call.argument<String>("mimeType") ?: "application/json",
                    result,
                )
                "saveBytesToDownloads" -> saveBytesToDownloads(
                    call.argument<String>("filename") ?: "verifin-backup.zip",
                    call.argument<ByteArray>("bytes") ?: ByteArray(0),
                    call.argument<String>("mimeType") ?: "application/zip",
                    result,
                )
                "pickBackupDirectory" -> pickBackupDirectory(result)
                "pickBackupFile" -> pickBackupFile(result)
                "stageBackupFile" -> stageBackupFile(
                    call.argument<String>("fileUri") ?: "",
                    result,
                )
                "writeBackupFromCache" -> writeBackupFromCache(
                    call.argument<String>("directoryUri") ?: "",
                    call.argument<String>("filename") ?: "verifin-backup.zip",
                    call.argument<String>("cachePath") ?: "",
                    call.argument<String>("mimeType") ?: "application/zip",
                    result,
                )
                "saveCacheFileToDownloads" -> saveCacheFileToDownloads(
                    call.argument<String>("filename") ?: "verifin-backup.zip",
                    call.argument<String>("cachePath") ?: "",
                    call.argument<String>("mimeType") ?: "application/zip",
                    result,
                )
                "deleteCacheFile" -> deleteCacheFile(
                    call.argument<String>("path") ?: "",
                    result,
                )
                "availableBytes" -> {
                    val path = call.argument<String>("path") ?: ""
                    val available = try {
                        StatFs(File(path).absolutePath).availableBytes
                    } catch (_: Exception) {
                        null
                    }
                    result.success(available)
                }
                "listBackupFiles" -> listBackupFiles(
                    call.argument<String>("directoryUri") ?: "",
                    result,
                )
                "deleteBackupFile" -> deleteBackupFile(
                    call.argument<String>("fileUri") ?: "",
                    result,
                )
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        widgetPreview?.close()
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == ACTION_QUICK_ENTRY) {
            // Keep the event pending until Dart acknowledges it. The shell may
            // not be mounted yet (consent/onboarding/app lock), in which case
            // the inbound method call has no registered handler and must not
            // consume the one-shot entry.
            pendingQuickEntryIntent = true
            channel?.invokeMethod("openQuickEntry", null)
        }
        if (isWidgetRouteIntent(intent)) {
            rememberWidgetRouteIntent(intent)
            // Same one-shot rule as quick entry: only the Dart dispatcher that
            // actually has a shell route handler consumes this value.
            channel?.invokeMethod("openWidgetRoute", pendingWidgetRoute)
        }
        if (intent.action == ACTION_CAPTURE_IMAGE || intent.action == ACTION_CAPTURE_TEXT) {
            rememberCaptureIntent(intent)
            // 引擎已就绪则立刻通知 Flutter 拉取；冷启动时由 Flutter 开屏主动 consume。
            channel?.invokeMethod("openSharedCapture", null)
        }
    }

    /// 记住分享/外部采集意图（由 ShareReceiverActivity 转发进来），待 Flutter 拉取。
    private fun rememberCaptureIntent(intent: Intent?) {
        when (intent?.action) {
            ACTION_CAPTURE_IMAGE -> {
                val uri = intent.getStringExtra(EXTRA_CAPTURE_IMAGE_URI)
                if (!uri.isNullOrBlank()) {
                    pendingCaptureImageUri = Uri.parse(uri)
                }
            }
            ACTION_CAPTURE_TEXT -> {
                val text = intent.getStringExtra(EXTRA_CAPTURE_TEXT)
                if (!text.isNullOrBlank()) {
                    // 外部送入的文本不可信，原生侧先做长度上限（Dart 侧还有截断）。
                    pendingCaptureText = text.take(MAX_CAPTURE_TEXT_LENGTH)
                }
            }
        }
    }

    /// 读取待识别的分享图片字节并清除。图片可能几 MB，放后台线程读；超限拒绝。
    private fun consumeCaptureImage(result: MethodChannel.Result) {
        val uri = pendingCaptureImageUri
        pendingCaptureImageUri = null
        if (uri == null) {
            result.success(null)
            return
        }
        Thread {
            try {
                val bytes = readCaptureImageBytes(uri)
                if (bytes == null || bytes.isEmpty()) {
                    runOnUiThread { result.success(null) }
                } else {
                    runOnUiThread { result.success(bytes) }
                }
            } catch (error: Exception) {
                // 分享方 URI 失效等异常按「没有待识别图片」处理，不打断开屏。
                runOnUiThread { result.success(null) }
            }
        }.start()
    }

    /// 外部 ContentProvider 的长度不可信，必须边读边累计；超过上限立即停止，不能先
    /// readBytes() 把任意大流装进内存后再检查，否则 exported 分享入口可触发 OOM。
    private fun readCaptureImageBytes(uri: Uri): ByteArray? {
        return contentResolver.openInputStream(uri)?.use { input ->
            val output = ByteArrayOutputStream(DEFAULT_BUFFER_SIZE)
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            var total = 0
            while (true) {
                val read = input.read(buffer)
                if (read == -1) break
                total += read
                if (total > MAX_CAPTURE_IMAGE_BYTES) {
                    return null
                }
                output.write(buffer, 0, read)
            }
            output.toByteArray()
        }
    }

    /// 开关 FLAG_SECURE：开启后应用内容不可截屏/录屏，且从最近任务缩略图中隐藏，
    /// 避免账户余额等敏感信息泄漏。由 Flutter 侧在启用应用锁时打开。
    private fun setSecureFlag(secure: Boolean) {
        runOnUiThread {
            if (secure) {
                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
        }
    }

    private fun rememberQuickEntryIntent(intent: Intent?) {
        if (intent?.action == ACTION_QUICK_ENTRY) {
            pendingQuickEntryIntent = true
        }
    }

    private fun isWidgetRouteIntent(intent: Intent?): Boolean =
        intent?.action == ACTION_WIDGET_ROUTE ||
            intent?.action == HOME_WIDGET_LAUNCH_ACTION

    private fun rememberWidgetRouteIntent(intent: Intent?) {
        if (!isWidgetRouteIntent(intent)) return
        val uri = intent?.data
        val path = uri?.pathSegments.orEmpty()
        pendingWidgetRoute = mapOf(
            "route" to (path.lastOrNull() ?: intent?.getStringExtra("widgetRoute") ?: "app"),
            "bookId" to (uri?.getQueryParameter("bookId") ?: intent?.getStringExtra("widgetBookId") ?: ""),
            "widgetId" to (path.firstOrNull() ?: intent?.getIntExtra("widgetId", 0)?.toString().orEmpty()),
        )
    }

    private fun saveTextToDownloads(
        filename: String,
        content: String,
        mimeType: String,
        result: MethodChannel.Result,
    ) {
        // Android 10 以下写公共下载目录需要运行时授予存储权限。
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.WRITE_EXTERNAL_STORAGE,
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            if (pendingDownloadsWrite != null) {
                result.error("EXPORT_FAILED", "已有导出任务在等待授权，请稍后再试。", null)
                return
            }
            pendingDownloadsWrite = PendingDownloadsWrite(filename, content, mimeType, result)
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                REQUEST_WRITE_DOWNLOADS,
            )
            return
        }
        writeTextToDownloads(filename, content, mimeType, result)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_WRITE_DOWNLOADS) {
            return
        }
        val pending = pendingDownloadsWrite ?: return
        pendingDownloadsWrite = null
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            writeTextToDownloads(pending.filename, pending.content, pending.mimeType, pending.result)
        } else {
            pending.result.error("EXPORT_FAILED", "需要存储权限才能导出到下载目录。", null)
        }
    }

    private fun writeTextToDownloads(
        filename: String,
        content: String,
        mimeType: String,
        result: MethodChannel.Result,
    ) {
        Thread {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    val values = ContentValues().apply {
                        put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
                        put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                        put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                        put(MediaStore.MediaColumns.IS_PENDING, 1)
                    }
                    val uri = contentResolver.insert(
                        MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                        values,
                    ) ?: throw IllegalStateException("无法创建下载文件")
                    contentResolver.openOutputStream(uri)?.use { output ->
                        output.write(content.toByteArray(Charsets.UTF_8))
                    } ?: throw IllegalStateException("无法写入下载文件")
                    values.clear()
                    values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                    contentResolver.update(uri, values, null, null)
                } else {
                    val downloadsDir = Environment.getExternalStoragePublicDirectory(
                        Environment.DIRECTORY_DOWNLOADS,
                    ).apply { mkdirs() }
                    File(downloadsDir, filename).writeText(content, Charsets.UTF_8)
                }
                runOnUiThread { result.success(true) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error(
                        "EXPORT_FAILED",
                        error.message ?: "导出失败，请稍后再试。",
                        null,
                    )
                }
            }
        }.start()
    }

    // ---- 备份目录（SAF）----

    private fun pickBackupDirectory(result: MethodChannel.Result) {
        if (pendingDirectoryPick != null) {
            result.error("PICK_BUSY", "已有目录选择在进行中，请稍后再试。", null)
            return
        }
        pendingDirectoryPick = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            )
        }
        try {
            startActivityForResult(intent, REQUEST_PICK_BACKUP_DIR)
        } catch (error: Exception) {
            pendingDirectoryPick = null
            result.error("PICK_FAILED", error.message ?: "无法打开目录选择器。", null)
        }
    }

    /// 让用户挑一个备份文件，只回传 SAF 的 `content://` URI 与元信息；字节由
    /// [stageBackupFile] 流式复制，避免经过 Flutter 插件时整份读进内存（Issue 45）。
    private fun pickBackupFile(result: MethodChannel.Result) {
        if (pendingBackupFilePick != null) {
            result.error("PICK_BUSY", "已有文件选择在进行中，请稍后再试。", null)
            return
        }
        pendingBackupFilePick = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            // `*/*` 是为了兼容把 .verifin 当成未知类型、或按 MIME 过滤不严的第三方文件管理器；
            // 具体格式仍由应用自己按魔数判定，选错文件会得到明确的「格式不正确」提示。
            type = "*/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf("application/json", "application/zip", "application/octet-stream"),
            )
        }
        try {
            startActivityForResult(intent, REQUEST_PICK_BACKUP_FILE)
        } catch (error: Exception) {
            pendingBackupFilePick = null
            result.error("PICK_FAILED", error.message ?: "无法打开文件选择器。", null)
        }
    }

    private fun completeBackupFilePick(resultCode: Int, data: Intent?) {
        val pending = pendingBackupFilePick ?: return
        pendingBackupFilePick = null
        val uri = if (resultCode == RESULT_OK) data?.data else null
        if (uri == null) {
            pending.success(null)
            return
        }
        var name: String? = null
        var size: Long? = null
        try {
            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (nameIndex >= 0 && !cursor.isNull(nameIndex)) {
                        name = cursor.getString(nameIndex)
                    }
                    val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                    if (sizeIndex >= 0 && !cursor.isNull(sizeIndex)) {
                        size = cursor.getLong(sizeIndex)
                    }
                }
            }
        } catch (error: Exception) {
            // 元信息读不到不影响导入：字节读取才是必需的。
            name = null
            size = null
        }
        pending.success(
            mapOf(
                "uri" to uri.toString(),
                "name" to (name ?: uri.lastPathSegment ?: ""),
                "size" to size,
            ),
        )
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            REQUEST_PICK_BACKUP_FILE -> {
                completeBackupFilePick(resultCode, data)
                return
            }
            REQUEST_PICK_BACKUP_DIR -> Unit
            else -> return
        }
        val pending = pendingDirectoryPick ?: return
        pendingDirectoryPick = null
        val treeUri = if (resultCode == RESULT_OK) data?.data else null
        if (treeUri == null) {
            pending.success(null)
            return
        }
        try {
            val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            contentResolver.takePersistableUriPermission(treeUri, flags)
            val label = DocumentFile.fromTreeUri(this, treeUri)?.name ?: treeUri.lastPathSegment
            pending.success(
                mapOf(
                    "uri" to treeUri.toString(),
                    "label" to (label ?: treeUri.toString()),
                ),
            )
        } catch (error: Exception) {
            pending.error("PICK_FAILED", error.message ?: "无法保存目录授权。", null)
        }
    }

    private fun backupTree(directoryUri: String): DocumentFile? {
        if (directoryUri.isEmpty()) {
            return null
        }
        return DocumentFile.fromTreeUri(this, Uri.parse(directoryUri))
    }

    // ---- 大文件流式复制 ----
    //
    // 备份/恢复/导出可能是 GB 级。MethodChannel 传 ByteArray 会把整包放进 Java 堆，
    // 超过设备堆上限直接 OutOfMemoryError（Issue 45）。以下方法一律只传路径，在原生
    // 侧边读边写固定缓冲区，并在复制过程中同步算出 SHA-256 供 Dart 侧比对。

    /// 把外部备份文件流式复制到应用缓存目录，返回本地路径与字节数。
    ///
    /// 接受 SAF `content://` URI，也兼容直接传入本地路径 / `file://`（旧调用方与测试）。
    /// 已经是本地普通文件时不再复制，原样返回并标 `owned=false`，调用方不得删除它。
    private fun stageBackupFile(fileUri: String, result: MethodChannel.Result) {
        Thread {
            try {
                if (fileUri.isEmpty()) {
                    throw IllegalStateException("无法读取备份文件。")
                }
                val uri = Uri.parse(fileUri)
                val scheme = uri.scheme?.lowercase()
                val localFile = when {
                    scheme == null -> File(fileUri)
                    scheme == "file" -> uri.path?.let { File(it) }
                    else -> null
                }
                if (localFile != null) {
                    if (!localFile.isFile) {
                        throw IllegalStateException("无法读取备份文件。")
                    }
                    runOnUiThread {
                        result.success(
                            mapOf(
                                "path" to localFile.absolutePath,
                                "bytes" to localFile.length(),
                                "owned" to false,
                            ),
                        )
                    }
                    return@Thread
                }
                val target = File(cacheDir, "backup_stage_${System.currentTimeMillis()}")
                var bytes = 0L
                contentResolver.openInputStream(uri)?.use { input ->
                    FileOutputStream(target).use { output ->
                        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                        while (true) {
                            val read = input.read(buffer)
                            if (read == -1) break
                            output.write(buffer, 0, read)
                            bytes += read
                        }
                        output.flush()
                    }
                } ?: throw IllegalStateException("无法读取备份文件。")
                runOnUiThread {
                    result.success(
                        mapOf(
                            "path" to target.absolutePath,
                            "bytes" to bytes,
                            "owned" to true,
                        ),
                    )
                }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error(
                        "BACKUP_READ_FAILED",
                        error.message ?: "读取备份文件失败。",
                        null,
                    )
                }
            }
        }.start()
    }

    /// 把缓存文件流式复制到备份目录（同名覆盖），返回目标 URI、SHA-256 与字节数。
    private fun writeBackupFromCache(
        directoryUri: String,
        filename: String,
        cachePath: String,
        mimeType: String,
        result: MethodChannel.Result,
    ) {
        Thread {
            try {
                val tree = backupTree(directoryUri)
                    ?: throw IllegalStateException("备份目录不可用，请重新选择。")
                tree.findFile(filename)?.delete()
                val file = tree.createFile(mimeType, filename)
                    ?: throw IllegalStateException("无法在备份目录创建文件。")
                val digest = MessageDigest.getInstance("SHA-256")
                var bytes = 0L
                contentResolver.openOutputStream(file.uri)?.use { output ->
                    FileInputStream(cachePath).use { input ->
                        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                        while (true) {
                            val read = input.read(buffer)
                            if (read == -1) break
                            output.write(buffer, 0, read)
                            digest.update(buffer, 0, read)
                            bytes += read
                        }
                        output.flush()
                    }
                } ?: throw IllegalStateException("无法写入备份文件。")
                runOnUiThread {
                    result.success(
                        mapOf(
                            "uri" to file.uri.toString(),
                            "sha256" to digest.digest().toHex(),
                            "bytes" to bytes,
                        ),
                    )
                }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("BACKUP_FAILED", error.message ?: "写入备份失败。", null)
                }
            }
        }.start()
    }

    /// 把缓存文件流式写入系统下载目录（zip 导出）。Android 10+ 用 MediaStore；
    /// 更低版本返回 null，由 Flutter 侧回退到系统「保存到」选择器。
    private fun saveCacheFileToDownloads(
        filename: String,
        cachePath: String,
        mimeType: String,
        result: MethodChannel.Result,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.success(null)
            return
        }
        Thread {
            try {
                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
                    put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }
                val uri = contentResolver.insert(
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                    values,
                ) ?: throw IllegalStateException("无法创建下载文件")
                val digest = MessageDigest.getInstance("SHA-256")
                var bytes = 0L
                contentResolver.openOutputStream(uri)?.use { output ->
                    FileInputStream(cachePath).use { input ->
                        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                        while (true) {
                            val read = input.read(buffer)
                            if (read == -1) break
                            output.write(buffer, 0, read)
                            digest.update(buffer, 0, read)
                            bytes += read
                        }
                        output.flush()
                    }
                } ?: throw IllegalStateException("无法写入下载文件")
                values.clear()
                values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                contentResolver.update(uri, values, null, null)
                runOnUiThread {
                    result.success(
                        mapOf(
                            "sha256" to digest.digest().toHex(),
                            "bytes" to bytes,
                        ),
                    )
                }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error(
                        "EXPORT_FAILED",
                        error.message ?: "导出失败，请稍后再试。",
                        null,
                    )
                }
            }
        }.start()
    }

    /// 删除应用缓存目录里的临时文件（备份/恢复收尾）。只允许删 cacheDir 树下（含子目录，
    /// 例如文件选择插件自己建的 `cache/<uuid>/`）的文件，顺带清掉空目录。
    private fun deleteCacheFile(path: String, result: MethodChannel.Result) {
        try {
            val cache = cacheDir.canonicalFile
            val target = File(path).canonicalFile
            val cachePrefix = cache.path + File.separator
            val inside = target.path == cache.path || target.path.startsWith(cachePrefix)
            val parent = target.parentFile
            val deleted = inside && (!target.exists() || target.delete())
            if (inside && parent != null && parent.canonicalFile.path != cache.path) {
                // 只清空壳目录：里面还有别的文件就留着。
                parent.list()?.isEmpty()?.let { empty ->
                    if (empty) parent.delete()
                }
            }
            result.success(deleted)
        } catch (error: Exception) {
            result.success(false)
        }
    }

    private fun ByteArray.toHex(): String =
        joinToString("") { "%02x".format(it) }

    // 写公共下载目录的字节版（zip 导出）。Android 10+ 用 MediaStore、无需权限；
    // 更低版本返回 false，由 Flutter 侧回退到系统「保存到」选择器。
    private fun saveBytesToDownloads(
        filename: String,
        bytes: ByteArray,
        mimeType: String,
        result: MethodChannel.Result,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.success(false)
            return
        }
        Thread {
            try {
                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
                    put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }
                val uri = contentResolver.insert(
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                    values,
                ) ?: throw IllegalStateException("无法创建下载文件")
                contentResolver.openOutputStream(uri)?.use { output ->
                    output.write(bytes)
                } ?: throw IllegalStateException("无法写入下载文件")
                values.clear()
                values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                contentResolver.update(uri, values, null, null)
                runOnUiThread { result.success(true) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("EXPORT_FAILED", error.message ?: "导出失败，请稍后再试。", null)
                }
            }
        }.start()
    }

    private fun listBackupFiles(directoryUri: String, result: MethodChannel.Result) {
        Thread {
            try {
                val tree = backupTree(directoryUri)
                if (tree == null || !tree.isDirectory) {
                    runOnUiThread { result.success(emptyList<Map<String, Any>>()) }
                    return@Thread
                }
                val files = tree.listFiles()
                    .filter {
                        it.isFile &&
                            (it.name?.endsWith(".json") == true ||
                                it.name?.endsWith(".zip") == true ||
                                it.name?.endsWith(".verifin") == true)
                    }
                    .map { doc ->
                        mapOf(
                            "uri" to doc.uri.toString(),
                            "name" to (doc.name ?: ""),
                            "modifiedAt" to doc.lastModified(),
                            "sizeBytes" to doc.length(),
                        )
                    }
                runOnUiThread { result.success(files) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("BACKUP_LIST_FAILED", error.message ?: "读取备份目录失败。", null)
                }
            }
        }.start()
    }

    private fun deleteBackupFile(fileUri: String, result: MethodChannel.Result) {
        Thread {
            try {
                val doc = DocumentFile.fromSingleUri(this, Uri.parse(fileUri))
                val deleted = doc?.delete() ?: false
                runOnUiThread { result.success(deleted) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("BACKUP_DELETE_FAILED", error.message ?: "删除备份文件失败。", null)
                }
            }
        }.start()
    }

    private data class PendingDownloadsWrite(
        val filename: String,
        val content: String,
        val mimeType: String,
        val result: MethodChannel.Result,
    )

    companion object {
        const val ACTION_QUICK_ENTRY = "top.talyra42.verifin.action.QUICK_ENTRY"
        const val ACTION_WIDGET_ROUTE = "top.talyra42.verifin.action.WIDGET_ROUTE"
        private const val HOME_WIDGET_LAUNCH_ACTION =
            "es.antonborri.home_widget.action.LAUNCH"

        /// 外部采集：自动化工具（Tasker 等）可显式发起，extra `text` 带账单原文；
        /// 分享文本/图片经 ShareReceiverActivity 归一到同两个内部 action。
        const val ACTION_CAPTURE_TEXT = "top.talyra42.verifin.action.CAPTURE_TEXT"
        const val ACTION_CAPTURE_IMAGE = "top.talyra42.verifin.action.CAPTURE_IMAGE"
        const val EXTRA_CAPTURE_TEXT = "text"
        const val EXTRA_CAPTURE_IMAGE_URI = "imageUri"
        private const val MAX_CAPTURE_TEXT_LENGTH = 8_000
        private const val MAX_CAPTURE_IMAGE_BYTES = 25 * 1024 * 1024
        private const val CHANNEL_NAME = "verifin/app"
        private const val REQUEST_WRITE_DOWNLOADS = 4301
        private const val REQUEST_PICK_BACKUP_DIR = 4302
        private const val REQUEST_PICK_BACKUP_FILE = 4303
    }
}
