package top.talyra42.verifin

import android.app.Activity
import android.content.res.ColorStateList
import android.graphics.BitmapFactory
import android.graphics.drawable.BitmapDrawable
import android.os.Build
import android.util.TypedValue
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import com.example.liquidglass.GlassMaterial
import com.example.liquidglass.LiquidGlassTabBar

/**
 * 液态玻璃底栏：原生实现。
 *
 * QWEA0 LiquidGlassTabBar（AGSL 折射 + 水滴指示器）直接挂在 FlutterView 之上、
 * 同一 ViewGroup 内；backdrop 指向 FlutterView（必须为 texture 渲染模式），
 * 玻璃的 RenderNode 每帧重录 Flutter 内容，折射与原生宿主同一条渲染管线。
 *
 * 配色：玻璃与水滴保持库的外观；选中项图标/文字用主题主色（Dart 下发两档变体），
 * 未选中项用中性墨色。深浅极性取主题亮度：库的 BackdropLuminanceMeter 采样在
 * TextureView（RenderMode.texture）下取不到内容——实测光滑亮度持续衰减到 0、
 * isOverLight() 从不翻转，用它决定极性会把未选中项刷成白字压在浅色玻璃上，
 * 因此不做内容采样。
 *
 * 初始化失败 / SDK<33 时静默不装，Flutter 侧 fallback 样式生效。
 */
class LiquidGlassBarController(private val activity: Activity) {

    /** 一个 tab：标签 + 白色剪影图标（null = 纯文字）。 */
    data class Tab(val label: String, val iconBytes: ByteArray?)

    var onTabSelected: ((Int) -> Unit)? = null

    private var tabBar: LiquidGlassTabBar? = null
    private var host: FrameLayout? = null
    private var installed = false
    private var flutterView: View? = null
    private var tabs: List<Tab> = emptyList()
    private var bottomInsetPx = 0
    private var dark = false

    /** 主题主色的两档变体（ARGB）：浅底用 [accentOverLight]，深底用 [accentOverDark]。 */
    private var accentOverLight: Int? = null
    private var accentOverDark: Int? = null

    /// Dart 侧认定的当前选中下标，也是唯一权威：回声判定与重装初值都以它为准。
    ///
    /// 库只在选中值**真正变化**时回调 `onTabSelected`（见库的 `selectTab(index, changed)`）。
    /// 早期实现用一个「期望值」标记来吞掉 Dart 驱动引发的自反回调，但那个标记只在回调里
    /// 清除：当用户点的正好是库已选中的那一项时库不回调，标记滞留，之后对同一项的真实
    /// 点击会被当成回声吞掉——表现就是点了没反应、卡在某个 Tab 上。
    @Volatile private var dartSelectedIndex = 0

    /// 已知库当前停在的下标，避免对库重复设值。
    private var librarySelectedIndex = 0

    val isActive: Boolean
        get() = installed && tabBar != null && Build.VERSION.SDK_INT >= 33

    private fun dp(v: Float): Float =
        TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, v, activity.resources.displayMetrics)

    /** 安装玻璃底栏（重复调用 = 重装，用于几何/主题变化）。 */
    fun install(
        flutterView: View,
        tabs: List<Tab>,
        initialIndex: Int,
        dark: Boolean,
        bottomInsetPx: Int,
        accentOverLight: Int?,
        accentOverDark: Int?,
    ) {
        if (Build.VERSION.SDK_INT < 33) return
        this.flutterView = flutterView
        this.tabs = tabs
        this.dartSelectedIndex = initialIndex
        this.librarySelectedIndex = initialIndex
        this.bottomInsetPx = bottomInsetPx
        this.dark = dark
        this.accentOverLight = accentOverLight
        this.accentOverDark = accentOverDark
        try {
            uninstall()
            val content = flutterView.parent as? ViewGroup ?: return
            val frame = FrameLayout(activity)
            frame.layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT)
            val bar = LiquidGlassTabBar(activity).apply {
                layoutParams = FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    dp(BAR_HEIGHT_DP).toInt(),
                    android.view.Gravity.BOTTOM)
                cornerRadius = 999f
                material = GlassMaterial.REGULAR
                refractionHeight = dp(REFRACTION_HEIGHT_DP)
                bevelWidth = dp(BEVEL_WIDTH_DP)
                dispersionStrength = DISPERSION
                enableSensorHighlight = true
                backdropSource = flutterView
                // Flutter 内容滚动不产生 Android 滚动事件，必须常驻重录 backdrop。
                enableDynamicBackground = true
                // 玻璃与水滴的亮度基准，同时决定选中/未选中文字的墨色极性。
                overLight = dark
            }
            // 几何默认值：高 60dp、距底 16dp、左右 16dp（胶囊悬浮）。
            (bar.layoutParams as FrameLayout.LayoutParams).apply {
                leftMargin = dp(SIDE_MARGIN_DP).toInt()
                rightMargin = dp(SIDE_MARGIN_DP).toInt()
                bottomMargin = dp(BOTTOM_OFFSET_DP).toInt() + bottomInsetPx
                width = ViewGroup.LayoutParams.MATCH_PARENT
            }
            applyTabs(bar, tabs)
            bar.selectedIndex = librarySelectedIndex
            // 原生 tab 点击/拖动 → Dart 侧切页（Shell 状态机不变）。库对「同步时设的
            // 值」不触发回调，因此不会产生回声；这里只需按传入下标与 Dart 权威下标比对，
            // 排除库因其他原因报回来的相同值。
            bar.onTabSelected = { index ->
                // 库在点击后已切换选中项，这里补一次墨色刷新。
                scheduleRepaint(bar)
                if (index != dartSelectedIndex) {
                    librarySelectedIndex = index
                    dartSelectedIndex = index
                    onTabSelected?.invoke(index)
                }
            }
            frame.addView(bar)
            content.addView(frame)
            host = frame
            tabBar = bar
            installed = true
            scheduleRepaint(bar)
        } catch (t: Throwable) {
            installed = false
            host = null
            tabBar = null
            // 静默：Flutter fallback 样式接管。
            android.util.Log.w(TAG, "install failed: $t")
        }
    }

    /** 底部 inset 变化时重装（键盘避让；几何随 Flutter 侧走）。 */
    fun updateGeometry(dark: Boolean, bottomInsetPx: Int) {
        val view = flutterView ?: return
        val themeChanged = dark != this.dark
        if (!installed || (bottomInsetPx == this.bottomInsetPx && !themeChanged)) {
            this.dark = dark
            this.bottomInsetPx = bottomInsetPx
            return
        }
        install(
            view, tabs, dartSelectedIndex, dark, bottomInsetPx,
            accentOverLight, accentOverDark)
    }

    /// 切主题或换主题色时同步配色：更新两档主色变体并刷新选中项与未选中项的颜色。
    fun updateAppearance(dark: Boolean, accentOverLight: Int?, accentOverDark: Int?) {
        try {
            this.dark = dark
            this.accentOverLight = accentOverLight
            this.accentOverDark = accentOverDark
            tabBar?.let {
                // 玻璃与水滴的亮度基准随主题切换，文字墨色极性同步翻转。
                it.overLight = dark
                scheduleRepaint(it)
            }
        } catch (t: Throwable) {
            android.util.Log.w(TAG, "updateAppearance failed: $t")
        }
    }

    /// 有 route 盖在根页面上时隐藏原生栏（不卸载，保持折射状态），恢复时显示。
    fun setHidden(hidden: Boolean) {
        try {
            host?.visibility = if (hidden) View.GONE else View.VISIBLE
        } catch (t: Throwable) {
            android.util.Log.w(TAG, "setHidden failed: $t")
        }
    }

    private fun applyTabs(bar: LiquidGlassTabBar, tabs: List<Tab>) {
        val items = tabs.map { tab ->
            val drawable = tab.iconBytes?.let { bytes ->
                try {
                    BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                        ?.let { BitmapDrawable(activity.resources, it) }
                } catch (t: Throwable) {
                    null
                }
            }
            LiquidGlassTabBar.TabItem(tab.label, drawable)
        }
        bar.setTabs(items)
    }

    fun updateSelection(index: Int) {
        try {
            if (!installed) return
            // Dart 是选中态的权威：先记下来，这个值同时用于识别库报回来的回声。
            dartSelectedIndex = index
            if (index == librarySelectedIndex) {
                return
            }
            librarySelectedIndex = index
            tabBar?.let {
                it.selectedIndex = index
                scheduleRepaint(it)
            }
        } catch (t: Throwable) {
            android.util.Log.w(TAG, "updateSelection failed: $t")
        }
    }

    fun uninstall() {
        try {
            host?.let { (it.parent as? ViewGroup)?.removeView(it) }
        } catch (t: Throwable) {
            android.util.Log.w(TAG, "uninstall failed: $t")
        }
        host = null
        tabBar = null
        installed = false
    }

    /// 库会在选中切换、换 tab 时重涂文字，所以这些时机之后都要刷新一次。
    /// 同时在下一帧补刷，覆盖库异步完成的样式更新。
    private fun scheduleRepaint(bar: LiquidGlassTabBar) {
        repaintTabs(bar)
        bar.post {
            if (tabBar === bar) repaintTabs(bar)
        }
    }

    /**
     * 选中项用主题主色变体（经库的 selectedTintColor，文字与图标同色），
     * 未选中项直接给文字与图标设中性墨色。极性取主题亮度：浅色主题配深色墨、
     * 深色主题配白色墨（内容采样在 TextureView 下取不到值，见类注释）。
     */
    private fun repaintTabs(bar: LiquidGlassTabBar) {
        if (tabs.isEmpty()) return
        val overLight = !dark
        val accent = if (overLight) accentOverLight else accentOverDark
        val ink = if (overLight) INK_OVER_LIGHT else INK_OVER_DARK
        // 选中项交给库的 selectedTintColor（文字与图标同色，实测生效）。
        bar.selectedTintColor = accent
        val row = findTabRow(bar, tabs.size) ?: run {
            // 库内部结构不符合预期：保留库默认配色，只影响对比度，不影响功能。
            android.util.Log.w(TAG, "tab row not found; keep library ink")
            return
        }
        val current = bar.selectedIndex
        for (index in 0 until row.childCount) {
            // 选中项由 selectedTintColor 负责，这里只补未选中项的墨色——库给未选中项
            // 用的白字在浅色玻璃上几乎看不见，这是本次修复的目标。
            if (index == current) continue
            val item = row.getChildAt(index) as? ViewGroup ?: continue
            item.findFirst(TextView::class.java)?.setTextColor(ink)
            item.findFirst(ImageView::class.java)?.imageTintList = ColorStateList.valueOf(ink)
        }
    }

    /// 库把每个 tab 放在同一行容器里（子节点数等于 tab 数，且每个子节点都是容器）。
    private fun findTabRow(parent: ViewGroup, count: Int): ViewGroup? {
        for (i in 0 until parent.childCount) {
            val child = parent.getChildAt(i) as? ViewGroup ?: continue
            if (child.childCount == count &&
                (0 until count).all { child.getChildAt(it) is ViewGroup }
            ) {
                return child
            }
            findTabRow(child, count)?.let { return it }
        }
        return null
    }

    private fun <T : View> ViewGroup.findFirst(type: Class<T>): T? {
        for (i in 0 until childCount) {
            val child = getChildAt(i)
            if (type.isInstance(child)) return type.cast(child)
            if (child is ViewGroup) child.findFirst(type)?.let { return it }
        }
        return null
    }

    companion object {
        private const val TAG = "LiquidGlassBar"
        const val BAR_HEIGHT_DP = 60f
        const val BOTTOM_OFFSET_DP = 16f
        const val SIDE_MARGIN_DP = 16f
        const val REFRACTION_HEIGHT_DP = 60f
        const val BEVEL_WIDTH_DP = 16f
        const val DISPERSION = 0.12f

        /// 未选中项墨色：浅底用 70% 深色墨，深底用 85% 白色墨（高于库默认，保证与玻璃底对比）。
        private val INK_OVER_LIGHT = 0xB3000000.toInt()
        private val INK_OVER_DARK = 0xD9FFFFFF.toInt()
    }
}
