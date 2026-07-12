# google_mlkit_text_recognition 的原生代码引用全部脚本（中/梵/日/韩）的
# Options 类，但各脚本库在插件里只 compileOnly。中文库已在 build.gradle.kts
# 显式引入；梵文/日文/韩文本应用不用、不引入，让 R8 忽略这些缺失类。
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ML Kit 识别器靠反射实例化选项/实现类（ChineseTextRecognizerOptions 等），
# R8 全量混淆会把这些类/成员改名或裁掉，导致 release 下初始化 NPE
# （getClass() on null；debug 不混淆则正常）。整包保留其类与成员。
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_bundled_common.** { *; }

# flutter_local_notifications 用 Gson 反射序列化「已排程通知详情」等模型类。
# R8 裁剪/混淆会破坏 Gson 的字段名反射，导致 release 下排程通知崩溃或丢失
# （记账提醒失效）。保留插件类与 Gson，并保住泛型 Signature/注解供 Gson 读取。
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses,EnclosingMethod
