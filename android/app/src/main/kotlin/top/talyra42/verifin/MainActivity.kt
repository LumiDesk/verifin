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
import java.io.FileOutputStream
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.concurrent.atomic.AtomicBoolean

// local_auth 需要宿主是 FragmentActivity，故继承 FlutterFragmentActivity。
class MainActivity : FlutterFragmentActivity() {
    private var channel: MethodChannel? = null
    private var pendingQuickEntryIntent = false
    private var pendingCaptureImageUri: Uri? = null
    private var pendingCaptureText: String? = null
    private var pendingDownloadsWrite: PendingDownloadsWrite? = null
    private var pendingDirectoryPick: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        rememberQuickEntryIntent(intent)
        rememberCaptureIntent(intent)
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
                "consumeCaptureImage" -> consumeCaptureImage(result)
                "consumeCaptureText" -> {
                    val text = pendingCaptureText
                    pendingCaptureText = null
                    result.success(text)
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
                "installDownloadedUpdate" -> installDownloadedUpdate(result)
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
                val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
                if (bytes == null || bytes.isEmpty() || bytes.size > MAX_CAPTURE_IMAGE_BYTES) {
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
            // 跨天/跨期自愈锚点（预算锚点为周期截止日 yyyy-MM-dd，支持自定义预算周期）。
            WidgetData.KEY_TODAY_DATE to (call.argument<String>("todayDate") ?: ""),
            WidgetData.KEY_TODAY_ZERO to (call.argument<String>("todayZeroAmount") ?: "0"),
            WidgetData.KEY_BUDGET_EXPIRY to (call.argument<String>("budgetExpiry") ?: ""),
            WidgetData.KEY_BUDGET_FULL to (call.argument<String>("budgetFullAmount") ?: "0"),
            WidgetData.KEY_BUDGET_FULL_LABEL to
                (call.argument<String>("budgetFullLabel") ?: "本月可用预算"),
        )
        WidgetData.write(this, values)
        WidgetData.refresh(this, QuickEntryWidgetProvider::class.java)
        WidgetData.refresh(this, BudgetWidgetProvider::class.java)
        WidgetData.refresh(this, NetWorthWidgetProvider::class.java)
        // 推送新数据后对齐下一次午夜刷新闹钟。
        WidgetRefreshScheduler.scheduleNextMidnight(this)
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
        // Dart 层已有 single-flight；原生层仍独立加锁，避免生命周期重建、未来新增入口
        // 或异常重复调用并发删除 / 写入同一个更新 APK。
        if (!UPDATE_DOWNLOAD_IN_PROGRESS.compareAndSet(false, true)) {
            result.success(
                mapOf(
                    "status" to "error",
                    "message" to "已有更新下载正在进行，请稍候。",
                    "currentVersion" to BuildConfig.VERSION_NAME,
                ),
            )
            return
        }
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
            } finally {
                UPDATE_DOWNLOAD_IN_PROGRESS.set(false)
            }
        }.start()
    }

    /// 重新拉起对「已下载」APK 的安装（用户在系统安装页点错取消后可再次触发，无需重下）。
    /// 找不到已下载文件时回 noAsset，供 Flutter 侧回退到重新下载。
    private fun installDownloadedUpdate(result: MethodChannel.Result) {
        val currentVersion = BuildConfig.VERSION_NAME
        if (UPDATE_DOWNLOAD_IN_PROGRESS.get()) {
            result.success(
                mapOf(
                    "status" to "error",
                    "message" to "更新仍在下载，请稍候。",
                    "currentVersion" to currentVersion,
                ),
            )
            return
        }
        val apkFile = downloadedApkFile()
        if (apkFile == null) {
            result.success(
                mapOf(
                    "status" to "noAsset",
                    "message" to "安装包已不存在，请重新下载。",
                    "currentVersion" to currentVersion,
                ),
            )
            return
        }
        val latestVersion = try {
            validateUpdateApk(apkFile)
        } catch (error: Exception) {
            apkFile.delete()
            result.success(
                mapOf(
                    "status" to "noAsset",
                    "message" to "已下载的安装包不完整，请重新下载。",
                    "currentVersion" to currentVersion,
                ),
            )
            return
        }
        if (!isNewerVersion(latestVersion, currentVersion)) {
            apkFile.delete()
            result.success(
                mapOf(
                    "status" to "upToDate",
                    "message" to "当前已经是最新版本：v$currentVersion。",
                    "currentVersion" to currentVersion,
                    "latestVersion" to "v$latestVersion",
                ),
            )
            return
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
            result.success(
                mapOf(
                    "status" to "error",
                    "message" to "请先允许 VeriFin 安装未知应用，授权后再次点击立即安装。",
                    "currentVersion" to currentVersion,
                    "latestVersion" to "v$latestVersion",
                ),
            )
            return
        }
        startApkInstall(apkFile)
        result.success(
            mapOf(
                "status" to "installing",
                "message" to "已重新打开安装确认。",
                "currentVersion" to currentVersion,
                "latestVersion" to "v$latestVersion",
            ),
        )
    }

    /// 返回缓存目录中已下载的更新 APK（downloadApk 每次只保留一个），不存在则 null。
    private fun downloadedApkFile(expectedVersion: String? = null): File? {
        val updatesDir = File(cacheDir, "updates")
        if (!updatesDir.isDirectory) {
            return null
        }
        val candidates = updatesDir.listFiles()
            ?.filter { it.isFile && it.name.endsWith(".apk", ignoreCase = true) }
            ?.sortedByDescending { it.lastModified() }
            ?: return null
        for (candidate in candidates) {
            try {
                validateUpdateApk(candidate, expectedVersion)
                return candidate
            } catch (error: Exception) {
                // 半成品、错包或旧版本缓存都不能再暴露给安装入口。
                candidate.delete()
            }
        }
        return null
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
        val apkAsset = findApkAsset(release)
            ?: return mapOf(
                "status" to "noAsset",
                "message" to "发现 $latestTag，但 Release 中没有可安装的 APK。",
                "currentVersion" to currentVersion,
                "latestVersion" to latestTag,
            )
        if (downloadedApkFile(latestVersion) != null) {
            return mapOf(
                "status" to "downloaded",
                "message" to "新版本 $latestTag 已下载，可以立即安装。",
                "currentVersion" to currentVersion,
                "latestVersion" to latestTag,
                "isPrerelease" to isPrerelease,
            )
        }
        recoverCompletedIncoming(apkAsset, latestTag, latestVersion)?.let {
            return mapOf(
                "status" to "downloaded",
                "message" to "新版本 $latestTag 已下载，可以立即安装。",
                "currentVersion" to currentVersion,
                "latestVersion" to latestTag,
                "isPrerelease" to isPrerelease,
            )
        }
        partialUpdateDownload(latestTag, apkAsset.sizeBytes)?.let { partial ->
            val percent = if (partial.totalBytes > 0) {
                ((partial.receivedBytes * 100) / partial.totalBytes).coerceIn(0, 100)
            } else {
                0
            }
            return mapOf(
                "status" to "paused",
                "message" to "上次下载在 $percent% 处中断，已保留进度，可以继续下载。",
                "currentVersion" to currentVersion,
                "latestVersion" to latestTag,
                "isPrerelease" to isPrerelease,
                "receivedBytes" to partial.receivedBytes,
                "totalBytes" to partial.totalBytes,
            )
        }
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
        val apkAsset = findApkAsset(release)
            ?: return mapOf(
                "status" to "noAsset",
                "message" to "发现 $latestTag，但 Release 中没有可安装的 APK。",
                "currentVersion" to currentVersion,
                "latestVersion" to latestTag,
            )
        val apkFile = try {
            downloadApk(apkAsset, latestTag, latestVersion)
        } catch (error: UpdateDownloadPausedException) {
            val percent = if (error.partial.totalBytes > 0) {
                ((error.partial.receivedBytes * 100) / error.partial.totalBytes)
                    .coerceIn(0, 100)
            } else {
                0
            }
            return mapOf(
                "status" to "paused",
                "message" to "下载暂时中断，已保留 $percent% 的进度，点击继续下载即可从断点恢复。",
                "currentVersion" to currentVersion,
                "latestVersion" to latestTag,
                "isPrerelease" to isPrerelease,
                "receivedBytes" to error.partial.receivedBytes,
                "totalBytes" to error.partial.totalBytes,
            )
        }
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

    private fun findApkAsset(release: JSONObject): UpdateApkAsset? {
        val assets = release.optJSONArray("assets") ?: return null
        for (index in 0 until assets.length()) {
            val asset = assets.optJSONObject(index) ?: continue
            val name = asset.optString("name")
            val url = asset.optString("browser_download_url")
            if (name.endsWith(".apk", ignoreCase = true) && url.isNotBlank()) {
                val digest = asset.optString("digest")
                    .removePrefix("sha256:")
                    .takeIf { it.matches(Regex("[0-9a-fA-F]{64}")) }
                    ?.lowercase()
                return UpdateApkAsset(
                    downloadUrl = url,
                    sizeBytes = asset.optLong("size").takeIf { it > 0 } ?: 0,
                    sha256 = digest,
                )
            }
        }
        return null
    }

    private fun downloadApk(asset: UpdateApkAsset, tag: String, expectedVersion: String): File {
        val incomingFile = updateIncomingFile(tag)
        incomingFile.parentFile?.listFiles()?.forEach { file ->
            if (file != incomingFile) {
                file.delete()
            }
        }
        recoverCompletedIncoming(asset, tag, expectedVersion)?.let { return it }

        var lastError: IOException? = null
        var resetAfterCorruption = false
        for (attempt in 1..UPDATE_MAX_AUTO_RESUME_ATTEMPTS) {
            try {
                return downloadApkAttempt(asset, tag, expectedVersion)
            } catch (error: CorruptUpdateDownloadException) {
                incomingFile.delete()
                if (resetAfterCorruption) {
                    throw error
                }
                resetAfterCorruption = true
                lastError = error
            } catch (error: IOException) {
                lastError = error
            }
            if (attempt < UPDATE_MAX_AUTO_RESUME_ATTEMPTS) {
                Thread.sleep((attempt * 1_000L).coerceAtMost(3_000L))
            }
        }
        val partial = partialUpdateDownload(tag, asset.sizeBytes)
            ?: PartialUpdateDownload(0, asset.sizeBytes)
        throw UpdateDownloadPausedException(
            "更新下载暂时中断，已保留断点。",
            partial,
            lastError ?: IOException("未知下载错误"),
        )
    }

    private fun downloadApkAttempt(
        asset: UpdateApkAsset,
        tag: String,
        expectedVersion: String,
    ): File {
        val incomingFile = updateIncomingFile(tag)
        if (asset.sizeBytes > 0 && incomingFile.length() > asset.sizeBytes) {
            incomingFile.delete()
        }
        val resumeOffset = incomingFile.length().coerceAtLeast(0)
        val connection = URL(asset.downloadUrl).openConnection() as HttpURLConnection
        connection.requestMethod = "GET"
        connection.instanceFollowRedirects = true
        connection.setRequestProperty("User-Agent", "VeriFin/${BuildConfig.VERSION_NAME}")
        connection.setRequestProperty("Accept-Encoding", "identity")
        if (resumeOffset > 0) {
            connection.setRequestProperty("Range", "bytes=$resumeOffset-")
        }
        connection.connectTimeout = UPDATE_CONNECT_TIMEOUT_MS
        connection.readTimeout = UPDATE_READ_TIMEOUT_MS
        try {
            val code = connection.responseCode
            if (code == 416 &&
                asset.sizeBytes > 0 &&
                resumeOffset == asset.sizeBytes
            ) {
                return finalizeDownloadedApk(asset, tag, expectedVersion)
            }
            if (code == 408 ||
                code == 429 ||
                code in 500..599
            ) {
                throw RetryableDownloadException("APK 下载暂时失败：HTTP $code")
            }
            if (code !in 200..299) {
                throw IllegalStateException("APK 下载失败：HTTP $code")
            }

            val contentRange = connection.getHeaderField("Content-Range")
            val rangeMatch = contentRange?.let {
                Regex("bytes\\s+(\\d+)-(\\d+)/(\\d+|\\*)", RegexOption.IGNORE_CASE)
                    .find(it)
            }
            val rangeStart = rangeMatch?.groupValues?.getOrNull(1)?.toLongOrNull()
            val rangeTotal = rangeMatch?.groupValues?.getOrNull(3)
                ?.takeUnless { it == "*" }
                ?.toLongOrNull()
                ?: 0
            val append = resumeOffset > 0 &&
                code == HttpURLConnection.HTTP_PARTIAL &&
                rangeStart == resumeOffset
            if (resumeOffset > 0 && code == HttpURLConnection.HTTP_PARTIAL && !append) {
                throw RetryableDownloadException("服务器返回的断点位置不一致。")
            }
            val receivedBefore = if (append) resumeOffset else 0
            val totalBytes = asset.sizeBytes.takeIf { it > 0 }
                ?: rangeTotal.takeIf { it > 0 }
                ?: connection.contentLengthLong.takeIf { it > 0 }
                    ?.plus(receivedBefore)
                ?: 0
            sendDownloadProgress(receivedBefore, totalBytes)
            connection.inputStream.use { input ->
                FileOutputStream(incomingFile, append).buffered().use { output ->
                    val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                    var received = receivedBefore
                    var lastProgress = if (totalBytes > 0) {
                        ((received * 100) / totalBytes).toInt()
                    } else {
                        -1
                    }
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
            val finalSize = incomingFile.length()
            if (totalBytes > 0 && finalSize < totalBytes) {
                throw RetryableDownloadException(
                    "APK 下载中断：应为 $totalBytes 字节，当前为 $finalSize 字节。",
                )
            }
            if (totalBytes > 0 && finalSize > totalBytes) {
                throw CorruptUpdateDownloadException(
                    "APK 下载长度异常：应为 $totalBytes 字节，实际为 $finalSize 字节。",
                )
            }
            return finalizeDownloadedApk(asset, tag, expectedVersion)
        } finally {
            connection.disconnect()
        }
    }

    private fun recoverCompletedIncoming(
        asset: UpdateApkAsset,
        tag: String,
        expectedVersion: String,
    ): File? {
        val incomingFile = updateIncomingFile(tag)
        if (!incomingFile.isFile || incomingFile.length() <= 0) {
            return null
        }
        if (asset.sizeBytes <= 0 || incomingFile.length() != asset.sizeBytes) {
            return null
        }
        return try {
            finalizeDownloadedApk(asset, tag, expectedVersion)
        } catch (_: CorruptUpdateDownloadException) {
            // 只有内容校验失败才丢弃；提交阶段的临时文件系统错误应保留完整文件，
            // 让下一次检查/继续下载可以再次尝试原子提交。
            incomingFile.delete()
            null
        }
    }

    private fun finalizeDownloadedApk(
        asset: UpdateApkAsset,
        tag: String,
        expectedVersion: String,
    ): File {
        val updatesDir = File(cacheDir, "updates").apply { mkdirs() }
        val incomingFile = updateIncomingFile(tag)
        try {
            if (asset.sizeBytes > 0 && incomingFile.length() != asset.sizeBytes) {
                throw IllegalStateException("下载的 APK 长度与 Release 记录不一致。")
            }
            validateUpdateDigest(incomingFile, asset.sha256)
            validateUpdateApk(incomingFile, expectedVersion)
        } catch (error: Exception) {
            throw CorruptUpdateDownloadException("下载的 APK 完整性校验失败。", error)
        }
        val apkFile = updateFinalFile(tag)
        // 校验完成后才替换旧缓存；同一文件系统内 rename 是原子提交。
        if (apkFile.exists() && !apkFile.delete()) {
            throw IllegalStateException("无法替换旧更新安装包。")
        }
        if (!incomingFile.renameTo(apkFile)) {
            throw IllegalStateException("无法提交已下载的更新安装包。")
        }
        updatesDir.listFiles()?.forEach { file ->
            if (file.isFile &&
                file != apkFile &&
                file.name.endsWith(".apk", ignoreCase = true)
            ) {
                file.delete()
            }
        }
        val finalSize = apkFile.length()
        sendDownloadProgress(finalSize, asset.sizeBytes.takeIf { it > 0 } ?: finalSize)
        return apkFile
    }

    private fun updateIncomingFile(tag: String): File {
        val safeTag = tag.replace(Regex("[^A-Za-z0-9._-]"), "_")
        val incomingDir = File(cacheDir, "updates/incoming").apply { mkdirs() }
        return File(incomingDir, "verifin-$safeTag.apk")
    }

    private fun updateFinalFile(tag: String): File {
        val safeTag = tag.replace(Regex("[^A-Za-z0-9._-]"), "_")
        val updatesDir = File(cacheDir, "updates").apply { mkdirs() }
        return File(updatesDir, "verifin-$safeTag.apk")
    }

    private fun partialUpdateDownload(tag: String, expectedTotal: Long): PartialUpdateDownload? {
        val incomingFile = updateIncomingFile(tag)
        val received = incomingFile.length()
        if (!incomingFile.isFile || received <= 0) {
            return null
        }
        if (expectedTotal > 0 && received > expectedTotal) {
            incomingFile.delete()
            return null
        }
        return PartialUpdateDownload(received, expectedTotal)
    }

    private fun validateUpdateDigest(apkFile: File, expectedSha256: String?) {
        if (expectedSha256 == null) {
            return
        }
        val digest = MessageDigest.getInstance("SHA-256")
        apkFile.inputStream().buffered().use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val read = input.read(buffer)
                if (read == -1) {
                    break
                }
                digest.update(buffer, 0, read)
            }
        }
        val actual = digest.digest().joinToString("") { byte ->
            "%02x".format(byte.toInt() and 0xff)
        }
        if (actual != expectedSha256) {
            throw IllegalStateException("下载的 APK SHA-256 与 Release 不一致。")
        }
    }

    /// 校验 APK 至少能被系统解析、包名属于当前应用，且版本与目标 Release 一致。
    /// 最终安装时 Android 仍会再次校验签名；这里负责在拉起安装器前拦住残包/错包。
    @Suppress("DEPRECATION")
    private fun validateUpdateApk(apkFile: File, expectedVersion: String? = null): String {
        val packageInfo = packageManager.getPackageArchiveInfo(apkFile.absolutePath, 0)
            ?: throw IllegalStateException("下载的文件不是有效 APK。")
        if (packageInfo.packageName != packageName) {
            throw IllegalStateException("下载的 APK 包名与 VeriFin 不一致。")
        }
        val version = packageInfo.versionName?.removePrefix("v")
            ?.takeIf { it.isNotBlank() }
            ?: throw IllegalStateException("下载的 APK 缺少版本号。")
        if (expectedVersion != null && version != expectedVersion.removePrefix("v")) {
            throw IllegalStateException("下载的 APK 版本与目标 Release 不一致。")
        }
        return version
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

    private data class UpdateApkAsset(
        val downloadUrl: String,
        val sizeBytes: Long,
        val sha256: String?,
    )

    private data class PartialUpdateDownload(
        val receivedBytes: Long,
        val totalBytes: Long,
    )

    private class UpdateDownloadPausedException(
        message: String,
        val partial: PartialUpdateDownload,
        cause: Throwable,
    ) : IOException(message, cause)

    private class RetryableDownloadException(message: String) : IOException(message)

    private class CorruptUpdateDownloadException(
        message: String,
        cause: Throwable? = null,
    ) : IOException(message, cause)

    companion object {
        const val ACTION_QUICK_ENTRY = "top.talyra42.verifin.action.QUICK_ENTRY"

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
        private const val RELEASE_API_URL =
            "https://api.github.com/repos/LumiDesk/verifin/releases/latest"
        // 预发布检查用列表端点：/releases/latest 天然排除预发布，需拉列表自行筛选。
        private const val RELEASE_LIST_API_URL =
            "https://api.github.com/repos/LumiDesk/verifin/releases?per_page=20"
        private const val UPDATE_CONNECT_TIMEOUT_MS = 15_000
        private const val UPDATE_READ_TIMEOUT_MS = 60_000
        private const val UPDATE_MAX_AUTO_RESUME_ATTEMPTS = 3
        private val UPDATE_DOWNLOAD_IN_PROGRESS = AtomicBoolean(false)
    }
}
