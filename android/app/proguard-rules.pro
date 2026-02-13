# Flutter 相关
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# media_kit 相关
-keep class com.alexmercerind.media_kit.** { *; }
-keep class com.alexmercerind.media_kit_video.** { *; }
-keep class com.alexmercerind.media_kit_libs_android_video.** { *; }

# Google Play Core (不需要，忽略警告)
-dontwarn com.google.android.play.core.**

# Android 系统
-dontwarn android.**
-dontwarn androidx.**

# Media3 ExoPlayer (video_player_android 本地 fork)
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**

# 保持 native 方法
-keepclasseswithmembernames class * {
    native <methods>;
}
