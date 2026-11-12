# Classes do Play Core referenciadas pelo Flutter e não usadas (sem componentes adiados).
-dontwarn com.google.android.play.core.**

# Google Mobile Ads e User Messaging Platform (consentimento).
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.android.ump.** { *; }
-keep class io.flutter.plugins.googlemobileads.** { *; }

# WorkManager (usado pelo SDK de anúncios) cria o banco Room por reflexão.
# Sem isto, o APK de release fecha ao abrir: "Failed to create an instance of WorkDatabase".
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }

# Google Play Billing.
-keep class com.android.billingclient.** { *; }
-keep class io.flutter.plugins.inapppurchase.** { *; }
