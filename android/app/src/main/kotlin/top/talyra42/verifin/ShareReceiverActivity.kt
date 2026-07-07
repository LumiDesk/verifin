package top.talyra42.verifin

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle

/// 分享/外部采集的无界面跳板：ACTION_SEND 会把目标 Activity 起在分享方的任务栈里，
/// 直接指向 MainActivity 会在别人的栈里再起一个 Flutter 实例（双引擎、双控制器）。
/// 故由本 Activity 接收后转发到自家任务栈的 MainActivity（singleTop 复用），立即 finish，
/// 返回键仍回到分享方应用。
class ShareReceiverActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val source = intent
        val forward = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        when {
            // 分享图片：转发 content URI（同应用内 URI 读权限天然可用），Flutter 侧拉字节。
            source?.action == Intent.ACTION_SEND && source.type?.startsWith("image/") == true -> {
                val uri = streamUri(source)
                if (uri != null) {
                    forward.action = MainActivity.ACTION_CAPTURE_IMAGE
                    forward.putExtra(MainActivity.EXTRA_CAPTURE_IMAGE_URI, uri.toString())
                    forward.clipData = ClipData.newRawUri(null, uri)
                    forward.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
            }
            // 分享文本 / 自动化工具显式意图：统一走文本采集，长度在读取处限制。
            source?.action == Intent.ACTION_SEND && source.type == "text/plain" -> {
                val text = source.getStringExtra(Intent.EXTRA_TEXT)
                if (!text.isNullOrBlank()) {
                    forward.action = MainActivity.ACTION_CAPTURE_TEXT
                    forward.putExtra(MainActivity.EXTRA_CAPTURE_TEXT, text)
                }
            }
            source?.action == MainActivity.ACTION_CAPTURE_TEXT -> {
                val text = source.getStringExtra(MainActivity.EXTRA_CAPTURE_TEXT)
                    ?: source.getStringExtra("text")
                if (!text.isNullOrBlank()) {
                    forward.action = MainActivity.ACTION_CAPTURE_TEXT
                    forward.putExtra(MainActivity.EXTRA_CAPTURE_TEXT, text)
                }
            }
        }
        if (forward.action != null) {
            startActivity(forward)
        }
        finish()
    }

    private fun streamUri(intent: Intent): Uri? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }
    }
}
