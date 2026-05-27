# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class com.media_kit.** { *; }
-keep class com.open_filex.** { *; }
-keep class com.receive_sharing_intent.** { *; }
-dontwarn io.flutter.embedding.**
-dontwarn com.media_kit.**

# audio_service — keep all classes needed for MediaBrowserService and notification
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.** { *; }
-dontwarn com.ryanheise.**

# audio_session — keep audio focus classes
-keep class com.ryanheise.audiosession.** { *; }
-dontwarn com.ryanheise.audiosession.**

# device_info_plus
-keep class dev.fluttercommunity.plus.device_info.** { *; }
-dontwarn dev.fluttercommunity.plus.device_info.**

# AndroidX Media / MediaBrowserServiceCompat — must not be obfuscated
-keep class androidx.media.** { *; }
-keep class android.support.v4.media.** { *; }
-dontwarn androidx.media.**

