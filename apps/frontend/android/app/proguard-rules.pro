# Keep audio_service classes
-keep class com.ryanheise.audioservice.** { *; }
-keep interface com.ryanheise.audioservice.** { *; }

# Keep just_audio classes
-keep class com.ryanheise.just_audio.** { *; }

# Keep audio_session classes  
-keep class com.ryanheise.audio_session.** { *; }

# Keep MediaSessionCompat
-keep class androidx.media.** { *; }
-keep interface androidx.media.** { *; }

# Keep notification classes
-keep class androidx.core.app.NotificationCompat** { *; }

# Keep media classes
-dontwarn com.ryanheise.audioservice.**
-dontwarn com.ryanheise.just_audio.**

# ═══════════════════════════════════════════════════════════════════════════
# 🎵 FLUTTER MODELS - Prevent obfuscation of model properties
# ═══════════════════════════════════════════════════════════════════════════
# These models are used as tags in audio_service and accessed via reflection
# ProGuard must NOT rename their properties or the app will crash in release mode

# Keep all model classes and their members
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep json_serializable generated files
-keepattributes *Annotation*
-keepclassmembers class ** {
  @com.google.gson.annotations.* <fields>;
}

# Keep all Dart model classes (prevents field name obfuscation)
# This is critical for models used in audio playback (Song, Artist, etc.)
-keep class **.Song { *; }
-keep class **.Artist { *; }
-keep class **.Genre { *; }
-keep class **.Playlist { *; }
-keep class **.User { *; }
-keep class **.Album { *; }
-keep class **.FeaturedSong { *; }

# Keep all generated files from json_serializable and freezed
-keep class **.g.dart { *; }
-keep class **.freezed.dart { *; }

# Keep enum classes (SongStatus, etc.)
-keepclassmembers enum * {
  public static **[] values();
  public static ** valueOf(java.lang.String);
}

# Additional Flutter-specific rules
-dontwarn io.flutter.embedding.**
-keep class io.flutter.embedding.** { *; }
