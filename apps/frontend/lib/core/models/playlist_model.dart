import 'package:json_annotation/json_annotation.dart';
import 'user_model.dart';
import 'song_model.dart';

part 'playlist_model.g.dart';

enum PlaylistType {
  @JsonValue('user')
  user,
  @JsonValue('featured')
  featured,
  @JsonValue('genre')
  genre,
  @JsonValue('mood')
  mood,
}

enum PlaylistVisibility {
  @JsonValue('public')
  public,
  @JsonValue('private')
  private,
  @JsonValue('unlisted')
  unlisted,
}

/// Convertir número a int de forma segura, validando Infinity y NaN
int? _safeIntFromJson(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) {
    final doubleValue = value.toDouble();
    // Validar que no sea infinito o NaN antes de convertir a int
    if (!doubleValue.isFinite || doubleValue.isNaN) {
      return null;
    }
    return doubleValue.toInt();
  }
  return null;
}

@JsonSerializable(
  explicitToJson: true,
  includeIfNull: false,
)
class PlaylistSong {
  final String id;
  final String playlistId;
  final String songId;
  final int position;
  final DateTime? addedAt;
  final Song? song;

  const PlaylistSong({
    required this.id,
    required this.playlistId,
    required this.songId,
    required this.position,
    this.addedAt,
    this.song,
  });

  factory PlaylistSong.fromJson(Map<String, dynamic> json) => _$PlaylistSongFromJson(json);
  Map<String, dynamic> toJson() => _$PlaylistSongToJson(this);
}

@JsonSerializable(
  explicitToJson: true,
  includeIfNull: false,
)
class Playlist {
  final String id;
  final String? userId;
  final String? name;
  final String? description;
  final String? coverArtUrl;
  final PlaylistType? type;
  final PlaylistVisibility? visibility;
  final bool? isPublic;
  final bool? isFeatured;
  final int? totalTracks;
  final int? totalFollowers;
  @JsonKey(fromJson: _safeIntFromJson)
  final int? totalDuration;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final User? user;
  @JsonKey(name: 'playlistSongs')
  final List<PlaylistSong>? playlistSongs;

  const Playlist({
    required this.id,
    this.userId,
    this.name,
    this.description,
    this.coverArtUrl,
    this.type,
    this.visibility,
    this.isPublic,
    this.isFeatured,
    this.totalTracks,
    this.totalFollowers,
    this.totalDuration,
    this.createdAt,
    this.updatedAt,
    this.user,
    this.playlistSongs,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) => _$PlaylistFromJson(json);
  Map<String, dynamic> toJson() => _$PlaylistToJson(this);

  /// Obtener las canciones de la playlist
  List<Song> get songs {
    if (playlistSongs == null || playlistSongs!.isEmpty) return [];
    
    // Ordenar por posición y extraer las canciones
    final sortedPlaylistSongs = List<PlaylistSong>.from(playlistSongs!)
      ..sort((a, b) => a.position.compareTo(b.position));
    
    return sortedPlaylistSongs
        .where((ps) => ps.song != null)
        .map((ps) => ps.song!)
        .toList();
  }

  String get durationFormatted {
    if (totalDuration == null || totalDuration! <= 0) return '0m';
    
    // Validar que no sea infinito o NaN
    final duration = totalDuration!.toDouble();
    if (!duration.isFinite || duration.isNaN) return '0m';
    
    final totalSeconds = duration.toInt();
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}

@JsonSerializable(
  fieldRename: FieldRename.snake,
  explicitToJson: true,
  includeIfNull: false,
)
class FeaturedPlaylist {
  final Playlist playlist;
  final String? featuredReason;
  final int rank;

  const FeaturedPlaylist({
    required this.playlist,
    this.featuredReason,
    required this.rank,
  });

  factory FeaturedPlaylist.fromJson(Map<String, dynamic> json) => _$FeaturedPlaylistFromJson(json);
  Map<String, dynamic> toJson() => _$FeaturedPlaylistToJson(this);
}
