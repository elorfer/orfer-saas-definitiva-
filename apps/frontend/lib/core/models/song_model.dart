import 'package:json_annotation/json_annotation.dart';
import 'artist_model.dart';

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
