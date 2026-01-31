# ============================================
# FLUTTER CORE - MUST KEEP
# ============================================
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# ============================================
# FLUTTER PIGEON (CRITICAL - used by modern Flutter plugins)
# ============================================
# Keep ALL Pigeon-generated code
-keep class dev.flutter.pigeon.** { *; }
-keep interface dev.flutter.pigeon.** { *; }
-keepclassmembers class dev.flutter.pigeon.** { *; }

# Keep all classes that implement Pigeon APIs
-keep class * implements dev.flutter.pigeon.** { *; }
-keep class **.*Api { *; }
-keep class **.*Api$* { *; }

# Prevent obfuscation of method names used in method channels
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Keep all native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# ============================================
# GOOGLE PLAY CORE (Required for Flutter)
# ============================================
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }

# ============================================
# HTTP/NETWORKING - CRITICAL FOR API CALLS
# ============================================
# Apache HTTP (legacy)
-keep class org.apache.http.** { *; }
-keep class org.apache.commons.** { *; }
-dontwarn org.apache.http.**
-dontwarn org.apache.commons.**

# Android HTTP
-keep class android.net.http.** { *; }
-keep class android.net.** { *; }

# OkHttp (used internally by some packages)
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-keep class okio.** { *; }

# Retrofit (if used)
-dontwarn retrofit2.**
-keep class retrofit2.** { *; }

# ============================================
# SSL/TLS/SECURITY - NEEDED FOR HTTPS
# ============================================
-keep class javax.net.ssl.** { *; }
-keep class javax.security.** { *; }
-keep class java.security.** { *; }
-keep class javax.crypto.** { *; }
-keep class org.conscrypt.** { *; }
-dontwarn org.conscrypt.**

# ============================================
# JSON PARSING
# ============================================
-keep class com.google.gson.** { *; }
-keep class org.json.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# Keep generic type info for Gson
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# ============================================
# FLUTTER SECURE STORAGE (CRITICAL)
# ============================================
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class com.it_nomads.** { *; }
-keepclassmembers class com.it_nomads.fluttersecurestorage.** { *; }
-keep class androidx.security.crypto.** { *; }
-keep class androidx.security.** { *; }

# Keep the plugin method channels
-keep class io.flutter.plugin.common.** { *; }
-keep class io.flutter.plugin.common.MethodChannel { *; }
-keep class io.flutter.plugin.common.MethodChannel$* { *; }
-keep class io.flutter.plugin.common.MethodCall { *; }

# Keep all plugin registrants
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
-keepclassmembers class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# ============================================
# SHARED PREFERENCES (critical for auth)
# ============================================
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class io.flutter.plugins.shared_preferences.** { *; }
-keep class io.flutter.plugins.shared_preferences_android.** { *; }
-keep class dev.flutter.pigeon.shared_preferences_android.** { *; }

# ============================================
# FLUTTER PIGEON (used by many plugins)
# ============================================
-keep class dev.flutter.pigeon.** { *; }
-keep interface dev.flutter.pigeon.** { *; }
-keepclassmembers class dev.flutter.pigeon.** { *; }

# ============================================
# PATH PROVIDER
# ============================================
-keep class io.flutter.plugins.pathprovider.** { *; }
-keep class io.flutter.plugins.path_provider.** { *; }
-keep class io.flutter.plugins.path_provider_android.** { *; }
-keep class dev.flutter.pigeon.path_provider_android.** { *; }

# ============================================
# FLUTTERTOAST
# ============================================
-keep class io.github.nicosalvato.fluttertoast.** { *; }
-keep class io.github.nicosalvato.** { *; }
-keep class com.shashank.sony.fancytoastlib.** { *; }
-keep class io.flutter.plugins.fluttertoast.** { *; }
-keep class dev.flutter.pigeon.fluttertoast.** { *; }

# ============================================
# KOTLIN
# ============================================
-dontwarn kotlin.**
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}

# ============================================
# ANDROIDX
# ============================================
-keep class androidx.** { *; }
-keep interface androidx.** { *; }
-dontwarn androidx.**

# ============================================
# GENERAL RULES
# ============================================
# Preserve line numbers for debugging
-keepattributes SourceFile,LineNumberTable

# Keep exception names
-keepattributes Exceptions

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Parcelable
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep Serializable
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep R class
-keepclassmembers class **.R$* {
    public static <fields>;
}

# ============================================
# SUPPRESS WARNINGS
# ============================================
-dontwarn java.lang.invoke.**
-dontwarn sun.misc.**
-dontwarn com.google.android.material.**
-dontnote android.net.http.**
-dontnote org.apache.http.**

# ============================================
# APACHE TIKA / XML (used by file_picker, printing)
# ============================================
-dontwarn javax.xml.stream.**
-dontwarn org.apache.tika.**
-dontwarn org.apache.poi.**
-dontwarn org.apache.xmlbeans.**
-dontwarn org.openxmlformats.**
-dontwarn schemaorg_apache_xmlbeans.**

# Ignore missing javax.xml classes (not available on Android)
-dontwarn javax.xml.**
-dontwarn org.w3c.dom.**
-dontwarn org.xml.sax.**

# ============================================
# R8 COMPATIBILITY - Treat missing classes as warnings, not errors
# ============================================
# This prevents R8 from failing on references to classes that exist
# in the library but are not available on Android (e.g., javax.xml.stream)
-ignorewarnings
