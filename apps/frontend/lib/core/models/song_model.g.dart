// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'song_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Song _$SongFromJson(Map<String, dynamic> json) => Song(
      id: json['id'] as String,
      artistId: json['artist_id'] as String?,
      albumId: json['album_id'] as String?,
      title: json['title'] as String?,
      duration: (json['duration'] as num?)?.toInt(),
      fileUrl: json['file_url'] as String?,
      coverArtUrl: json['cover_art_url'] as String?,
      lyrics: json['lyrics'] as String?,
      genreId: json['genre_id'] as String?,
      genres:
          (json['genres'] as List<dynamic>?)?.map((e) => e as String).toList(),
      trackNumber: (json['track_number'] as num?)?.toInt(),
      status: $enumDecodeNullable(_$SongStatusEnumMap, json['status']) ??
          SongStatus.draft,
      isExplicit: json['is_explicit'] as bool? ?? false,
      releaseDate: json['release_date'] == null
          ? null
          : DateTime.parse(json['release_date'] as String),
      totalStreams: (json['total_streams'] as num?)?.toInt() ?? 0,
      totalLikes: (json['total_likes'] as num?)?.toInt() ?? 0,
      totalShares: (json['total_shares'] as num?)?.toInt() ?? 0,
      featured: json['featured'] as bool? ?? false,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      artist: json['artist'] == null
          ? null
          : Artist.fromJson(json['artist'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$SongToJson(Song instance) {
  final val = <String, dynamic>{
    'id': instance.id,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('artist_id', instance.artistId);
  writeNotNull('album_id', instance.albumId);
  writeNotNull('title', instance.title);
  writeNotNull('duration', instance.duration);
  writeNotNull('file_url', instance.fileUrl);
  writeNotNull('cover_art_url', instance.coverArtUrl);
  writeNotNull('lyrics', instance.lyrics);
  writeNotNull('genre_id', instance.genreId);
  writeNotNull('genres', instance.genres);
  writeNotNull('track_number', instance.trackNumber);
  val['status'] = _$SongStatusEnumMap[instance.status]!;
  val['is_explicit'] = instance.isExplicit;
  writeNotNull('release_date', instance.releaseDate?.toIso8601String());
  val['total_streams'] = instance.totalStreams;
  val['total_likes'] = instance.totalLikes;
  val['total_shares'] = instance.totalShares;
  val['featured'] = instance.featured;
  writeNotNull('created_at', instance.createdAt?.toIso8601String());
  writeNotNull('updated_at', instance.updatedAt?.toIso8601String());
  writeNotNull('artist', instance.artist?.toJson());
  return val;
}

const _$SongStatusEnumMap = {
  SongStatus.draft: 'draft',
  SongStatus.published: 'published',
  SongStatus.archived: 'archived',
};

FeaturedSong _$FeaturedSongFromJson(Map<String, dynamic> json) => FeaturedSong(
      song: Song.fromJson(json['song'] as Map<String, dynamic>),
      featuredReason: json['featured_reason'] as String?,
      rank: (json['rank'] as num).toInt(),
    );

Map<String, dynamic> _$FeaturedSongToJson(FeaturedSong instance) {
  final val = <String, dynamic>{
    'song': instance.song.toJson(),
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('featured_reason', instance.featuredReason);
  val['rank'] = instance.rank;
  return val;
}
