import 'package:json_annotation/json_annotation.dart';
import 'package:just_audio/just_audio.dart';
import 'artist_model.dart';
import '../utils/url_normalizer.dart';

part 'song_model.g.dart';

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

  factory Song.fromJson(Map<String, dynamic> json) => _$SongFromJson(json);
  Map<String, dynamic> toJson() => _$SongToJson(this);

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
  /// ✅ VALIDAR SI LA CANCIÓN ES VÁLIDA PARA REPRODUCCIÓN
  /// Verifica que tenga fileUrl válido y no sea una URL de ejemplo
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
