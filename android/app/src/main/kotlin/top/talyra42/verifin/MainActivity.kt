package top.talyra42.verifin

import android.Manifest
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

// local_auth 需要宿主是 FragmentActivity，故继承 FlutterFragmentActivity。
class MainActivity : FlutterFragmentActivity() {
    private var channel: MethodChannel? = null
    private var pendingQuickEntryIntent = false
    private var pendingDownloadsWrite: PendingDownloadsWrite? = null
    private var pendingDirectoryPick: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        rememberQuickEntryIntent(intent)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "consumeQuickEntryIntent" -> {
                    val shouldOpen = pendingQuickEntryIntent
                    pendingQuickEntryIntent = false
                    result.success(shouldOpen)
                }
                "updateWidgetData" -> {
                    updateWidgetData(call)
                    result.success(true)
                }
                "setSecureFlag" -> {
                    setSecureFlag(call.argument<Boolean>("secure") ?: false)
                    result.success(true)
                }
                "pinWidget" -> pinWidget(call.argument<String>("widget") ?: "", result)
                "checkLatestRelease" -> checkLatestRelease(
                    call.argument<Boolean>("includePrerelease") ?: false,
                    result,
                )
                "downloadLatestUpdate" -> downloadLatestUpdate(
                    call.argument<Boolean>("includePrerelease") ?: false,
                    result,
                )
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
                "writeBackupFile" -> writeBackupFile(
                    call.argument<String>("directoryUri") ?: "",
                    call.argument<String>("filename") ?: "verifin-backup.json",
                    call.argument<String>("content") ?: "",
                    call.argument<String>("mimeType") ?: "application/json",
                    result,
                )
                "writeBackupBytes" -> writeBackupBytes(
                    call.argument<String>("directoryUri") ?: "",
                    call.argument<String>("filename") ?: "verifin-backup.zip",
                    call.argument<ByteArray>("bytes") ?: ByteArray(0),
                    call.argument<String>("mimeType") ?: "application/zip",
                    result,
                )
                "readBackupBytes" -> readBackupBytes(
                    call.argument<String>("fileUri") ?: "",
                    result,
                )
                "listBackupFiles" -> listBackupFiles(
                    call.argument<String>("directoryUri") ?: "",
                    result,
                )
                "readBackupFile" -> readBackupFile(
                    call.argument<String>("fileUri") ?: "",
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

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == ACTION_QUICK_ENTRY) {
            if (channel == null) {
                pendingQuickEntryIntent = true
            } else {
                channel?.invokeMethod("openQuickEntry", null)
            }
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

    /// 一次写入三个小组件的全部字段并广播刷新各 Provider。字段由 Flutter 侧格式化。
    private fun updateWidgetData(call: io.flutter.plugin.common.MethodCall) {
        val values = mapOf(
            WidgetData.KEY_TODAY_AMOUNT to (call.argument<String>("todayAmount") ?: "0"),
            WidgetData.KEY_TODAY_LABEL to (call.argument<String>("todayLabel") ?: "今日支出"),
            WidgetData.KEY_BUDGET_AMOUNT to (call.argument<String>("budgetAmount") ?: "0"),
            WidgetData.KEY_BUDGET_LABEL to (call.argument<String>("budgetLabel") ?: "本月可用预算"),
            WidgetData.KEY_NET_WORTH_AMOUNT to (call.argument<String>("netWorthAmount") ?: "0"),
            WidgetData.KEY_NET_WORTH_LABEL to (call.argument<String>("netWorthLabel") ?: "资产总额"),
        )
        WidgetData.write(this, values)
        WidgetData.refresh(this, QuickEntryWidgetProvider::class.java)
        WidgetData.refresh(this, BudgetWidgetProvider::class.java)
        WidgetData.refresh(this, NetWorthWidgetProvider::class.java)
    }

    /// 请求把指定小组件固定到桌面（API 26+ 且启动器支持时弹系统添加弹窗）。
    /// 返回是否成功发起；不支持则返回 false，Flutter 侧回落为手动添加引导。
    private fun pinWidget(widget: String, result: MethodChannel.Result) {
        val provider = when (widget) {
            "quick_entry" -> QuickEntryWidgetProvider::class.java
            "budget" -> BudgetWidgetProvider::class.java
            "net_worth" -> NetWorthWidgetProvider::class.java
            else -> null
        }
        if (provider == null) {
            result.success(false)
            return
        }
        val manager = AppWidgetManager.getInstance(this)
        // 部分启动器（尤其国产 ROM）不支持一键固定，或调用时抛异常——一律安全回落，
        // 由 Flutter 侧展示手动添加引导。
        val ok = try {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                manager.isRequestPinAppWidgetSupported &&
                manager.requestPinAppWidget(ComponentName(this, provider), null, null)
        } catch (e: Exception) {
            false
        }
        result.success(ok)
    }

    private fun checkLatestRelease(includePrerelease: Boolean, result: MethodChannel.Result) {
        Thread {
            try {
                val response = checkLatestReleaseInfo(includePrerelease)
                runOnUiThread { result.success(response) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error(
                        "UPDATE_CHECK_FAILED",
                        error.message ?: "检查更新失败，请稍后再试。",
                        null,
                    )
                }
            }
        }.start()
    }

    private fun downloadLatestUpdate(includePrerelease: Boolean, result: MethodChannel.Result) {
        Thread {
            try {
                val response = downloadLatestReleaseAndInstall(includePrerelease)
                runOnUiThread { result.success(response) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error(
                        "UPDATE_DOWNLOAD_FAILED",
                        error.message ?: "下载更新失败，请稍后再试。",
                        null,
                    )
                }
            }
        }.start()
    }

    private fun checkLatestReleaseInfo(includePrerelease: Boolean): Map<String, Any> {
        val release = resolveRelease(includePrerelease)
        val latestTag = release.optString("tag_name")
        val latestVersion = latestTag.removePrefix("v")
        val isPrerelease = release.optBoolean("prerelease")
        val currentVersion = BuildConfig.VERSION_NAME
        if (latestVersion.isBlank()) {
            return mapOf(
                "status" to "error",
                "message" to "没有读取到最新版本号。",
                "currentVersion" to currentVersion,
                "latestVersion" to latestTag,
            )
        }
        if (!isNewerVersion(latestVersion, currentVersion)) {
            return mapOf(
                "status" to "upToDate",
                "message" to "当前已经是最新版本：v$currentVersion。",
                "currentVersion" to currentVersion,
                "latestVersion" to latestTag,
            )
        }
        findApkAssetUrl(release)
            ?: return mapOf(
                "status" to "noAsset",
                "message" to "发现 $latestTag，但 Release 中没有可安装的 APK。",
                "currentVersion" to currentVersion,
                "latestVersion" to latestTag,
            )
        return mapOf(
            "status" to "available",
            "message" to "发现新版本 $latestTag，可以下载并安装。",
            "currentVersion" to currentVersion,
            "latestVersion" to latestTag,
            "isPrerelease" to isPrerelease,
        )
    }

    /// 解析目标 Release：不含预发布时用 /releases/latest（GitHub 天然排除预发布/草稿）；
    /// 含预发布时拉 /releases 列表，剔除草稿后取版本号最高的一个（含预发布）。
    private fun resolveRelease(includePrerelease: Boolean): JSONObject {
        if (!includePrerelease) {
            return fetchLatestRelease()
        }
        val releases = fetchReleaseList()
        var best: JSONObject? = null
        var bestVersion = ""
        for (index in 0 until releases.length()) {
            val release = releases.optJSONObject(index) ?: continue
            if (release.optBoolean("draft")) {
                continue
            }
            val version = release.optString("tag_name").removePrefix("v")
            if (version.isBlank()) {
                continue
            }
            if (best == null || isNewerVersion(version, bestVersion)) {
                best = release
                bestVersion = version
            }
        }
        // 列表为空/异常时回退到稳定版通道，避免整功能不可用。
        return best ?: fetchLatestRelease()
    }

    private fun downloadLatestReleaseAndInstall(includePrerelease: Boolean): Map<String, Any> {
        val release = resolveRelease(includePrerelease)
        val latestTag = release.optString("tag_name")
        val latestVersion = latestTag.removePrefix("v")
        val currentVersion = BuildConfig.VERSION_NAME
        if (latestVersion.isBlank()) {
            return mapOf(
                "status" to "error",
                "message" to "没有读取到最新版本号。",
                "currentVersion" to currentVersion,
                "latestVersion" to latestTag,
            )
        }
        if (!isNewerVersion(latestVersion, currentVersion)) {
            return mapOf(
                "status" to "upToDate",
                "message" to "当前已经是最新版本：v$currentVersion。",
                "currentVersion" to currentVersion,
                "latestVersion" to latestTag,
            )
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName"),
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
            return mapOf(
                "status" to "error",
                "message" to "请先允许 VeriFin 安装未知应用，授权后再次点击下载新版本。",
                "currentVersion" to currentVersion,
                "latestVersion" to latestTag,
            )
        }
        val apkUrl = findApkAssetUrl(release)
            ?: return mapOf(
                "status" to "noAsset",
                "message" to "发现 $latestTag，但 Release 中没有可安装的 APK。",
                "currentVersion" to currentVersion,
                "latestVersion" to latestTag,
            )
        val apkFile = downloadApk(apkUrl, latestTag)
        startApkInstall(apkFile)
        return mapOf(
            "status" to "installing",
            "message" to "发现 $latestTag，已下载并打开安装确认。",
            "currentVersion" to currentVersion,
            "latestVersion" to latestTag,
        )
    }

    private fun fetchLatestRelease(): JSONObject = JSONObject(fetchGithubJson(RELEASE_API_URL))

    private fun fetchReleaseList(): JSONArray = JSONArray(fetchGithubJson(RELEASE_LIST_API_URL))

    private fun fetchGithubJson(urlString: String): String {
        val connection = URL(urlString).openConnection() as HttpURLConnection
        connection.requestMethod = "GET"
        connection.setRequestProperty("Accept", "application/vnd.github+json")
        connection.setRequestProperty("User-Agent", "VeriFin/${BuildConfig.VERSION_NAME}")
        connection.connectTimeout = 15_000
        connection.readTimeout = 15_000
        val code = connection.responseCode
        // errorStream 在部分错误场景下为 null（如连接被重置、无响应体）。
        val stream = if (code in 200..299) connection.inputStream else connection.errorStream
        val body = stream?.bufferedReader()?.use { it.readText() } ?: ""
        connection.disconnect()
        if (code !in 200..299) {
            throw IllegalStateException("GitHub Release 查询失败：HTTP $code")
        }
        return body
    }

    private fun findApkAssetUrl(release: JSONObject): String? {
        val assets = release.optJSONArray("assets") ?: return null
        for (index in 0 until assets.length()) {
            val asset = assets.optJSONObject(index) ?: continue
            val name = asset.optString("name")
            val url = asset.optString("browser_download_url")
            if (name.endsWith(".apk", ignoreCase = true) && url.isNotBlank()) {
                return url
            }
        }
        return null
    }

    private fun downloadApk(downloadUrl: String, tag: String): File {
        val updatesDir = File(cacheDir, "updates").apply { mkdirs() }
        updatesDir.listFiles()?.forEach { it.delete() }
        val apkFile = File(updatesDir, "verifin-$tag.apk")
        val connection = URL(downloadUrl).openConnection() as HttpURLConnection
        connection.requestMethod = "GET"
        connection.setRequestProperty("User-Agent", "VeriFin/${BuildConfig.VERSION_NAME}")
        connection.connectTimeout = 15_000
        connection.readTimeout = 60_000
        val code = connection.responseCode
        if (code !in 200..299) {
            connection.disconnect()
            throw IllegalStateException("APK 下载失败：HTTP $code")
        }
        val totalBytes = connection.contentLengthLong.takeIf { it > 0 } ?: 0
        sendDownloadProgress(0, totalBytes)
        connection.inputStream.use { input ->
            apkFile.outputStream().use { output ->
                val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                var received = 0L
                var lastProgress = -1
                while (true) {
                    val read = input.read(buffer)
                    if (read == -1) {
                        break
                    }
                    output.write(buffer, 0, read)
                    received += read
                    val progress = if (totalBytes > 0) {
                        ((received * 100) / totalBytes).toInt()
                    } else {
                        0
                    }
                    if (progress != lastProgress) {
                        lastProgress = progress
                        sendDownloadProgress(received, totalBytes)
                    }
                }
            }
        }
        val finalSize = apkFile.length()
        sendDownloadProgress(finalSize, totalBytes.takeIf { it > 0 } ?: finalSize)
        connection.disconnect()
        return apkFile
    }

    private fun sendDownloadProgress(receivedBytes: Long, totalBytes: Long) {
        val progress = if (totalBytes > 0) {
            receivedBytes.toDouble() / totalBytes.toDouble()
        } else {
            0.0
        }.coerceIn(0.0, 1.0)
        runOnUiThread {
            channel?.invokeMethod(
                "updateDownloadProgress",
                mapOf(
                    "receivedBytes" to receivedBytes,
                    "totalBytes" to totalBytes,
                    "progress" to progress,
                ),
            )
        }
    }

    private fun startApkInstall(apkFile: File) {
        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            apkFile,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
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

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_PICK_BACKUP_DIR) {
            return
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

    private fun writeBackupFile(
        directoryUri: String,
        filename: String,
        content: String,
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
                contentResolver.openOutputStream(file.uri)?.use { output ->
                    output.write(content.toByteArray(Charsets.UTF_8))
                } ?: throw IllegalStateException("无法写入备份文件。")
                runOnUiThread { result.success(file.uri.toString()) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("BACKUP_FAILED", error.message ?: "写入备份失败。", null)
                }
            }
        }.start()
    }

    private fun writeBackupBytes(
        directoryUri: String,
        filename: String,
        bytes: ByteArray,
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
                contentResolver.openOutputStream(file.uri)?.use { output ->
                    output.write(bytes)
                } ?: throw IllegalStateException("无法写入备份文件。")
                runOnUiThread { result.success(file.uri.toString()) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("BACKUP_FAILED", error.message ?: "写入备份失败。", null)
                }
            }
        }.start()
    }

    private fun readBackupBytes(fileUri: String, result: MethodChannel.Result) {
        Thread {
            try {
                val bytes = contentResolver.openInputStream(Uri.parse(fileUri))?.use { input ->
                    input.readBytes()
                } ?: throw IllegalStateException("无法读取备份文件。")
                runOnUiThread { result.success(bytes) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("BACKUP_READ_FAILED", error.message ?: "读取备份文件失败。", null)
                }
            }
        }.start()
    }

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
                                it.name?.endsWith(".zip") == true)
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

    private fun readBackupFile(fileUri: String, result: MethodChannel.Result) {
        Thread {
            try {
                val text = contentResolver.openInputStream(Uri.parse(fileUri))?.use { input ->
                    input.readBytes().toString(Charsets.UTF_8)
                } ?: throw IllegalStateException("无法读取备份文件。")
                runOnUiThread { result.success(text) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("BACKUP_READ_FAILED", error.message ?: "读取备份文件失败。", null)
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

    private fun isNewerVersion(latest: String, current: String): Boolean {
        val latestParts = latest.split(".", "-").map { it.toIntOrNull() ?: 0 }
        val currentParts = current.split(".", "-").map { it.toIntOrNull() ?: 0 }
        val maxSize = maxOf(latestParts.size, currentParts.size, 3)
        for (index in 0 until maxSize) {
            val left = latestParts.getOrElse(index) { 0 }
            val right = currentParts.getOrElse(index) { 0 }
            if (left != right) {
                return left > right
            }
        }
        return false
    }

    private data class PendingDownloadsWrite(
        val filename: String,
        val content: String,
        val mimeType: String,
        val result: MethodChannel.Result,
    )

    companion object {
        const val ACTION_QUICK_ENTRY = "top.talyra42.verifin.action.QUICK_ENTRY"
        private const val CHANNEL_NAME = "verifin/app"
        private const val REQUEST_WRITE_DOWNLOADS = 4301
        private const val REQUEST_PICK_BACKUP_DIR = 4302
        private const val RELEASE_API_URL =
            "https://api.github.com/repos/LumiDesk/verifin/releases/latest"
        // 预发布检查用列表端点：/releases/latest 天然排除预发布，需拉列表自行筛选。
        private const val RELEASE_LIST_API_URL =
            "https://api.github.com/repos/LumiDesk/verifin/releases?per_page=20"
    }
}
