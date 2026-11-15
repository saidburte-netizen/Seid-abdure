# Flutter embedding and plugin entry points.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keepattributes Signature,*Annotation*

# Keep Kotlin metadata used by reflection in some plugins.
-keep class kotlin.Metadata { *; }
-dontwarn io.flutter.embedding.**
