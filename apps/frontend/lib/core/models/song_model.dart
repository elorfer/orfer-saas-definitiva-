import 'package:json_annotation/json_annotation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'artist_model.dart';
import '../utils/url_normalizer.dart';

part 'song_model.g.dart';

// Top-level helpers used by `compute()` (must be top-level functions)
Song _songFromJsonIsolate(Map<String, dynamic> json) => _$SongFromJson(Map<String, dynamic>.from(json));

List<Song> _songsFromJsonIsolate(List<dynamic> list) =>
  list.map((e) => _$SongFromJson(Map<String, dynamic>.from(e as Map))).toList();

enum SongStatus {
  @JsonValue('draft')
  draft,
  @JsonValue('published')
  published,
  @JsonValue('archived')
  archived,
}

@JsonSerializable(
  fieldRename: FieldRename.snake,
  explicitToJson: true,
  includeIfNull: false,
)
class Song {
  final String id;
  final String? artistId;
  final String? albumId;
  final String? title;
  final int? duration; // en segundos
  final String? fileUrl; // URL del archivo HLS
  final String? coverArtUrl;
  final String? lyrics;
  final String? genreId;
  final List<String>? genres; // Array de géneros musicales
  final int? trackNumber;
  final SongStatus status;
  final bool isExplicit;
  final DateTime? releaseDate;
  final int totalStreams;
  final int totalLikes;
  final int totalShares;
  final bool featured; // Indica si la canción es destacada
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Artist? artist;

  const Song({
    required this.id,
    this.artistId,
    this.albumId,
    this.title,
    this.duration,
    this.fileUrl,
    this.coverArtUrl,
    this.lyrics,
    this.genreId,
    this.genres,
    this.trackNumber,
    this.status = SongStatus.draft,
    this.isExplicit = false,
    this.releaseDate,
    this.totalStreams = 0,
    this.totalLikes = 0,
    this.totalShares = 0,
    this.featured = false,
    this.createdAt,
    this.updatedAt,
    this.artist,
  });

  /// Parse a single `Song` on a background isolate using `compute`.
  /// Use this when parsing many items to keep the main thread free.
  static Future<Song> parse(Map<String, dynamic> json) async {
    if (kIsWeb) {
      return _$SongFromJson(Map<String, dynamic>.from(json));
    }
    return compute(_songFromJsonIsolate, json);
  }

  /// Parse a list of songs on a background isolate using `compute`.
  static Future<List<Song>> parseList(List<dynamic> jsonList) async {
    if (kIsWeb) {
      return jsonList
          .map((e) => _$SongFromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return compute(_songsFromJsonIsolate, jsonList);
  }

  factory Song.fromJson(Map<String, dynamic> json) {
    // Only log in debug mode to avoid heavy IO on main thread (profile/release)
    // Only log in debug mode to avoid heavy IO on main thread (profile/release)
    // ⚡ OPTIMIZACIÓN: Logs comentados para evitar "Skipped frames" durante parsing masivo
    /*
    if (kDebugMode) {
      debugPrint('Song.fromJson raw JSON: ${json.toString()}');
      debugPrint('Song.fromJson genres field: ${json['genres']}');
    }
    */
    return _$SongFromJson(Map<String, dynamic>.from(json));
  }
  Map<String, dynamic> toJson() => _$SongToJson(this);

  /// ═══════════════════════════════════════════════════════════════════════
  /// 🔄 COPYWIDTH ROBUSTO - ACTUALIZACIONES INMUTABLES
  /// ═══════════════════════════════════════════════════════════════════════
  Song copyWith({
    String? id,
    String? artistId,
    String? albumId,
    String? title,
    int? duration,
    String? fileUrl,
    String? coverArtUrl,
    String? lyrics,
    String? genreId,
    List<String>? genres,
    int? trackNumber,
    SongStatus? status,
    bool? isExplicit,
    DateTime? releaseDate,
    int? totalStreams,
    int? totalLikes,
    int? totalShares,
    bool? featured,
    DateTime? createdAt,
    DateTime? updatedAt,
    Artist? artist,
    // Flags para setear null explícitamente
    bool clearArtistId = false,
    bool clearAlbumId = false,
    bool clearTitle = false,
    bool clearFileUrl = false,
    bool clearCoverArtUrl = false,
    bool clearLyrics = false,
    bool clearGenreId = false,
    bool clearArtist = false,
  }) {
    return Song(
      id: id ?? this.id,
      artistId: clearArtistId ? null : (artistId ?? this.artistId),
      albumId: clearAlbumId ? null : (albumId ?? this.albumId),
      title: clearTitle ? null : (title ?? this.title),
      duration: duration ?? this.duration,
      fileUrl: clearFileUrl ? null : (fileUrl ?? this.fileUrl),
      coverArtUrl: clearCoverArtUrl ? null : (coverArtUrl ?? this.coverArtUrl),
      lyrics: clearLyrics ? null : (lyrics ?? this.lyrics),
      genreId: clearGenreId ? null : (genreId ?? this.genreId),
      genres: genres ?? this.genres,
      trackNumber: trackNumber ?? this.trackNumber,
      status: status ?? this.status,
      isExplicit: isExplicit ?? this.isExplicit,
      releaseDate: releaseDate ?? this.releaseDate,
      totalStreams: totalStreams ?? this.totalStreams,
      totalLikes: totalLikes ?? this.totalLikes,
      totalShares: totalShares ?? this.totalShares,
      featured: featured ?? this.featured,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      artist: clearArtist ? null : (artist ?? this.artist),
    );
  }

  String get durationFormatted {
    if (duration == null || duration! <= 0) return '00:00';
    
    // Validar que no sea infinito o NaN
    final durationValue = duration!.toDouble();
    if (!durationValue.isFinite || durationValue.isNaN) return '00:00';
    
    final totalSeconds = durationValue.toInt();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  bool get isPublished => status == SongStatus.published;

  /// ✅ VALIDAR SI LA CANCIÓN ES VÁLIDA PARA REPRODUCCIÓN
  /// Verifica que tenga fileUrl válido y no sea una URL de ejemplo
  /// 🎯 NOTA: Movido desde extensión a clase directamente para evitar problemas en runtime
  bool get isValidForPlayback {
    if (fileUrl == null || fileUrl!.isEmpty) {
      return false;
    }
    
    // Excluir URLs de ejemplo o placeholder
    final url = fileUrl!.toLowerCase();
    if (url.contains('example.com') || 
        url.contains('picsum.photos') ||
        url.contains('placeholder') ||
        url.contains('test') ||
        url.startsWith('http://example') ||
        url.startsWith('https://example')) {
      return false;
    }
    
    // Verificar que sea una URL válida
    try {
      final uri = Uri.parse(fileUrl!);
      if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
        return false;
      }
    } catch (e) {
      return false;
    }
    
    return true;
  }
}

@JsonSerializable(
  fieldRename: FieldRename.snake,
  explicitToJson: true,
  includeIfNull: false,
)
class FeaturedSong {
  final Song song;
  final String? featuredReason;
  final int rank;

  const FeaturedSong({
    required this.song,
    this.featuredReason,
    required this.rank,
  });

  factory FeaturedSong.fromJson(Map<String, dynamic> json) => _$FeaturedSongFromJson(json);
  Map<String, dynamic> toJson() => _$FeaturedSongToJson(this);
}

/// Extensión para convertir Song a AudioSource de just_audio
extension SongToAudioSource on Song {
  /// Convierte una canción a AudioSource para just_audio
  /// Normaliza la URL automáticamente para emulador Android
  AudioSource toAudioSource() {
    if (!isValidForPlayback) {
      throw Exception('La canción no tiene URL de archivo válida: ${title ?? id} (fileUrl: ${fileUrl ?? "null"})');
    }

    // Normalizar URL para emulador Android (localhost -> 10.0.2.2)
    final normalizedUrl = UrlNormalizer.normalizeUrl(fileUrl!);
    final uri = Uri.parse(normalizedUrl);

    return AudioSource.uri(
      uri,
      tag: this, // Permite recuperar el objeto Song del reproductor
    );
  }
}
