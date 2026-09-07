# ProGuard / R8 Keep Rules for PATHLUME

# Flutter optional deferred components
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# 1. Google ARCore Keep Rules
-keep class com.google.ar.core.** { *; }
-keep interface com.google.ar.core.** { *; }
-keep enum com.google.ar.core.** { *; }
-keepclassmembers class com.google.ar.core.** { *; }

# 2. Native OpenGL ES & PATHLUME AR Package Keep Rules
-keep class com.pathlume.app.ar.** { *; }
-keepclassmembers class com.pathlume.app.ar.** { *; }
-keep class com.pathlume.app.MainActivity { *; }

# 3. Flutter & Platform Channels
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }
-keepclassmembers class * implements io.flutter.plugin.common.MethodChannel$MethodCallHandler { *; }
-keepclassmembers class * {
    @io.flutter.plugin.common.MethodChannel$MethodCallHandler *;
    native <methods>;
}

# 4. Mobile Scanner & ML Kit Barcode Processing
-keep class com.google.mlkit.** { *; }
-keep class dev.steffan.mobile_scanner.** { *; }

# 5. AndroidX & Material
-keep class androidx.annotation.Keep
-keep @androidx.annotation.Keep class * { *; }
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}
