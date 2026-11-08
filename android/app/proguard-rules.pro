# Keep WorkManager and Room database implementation classes from being stripped by R8 in release builds
-keep class androidx.work.impl.WorkDatabase { *; }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.WorkManagerInitializer { *; }
-keep class androidx.startup.InitializationProvider { *; }

# Google Mobile Ads / Play Services
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.mediation.** { *; }
