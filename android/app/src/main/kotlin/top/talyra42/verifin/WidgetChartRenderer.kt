package top.talyra42.verifin

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Shader
import java.util.Locale
import kotlin.math.roundToInt

/** Small, allocation-light sparkline suitable for RemoteViews ImageView. */
object WidgetChartRenderer {
    fun progressRing(progress: Float?, size: Int = 192): Bitmap? {
        val value = progress ?: return null
        if (!value.isFinite()) return null
        val clamped = value.coerceIn(0f, 1f)
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val center = size / 2f
        val radius = center - 18f
        val track = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(80, 255, 255, 255)
            style = Paint.Style.STROKE
            strokeWidth = 16f
            strokeCap = Paint.Cap.ROUND
        }
        val accent = Paint(track).apply { color = Color.rgb(52, 110, 219) }
        canvas.drawCircle(center, center, radius, track)
        canvas.drawArc(center - radius, center - radius, center + radius, center + radius,
            -90f, clamped * 360f, false, accent)
        val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = size * .24f
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            textAlign = Paint.Align.CENTER
        }
        val label = String.format(Locale.US, "%d%%", (clamped * 100).roundToInt())
        canvas.drawText(label, center, center - (text.ascent() + text.descent()) / 2f, text)
        return bitmap
    }

    fun sparkline(points: List<Float>, width: Int = 480, height: Int = 96): Bitmap? {
        if (points.size < 2) return null
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val values = points.map { if (it.isFinite()) it else 0f }
        var min = values.minOrNull() ?: 0f
        var max = values.maxOrNull() ?: 1f
        if (max - min < 0.0001f) { min -= 1f; max += 1f }
        val path = Path()
        values.forEachIndexed { index, value ->
            val x = index * (width - 1f) / (values.size - 1)
            val y = height - 8f - ((value - min) / (max - min)) * (height - 16f)
            if (index == 0) path.moveTo(x, y) else path.lineTo(x, y)
        }
        val area = Path(path)
        area.lineTo(width.toFloat(), height.toFloat())
        area.lineTo(0f, height.toFloat())
        area.close()
        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(
                0f, 0f, 0f, height.toFloat(),
                Color.argb(100, 52, 110, 219),
                Color.argb(0, 52, 110, 219),
                Shader.TileMode.CLAMP,
            )
            style = Paint.Style.FILL
        }
        canvas.drawPath(area, fill)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(52, 110, 219)
            style = Paint.Style.STROKE
            strokeWidth = 6f
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }
        canvas.drawPath(path, paint)
        return bitmap
    }
}
