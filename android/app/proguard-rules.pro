# ProGuard / R8 rules for Flutter + plugins
# تقليل الحجم مع الحفاظ على ما يلزم لمنع أعطال runtime

# احتفظ بفئات Flutter الأساسية
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.app.** { *; }

# احتفظ بالـ MethodChannel handlers (انعكاس)
-keep class * extends io.flutter.embedding.android.FlutterActivity { *; }
-keep class * implements io.flutter.plugin.common.MethodChannel$MethodCallHandler { *; }

# Dio / OkHttp / GSON-like (لو استُخدمت)
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**

# Video player / ExoPlayer قد يعتمد على الانعكاس
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# FFmpeg Kit (مهم لتفادي إزالة ديناميكية)
-keep class com.arthenica.ffmpegkit.** { *; }
-dontwarn com.arthenica.ffmpegkit.**

# WorkManager & background service
-keep class androidx.work.** { *; }
-dontwarn androidx.work.**

# Local notifications / AlarmManager
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**

# Prevent stripping entry points used by reflection
-keep class **.R
-keep class **.R$* { *; }

# احتفظ برسائل الأعطال (اختياري - أزلها لمزيد من التصغير)
-keepattributes SourceFile,LineNumberTable

# يمكنك لاحقاً إضافة قواعد إضافية إذا ظهر Crash في الإصدار المصغّر

# Play Core deferred components (SplitCompat & SplitInstall)
-keep class com.google.android.play.core.splitcompat.** { *; }
-dontwarn com.google.android.play.core.splitcompat.**
-keep class com.google.android.play.core.splitinstall.** { *; }
-dontwarn com.google.android.play.core.splitinstall.**
