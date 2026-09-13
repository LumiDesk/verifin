package top.talyra42.verifin

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Shader

/** Small, allocation-light sparkline suitable for RemoteViews ImageView. */
object WidgetChartRenderer {
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
