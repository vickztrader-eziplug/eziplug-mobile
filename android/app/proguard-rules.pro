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
# FLUTTER SECURE STORAGE
# ============================================
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class androidx.security.crypto.** { *; }

# ============================================
# SHARED PREFERENCES
# ============================================
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# ============================================
# PATH PROVIDER
# ============================================
-keep class io.flutter.plugins.pathprovider.** { *; }

# ============================================
# FLUTTERTOAST
# ============================================
-keep class io.github.nicosalvato.fluttertoast.** { *; }
-keep class com.shashank.sony.fancytoastlib.** { *; }

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
