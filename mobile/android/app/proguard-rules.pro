# ML Kit & Google Play Services
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.common.** { *; }
-dontwarn com.google.mlkit.**

# WorkManager & Room (prevents "Failed to create an instance of androidx.work.impl.WorkDatabase" under R8)
-keep class androidx.work.impl.WorkDatabase { *; }
-keep class * extends androidx.room.RoomDatabase {
    <init>();
}
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}

# Dart JNI (used by path_provider_android 2.3+ / google_fonts)
-keep class com.github.dart_lang.jni.** { *; }
-keep class com.github.dart_lang.jni_flutter.** { *; }
-keepclasseswithmembernames class * {
    native <methods>;
}

