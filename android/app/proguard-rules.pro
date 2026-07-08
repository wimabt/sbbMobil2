# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class plugins.flutter.io.** { *; }
-keep class io.flutter.plugins.** { *; }

# Retrofit (if pulled transitively; avoids R8 missing-class noise)
-dontwarn retrofit2.**

# Dio HTTP client
-keep class dio.** { *; }
-keepclassmembers class dio.** { *; }
-dontwarn dio.**

# JSON serialization
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Parcelable implementations
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep Serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep annotation default values
-keepattributes AnnotationDefault

# Keep enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep R classes
-keepclassmembers class **.R$* {
    public static <fields>;
}

# OkHttp (Dio'nun altında kullanılıyor)
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings {
    <fields>;
}
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}

# Google Maps
-keep class com.google.android.gms.maps.** { *; }
-keep interface com.google.android.gms.maps.** { *; }
-dontwarn com.google.android.gms.**

# Geolocator
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.geolocator.**

# Video player
-keep class io.flutter.plugins.videoplayer.** { *; }
-dontwarn io.flutter.plugins.videoplayer.**

# Cached network image
-keep class com.github.fluttercommunity.** { *; }
-dontwarn com.github.fluttercommunity.**

# model_viewer_plus (WebView-based 3D/AR viewer)
-keep class android.webkit.** { *; }
-dontwarn android.webkit.**
-keep class com.nicholaschernandez.** { *; }
-dontwarn com.nicholaschernandez.**

# mobile_scanner (QR/Barcode scanning via ML Kit)
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
-keep class com.google.android.gms.vision.** { *; }
-dontwarn com.google.android.gms.vision.**

# Play Core (Flutter deferred components; optional — not on app classpath)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

# ───────────────────────────────────────────────────────────────────────────
# AR (ar_flutter_plugin_2 → io.github.sceneview:arsceneview → Filament/gltfio +
# Google ARCore). Bu kütüphaneler JNI/reflection ile native sınıflara erişiyor;
# R8 strip/rename ederse method-channel handler kaybolur ve uygulama içi AR
# "MissingPluginException (... arobjects_0)" verip modeli yükleyemez.
# ───────────────────────────────────────────────────────────────────────────
# Plugin (Kotlin tarafı + method channel + serializers)
-keep class com.uhg0.ar_flutter_plugin_2.** { *; }
-dontwarn com.uhg0.ar_flutter_plugin_2.**

# SceneView / ARSceneView
-keep class io.github.sceneview.** { *; }
-keep interface io.github.sceneview.** { *; }
-dontwarn io.github.sceneview.**

# Google Filament (render motoru — JNI; native köprü sınıfları korunmalı)
-keep class com.google.android.filament.** { *; }
-keep class com.google.android.filament.gltfio.** { *; }
-keep class com.google.android.filament.utils.** { *; }
-keepclassmembers class com.google.android.filament.** { *; }
-dontwarn com.google.android.filament.**

# Google ARCore
-keep class com.google.ar.** { *; }
-keep interface com.google.ar.** { *; }
-dontwarn com.google.ar.**

# Preserve line numbers for debugging
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
