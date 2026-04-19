# ML Kit Text Recognition
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.android.gms.internal.** { *; }
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Camera
-keep class androidx.camera.** { *; }
-keep class androidx.lifecycle.** { *; }

# Image Picker
-keep class io.flutter.plugins.imagepicker.** { *; }
