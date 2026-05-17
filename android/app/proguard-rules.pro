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

# Extreme Bytecode Optimizations
-allowaccessmodification
-repackageclasses ''
-mergeinterfacesaggressively
