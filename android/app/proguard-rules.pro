# Copyright (c) Meta Platforms, Inc. and affiliates.
# Licensed under the MIT license.

# ========================================
# ✅ React Native Core
# ========================================
-keep,allowobfuscation @interface com.facebook.proguard.annotations.DoNotStrip
-keep,allowobfuscation @interface com.facebook.proguard.annotations.KeepGettersAndSetters
-keep class com.hiennv.flutter_callkit_incoming.** { *; }
-keep @com.facebook.proguard.annotations.DoNotStrip class *
-keepclassmembers class * {
    @com.facebook.proguard.annotations.DoNotStrip *;
}
-keep @com.facebook.proguard.annotations.DoNotStripAny class * {
    *;
}
-keepclassmembers @com.facebook.proguard.annotations.KeepGettersAndSetters class * {
    void set*(***);
    *** get*();
}
-keep class * implements com.facebook.react.bridge.JavaScriptModule { *; }
-keep class * implements com.facebook.react.bridge.NativeModule { *; }
-keepclassmembers,includedescriptorclasses class * { native <methods>; }
-keepclassmembers class *  { @com.facebook.react.uimanager.annotations.ReactProp <methods>; }
-keepclassmembers class *  { @com.facebook.react.uimanager.annotations.ReactPropGroup <methods>; }

-dontwarn com.facebook.react.**
-keep,includedescriptorclasses class com.facebook.react.bridge.** { *; }
-keep,includedescriptorclasses class com.facebook.react.turbomodule.core.** { *; }

# ========================================
# ✅ Hermes Engine
# ========================================
-keep class com.facebook.jni.** { *; }

# ========================================
# ✅ OKIO / Java NIO
# ========================================
-keep class sun.misc.Unsafe { *; }
-dontwarn java.nio.file.*
-dontwarn org.codehaus.mojo.animal_sniffer.IgnoreJRERequirement
-dontwarn okio.**

# ========================================
# ✅ Yoga Layout
# ========================================
-keep,allowobfuscation @interface com.facebook.yoga.annotations.DoNotStrip
-keep @com.facebook.yoga.annotations.DoNotStrip class *
-keepclassmembers class * {
    @com.facebook.yoga.annotations.DoNotStrip *;
}

# ========================================
# ✅ WebRTC
# ========================================
-keep class org.webrtc.** { *; }
-dontwarn org.chromium.build.BuildHooksAndroid

# ========================================
# ✅ Jitsi Meet
# ========================================
-keep class org.jitsi.meet.** { *; }
-keep class org.jitsi.meet.sdk.** { *; }

# ========================================
# ✅ React Dev Support
# ========================================
-keep class com.facebook.react.bridge.CatalystInstanceImpl { *; }
-keep class com.facebook.react.bridge.ExecutorToken { *; }
-keep class com.facebook.react.bridge.JavaScriptExecutor { *; }
-keep class com.facebook.react.bridge.ModuleRegistryHolder { *; }
-keep class com.facebook.react.bridge.ReadableType { *; }
-keep class com.facebook.react.bridge.queue.NativeRunnable { *; }
-keep class com.facebook.react.devsupport.** { *; }

-dontwarn com.facebook.react.devsupport.**
-dontwarn com.google.appengine.**
-dontwarn com.squareup.okhttp.**
-dontwarn javax.servlet.**

# ========================================
# ✅ SVG Support
# ========================================
-keep public class com.horcrux.svg.** { *; }

# ========================================
# ✅ Fresco & Image Handling
# ========================================
-keep public class com.facebook.imageutils.** {
   public *;
}
-keep class com.facebook.imagepipeline.nativecode.WebpTranscoderImpl { *; }
-dontwarn com.facebook.imagepipeline.nativecode.WebpTranscoder

# ========================================
# ✅ Giphy SDK / Kotlin Parcelize
# ========================================
-keep class kotlinx.parcelize.** { *; }
-dontwarn kotlinx.parcelize.**

# ========================================
# ✅ Android 12+ Attribute Fix (lStar)
# ========================================
-dontwarn android.graphics.ColorSpace$Named
# Jackson
-keep class com.fasterxml.jackson.** { *; }
-keep @com.fasterxml.jackson.annotation.JsonIgnoreProperties class * { *; }
-keep class * {
    @com.fasterxml.jackson.annotation.JsonProperty <fields>;
}
-keepnames class com.fasterxml.jackson.** { *; }
-dontwarn com.fasterxml.jackson.databind.**

# Java beans support
-dontwarn java.beans.**
-keep class java.beans.** { *; }

# DOM support
-dontwarn org.w3c.dom.bootstrap.**
-keep class org.w3c.dom.bootstrap.** { *; }

# Google Play Core
-keep class com.google.android.play.core.** { *; }
-keep interface com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Flutter Play Store Split
-keep class io.flutter.app.FlutterPlayStoreSplitApplication { *; }
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }

# Media3 and ExoPlayer2 conflict resolution
-keep class androidx.media3.** { *; }
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**
# Prevent class renaming that could cause conflicts
-keepnames class androidx.media3.** { *; }
-keepnames class com.google.android.exoplayer2.** { *; }

# If JitsiMeetSDK tries to create an ExoPlayer2 PlayerView
-dontwarn com.google.android.exoplayer2.ui.PlayerView
-dontwarn com.google.android.exoplayer2.ui.DefaultTimeBar
-dontwarn com.google.android.exoplayer2.ui.TimeBar