# flutter_local_notifications 用 Gson 反射序列化「已排程通知详情」等模型类。
# R8 裁剪/混淆会破坏 Gson 的字段名反射，导致 release 下排程通知崩溃或丢失
# （记账提醒失效）。保留插件类与 Gson，并保住泛型 Signature/注解供 Gson 读取。
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses,EnclosingMethod
