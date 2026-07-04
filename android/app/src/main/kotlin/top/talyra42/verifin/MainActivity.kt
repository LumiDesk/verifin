package top.talyra42.verifin

import android.Manifest
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

// local_auth 需要宿主是 FragmentActivity，故继承 FlutterFragmentActivity。
class MainActivity : FlutterFragmentActivity() {
    private var channel: MethodChannel? = null
    private var pendingQuickEntryIntent = false
    private var pendingDownloadsWrite: PendingDownloadsWrite? = null

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
                "checkLatestRelease" -> checkLatestRelease(result)
                "downloadLatestUpdate" -> downloadLatestUpdate(result)
                "saveTextToDownloads" -> saveTextToDownloads(
                    call.argument<String>("filename") ?: "verifin-backup.json",
                    call.argument<String>("content") ?: "",
                    call.argument<String>("mimeType") ?: "application/json",
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

    private fun rememberQuickEntryIntent(intent: Intent?) {
        if (intent?.action == ACTION_QUICK_ENTRY) {
            pendingQuickEntryIntent = true
        }
    }

    private fun checkLatestRelease(result: MethodChannel.Result) {
        Thread {
            try {
                val response = checkLatestReleaseInfo()
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

    private fun downloadLatestUpdate(result: MethodChannel.Result) {
        Thread {
            try {
                val response = downloadLatestReleaseAndInstall()
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

    private fun checkLatestReleaseInfo(): Map<String, Any> {
        val release = fetchLatestRelease()
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
        )
    }

    private fun downloadLatestReleaseAndInstall(): Map<String, Any> {
        val release = fetchLatestRelease()
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

    private fun fetchLatestRelease(): JSONObject {
        val connection = URL(RELEASE_API_URL).openConnection() as HttpURLConnection
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
        return JSONObject(body)
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
        private const val RELEASE_API_URL =
            "https://api.github.com/repos/LumiDesk/verifin/releases/latest"
    }
}
